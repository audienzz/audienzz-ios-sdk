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
import UIKit

/// Maps an `AUEventDomain` to the flat `AUEventNetwork` payload, filling the common envelope
/// (locale, timezone, screen, app/sdk metadata, user agent). Mirrors Android's `EventNetworkMapper`.
struct AUEventNetworkMapper {

    static let source = "ios-sdk"
    static let sdkName = "ios"

    // App metadata is constant for the process — resolve once.
    private static let appPackageName = Bundle.main.bundleIdentifier
    private static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    private static let appTitle =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)

    /// A UA string the backend can parse as iOS (constructed; iOS has no `http.agent` equivalent).
    private static let userAgent: String = {
        let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osVersion) like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 "
            + "AudienzziOSSDK/\(AUSDKVersion)"
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    func toNetwork(_ event: AUEventDomain) -> AUEventNetwork {
        let screen = UIScreen.main.bounds.size
        let width = Int(screen.width)
        let height = Int(screen.height)

        return AUEventNetwork(
            eventType: event.type.rawValue,
            companyId: event.companyId,
            source: Self.source,
            eventId: event.uuid ?? UUID().uuidString.lowercased(),
            pageImpressionId: event.pageImpressionId,
            sessionId: event.sessionId,
            sessionStartTimestamp: event.sessionStartTimestamp,
            sessionSeq: event.sessionSeq ?? 0,
            eventTimestamp: Self.dateFormatter.string(from: event.timestamp),
            locale: Locale.current.identifier,
            zoneOffsetSeconds: TimeZone.current.secondsFromGMT(),
            screenHeight: height,
            screenWidth: width,
            viewportHeight: height,
            viewportWidth: width,
            deviceId: event.deviceId,
            userAgent: Self.userAgent,
            sdkName: Self.sdkName,
            sdkVersion: AUSDKVersion,
            appPackageName: Self.appPackageName,
            appVersion: Self.appVersion,
            appTitle: Self.appTitle,
            screenName: event.screenName,
            pageUrl: nil,
            visitorId: event.visitorId,
            attributes: Self.buildAttributes(event)
        )
    }

    private static func buildAttributes(_ e: AUEventDomain) -> [String: String] {
        var a: [String: String] = [:]
        if let v = e.adUnitId { a["ad_unit_id"] = v }
        if let v = e.resultCode { a["result_code"] = v }
        if let v = e.sizes { a["sizes"] = v }
        if let v = e.adType { a["ad_type"] = v }
        if let v = e.adSubtype { a["ad_subtype"] = v }
        if let v = e.apiType { a["api_type"] = v }
        if let v = e.isAutorefresh { a["autorefresh"] = String(v) }
        if let v = e.autorefreshTime { a["autorefresh_time"] = String(v) }
        if let v = e.isRefresh { a["refresh"] = String(v) }
        if let v = e.timeToRespond { a["time_to_respond"] = String(v) }
        if let v = e.bidderCode { a["bidder_code"] = v }
        if let v = e.winnerBidderCode { a["winner_bidder_code"] = v }
        if let v = e.priceBucket { a["price_bucket"] = v }
        if let v = e.hbSize { a["hb_size"] = v }
        if let v = e.hbFormat { a["hb_format"] = v }
        if let v = e.cpm { a["cpm"] = String(v) }
        if let v = e.currency { a["currency"] = v }
        if let v = e.creativeId { a["creative_id"] = v }
        if let v = e.auctionId { a["auction_id"] = v }
        if let v = e.adId { a["ad_id"] = v }
        return a
    }
}
