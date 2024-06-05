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

protocol AUEventHandlerType {
    init?(_ payload: PayloadModel)
}

public enum AUAdEventType: String, Codable {
    case BID_WINNER = "BID_WINNER"
    case AD_CLICK = "AD_CLICK"
    case VIEWABILITY = "VIEWABILITY"
    case BID_REQUEST = "BID_REQUEST"
    case AD_CREATION = "AD_CREATION"
    case CLOSE_AD = "CLOSE_AD"
    case AD_FAILED_TO_LOAD = "AD_FAILED_TO_LOAD"
}

protocol NetDBPayloadType {
    func makePayload() -> String?
}

public struct PayloadModel: Codable, NetDBPayloadType {
    let adViewId: String
    let adUnitID: String
    let type: AUAdEventType

    let resultCode: String?
    let targetKeywords: [String: String]?
    let isAutorefresh: Bool?
    let autorefreshTime: Int?
    let initialRefresh: Int?
    let size: String?
    let adType: String?
    let adSubType: String?
    let apiType: String?
    
    let errorMessage: String?
    let errorCode: Int?
    
    public init(adViewId: String,
         adUnitID: String,
         type: AUAdEventType,
         resultCode: String?,
         targetKeywords: [String: String]?,
         isAutorefresh: Bool?,
         autorefreshTime: Int?,
         initialRefresh: Int?,
         size: String?,
         adType: String?,
         adSubType: String?,
         apiType: String?,
         errorMessage: String?,
         errorCode: Int?) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.type = type
        
        self.resultCode = resultCode
        self.targetKeywords = targetKeywords
        self.isAutorefresh = isAutorefresh
        self.autorefreshTime = autorefreshTime
        self.initialRefresh = initialRefresh
        self.size = size
        self.adType = adType
        self.adSubType = adSubType
        self.apiType = apiType
        
        self.errorMessage = errorMessage
        self.errorCode = errorCode
    }
    
    public init(adViewId: String, adUnitID: String ,type: AUAdEventType) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.type = type
        
        self.resultCode = nil
        self.targetKeywords = nil
        self.isAutorefresh = nil
        self.autorefreshTime = nil
        self.initialRefresh = nil
        self.size = nil
        self.adType = nil
        self.adSubType = nil
        self.apiType = nil
        
        self.errorMessage = nil
        self.errorCode = nil
    }
    
    
    func makePayload() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Optional: for pretty-printed JSON
            let jsonData = try encoder.encode(self)
            
            // Convert JSON data to a JSON string
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("JSON String:\n\(jsonString)")
                return jsonString
            }
        } catch {
            print("Error encoding user: \(error)")
        }
        
        return nil
    }
}
