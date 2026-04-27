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

    let auBannerView: AUBannerView
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

    private func addListener() {
        self.gamView.delegate = self
        self.gamView.appEventDelegate = self
        self.gamView.adSizeDelegate = self
    }

    deinit {
        AULogEvent.logDebug("AUBannerHandler")
    }

    // MARK: - GADBannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        LogEvent("bannerViewDidReceiveAd")

        if let gamBannerView = bannerView as? AdManagerBannerView {
            // Determine the actual rendered size using a three-level priority:
            // 1. pendingGAMSize — set by willChangeAdSizeTo, which fires synchronously
            //    before this callback. gamView.adSize is NOT yet updated at that point,
            //    so the delegate parameter is the only reliable source. This covers GAM
            //    serving any non-primary size from validAdSizes (e.g. 300×600 when the
            //    primary was 320×50) — and is also why adSize.size alone caused 50px banners.
            // 2. lastPrebidCreativeSize — hb_size from Prebid targeting after fetchDemand.
            //    Covers Prebid wins where the creative size matches the primary declared
            //    adSize (willChangeAdSizeTo doesn't fire in that case).
            // 3. gamBannerView.adSize.size — final fallback for when GAM serves exactly
            //    the primary declared adSize and Prebid did not participate.
            let actualSize = pendingGAMSize
                ?? auBannerView.lastPrebidCreativeSize
                ?? gamBannerView.adSize.size

            if actualSize != .zero {
                gamBannerView.resize(adSizeFor(cgSize: actualSize))
                auBannerView.onAdSizeChanged?(actualSize)
            }
        }
        pendingGAMSize = nil

        bannerDelegate?.bannerViewDidReceiveAd?(bannerView)
    }
    func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: any Error
    ) {
        LogEvent("didFailToReceiveAdWithError")
        LogEvent(error.localizedDescription)

        let event = AUFailedLoadEvent(
            adViewId: auBannerView.configId,
            adUnitID: adUnitID ?? "",
            errorMessage: error.localizedDescription,
            errorCode: error.errorCode ?? -1
        )

        guard let payload = event.convertToJSONString() else {
            bannerDelegate?.bannerView?(
                bannerView,
                didFailToReceiveAdWithError: error
            )
            return
        }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
        bannerDelegate?.bannerView?(
            bannerView,
            didFailToReceiveAdWithError: error
        )
    }

    /// Tells the delegate that an impression has been recorded for an ad.
    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        LogEvent("bannerViewDidRecordImpression")
        bannerDelegate?.bannerViewDidRecordImpression?(bannerView)
    }

    /// Tells the delegate that a click has been recorded for the ad.
    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        LogEvent("bannerViewDidRecordClick")

        let event = AUAdClickEvent(
            adViewId: auBannerView.configId,
            adUnitID: adUnitID ?? ""
        )

        guard let payload = event.convertToJSONString() else {
            bannerDelegate?.bannerViewDidRecordClick?(bannerView)
            return
        }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))

        bannerDelegate?.bannerViewDidRecordClick?(bannerView)
    }

    // MARK: - Click-Time

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        LogEvent("bannerViewWillPresentScreen")
        bannerDelegate?.bannerViewWillPresentScreen?(bannerView)
    }

    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        LogEvent("bannerViewWillDismissScreen")
        bannerDelegate?.bannerViewWillDismissScreen?(bannerView)
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        LogEvent("bannerViewDidDismissScreen")
        bannerDelegate?.bannerViewDidDismissScreen?(bannerView)
    }

    // MARK: - GADAppEventDelegate
    func adView(
        _ banner: BannerView,
        didReceiveAppEvent name: String,
        with info: String?
    ) {
        LogEvent("didReceiveAppEvent")
        eventDelegate?.adView?(banner, didReceiveAppEvent: name, with: info)
    }

    // MARK: - GADAdSizeDelegate
    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) {
        LogEvent("willChangeAdSizeTo")
        // Capture GAM's chosen size before bannerViewDidReceiveAd fires.
        // gamView.adSize is not yet updated here — size.size is the correct value.
        pendingGAMSize = size.size
        sizeDelegate?.adView(bannerView, willChangeAdSizeTo: size)
    }
}
