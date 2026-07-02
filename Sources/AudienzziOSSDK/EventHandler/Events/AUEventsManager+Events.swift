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

/// Ad type / subtype / API constants mirroring the Android SDK's enums.
enum AUAdType {
    static let banner = "BANNER"
    static let interstitial = "INTERSTITIAL"
    static let rewarded = "REWARDED"
}

enum AUAdSubtype {
    static let html = "HTML"
    static let video = "VIDEO"
    static let multiformat = "MULTIFORMAT"
}

enum AUEventApiType {
    static let original = "ORIGINAL"
    static let rendering = "RENDER"
}

/// App-event name a GAM Prebid line item sends when it wins (used for render-winner attribution).
let PREBID_APP_EVENT = "Prebid"
/// `bidder_code` reported when the ad server (Google/AdX/direct) rendered instead of Prebid.
let AD_SERVER_BIDDER = "google"

/// Typed event helpers — the public firing surface used by the ad views/handlers.
extension AUEventsManager {

    func bidRequest(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
                    adType: String, adSubtype: String, apiType: String,
                    isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool) {
        var e = AUEventDomain(type: .bidRequest)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        logEvent(e)
    }

    func bidResponse(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
                     adType: String, adSubtype: String, apiType: String,
                     isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool,
                     resultCode: String?, timeToRespond: Int64? = nil) {
        var e = AUEventDomain(type: .bidResponse)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.resultCode = resultCode; e.timeToRespond = timeToRespond
        logEvent(e)
    }

    // Economics params (cpm/currency/creativeId/auctionId/adId) are populated from the winning bid
    // via the patched Prebid fork (BidInfo now surfaces them on the original/GAM API).
    func bidWon(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
                adType: String, adSubtype: String, apiType: String,
                isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool,
                priceBucket: String? = nil, hbSize: String? = nil, hbFormat: String? = nil,
                cpm: Double? = nil, currency: String? = nil, creativeId: String? = nil,
                auctionId: String? = nil, adId: String? = nil) {
        var e = AUEventDomain(type: .bidWon)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.priceBucket = priceBucket; e.hbSize = hbSize; e.hbFormat = hbFormat
        e.cpm = cpm; e.currency = currency; e.creativeId = creativeId
        e.auctionId = auctionId; e.adId = adId
        logEvent(e)
    }

    func noBid(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
               adType: String, adSubtype: String, apiType: String,
               isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool, resultCode: String?) {
        var e = AUEventDomain(type: .noBid)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.resultCode = resultCode
        logEvent(e)
    }

    func adImpression(adUnitId: String, adType: String, adSubtype: String, apiType: String,
                      bidderCode: String? = nil, winnerBidderCode: String? = nil) {
        var e = AUEventDomain(type: .adImpression)
        e.adUnitId = adUnitId; e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.bidderCode = bidderCode; e.winnerBidderCode = winnerBidderCode
        logEvent(e)
    }

    func adClick(adUnitId: String) {
        var e = AUEventDomain(type: .adClick)
        e.adUnitId = adUnitId
        logEvent(e)
    }

    func viewabilityStart(adUnitId: String, adType: String, adSubtype: String, apiType: String) {
        var e = AUEventDomain(type: .viewabilityStart)
        e.adUnitId = adUnitId; e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        logEvent(e)
    }

    func viewabilitySuccess(adUnitId: String, adType: String, adSubtype: String, apiType: String) {
        var e = AUEventDomain(type: .viewabilitySuccess)
        e.adUnitId = adUnitId; e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        logEvent(e)
    }
}
