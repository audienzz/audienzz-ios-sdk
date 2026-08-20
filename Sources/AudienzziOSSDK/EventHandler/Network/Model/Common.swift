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

protocol AUEventHandlerType: BodyObjectEncodable {
    var type: AUAdEventType { get }
    var visitorId: String { get set }
    var companyId: String { get set }
    var sessionId: String { get set }
    var sessionStartTimestamp: Int { get set }
    var deviceId: String { get set }
    var pageImpressionId: String? { get set }
    var screenWidth: Int { get set }
    var screenHeight: Int { get set }
    var locale: String { get set }
    var zoneOffsetSeconds: Int { get set }
}

extension AUEventHandlerType {
    func buildFlatPayload(pageUrl: String? = nil, attributes: JSONObject) -> JSONObject {
        var result = JSONObject()
        result["event_type"] = type.rawValue
        result["company_id"] = companyId
        result["source"] = "ios-sdk"
        result["event_id"] = AUUniqHelper.makeUniqID()
        if let pid = pageImpressionId { result["page_impression_id"] = pid }
        result["session_id"] = sessionId
        result["session_start_timestamp"] = sessionStartTimestamp
        result["event_timestamp"] = Date().currentTimeStmp
        result["locale"] = locale
        result["zone_offset_seconds"] = zoneOffsetSeconds
        result["screen_height"] = screenHeight
        result["screen_width"] = screenWidth
        result["viewport_height"] = screenHeight
        result["viewport_width"] = screenWidth
        if let url = pageUrl { result["page_url"] = url }
        result["visitor_id"] = visitorId
        result["attributes"] = attributes
        return result
    }
}

enum AUAdEventType: String, Codable, CaseIterable, Equatable {
    case HEADER_LOADED        = "headerLoaded"
    case PAGE_IMPRESSION      = "pageImpression"
    case BID_REQUEST          = "bidRequest"
    case BID_RESPONSE         = "bidResponse"
    case BID_WON              = "bidWon"
    case NO_BID               = "noBid"
    case AD_IMPRESSION        = "adImpression"
    case AD_VIEW              = "adView"
    case AD_CLICK             = "adClick"
    case VIEWABILITY_MEASURED = "viewabilityMeasured"
}
