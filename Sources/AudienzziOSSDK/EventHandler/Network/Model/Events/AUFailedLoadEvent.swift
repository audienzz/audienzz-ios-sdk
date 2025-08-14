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

struct AUFailedLoadEvent: Codable, AUEventHandlerType {
    let adViewId: String
    let adUnitID: String
    let errorMessage: String
    let errorCode: Int
    let type: AUAdEventType
    
    var visitorId: String
    var companyId: String
    var sessionId: String
    var deviceId: String
    
    init(adViewId: String, adUnitID: String, errorMessage: String, errorCode: Int) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.errorMessage = errorMessage
        self.errorCode = errorCode
        self.type = .AD_FAILED_TO_LOAD
        
        self.visitorId = ""
        self.companyId = ""
        self.sessionId = ""
        self.deviceId = ""
    }
    
    init?(_ payload: PayloadModel) {
        self.adViewId = payload.adViewId
        self.adUnitID = payload.adUnitID
        self.type = payload.type
        
        self.visitorId = payload.visitorId
        self.companyId = payload.companyId
        self.sessionId = payload.sessionId
        self.deviceId = payload.deviceId
        
        guard let errorCode = payload.errorCode,
              let errorMessage = payload.errorMessage
        else { return nil }
        
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
    
    func convertToJSONString() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Optional: for pretty-printed JSON
            let jsonData = try encoder.encode(self)
            
            // Convert JSON data to a JSON string
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            AULogEvent.logDebug("Error encoding user: \(error)")
        }
        
        return nil
    }
}

extension AUFailedLoadEvent: BodyObjectEncodable {
    func encode() -> JSONObject {
        var result = JSONObject()
        
        result["source"] = "mobile-sdk"
        result["type"] = type.rawValue
        result["datacontenttype"] = "application/json"
        result["specversion"] = "1.0"
        result["id"] = AUUniqHelper.makeUniqID()
        
        var dataObject = JSONObject()
        dataObject["adUnitId"] = adUnitID
        dataObject["visitorId"] = visitorId
        dataObject["companyId"] = companyId
        dataObject["sessionId"] = sessionId
        dataObject["deviceId"] = deviceId
        dataObject["errorMessage"] = "Error Code \(errorCode): " + errorMessage
        
        result["data"] = dataObject
        result["time"] = Date().currentTimeStmp
        
        return result
    }
}
