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
public class AUInterstitialEventHandler: NSObject {
    let adUnit: InterstitialAd

    public init(adUnit: InterstitialAd) {
        self.adUnit = adUnit
    }
}

class AUInterstitialHandler: NSObject,
    FullScreenContentDelegate,
    AppEventDelegate,
    AULogEventType
{

    let handler: AUInterstitialEventHandler
    let adView: AUInterstitialView
    weak var fullScreentDelegate: FullScreenContentDelegate?

    init(handler: AUInterstitialEventHandler, adView: AUInterstitialView) {
        self.handler = handler
        self.fullScreentDelegate = handler.adUnit.fullScreenContentDelegate
        self.adView = adView
        super.init()
        addListener()
    }

    var adUnitID: String {
        self.handler.adUnit.adUnitID
    }

    private func addListener() {
        handler.adUnit.fullScreenContentDelegate = self
    }

    deinit {
        AULogEvent.logDebug("AUInterstitialHandler")
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidRecordImpression")
        AUEventsManager.shared.adImpression(
            adUnitId: adUnitID, adType: AUAdType.interstitial,
            adSubtype: adView.makeAdSubType(), apiType: AUEventApiType.original,
            adViewId: adView.configId, economics: renderEconomics()
        )
        fullScreentDelegate?.adDidRecordImpression?(ad)
    }

    func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidRecordClick")
        AUEventsManager.shared.adClick(
            adUnitId: adUnitID, adType: AUAdType.interstitial,
            adSubtype: adView.makeAdSubType(), apiType: AUEventApiType.original,
            adViewId: adView.configId, economics: renderEconomics()
        )
        fullScreentDelegate?.adDidRecordClick?(ad)
    }

    /// Full-screen ads expose no app event, so the render winner is best-effort: the Prebid auction
    /// winner's economics if there was one, else an ad-server (direct) impression.
    private func renderEconomics() -> AURenderEconomics {
        adView.lastRenderEconomics ?? AURenderEconomics(
            bidderCode: AD_SERVER_BIDDER, winnerBidderCode: AD_SERVER_BIDDER,
            winnerType: AUWinnerType.direct)
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        LogEvent("didFailToPresentFullScreenContentWithError")
        adView.fullScreenViewabilityTimer?.cancel()
        fullScreentDelegate?.ad?(
            ad,
            didFailToPresentFullScreenContentWithError: error
        )
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adWillPresentFullScreenContent")
        let adUnitID = self.adUnitID
        let subtype = adView.makeAdSubType()
        let viewId = adView.configId
        let economics = renderEconomics()
        let timer = AUFullScreenViewabilityTimer(
            onStart: {
                AUEventsManager.shared.viewabilityStart(
                    adUnitId: adUnitID, adType: AUAdType.interstitial,
                    adSubtype: subtype, apiType: AUEventApiType.original,
                    adViewId: viewId, economics: economics)
            },
            onSuccess: {
                AUEventsManager.shared.viewabilitySuccess(
                    adUnitId: adUnitID, adType: AUAdType.interstitial,
                    adSubtype: subtype, apiType: AUEventApiType.original,
                    adViewId: viewId, economics: economics)
            }
        )
        adView.fullScreenViewabilityTimer = timer
        timer.onShown()
        fullScreentDelegate?.adWillPresentFullScreenContent?(ad)
    }

    func adWillDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adWillDismissFullScreenContent")
        fullScreentDelegate?.adWillDismissFullScreenContent?(ad)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidDismissFullScreenContent")
        adView.fullScreenViewabilityTimer?.cancel()
        fullScreentDelegate?.adDidDismissFullScreenContent?(ad)
    }
}
