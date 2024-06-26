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

protocol TestableValue {
    static var random: Self { get }
}

extension String: TestableValue {
    static var random: String {
        return String(Int.random(in: Range(uncheckedBounds: (Int.min, Int.max))))
    }
}

extension TimeInterval: TestableValue {
    static var random: TimeInterval {
        return TimeInterval(Int.random)
    }
}

extension Bool: TestableValue {
    static var random: Bool {
        return Bool.random()
    }
}

extension Int: TestableValue {
    static var random: Int {
        return Int.random(in: Range(uncheckedBounds: (Int.min, Int.max)))
    }
}

extension AUAdEventType: TestableValue {
    static var random: AUAdEventType {
        let allTypes = [AUAdEventType.BID_WINNER.rawValue,
                        AUAdEventType.AD_CLICK.rawValue,
                        AUAdEventType.VIEWABILITY.rawValue,
                        AUAdEventType.BID_REQUEST.rawValue,
                        AUAdEventType.AD_CREATION.rawValue,
                        AUAdEventType.CLOSE_AD.rawValue,
                        AUAdEventType.AD_FAILED_TO_LOAD.rawValue,
                        AUAdEventType.SCREEN_IMPRESSION.rawValue]

        let randType: AUAdEventType = AUAdEventType(rawValue: allTypes.randomElement()!)!

        switch randType {
        case .BID_WINNER:
            return .BID_WINNER
        case .AD_CLICK:
            return .AD_CLICK
        case .VIEWABILITY:
            return .VIEWABILITY
        case .BID_REQUEST:
            return .BID_REQUEST
        case .AD_CREATION:
            return .AD_CREATION
        case .CLOSE_AD:
            return .CLOSE_AD
        case .AD_FAILED_TO_LOAD:
            return .AD_FAILED_TO_LOAD
        case .SCREEN_IMPRESSION:
            return .SCREEN_IMPRESSION
        }
    }
}
