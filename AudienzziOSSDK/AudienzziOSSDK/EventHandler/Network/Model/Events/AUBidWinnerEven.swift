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

struct AUBidWinnerEven: Codable, AUEventHandlerType {
    let resultCode: String
    let adUnitID: String
    let targetKeywords: [String: String]
    let isAutorefresh: Bool
    let autorefreshTime: Int
    let initialRefresh: Bool?
    let adViewId: String
    let size: String
    let adType: String
    let adSubType: String
    let apiType: String
    let type: AUAdEventType
    
    init(resultCode: String, adUnitID: String, targetKeywords: [String : String], isAutorefresh: Bool, autorefreshTime: Int, initialRefresh: Bool?, adViewId: String, size: String, adType: String, adSubType: String, apiType: String) {
        self.resultCode = resultCode
        self.adUnitID = adUnitID
        self.targetKeywords = targetKeywords
        self.isAutorefresh = isAutorefresh
        self.autorefreshTime = autorefreshTime
        self.initialRefresh = initialRefresh
        self.adViewId = adViewId
        self.size = size
        self.adType = adType
        self.adSubType = adSubType
        self.apiType = apiType
        self.type = .BID_WINNER
    }
    
    init?(_ payload: PayloadModel) {
        self.adViewId = payload.adViewId
        self.adUnitID = payload.adUnitID
        self.type = payload.type
        
        guard let isAutorefresh = payload.isAutorefresh,
              let size = payload.size,
              let autorefreshTime = payload.autorefreshTime,
              let adType = payload.adType,
              let adSubType = payload.adSubType,
              let apiType = payload.apiType,
              let resultCode = payload.resultCode,
              let targetKeywords = payload.targetKeywords
        else { return nil}
        
        self.size = size
        self.isAutorefresh = isAutorefresh
        self.autorefreshTime = autorefreshTime
        self.initialRefresh = payload.initialRefresh
        self.adType = adType
        self.adSubType = adSubType
        self.apiType = apiType
        self.resultCode = resultCode
        self.targetKeywords = targetKeywords
    }
    
    func convertToJSONString() -> String? {
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
