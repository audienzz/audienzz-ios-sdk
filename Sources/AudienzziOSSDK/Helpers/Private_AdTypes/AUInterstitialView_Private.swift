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
        prebidWinningBidder = nil
        let requestStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            AULogEvent.logDebug(
                "Audienzz demand fetch for GAM \(resultCode.name())"
            )
            guard let self = self else { return }
            let timeToRespond = Int64(Date().timeIntervalSince1970 * 1000) - requestStartMs
            let rawTargeting = gamRequest.customTargeting as? [AnyHashable: Any] ?? [:]
            self.makeResultEvents(
                resultCode: resultCode,
                timeToRespond: timeToRespond,
                hbBidder: AUBannerView.keyword("hb_bidder", in: rawTargeting),
                priceBucket: AUBannerView.keyword("hb_pb", in: rawTargeting),
                hbSize: AUBannerView.keyword("hb_size", in: rawTargeting),
                hbFormat: AUBannerView.keyword("hb_format", in: rawTargeting)
            )
            self.onLoadRequest?(gamRequest)
        }
    }

    private func makeRequestEvent() {
        guard let adUnitID = gadUnitID else { return }
        AUEventsManager.shared.bidRequest(
            adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString, adSubtype: makeAdSubType(), apiType: apiTypeString,
            isAutorefresh: false, autorefreshTime: 0, isRefresh: false
        )
    }

    private func makeResultEvents(resultCode: ResultCode, timeToRespond: Int64,
                                  hbBidder: String?, priceBucket: String?,
                                  hbSize: String?, hbFormat: String?) {
        guard let adUnitID = gadUnitID else { return }
        let subtype = makeAdSubType()
        let codeName = AUResulrCodeConverter.convertResultCodeName(resultCode)

        AUEventsManager.shared.bidResponse(
            adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
            isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
            resultCode: codeName, timeToRespond: timeToRespond
        )

        if resultCode == .prebidDemandFetchSuccess, let bidder = hbBidder, !bidder.isEmpty {
            self.prebidWinningBidder = bidder
            AUEventsManager.shared.bidWon(
                adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
                priceBucket: priceBucket, hbSize: hbSize, hbFormat: hbFormat
            )
        } else {
            self.prebidWinningBidder = nil
            AUEventsManager.shared.noBid(
                adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: false, autorefreshTime: 0, isRefresh: false, resultCode: codeName
            )
        }
    }

    func makeAdSubType() -> String {
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
}
