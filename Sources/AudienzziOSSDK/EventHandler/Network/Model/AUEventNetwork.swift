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

/// Flat clickstream event payload sent to the collector (mirrors Android's `EventNetwork`).
/// Optional fields are omitted from the JSON when nil (synthesized `encodeIfPresent`).
struct AUEventNetwork: Encodable {
    let eventType: String
    let companyId: String?
    let source: String
    let eventId: String
    let pageImpressionId: String?
    let sessionId: String?
    let sessionStartTimestamp: Int64?
    let sessionSeq: Int
    let eventTimestamp: String
    let locale: String
    let zoneOffsetSeconds: Int
    let screenHeight: Int
    let screenWidth: Int
    let viewportHeight: Int
    let viewportWidth: Int
    let deviceId: String?
    let userAgent: String?
    let sdkName: String
    let sdkVersion: String
    let appPackageName: String?
    let appVersion: String?
    let appTitle: String?
    let screenName: String?
    let pageUrl: String?
    let visitorId: String?
    let attributes: [String: String]

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case companyId = "company_id"
        case source
        case eventId = "event_id"
        case pageImpressionId = "page_impression_id"
        case sessionId = "session_id"
        case sessionStartTimestamp = "session_start_timestamp"
        case sessionSeq = "session_seq"
        case eventTimestamp = "event_timestamp"
        case locale
        case zoneOffsetSeconds = "zone_offset_seconds"
        case screenHeight = "screen_height"
        case screenWidth = "screen_width"
        case viewportHeight = "viewport_height"
        case viewportWidth = "viewport_width"
        case deviceId = "device_id"
        case userAgent = "user_agent"
        case sdkName = "sdk_name"
        case sdkVersion = "sdk_version"
        case appPackageName = "app_package_name"
        case appVersion = "app_version"
        case appTitle = "app_title"
        case screenName = "screen_name"
        case pageUrl = "page_url"
        case visitorId = "visitor_id"
        case attributes
    }
}
