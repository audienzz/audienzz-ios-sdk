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

/// `winner_type` values (web-clickstream parity).
enum AUWinnerType {
    static let rtb = "RTB"
    static let direct = "direct"
}

/// Winning-bid economics captured when a bid resolves and reused across the render events
/// (`bidResponse`/`bidWon`/`adImpression`/`adClick`/`viewability.*`). Mirrors the web attribute set.
struct AURenderEconomics {
    var bidderCode: String? = nil
    var winnerBidderCode: String? = nil
    var winnerType: String? = nil
    var priceBucket: String? = nil
    var hbSize: String? = nil
    var hbFormat: String? = nil
    var mediaType: String? = nil
    var size: String? = nil
    var cpm: Double? = nil
    var currency: String? = nil
    var creativeId: String? = nil
    var auctionId: String? = nil
    var adId: String? = nil
    var timeToRespond: Int64? = nil
    var slotReload: Int? = nil
}

extension AUEventDomain {
    /// Applies the shared render economics onto an event (no-op for nil fields).
    mutating func apply(_ ec: AURenderEconomics?) {
        guard let ec else { return }
        bidderCode = bidderCode ?? ec.bidderCode
        winnerBidderCode = winnerBidderCode ?? ec.winnerBidderCode
        winnerType = ec.winnerType
        priceBucket = ec.priceBucket
        hbSize = ec.hbSize
        hbFormat = ec.hbFormat
        mediaType = ec.mediaType
        size = ec.size
        cpm = ec.cpm
        currency = ec.currency
        creativeId = ec.creativeId
        auctionId = ec.auctionId
        adId = ec.adId
        if timeToRespond == nil { timeToRespond = ec.timeToRespond }
        slotReload = ec.slotReload
    }
}

/// Typed event helpers — the public firing surface used by the ad views/handlers.
extension AUEventsManager {

    func bidRequest(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
                    adType: String, adSubtype: String, apiType: String,
                    isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool,
                    mediaTypes: String? = nil, auctionId: String? = nil) {
        var e = AUEventDomain(type: .bidRequest)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.mediaTypes = mediaTypes; e.auctionId = auctionId
        logEvent(e)
    }

    func bidResponse(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
                     adType: String, adSubtype: String, apiType: String,
                     isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool,
                     resultCode: String?, timeToRespond: Int64? = nil,
                     economics: AURenderEconomics? = nil) {
        var e = AUEventDomain(type: .bidResponse)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.resultCode = resultCode; e.timeToRespond = timeToRespond
        e.apply(economics)
        logEvent(e)
    }

    // Economics (cpm/currency/creativeId/auctionId/adId/media_type/size/bidder_code) come from the
    // winning bid via the patched Prebid fork (BidInfo surfaces them on the original/GAM API).
    func bidWon(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
                adType: String, adSubtype: String, apiType: String,
                isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool,
                economics: AURenderEconomics? = nil) {
        var e = AUEventDomain(type: .bidWon)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.apply(economics)
        logEvent(e)
    }

    func noBid(adUnitId: String, adViewId: String? = nil, sizes: String? = nil,
               adType: String, adSubtype: String, apiType: String,
               isAutorefresh: Bool, autorefreshTime: Int, isRefresh: Bool, resultCode: String?,
               mediaTypes: String? = nil, auctionId: String? = nil) {
        var e = AUEventDomain(type: .noBid)
        e.adUnitId = adUnitId; e.adViewId = adViewId; e.sizes = sizes
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.isAutorefresh = isAutorefresh; e.autorefreshTime = autorefreshTime; e.isRefresh = isRefresh
        e.resultCode = resultCode; e.mediaTypes = mediaTypes; e.auctionId = auctionId
        logEvent(e)
    }

    func adImpression(adUnitId: String, adType: String, adSubtype: String, apiType: String,
                      adViewId: String? = nil, bidderCode: String? = nil,
                      winnerBidderCode: String? = nil, economics: AURenderEconomics? = nil) {
        var e = AUEventDomain(type: .adImpression)
        e.adUnitId = adUnitId; e.adViewId = adViewId
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.bidderCode = bidderCode; e.winnerBidderCode = winnerBidderCode
        e.apply(economics)
        logEvent(e)
    }

    func adClick(adUnitId: String, adType: String? = nil, adSubtype: String? = nil,
                 apiType: String? = nil, adViewId: String? = nil,
                 economics: AURenderEconomics? = nil) {
        var e = AUEventDomain(type: .adClick)
        e.adUnitId = adUnitId; e.adViewId = adViewId
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.apply(economics)
        logEvent(e)
    }

    func viewabilityStart(adUnitId: String, adType: String, adSubtype: String, apiType: String,
                          adViewId: String? = nil, economics: AURenderEconomics? = nil) {
        var e = AUEventDomain(type: .viewabilityStart)
        e.adUnitId = adUnitId; e.adViewId = adViewId
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.apply(economics)
        logEvent(e)
    }

    func viewabilitySuccess(adUnitId: String, adType: String, adSubtype: String, apiType: String,
                            adViewId: String? = nil, economics: AURenderEconomics? = nil) {
        var e = AUEventDomain(type: .viewabilitySuccess)
        e.adUnitId = adUnitId; e.adViewId = adViewId
        e.adType = adType; e.adSubtype = adSubtype; e.apiType = apiType
        e.apply(economics)
        logEvent(e)
    }
}
