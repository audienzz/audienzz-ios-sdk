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
import PrebidMobile

/**
 # OpenRTB - API Frameworks #
 ```
 | Value | Description |
 |-------|-------------|
 | 1     | VPAID 1.0   |
 | 2     | VPAID 2.0   |
 | 3     | MRAID-1     |
 | 4     | ORMMA       |
 | 5     | MRAID-2     |
 | 6     | MRAID-3     |
 | 7     | OMID-1      |
 ```
 */

@objc(AUApiType)
public enum AUApiType: Int {
    case VPAID_1 = 1
    case VPAID_2 = 2
    case MRAID_1 = 3
    case ORMMA   = 4
    case MRAID_2 = 5
    case MRAID_3 = 6
    case OMID_1 = 7
    
    internal var toAPI: Signals.Api {
        Signals.Api(integerLiteral: self.rawValue)
    }
}

@objc(AUApi)
public class AUApi: NSObject {
    @objc var apiType: AUApiType
    
    @objc public init(apiType: AUApiType) {
        self.apiType = apiType
    }
}

