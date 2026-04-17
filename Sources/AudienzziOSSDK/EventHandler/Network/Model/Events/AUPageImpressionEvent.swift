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

struct AUPageImpressionEvent: AUEventHandlerType {
    let adViewId: String
    let adUnitID: String
    let screenName: String
    let type: AUAdEventType = .PAGE_IMPRESSION

    var visitorId: String = ""
    var companyId: String = ""
    var sessionId: String = ""
    var sessionStartTimestamp: Int = 0
    var deviceId: String = ""
    var pageImpressionId: String? = nil
    var screenWidth: Int = 0
    var screenHeight: Int = 0
    var locale: String = ""
    var zoneOffsetSeconds: Int = 0

    init(adViewId: String, adUnitID: String, screenName: String) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.screenName = screenName
    }
}

extension AUPageImpressionEvent: BodyObjectEncodable {
    func encode() -> JSONObject {
        var attrs = JSONObject()
        attrs["device_id"] = deviceId
        attrs["ad_unit_id"] = adUnitID
        return buildFlatPayload(pageUrl: screenName, attributes: attrs)
    }
}
