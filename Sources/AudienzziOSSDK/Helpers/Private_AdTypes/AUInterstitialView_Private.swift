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

import PrebidMobile
import UIKit
import GoogleMobileAds

private let adTypeString = "INTERSTITIAL"
private let apiTypeString = "ORIGINAL"

@objc
extension AUInterstitialView {
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest as? AdManagerRequest else {
            return
        }

        #if DEBUG
            AULogEvent.logDebug("[AUInterstitialView] became visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }

    internal override func fetchRequest(_ gamRequest: AdManagerRequest) {
        makeBidRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            AULogEvent.logDebug(
                "Audienzz demand fetch for GAM \(resultCode.name())"
            )
            guard let self = self else { return }
            let resultCodeStr = AUResulrCodeConverter.convertResultCodeName(resultCode)
            self.makeBidResponseEvent(resultCodeStr)
            if resultCode == .prebidDemandFetchSuccess {
                self.makeBidWonEvent()
            } else {
                self.makeNoBidEvent(resultCodeStr)
            }
            self.onLoadRequest?(gamRequest)
        }
    }

    private func makeBidRequestEvent() {
        guard let adUnitID = gadUnitID else { return }

        let event = AUBidRequestEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            size: AUUniqHelper.sizeMaker(adSize),
            isAutorefresh: false,
            autorefreshTime: 0,
            initialRefresh: false,
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeBidResponseEvent(_ resultCode: String) {
        guard let adUnitID = gadUnitID else { return }

        let event = AUBidResponseEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            resultCode: resultCode,
            size: AUUniqHelper.sizeMaker(adSize),
            isAutorefresh: false,
            autorefreshTime: 0,
            initialRefresh: false,
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeBidWonEvent() {
        guard let adUnitID = gadUnitID else { return }

        let event = AUBidWonEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            targetKeywords: [:],
            size: AUUniqHelper.sizeMaker(adSize),
            isAutorefresh: false,
            autorefreshTime: 0,
            initialRefresh: false,
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeNoBidEvent(_ resultCode: String) {
        guard let adUnitID = gadUnitID else { return }

        let event = AUNoBidEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            resultCode: resultCode,
            size: AUUniqHelper.sizeMaker(adSize),
            isAutorefresh: false,
            autorefreshTime: 0,
            initialRefresh: false,
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeAdSubType() -> String {
        if adUnit.adFormats.count >= 2 {
            return "MULTIFORMAT"
        } else if adUnit.adFormats.contains(where: { $0.rawValue == 1 })
            && adUnit.adFormats.count == 1
        {
            return "HTML"
        } else if adUnit.adFormats.contains(where: { $0.rawValue == 2 })
            && adUnit.adFormats.count == 1
        {
            return "VIDEO"
        }

        return ""
    }

    internal func makeHeaderLoadedEvent() {
        let event = AUHeaderLoadedEvent(
            adViewId: configId,
            adUnitID: eventHandler?.adUnitID ?? "",
            size: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )
        AUEventsManager.shared.sendEvent(event)
    }
}
