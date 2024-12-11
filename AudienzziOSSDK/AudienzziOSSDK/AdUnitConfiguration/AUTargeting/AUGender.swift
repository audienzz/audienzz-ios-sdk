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

@objc(PBMGender)
public enum AUGender : Int {
    case unknown
    case male
    case female
    case other
}

enum AUGenderDescription : String {
    case male       = "M"
    case female     = "F"
    case other      = "O"
}

func AUGenderFromDescription(_ genderDescription: String) -> AUGender {
    guard let knownGender = AUGenderDescription(rawValue: genderDescription) else {
        return .unknown
    }
    
    switch knownGender {
        case .male:      return .male
        case .female:    return .female
        case .other:     return .other
    }
}

func DescriptionOfAUGender(_ gender: AUGender) -> String? {
    switch gender {
        case .unknown:   return nil
        case .male:      return AUGenderDescription.male.rawValue
        case .female:    return AUGenderDescription.female.rawValue
        case .other:     return AUGenderDescription.other.rawValue
    }
}

internal extension AUGender {
    func unwrap() -> Gender {
        switch self {
        case .unknown:
            Gender.unknown
        case .male:
            Gender.male
        case .female:
            Gender.female
        case .other:
            Gender.other
        }
    }
    
    init(with gender: Gender) {
        switch gender {
        case .unknown:
            self = AUGender.unknown
        case .male:
            self = AUGender.male
        case .female:
            self = AUGender.female
        case .other:
            self = AUGender.other
        @unknown default:
            self = AUGender.unknown
        }
    }
}
