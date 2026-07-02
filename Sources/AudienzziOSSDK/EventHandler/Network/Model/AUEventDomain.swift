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

/// Clickstream event types (aligned with the web htag / Android SDK schema).
enum AUAnalyticsEventType: String {
    case pageImpression = "pageImpression"
    case bidRequest = "bidRequest"
    case bidResponse = "bidResponse"
    case bidWon = "bidWon"
    case noBid = "noBid"
    case adImpression = "adImpression"
    case adClick = "adClick"
    case viewabilityStart = "viewability.start"
    case viewabilitySuccess = "viewability.success"
}

/// In-memory representation of a single analytics event, before it is enriched with
/// session/identity data and mapped to the flat network payload. Mirrors the Android `EventDomain`.
struct AUEventDomain {
    let type: AUAnalyticsEventType
    let timestamp: Date

    // Identity / session (injected by the logger)
    var uuid: String?
    var visitorId: String?
    var companyId: String?
    var sessionId: String?
    var sessionStartTimestamp: Int64?
    var sessionSeq: Int?
    var deviceId: String?
    var pageImpressionId: String?

    // Ad context (per-event attributes)
    var adUnitId: String?
    var adViewId: String?
    var screenName: String?
    var sizes: String?
    var adType: String?
    var adSubtype: String?
    var apiType: String?
    var resultCode: String?
    var isAutorefresh: Bool?
    var autorefreshTime: Int?
    var isRefresh: Bool?
    var timeToRespond: Int64?

    // Bid / render economics
    var bidderCode: String?
    var winnerBidderCode: String?
    var priceBucket: String?
    var hbSize: String?
    var hbFormat: String?
    var cpm: Double?
    var currency: String?
    var creativeId: String?
    var auctionId: String?
    var adId: String?

    init(type: AUAnalyticsEventType) {
        self.type = type
        self.timestamp = Date()
    }
}
