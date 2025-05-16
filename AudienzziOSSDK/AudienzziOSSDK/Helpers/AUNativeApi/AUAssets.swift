/*   Copyright 2018-2025 Audienzz.org, Inc.

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

@objc public enum AUImageAsset: Int {

    case Icon = 1

    case Main = 3

    case Custom = 500

    internal var toImageAsset: SingleContainerInt {
        switch self {
        case .Icon, .Main:
            ImageAsset(integerLiteral: self.rawValue)
        case .Custom:
            ContextType(integerLiteral: self.rawValue)
        }
    }
}

@objc public enum AUDataAsset: Int {
    case sponsored = 1
    case description = 2
    case rating = 3
    case likes = 4
    case downloads = 5
    case price = 6
    case saleprice = 7
    case phone = 8
    case address = 9
    case description2 = 10
    case displayurl = 11
    case ctatext = 12
    case Custom = 500

    internal var toDataAsset: DataAsset {
        DataAsset(rawValue: self.rawValue) ?? DataAsset.Custom
    }
}
