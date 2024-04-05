/*   Copyright 2018-2024 Audienzz.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License";
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

public enum AUContextSubType: Int {
        
    case General = 10

    case Article = 11

    case Video = 12

    case Audio = 13

    case Image = 14

    case UserGenerated = 15

    case Social = 20

    case email = 21

    case chatIM = 22

    case SellingProduct = 30

    case AppStore = 31

    case ReviewSite = 32

    case Custom = 500
    
    internal var toContextSubType: ContextSubType {
        ContextSubType(integerLiteral: self.rawValue)
    }
}
