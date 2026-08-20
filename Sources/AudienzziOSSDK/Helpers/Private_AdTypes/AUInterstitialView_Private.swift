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
        // Mint the auction id up front so bidRequest and every later event of this auction share it.
        currentAuctionId = AUUniqHelper.makeUniqID()
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
                hbFormat: AUBannerView.keyword("hb_format", in: rawTargeting),
                adId: AUBannerView.keyword("hb_adid", in: rawTargeting),
                creativeId: AUBannerView.creativeIdKeyword(in: rawTargeting)
            )
            self.onLoadRequest?(gamRequest)
        }
    }

    private func makeRequestEvent() {
        guard let adUnitID = gadUnitID else { return }
        AUEventsManager.shared.bidRequest(
            adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizesJSON(adSize),
            adType: adTypeString, adSubtype: makeAdSubType(), apiType: apiTypeString,
            isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
            mediaTypes: AUBannerView.mediaTypesJSON(subtype: makeAdSubType()),
            auctionId: currentAuctionId
        )
    }

    private func makeResultEvents(resultCode: ResultCode, timeToRespond: Int64,
                                  hbBidder: String?, priceBucket: String?,
                                  hbSize: String?, hbFormat: String?,
                                  adId: String?, creativeId: String?) {
        guard let adUnitID = gadUnitID else { return }
        let subtype = makeAdSubType()
        let codeName = AUResulrCodeConverter.convertResultCodeName(resultCode)

        var economics: AURenderEconomics?
        if resultCode == .prebidDemandFetchSuccess, let bidder = hbBidder, !bidder.isEmpty {
            economics = AURenderEconomics(
                bidderCode: bidder, winnerBidderCode: bidder, winnerType: AUWinnerType.rtb,
                priceBucket: priceBucket, hbSize: hbSize, hbFormat: hbFormat,
                mediaType: hbFormat, size: hbSize,
                // Fork-free: cpm = bucketed hb_pb; currency from the GMA paid event at render;
                // creative_id = bidder-specific keyword when present, else "0"; ad_id = hb_adid.
                cpm: priceBucket.flatMap { Double($0) }, currency: nil, creativeId: creativeId ?? "0",
                auctionId: currentAuctionId, adId: adId ?? "0",
                timeToRespond: timeToRespond, slotReload: 0)
        }

        AUEventsManager.shared.bidResponse(
            adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizesJSON(adSize),
            adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
            isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
            resultCode: codeName, timeToRespond: timeToRespond, economics: economics
        )

        if let economics {
            self.prebidWinningBidder = economics.bidderCode
            self.lastRenderEconomics = economics
            AUEventsManager.shared.bidWon(
                adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizesJSON(adSize),
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: false, autorefreshTime: 0, isRefresh: false,
                economics: economics
            )
        } else {
            self.prebidWinningBidder = nil
            self.lastRenderEconomics = nil
            AUEventsManager.shared.noBid(
                adUnitId: adUnitID, adViewId: configId, sizes: AUUniqHelper.sizesJSON(adSize),
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: false, autorefreshTime: 0, isRefresh: false, resultCode: codeName,
                mediaTypes: AUBannerView.mediaTypesJSON(subtype: subtype),
                auctionId: currentAuctionId
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
