/*   Copyright 2018-2024 Audienzz.org, Inc.
 
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

struct AUAdClickEvent: Codable, AUEventHandlerType {
    let adViewId: String
    let adUnitID: String
    
    var visitorId: String
    var companyId: String
    var sessionId: String
    var deviceId: String

    let type: AUAdEventType
    
    init?(_ payload: PayloadModel) {
        self.adViewId = payload.adViewId
        self.adUnitID = payload.adUnitID
        self.type = payload.type
        
        self.visitorId = payload.visitorId
        self.companyId = payload.companyId
        self.sessionId = payload.sessionId
        self.deviceId = payload.deviceId
    }
    
    init(adViewId: String, adUnitID: String) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.type = .AD_CLICK
        
        self.visitorId = ""
        self.companyId = ""
        self.sessionId = ""
        self.deviceId = ""
    }
    
    func convertToJSONString() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Optional: for pretty-printed JSON
            let jsonData = try encoder.encode(self)
            
            // Convert JSON data to a JSON string
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                AULogEvent.logDebug("JSON String:\n\(jsonString)")
                return jsonString
            }
        } catch {
            AULogEvent.logDebug("Error encoding user: \(error)")
        }
        
        return nil
    }
}

extension AUAdClickEvent: BodyObjectEncodable {
    func encode() -> JSONObject {
        var result = JSONObject()
        
        result["source"] = "mobile-sdk"
        result["type"] = type.rawValue
        result["datacontenttype"] = "application/json"
        result["specversion"] = "1.0"
        result["id"] = UUID().uuidString
        
        var dataObject = JSONObject()
        dataObject["adViewId"] = adViewId
        dataObject["adUnitId"] = adUnitID
        dataObject["visitorId"] = visitorId
        dataObject["companyId"] = companyId
        dataObject["sessionId"] = sessionId
        dataObject["deviceId"] = deviceId
        
        result["data"] = dataObject
        result["time"] = Date().currentTimeStmp
        
        return result
    }
}
