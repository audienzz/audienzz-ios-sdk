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

struct BatchModel {
    let visitorId: Int64
    let appnexusId: String?
    let profileHash: String?
    let tenantId: Int64?
    
    init(visitorId: Int64) {
        self.visitorId = visitorId
        self.appnexusId = nil
        self.profileHash = nil
        self.tenantId = nil
    }
}

extension BatchModel: BodyObjectEncodable {
    func encode() -> JSONObject {
        var result = JSONObject()
        
        result["visitorId"] = visitorId
        result["appnexusId"] = appnexusId
        result["profileHash"] = profileHash
        result["tenantId"] = tenantId
        
        return result
    }
}

struct BatchRequestModel {
    let batch: BatchModel
    let netModels: [AUEventHandlerType]
    
    init(batch: BatchModel, netModels: [AUEventHandlerType]) {
        self.batch = batch
        self.netModels = netModels
    }
}

extension BatchRequestModel: BodyObjectEncodable {
    func encode() -> JSONObject {
        var result = JSONObject()
        result = batch.encode()
        result["body"] = netModels.compactMap { $0.encode() }
        
        return result
    }
}
