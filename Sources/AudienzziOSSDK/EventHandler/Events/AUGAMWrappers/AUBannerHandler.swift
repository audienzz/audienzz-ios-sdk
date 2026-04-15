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

    /// Set by `willChangeAdSizeTo` when GAM signals it will render an ad at a size
    /// different from the Prebid creative size. Consumed and cleared in `bannerViewDidReceiveAd`.
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

        // Resize the GAM banner to the actual rendered ad size.
        // If GAM chose to serve its own ad at a different size, `willChangeAdSizeTo` will
        // have fired first and stored that size in `pendingGAMSize`. Otherwise we fall back
        // to the Prebid winning creative size from `hb_size` targeting.
        if let gamBannerView = bannerView as? AdManagerBannerView {
            let resizeTarget = pendingGAMSize ?? auBannerView.lastPrebidCreativeSize
            if let size = resizeTarget {
                gamBannerView.resize(adSizeFor(cgSize: size))
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
        // GAM fires this before `bannerViewDidReceiveAd` when it decides to render an ad
        // whose size differs from the initially declared ad size (e.g. GAM serves a 300×600
        // direct ad against a slot that Prebid bid at 300×250). Store the actual size so
        // `bannerViewDidReceiveAd` can resize to what GAM actually rendered.
        pendingGAMSize = size.size
        sizeDelegate?.adView(bannerView, willChangeAdSizeTo: size)
    }
}
