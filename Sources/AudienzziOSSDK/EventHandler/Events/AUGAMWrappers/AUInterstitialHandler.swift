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
        // GMA paid value + currency (the only fork-free currency source), stashed for the render events.
        handler.adUnit.paidEventHandler = { [weak adView] adValue in
            AUAnalyticsDebugProbe.logAdValue(adValue, context: "interstitial")
            adView?.lastPaidCurrency = adValue.currencyCode
            adView?.lastPaidCpm = adValue.value.doubleValue
        }
    }

    deinit {
        AULogEvent.logDebug("AUInterstitialHandler")
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidRecordImpression")
        AUAnalyticsDebugProbe.logResponseInfo(handler.adUnit.responseInfo, context: "interstitial")
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

    /// Full-screen ads expose no app event; carry the winning-bid economics and best-effort
    /// bidder_code (the Prebid auction winner if there was one, else the ad server).
    private func renderEconomics() -> AURenderEconomics {
        var ec = adView.lastRenderEconomics ?? AURenderEconomics()
        let bidder = adView.prebidWinningBidder ?? AD_SERVER_BIDDER
        ec.bidderCode = bidder
        if bidder == AD_SERVER_BIDDER {
            // Ad server rendered — zero the creative id so a direct-sold impression isn't
            // misclassified as RTB (GMA exposes no served-creative id → "0" stub).
            ec.creativeId = "0"
        }
        ec.auctionId = ec.auctionId ?? adView.currentAuctionId
        // Currency (and cpm on a direct fill) from the GMA paid event.
        ec.currency = ec.currency ?? adView.lastPaidCurrency
        ec.cpm = ec.cpm ?? adView.lastPaidCpm
        return ec
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
