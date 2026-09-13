/*   Copyright 2018-2025 Audienzz.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit
import PrebidMobile
import GoogleMobileAds

/**
 AUBannerView.
 Ad view for demand  banner and/or video.
 Lazy load is true by default.
 */
@objcMembers
public class AUBannerView: AUAdView {
    internal var adUnit: BannerAdUnit!
    internal var gamRequest: AnyObject?
    internal var eventHandler: AUBannerHandler?

    public var videoParameters: AUVideoParameters?
    public var bannerParameters: AUBannerParameters?

    /// The creative size determined by the last winning Prebid bid.
    /// Populated from `hb_size` in the GAM request's `customTargeting` after `fetchDemand`
    /// completes — no WKWebView dependency. `nil` when Prebid did not win or `hb_size` is absent.
    /// Reliable alternative to `AUAdViewUtils.findCreativeSize` for multisize banner resizing.
    public internal(set) var lastPrebidCreativeSize: CGSize?

    /// Render-winner attribution for analytics `adImpression`. `prebidWinningBidder` is the Prebid
    /// auction winner (hb_bidder); `prebidLineItemWon` is set by the GAM app-event listener when the
    /// Prebid line item renders. Both reset per auction.
    internal var prebidWinningBidder: String?
    internal var prebidLineItemWon: Bool = false

    /// Winning-bid economics from the last auction, reused on adImpression/adClick/viewability.
    internal var lastRenderEconomics: AURenderEconomics?
    /// SDK-generated auction id, minted at auction start and reused across every event of that
    /// auction (bidRequest → bidResponse/bidWon/noBid → adImpression/adClick/viewability). Prebid
    /// only assigns its own id after the request, so we pre-generate one for full-funnel counting.
    internal var currentAuctionId: String?
    /// Currency + value captured from the GMA paid event (`AdValue`), which fires around impression.
    /// Backfills `currency` (and cpm on a direct fill) on the render events, since exact economics
    /// aren't available on the original API without the Prebid fork.
    internal var lastPaidCurrency: String?
    internal var lastPaidCpm: Double?
    /// Number of times this slot has (re)loaded — reported as `slot_reload`. First load = 0.
    internal var slotReloadCount: Int = 0

    /// Viewability tracker for the current creative; restarted on each `adImpression`.
    internal var viewabilityTracker: AUViewabilityTracker?

    /// Cached host UIViewController (the "screen") for smart-refresh-v2 screen matching.
    private weak var cachedHostVC: UIViewController?

    /// Set while the GAM banner is hidden for a screen-change reload (see `blankOnScreenReload`);
    /// the handler restores visibility when the fresh ad is received.
    internal var blankedForReload = false

    /// Caller-supplied screen token (a route key) for hosts not inferable from the responder chain —
    /// SwiftUI destinations, or a custom navigation model. Wins over view-controller resolution.
    internal var hostScreenOverride: AnyObject?

    /// Associate this banner with a screen the SDK can't infer from the view hierarchy (a SwiftUI
    /// destination, or a custom route). Pass the same token you report to
    /// `Audienzz.shared.pageImpression(token)` — typically the route-key `String`; it's matched by
    /// value, so the key reported on resume and the one set here just have to be equal. Not needed
    /// for `UIViewController`-hosted banners (those are resolved automatically via the responder chain).
    public func setScreen(_ screenKey: Any) {
        hostScreenOverride = screenKey as AnyObject
    }

    /// True when this ad lives on `screen`. An explicit `hostScreenOverride` (route key) matches by
    /// value; otherwise the host `UIViewController` matches by identity.
    internal func isHostedBy(_ screen: AnyObject) -> Bool {
        if let override = hostScreenOverride {
            if override === screen { return true }
            if let a = override as? NSObject, let b = screen as? NSObject { return a.isEqual(b) }
            return false
        }
        guard let host = resolveHostViewController() else { return false }
        return host === screen
    }

    /// Smart-refresh v2 uses the directional viewport gate; legacy uses the base ≥20% gate.
    internal override var usesDirectionalRefreshGate: Bool {
        Audienzz.shared.isSmartRefreshV2Enabled
    }

    /// The nearest `UIViewController` up the responder chain — this banner's "screen". Cached once
    /// resolved (nil is not cached, since the responder chain is only reliable once in a window).
    internal func resolveHostViewController() -> UIViewController? {
        if let cached = cachedHostVC { return cached }
        var responder: UIResponder? = self.next
        while let current = responder {
            if let vc = current as? UIViewController {
                cachedHostVC = vc
                return vc
            }
            responder = current.next
        }
        return nil
    }

    /**
     Initialize banner view
     Lazy load is true by default.
     */
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat]) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: true)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)

        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }

    /**
     Initialize banner view
     Lazy load is optional to set if needed.
     */
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat], isLazyLoad: Bool) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: isLazyLoad)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)

        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Once the banner is in a window its responder chain resolves, so a banner that was created
    /// before its screen's `pageImpression` — and therefore looked host-less to the page sweep —
    /// can be adopted into the current page instead of staying dormant.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        AUScreenAdCoordinator.shared.adoptIfOnActiveScreen(self)
    }

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        AUScreenAdCoordinator.shared.deregister(self)
        adUnit?.stopAutoRefresh()
        self.adUnit = nil
        self.gamRequest = nil
        self.eventHandler = nil
    }

    /// Explicitly tears down the ad: stops auto-refresh and releases the Prebid
    /// ad unit, GAM request, and event handler. Prefer this over relying on
    /// `removeFromSuperview` as a destructor — call it when you're done with the
    /// ad (e.g. the owning controller's `deinit`). Safe to call more than once.
    public func destroy() {
        AUScreenAdCoordinator.shared.deregister(self)
        adUnit?.stopAutoRefresh()
        self.adUnit = nil
        self.gamRequest = nil
        self.eventHandler = nil
    }
    
    public func addAdditionalSize(sizes: [CGSize]) {
        adUnit.addAdditionalSize(sizes: sizes)
    }
    
    public func setImpOrtbConfig(ortbConfig: String){
        adUnit.setImpORTBConfig(ortbConfig)
    }
    
    public func getImpOrtbConfig() -> String? {
        return adUnit.getImpORTBConfig()
    }

    /// Returns a correctly-encoded `NSValue` array ready to assign to
    /// `AdManagerBannerView.validAdSizes`.
    ///
    /// Use this instead of `NSValue(cgSize:)`, which wraps a plain `CGSize` and
    /// causes GAM to silently ignore all additional sizes — resulting in only the
    /// primary declared `adSize` ever being served (and multi-size banners being
    /// clipped to the primary height).
    ///
    /// Example usage:
    /// ```swift
    /// gamBanner.validAdSizes = AUBannerView.validAdSizes(for: [
    ///     CGSize(width: 320, height: 50),
    ///     CGSize(width: 300, height: 250)
    /// ])
    /// ```
    public static func validAdSizes(for sizes: [CGSize]) -> [NSValue] {
        sizes.map { nsValue(for: adSizeFor(cgSize: $0)) }
    }

    deinit {
        self.eventHandler = nil
    }

    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AdManagerRequest, gamBanner: UIView, eventHandler: AUBannerEventHandler? = nil) {
        if let parameters = bannerParameters {
            adUnit.bannerParameters = parameters.makeBannerParameters()
        } else {
            let parameters = BannerParameters()
            parameters.api = [Signals.Api.MRAID_1, Signals.Api.MRAID_2, Signals.Api.MRAID_3, Signals.Api.OMID_1]
            adUnit.bannerParameters = parameters
        }
        addSubview(gamBanner)

        adUnit.videoParameters = self.videoParameters?.unwrap() ?? defaultVideoParameters()
        
        let ppid = PPIDManager.shared.getPPID()
        
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }

        self.gamRequest = AUTargeting.shared.customTargetingManager.applyToGamRequest(request: gamRequest)

        if let bannerEventHandler = eventHandler {
            self.eventHandler = AUBannerHandler(auBannerView: self, gamView: bannerEventHandler.gamView)
        }

        // Join the current page. The epoch stamp is what lets the coordinator tell this screen's
        // banners from a previous screen's on the next page impression.
        AUScreenAdCoordinator.shared.register(self)
        screenActive = AUScreenAdCoordinator.shared.isActiveScreen(for: self)
        pageEpoch = AUScreenAdCoordinator.shared.epoch

        // A non-lazy banner must still respect page ownership: asynchronous setup can finish after
        // the user has moved to another screen, and firing here would auction for a page they left.
        // `recreateForPage` picks it up when its page comes back.
        guard screenActive else {
            AULogEvent.logDebug("[AUBannerView] \(configId) created for a non-active page — deferring first load")
            return
        }

        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        } else {
            loadIfAlreadyVisible()
        }
    }
}
