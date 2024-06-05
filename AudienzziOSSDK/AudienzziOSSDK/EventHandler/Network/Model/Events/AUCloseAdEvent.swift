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

struct AUCloseAdEvent: Codable, AUEventHandlerType {
    let adViewId: String
    let adUnitID: String
    let type: AUAdEventType
    
    init(adViewId: String, adUnitID: String) {
        self.adViewId = adViewId
        self.adUnitID = adUnitID
        self.type = .CLOSE_AD
    }
    
    init?(_ payload: PayloadModel) {
        self.adViewId = payload.adViewId
        self.adUnitID = payload.adUnitID
        self.type = payload.type
    }
}
