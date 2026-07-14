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
public class AURewardedEventHandler: NSObject {
    let adUnit: RewardedAd

    public init(adUnit: RewardedAd) {
        self.adUnit = adUnit
    }
}

class AURewardedHandler: NSObject,
    FullScreenContentDelegate,
    AppEventDelegate,
    AULogEventType
{

    let handler: AURewardedEventHandler
    let adView: AURewardedView
    weak var fullScreentDelegate: FullScreenContentDelegate?

    init(handler: AURewardedEventHandler, adView: AURewardedView) {
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
        AULogEvent.logDebug("AURewardedHandler")
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidRecordImpression")
        AUEventsManager.shared.adImpression(
            adUnitId: adUnitID, adType: AUAdType.rewarded,
            adSubtype: AUAdSubtype.video, apiType: AUEventApiType.original,
            adViewId: adView.configId, economics: renderEconomics()
        )
        fullScreentDelegate?.adDidRecordImpression?(ad)
    }

    func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidRecordClick")
        AUEventsManager.shared.adClick(
            adUnitId: adUnitID, adType: AUAdType.rewarded,
            adSubtype: AUAdSubtype.video, apiType: AUEventApiType.original,
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
        let timer = AUFullScreenViewabilityTimer(
            onStart: {
                AUEventsManager.shared.viewabilityStart(
                    adUnitId: adUnitID, adType: AUAdType.rewarded,
                    adSubtype: AUAdSubtype.video, apiType: AUEventApiType.original)
            },
            onSuccess: {
                AUEventsManager.shared.viewabilitySuccess(
                    adUnitId: adUnitID, adType: AUAdType.rewarded,
                    adSubtype: AUAdSubtype.video, apiType: AUEventApiType.original)
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
