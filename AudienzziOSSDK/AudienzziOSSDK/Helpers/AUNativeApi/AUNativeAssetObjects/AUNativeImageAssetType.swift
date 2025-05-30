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
import PrebidMobile

@objc public enum AUNativeImageAssetType: Int {
    case icon = 1
    case main = 3

    case custom = 500

    init(value: Int) {
        switch value {
        case 1:
            self = .icon
        case 3:
            self = .main
        case 500:
            self = .custom
        default:
            self = .custom
        }
    }

    internal func unwrap() -> NativeImageAssetType {
        NativeImageAssetType(rawValue: self.rawValue) ?? .custom
    }
}
