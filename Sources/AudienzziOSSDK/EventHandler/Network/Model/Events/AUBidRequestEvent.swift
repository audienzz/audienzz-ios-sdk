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

struct AUBidRequestEvent: AUEventHandlerType {
    let adViewId: String
    let adUnitID: String
    let size: String?
    let isAutorefresh: Bool
    let autorefreshTime: Int
    let initialRefresh: Bool?
    let adType: String
    let adSubType: String
    let apiType: String
    let type: AUAdEventType = .BID_REQUEST

    var visitorId: String = ""
    var companyId: String = ""
    var sessionId: String = ""
    var deviceId: String = ""

    init(adViewId: String, adUnitID: String, size: String?,
         isAutorefresh: Bool, autorefreshTime: Int, initialRefresh: Bool?,
         adType: String, adSubType: String, apiType: String) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.size = size
        self.isAutorefresh = isAutorefresh
        self.autorefreshTime = autorefreshTime
        self.initialRefresh = initialRefresh
        self.adType = adType
        self.adSubType = adSubType
        self.apiType = apiType
    }
}

extension AUBidRequestEvent: BodyObjectEncodable {
    func encode() -> JSONObject {
        var result = JSONObject()
        result["source"] = "mobile-sdk"
        result["type"] = type.rawValue
        result["datacontenttype"] = "application/json"
        result["specversion"] = "1.0"
        result["id"] = AUUniqHelper.makeUniqID()

        var data = JSONObject()
        data["adUnitId"] = adUnitID
        data["visitorId"] = visitorId
        data["companyId"] = companyId
        data["sessionId"] = sessionId
        data["deviceId"] = deviceId
        if size != AUUniqHelper.sizeUndefined { data["sizes"] = size }
        data["adType"] = adType
        data["adSubtype"] = adSubType
        data["apiType"] = apiType
        data["autorefresh"] = isAutorefresh
        data["autorefreshTime"] = autorefreshTime
        data["refresh"] = initialRefresh

        result["data"] = data
        result["time"] = Date().currentTimeStmp
        return result
    }
}
