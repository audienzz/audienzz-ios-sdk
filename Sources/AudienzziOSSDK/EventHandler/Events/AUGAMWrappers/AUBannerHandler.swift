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

import Foundation
import GoogleMobileAds

@objcMembers
public class AUBannerEventHandler: NSObject {
    let adUnitId: String
    let gamView: AdManagerBannerView

    public init(adUnitId: String, gamView: AdManagerBannerView) {
        self.adUnitId = adUnitId
        self.gamView = gamView
    }
}

class AUBannerHandler: NSObject,
    BannerViewDelegate,
    AppEventDelegate,
    AdSizeDelegate,
    AULogEventType
{

    // weak: AUBannerView strongly holds this handler via `eventHandler`. A strong
    // back-reference here formed a retain cycle that leaked the view, its GAM view
    // and WKWebView, and the Prebid ad unit — and the leaked dispatcher kept
    // auctioning an invisible, detached ad indefinitely.
    weak var auBannerView: AUBannerView?
    let gamView: AdManagerBannerView!
    weak var bannerDelegate: BannerViewDelegate?
    weak var eventDelegate: AppEventDelegate?
    weak var sizeDelegate: AdSizeDelegate?

    /// The actual ad size GAM will render, captured from `willChangeAdSizeTo` which fires
    /// synchronously before `bannerViewDidReceiveAd`. At that point `gamView.adSize` is not
    /// yet updated — the delegate parameter is the only reliable source of the chosen size.
    /// Consumed and cleared in `bannerViewDidReceiveAd`.
    private var pendingGAMSize: CGSize?

    init(auBannerView: AUBannerView, gamView: AdManagerBannerView) {
        self.auBannerView = auBannerView
        self.gamView = gamView
        self.bannerDelegate = gamView.delegate
        self.eventDelegate = gamView.appEventDelegate
        self.sizeDelegate = gamView.adSizeDelegate
        super.init()
        addListener()
    }

    var adUnitID: String? {
        self.gamView.adUnitID
    }

    func ensureListeners() {
        if gamView.delegate !== self { bannerDelegate = gamView.delegate; gamView.delegate = self }
        if gamView.appEventDelegate !== self { eventDelegate = gamView.appEventDelegate; gamView.appEventDelegate = self }
        if gamView.adSizeDelegate !== self { sizeDelegate = gamView.adSizeDelegate; gamView.adSizeDelegate = self }
    }

    private func addListener() {
        self.gamView.delegate = self
        self.gamView.appEventDelegate = self
        self.gamView.adSizeDelegate = self
        // GMA reports the impression's paid value + currency here (the only fork-free currency
        // source). Stash it on the view so the render events can carry currency (and cpm on a
        // direct fill). Fires around impression, so it lands on adImpression/adClick/viewability.
        self.gamView.paidEventHandler = { [weak auBannerView] adValue in
            guard auBannerView?.acceptsGoogleEvents == true else { return }
            auBannerView?.lastPaidCurrency = adValue.currencyCode
            auBannerView?.lastPaidCpm = adValue.value.doubleValue
        }
    }

    deinit {
        AULogEvent.logDebug("AUBannerHandler")
    }

    /// Reveals the GAM banner again after a `blankOnScreenReload` blanking, once the fresh ad
    /// arrives (or fails). No-op unless this slot blanked itself.
    private func restoreFromBlankIfNeeded() {
        auBannerView?.restoreFromBlankIfNeeded()
    }

    // MARK: - GADBannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        auBannerView.map {
            AUAdTrace.log(placement: $0.tracePlacement ?? $0.configId, delivery: $0.pendingDeliveryId,
                          event: .googleLoaded, visible: $0.isViewRefreshEligible)
        }
        guard auBannerView?.completeGoogleLoad(received: true, retryableFailure: false) == true else { return }
        LogEvent("bannerViewDidReceiveAd")
        // This is the moment the replacement becomes what the reader sees, so it is the moment its
        // economics become the ones render events describe.
        auBannerView?.commitDisplayedCreative()
        restoreFromBlankIfNeeded()

        if let gamBannerView = bannerView as? AdManagerBannerView {
            // Determine the actual rendered size using two sources:
            // 1. pendingGAMSize — set by willChangeAdSizeTo, which fires synchronously
            //    before this callback whenever GAM renders at a size different from the
            //    primary declared adSize (whether a Prebid creative or GAM's own ad).
            //    gamView.adSize is NOT yet updated at that point, so the delegate parameter
            //    is the only reliable source.
            // 2. gamBannerView.adSize.size — used when willChangeAdSizeTo did not fire,
            //    meaning GAM served exactly the primary declared adSize. In that case
            //    adSize is still the original primary value and is correct.
            // Note: lastPrebidCreativeSize (hb_size from Prebid targeting) is intentionally
            // excluded. When Prebid wins at a non-primary size willChangeAdSizeTo fires and
            // pendingGAMSize covers it. When Prebid wins at the primary size adSize.size is
            // correct. Using lastPrebidCreativeSize as a fallback caused all banners to be
            // sized to the Prebid bid size even when GAM served its own ad at the primary size.
            let actualSize = pendingGAMSize ?? gamBannerView.adSize.size

            if actualSize != .zero {
                gamBannerView.resize(adSizeFor(cgSize: actualSize))
                auBannerView?.onAdSizeChanged?(actualSize)
            }
        }
        pendingGAMSize = nil

        bannerDelegate?.bannerViewDidReceiveAd?(bannerView)
    }
    func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: any Error
    ) {
        let failure = error as NSError
        let retryable = failure.domain == GADErrorDomain &&
            [RequestError.networkError.rawValue, RequestError.serverError.rawValue,
             RequestError.timeout.rawValue, RequestError.internalError.rawValue].contains(failure.code)
        auBannerView.map {
            AUAdTrace.log(placement: $0.tracePlacement ?? $0.configId, delivery: $0.pendingDeliveryId,
                          event: .googleFailed, detail: retryable ? "retryable" : "terminal")
        }
        guard auBannerView?.completeGoogleLoad(received: false, retryableFailure: retryable) == true else { return }
        LogEvent("didFailToReceiveAdWithError")
        LogEvent(error.localizedDescription)
        restoreFromBlankIfNeeded()
        bannerDelegate?.bannerView?(
            bannerView,
            didFailToReceiveAdWithError: error
        )
    }

    /// Tells the delegate that an impression has been recorded for an ad.
    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        auBannerView.map {
            AUAdTrace.log(placement: $0.tracePlacement ?? $0.configId, delivery: $0.renderedDeliveryId,
                          event: .googleImpression, visible: $0.isViewRefreshEligible)
        }
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("bannerViewDidRecordImpression")
        AUEventsManager.shared.adImpression(
            adUnitId: adUnitID ?? "",
            adType: AUAdType.banner,
            adSubtype: auBannerView?.makeAdSubType() ?? "",
            apiType: AUEventApiType.original,
            adViewId: auBannerView?.configId ?? "",
            economics: renderEconomics()
        )
        auBannerView?.startViewabilityTracking()
        bannerDelegate?.bannerViewDidRecordImpression?(bannerView)
    }

    /// Tells the delegate that a click has been recorded for the ad.
    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("bannerViewDidRecordClick")
        AUEventsManager.shared.adClick(
            adUnitId: adUnitID ?? "",
            adType: AUAdType.banner,
            adSubtype: auBannerView?.makeAdSubType() ?? "",
            apiType: AUEventApiType.original,
            adViewId: auBannerView?.configId ?? "",
            economics: renderEconomics()
        )
        bannerDelegate?.bannerViewDidRecordClick?(bannerView)
    }

    /// Economics reported on render events. Delegates to the view's shared resolver so impression,
    /// click and viewability all attribute the same render winner (Prebid line item only when its
    /// GAM app event fired, else the ad server) and carry the SDK-minted auction id.
    private func renderEconomics() -> AURenderEconomics {
        auBannerView?.resolvedRenderEconomics() ?? AURenderEconomics()
    }

    // MARK: - Click-Time

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("bannerViewWillPresentScreen")
        bannerDelegate?.bannerViewWillPresentScreen?(bannerView)
    }

    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("bannerViewWillDismissScreen")
        bannerDelegate?.bannerViewWillDismissScreen?(bannerView)
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("bannerViewDidDismissScreen")
        bannerDelegate?.bannerViewDidDismissScreen?(bannerView)
    }

    // MARK: - GADAppEventDelegate
    func adView(
        _ banner: BannerView,
        didReceiveAppEvent name: String,
        with info: String?
    ) {
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("didReceiveAppEvent")
        // A Prebid line item's creative fires this app event when it wins the GAM auction;
        // its absence by impression time means the ad server (Google) rendered.
        if name.caseInsensitiveCompare(PREBID_APP_EVENT) == .orderedSame {
            auBannerView?.notePrebidLineItemRendered()
        }
        eventDelegate?.adView?(banner, didReceiveAppEvent: name, with: info)
    }

    // MARK: - GADAdSizeDelegate
    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) {
        guard auBannerView?.acceptsGoogleEvents == true else { return }
        LogEvent("willChangeAdSizeTo")
        // Capture GAM's chosen size before bannerViewDidReceiveAd fires.
        // gamView.adSize is not yet updated here — size.size is the correct value.
        pendingGAMSize = size.size
        sizeDelegate?.adView(bannerView, willChangeAdSizeTo: size)
    }
}
