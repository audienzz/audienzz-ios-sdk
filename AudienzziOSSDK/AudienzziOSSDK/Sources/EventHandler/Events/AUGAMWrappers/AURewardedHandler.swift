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
        fullScreentDelegate?.adDidRecordImpression?(ad)
    }

    func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidRecordClick")

        let event = AUAdClickEvent(
            adViewId: adView.configId,
            adUnitID: adUnitID
        )

        guard let payload = event.convertToJSONString() else {
            fullScreentDelegate?.adDidRecordClick?(ad)
            return
        }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))

        fullScreentDelegate?.adDidRecordClick?(ad)
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        LogEvent("didFailToPresentFullScreenContentWithError")

        let event = AUFailedLoadEvent(
            adViewId: adView.configId,
            adUnitID: adUnitID,
            errorMessage: error.localizedDescription,
            errorCode: error.errorCode ?? -1
        )

        guard event.convertToJSONString() != nil else {
            fullScreentDelegate?.ad?(
                ad,
                didFailToPresentFullScreenContentWithError: error
            )
            return
        }

        fullScreentDelegate?.ad?(
            ad,
            didFailToPresentFullScreenContentWithError: error
        )
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adWillPresentFullScreenContent")
        fullScreentDelegate?.adWillPresentFullScreenContent?(ad)
    }

    func adWillDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adWillDismissFullScreenContent")
        fullScreentDelegate?.adWillDismissFullScreenContent?(ad)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adDidDismissFullScreenContent")

        let event = AUCloseAdEvent(
            adViewId: adView.configId,
            adUnitID: adUnitID
        )
        guard let payload = event.convertToJSONString() else {
            fullScreentDelegate?.adDidDismissFullScreenContent?(ad)
            return
        }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))

        fullScreentDelegate?.adDidDismissFullScreenContent?(ad)
    }
}
