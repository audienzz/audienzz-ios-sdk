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
import GoogleMobileAds
import UIKit

private let adTypeString = "REWARDED"
private let apiTypeString = "ORIGINAL"

@objc
extension AURewardedView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest else {
            return
        }

        fetchRequest(request)
        isLazyLoaded = true
        #if DEBUG
            AULogEvent.logDebug("[AURewardedView] became visible")
        #endif
    }

    override func fetchRequest(_ gamRequest: AdManagerRequest) {
        prebidWinningBidder = nil
        let requestStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] bidInfo in
            let resultCode = bidInfo.resultCode
            AULogEvent.logDebug(
                "Audienz demand fetch for GAM \(resultCode.name())"
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
                hbFormat: AUBannerView.keyword("hb_format", in: rawTargeting),
                bidInfo: bidInfo
            )
            self.onLoadRequest?(gamRequest)
        }
    }

    private func makeRequestEvent() {
        guard let adUnitID = gadUnitID else { return }
        AUEventsManager.shared.bidRequest(
            adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString, adSubtype: AUAdSubtype.video, apiType: apiTypeString,
            isAutorefresh: false, autorefreshTime: 0, isRefresh: false
        )
    }

    private func makeResultEvents(resultCode: ResultCode, timeToRespond: Int64,
                                  hbBidder: String?, priceBucket: String?,
                                  hbSize: String?, hbFormat: String?,
                                  bidInfo: BidInfo) {
        guard let adUnitID = gadUnitID else { return }
        let codeName = AUResulrCodeConverter.convertResultCodeName(resultCode)

        AUEventsManager.shared.bidResponse(
            adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString, adSubtype: AUAdSubtype.video, apiType: apiTypeString,
            isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
            resultCode: codeName, timeToRespond: timeToRespond
        )

        if resultCode == .prebidDemandFetchSuccess, let bidder = hbBidder, !bidder.isEmpty {
            self.prebidWinningBidder = bidder
            AUEventsManager.shared.bidWon(
                adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
                adType: adTypeString, adSubtype: AUAdSubtype.video, apiType: apiTypeString,
                isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
                priceBucket: priceBucket, hbSize: hbSize, hbFormat: hbFormat,
                cpm: bidInfo.cpm, currency: bidInfo.currency, creativeId: bidInfo.creativeId,
                auctionId: bidInfo.auctionId, adId: bidInfo.adId
            )
        } else {
            self.prebidWinningBidder = nil
            AUEventsManager.shared.noBid(
                adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizeMaker(adSize),
                adType: adTypeString, adSubtype: AUAdSubtype.video, apiType: apiTypeString,
                isAutorefresh: false, autorefreshTime: 0, isRefresh: false, resultCode: codeName
            )
        }
    }
}
