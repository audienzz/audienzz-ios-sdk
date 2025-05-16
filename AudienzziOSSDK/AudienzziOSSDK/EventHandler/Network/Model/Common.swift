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
    init?(_ payload: PayloadModel)
    var type: AUAdEventType { get }
}

protocol NetDBPayloadType {
    func makePayload() -> String?
}

enum AUAdEventType: String, Codable, CaseIterable, Equatable {
    case BID_WINNER = "mobile.bid_winner"
    case AD_CLICK = "mobile.ad_click"
    case BID_REQUEST = "mobile.bid_request"
    case AD_CREATION = "mobile.ad_creation"
    case CLOSE_AD = "mobile.close_ad"
    case AD_FAILED_TO_LOAD = "mobile.ad_failed_to_load"
    case SCREEN_IMPRESSION = "mobile.screen_impression"
}

struct PayloadModel: Codable, NetDBPayloadType, Equatable {
    let adViewId: String
    let adUnitID: String
    let type: AUAdEventType
    
    let visitorId: String
    let companyId: String
    let sessionId: String
    let deviceId: String

    let resultCode: String?
    let targetKeywords: [String: String]?
    let isAutorefresh: Bool?
    let autorefreshTime: Int?
    let initialRefresh: Bool?
    let size: String?
    let adType: String?
    let adSubType: String?
    let apiType: String?
    
    let errorMessage: String?
    let errorCode: Int?
    let screenName: String? 
    
    init(adViewId: String,
         adUnitID: String,
         type: AUAdEventType,
         visitorId: String,
         companyId: String,
         sessionId: String,
         deviceId: String) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.type = type
        
        self.visitorId = visitorId
        self.companyId = companyId
        self.sessionId = sessionId
        self.deviceId = deviceId
        
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
        self.screenName = nil
    }
    
    init(adViewId: String,
         adUnitID: String,
         type: AUAdEventType,
         visitorId: String,
         companyId: String,
         sessionId: String,
         deviceId: String,
         resultCode: String? = nil,
         targetKeywords: [String: String]? = nil,
         isAutorefresh: Bool? = nil,
         autorefreshTime: Int? = nil,
         initialRefresh: Bool? = nil,
         size: String? = nil,
         adType: String? = nil,
         adSubType: String? = nil,
         apiType: String? = nil,
         errorMessage: String? = nil,
         errorCode: Int? = nil,
         screenName: String? = nil) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.type = type
        
        self.visitorId = visitorId
        self.companyId = companyId
        self.sessionId = sessionId
        self.deviceId = deviceId
        
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
        self.screenName = screenName
    }
    
    
    func makePayload() -> String? {
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
