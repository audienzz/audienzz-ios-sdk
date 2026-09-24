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
    internal var adUnit: AdUnit!
    internal var gamRequest: AnyObject?
    internal var eventHandler: AUBannerHandler?
    internal struct GoogleLoad {
        let auction: Int
        let refresh: Int
    }
    internal var googleLoad: GoogleLoad?
    internal var googleLoadTimeout: DispatchWorkItem?
    internal var googleLoadTimeoutSeconds: TimeInterval = 120
    internal var creativePageGeneration = 0
    internal var renderAuctionId: String?
    internal var googleEventPageGeneration: Int?
    internal var acceptsGoogleEvents: Bool {
        googleEventPageGeneration == creativePageGeneration && screenActive && !refreshController.isDestroyed
    }
    internal var pendingLoadReason: AURefreshRequestReason?

    /// Placement name used in the delivery trace. Defaults to the Prebid config id; a remote-config
    /// owner overrides it with its ad config id so both halves of the trace name the same slot.
    internal var tracePlacement: String?

    /// Distinguishes two banners serving the same placement, and survives every auction this
    /// banner runs. Auction counters alone collide across slots and restart on replacement.
    internal let traceSlotId = String(UUID().uuidString.prefix(8))

    /// Identity of the delivery currently being fetched, and of the one currently rendered.
    ///
    /// Held separately because they diverge: while a refresh is in flight the previous creative is
    /// still on screen, so its impression belongs to the delivery that produced it — reading the
    /// live auction counter labelled it as the new one.
    internal var pendingDeliveryId: String?
    internal var renderedDeliveryId: String?


    internal var demandFormats: Set<PrebidMobile.AdFormat> = [.banner]

    /// Whether each auction asks Prebid for a bid before loading GAM. `false` serves GAM-only: no
    /// Prebid request is sent and no bidRequest/bidResponse/bidWon/noBid event is reported, while
    /// refresh, page ownership, blanking and targeting behave as usual. Set it before the first load.
    ///
    /// A remote-config placement with no Prebid sizes turns this off. Handing Prebid a `.zero` size
    /// instead did not skip header bidding: stock Prebid only rejects negative sizes, so every
    /// auction still sent a request that could never be filled.
    public var headerBiddingEnabled: Bool = true

    /// Asks Prebid for demand. A seam so a test can see whether an auction reached Prebid at all.
    @nonobjc internal var demand: (AdUnit, AdManagerRequest, @escaping (ResultCode) -> Void) -> Void = {
        unit, request, completion in unit.fetchDemand(adObject: request, completion: completion)
    }

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
    /// How many times this slot has (re)loaded. Internal only.
    ///
    /// What is REPORTED is ``emittedSlotReload``, a binary flag. The counter itself used to be the
    /// reported value, so a slot that refreshed four times emitted `slot_reload` 0,1,2,3 — the
    /// collector's contract is "first load or not".
    internal var slotReloadCount: Int = 0

    /// `slot_reload` as the collector defines it: `0` for a slot's first load, `1` for every load
    /// after it. Serialized as a string, like the other `attributes` values.
    internal var emittedSlotReload: Int { slotReloadCount > 0 ? 1 : 0 }

    /// Economics of the creative CURRENTLY ON SCREEN, snapshotted when Google confirmed it rendered.
    ///
    /// Render events must describe the creative the reader is actually looking at. Reading the most
    /// recent auction instead meant that as soon as a replacement's Prebid response arrived — or as
    /// soon as it failed and cleared these fields — a late impression, click or viewability
    /// callback belonging to the creative still on screen was reported under the replacement's
    /// auction id, cpm, creative and bidder.
    internal var displayedEconomics: AURenderEconomics?

    /// The Prebid seat that won the auction behind the DISPLAYED creative, and whether that seat's
    /// GAM line item is what actually rendered.
    ///
    /// Snapshotted alongside ``displayedEconomics`` rather than read live, because starting the
    /// next auction resets the live values — which would silently re-attribute a creative that is
    /// still on screen.
    internal var displayedPrebidBidder: String?
    internal var displayedPrebidLineItemWon: Bool = false

    /// The single owner of periodic refresh for this banner. Prebid is never given an interval —
    /// its `Dispatcher` is created only by `AdUnit.setAutoRefreshMillis`, which the SDK no longer
    /// calls — so nothing else schedules a request.
    internal private(set) lazy var refreshController: AURefreshController = AURefreshController(
        label: configId
    ) { [weak self] reason, generation in
        self?.onRefreshDue(reason, generation)
    }

    /// Issues the request the controller asked for, re-checking that it is still wanted.
    /// Internal rather than private so a test can exercise the request-time gate itself, instead
    /// of the geometry helper it calls.
    internal func onRefreshDue(_ reason: AURefreshRequestReason, _ generation: Int) {
        guard generation == refreshController.generation else { return }
        guard let request = gamRequest as? AdManagerRequest else { return }
        // Re-read the geometry rather than trusting the cached verdict. The viewport flag is only
        // as current as the last signal that happened to be observed, and a request is the one
        // moment where being wrong costs money — so a periodic refresh confirms the ad is still
        // eligible at the instant it would be spent. A first load is deliberately exempt: it is
        // allowed to prefetch before the ad is on screen.
        // Recompute through the transition, not through a read-only check. A bare read told the
        // truth about geometry but left the cached verdict saying "eligible" while a hold was
        // recorded against it — so returning on an observed signal produced no false-to-true
        // transition, nothing cleared the hold, and the banner stayed paused on screen. Going
        // through `refreshVisibilityNow()` moves both together, which is the property that makes
        // the hold releasable by the same path that would have prevented it.
        if reason == .periodicRefresh, smartRefresh {
            refreshVisibilityNow()
        }
        if reason == .periodicRefresh, smartRefresh, !isViewRefreshEligible {
            AULogEvent.logDebug("[AUBannerView] \(configId) — refresh due but no longer visible; holding")
            refreshController.block(.notVisible)
            return
        }
        fetchRequest(request, reason: reason)
    }

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

    /// Route the publisher-facing refresh API into the controller.
    ///
    /// Installed at construction rather than at `createAd`, because both a publisher and
    /// `AURemoteConfigBannerView` configure refresh on the view as soon as it exists — well before
    /// the ad is built, and in the remote-config case asynchronously afterwards too.
    private func wireRefreshConfiguration() {
        guard let configuration = adUnitConfiguration as? AUAdUnitConfiguration else { return }
        adLoadCompletion = { [weak self] rendered, retryable in
            _ = self?.completeGoogleLoad(received: rendered, retryableFailure: retryable)
        }
        configuration.autorefreshIntervalObserver = { [weak self] millis in
            self?.refreshController.setIntervalMillis(millis)
        }
        configuration.autorefreshPauseObserver = { [weak self] paused in
            guard let self else { return }
            if paused {
                self.refreshController.block(.publisher)
            } else {
                self.refreshController.unblock(.publisher, schedule: false)
                self.resumeEligibleWork()
            }
        }
    }

    /**
     Initialize banner view
     Lazy load is true by default.
     */
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat]) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: true)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)

        self.demandFormats = Set(unwrapAdFormat(adFormats))
        (self.adUnit as? BannerAdUnit)?.adFormats = demandFormats
        wireRefreshConfiguration()
    }

    /**
     Initialize banner view
     Lazy load is optional to set if needed.
     */
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat], isLazyLoad: Bool) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: isLazyLoad)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)

        self.demandFormats = Set(unwrapAdFormat(adFormats))
        (self.adUnit as? BannerAdUnit)?.adFormats = demandFormats
        wireRefreshConfiguration()
    }

    /// Shared banner lifecycle for native demand rendered into a GAM banner.
    internal init(configId: String, demandUnit: AdUnit, isLazyLoad: Bool) {
        super.init(configId: configId, adSize: .zero, isLazyLoad: isLazyLoad)
        self.adUnit = demandUnit
        self.demandFormats = [.native]
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: demandUnit)
        wireRefreshConfiguration()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Once the banner is in a window its responder chain resolves, so a banner that was created
    /// before its screen's `pageImpression` — and therefore looked host-less to the page sweep —
    /// can be adopted into the current page instead of staying dormant.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            // A detached view cannot render, so a refresh into it would be an impression-less
            // request. Re-attaching clears only this reason.
            onDetachedFromWindow()
            return
        }
        onAttachedToWindow()
        AUScreenAdCoordinator.shared.adoptIfOnActiveScreen(self)
    }

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        AUScreenAdCoordinator.shared.deregister(self)
        googleLoadTimeout?.cancel()
        googleLoadTimeout = nil
        googleLoad = nil
        refreshController.destroy()
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
        googleLoadTimeout?.cancel()
        googleLoadTimeout = nil
        googleLoad = nil
        refreshController.destroy()
        self.adUnit = nil
        self.gamRequest = nil
        self.eventHandler = nil
    }
    
    public func addAdditionalSize(sizes: [CGSize]) {
        (adUnit as? BannerAdUnit)?.addAdditionalSize(sizes: sizes)
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

    /// Containers are supported. Multiple banners require an explicit event handler so we
    /// cannot silently observe the wrong slot. Custom renderers use notifyAdLoadCompleted.
    internal static func singleGoogleBanner(in root: UIView) -> AdManagerBannerView? {
        var matches: [AdManagerBannerView] = []
        func visit(_ view: UIView) {
            if let banner = view as? AdManagerBannerView { matches.append(banner); return }
            view.subviews.forEach(visit)
        }
        visit(root)
        return matches.count == 1 ? matches[0] : nil
    }

    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AdManagerRequest, gamBanner: UIView, eventHandler: AUBannerEventHandler? = nil) {
        if let bannerUnit = adUnit as? BannerAdUnit {
            if let parameters = bannerParameters {
                bannerUnit.bannerParameters = parameters.makeBannerParameters()
            } else {
                let parameters = BannerParameters()
                parameters.api = [Signals.Api.MRAID_1, Signals.Api.MRAID_2, Signals.Api.MRAID_3, Signals.Api.OMID_1]
                bannerUnit.bannerParameters = parameters
            }
            bannerUnit.videoParameters = self.videoParameters?.unwrap() ?? defaultVideoParameters()
        }
        addSubview(gamBanner)
        // Keep the GAM banner centered in this host; a creative narrower than the host
        // (full-width/tablet slot, or a multisize slot filled smaller) would otherwise
        // render at the leading edge. See AUAdView.layoutSubviews.
        centeredAdSubview = gamBanner
        setNeedsLayout()
        
        let ppid = PPIDManager.shared.getPPID()
        
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }

        // Kept as the publisher passed it. Global targeting and the SDK's keys are added to a copy
        // for every auction (AUAuctionTargeting), so they stay current and this object is untouched.
        self.gamRequest = gamRequest

        // The event wrapper is optional; GAM completion ownership is not.
        if let googleView = eventHandler?.gamView ?? Self.singleGoogleBanner(in: gamBanner) {
            if self.eventHandler?.gamView !== googleView {
                self.eventHandler = AUBannerHandler(auBannerView: self, gamView: googleView)
            }
            self.eventHandler?.ensureListeners()
        } else {
            AULogEvent.logWarn("[AUBannerView] No unique Google banner found; supply AUBannerEventHandler or call notifyAdLoadCompleted for custom renderers")
        }
        if window == nil { refreshController.block(.detached) }
        Audienzz.shared.observeForegroundReimpression()
        if Audienzz.shared.isAppBackgrounded { refreshController.block(.appBackground) }

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
            refreshController.block(.pageInactive)
            return
        }

        if !self.isLazyLoad {
            fetchRequest(gamRequest, reason: .firstLoad)
        } else {
            loadIfAlreadyVisible()
        }
    }
}
