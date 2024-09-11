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

@objc public enum AUNativeDataAssetType: Int {
    case undefined  = 0
    case sponsored  = 1 /// Sponsored By message where response should contain the brand name of the sponsor.
    case desc       = 2 /// Descriptive text associated with the product or service being advertised. Longer length of text in response may be truncated or ellipsed by the exchange.
    case rating     = 3 /// Rating of the product being offered to the user. For example an app’s rating in an app store from 0-5.
    case likes      = 4 /// Number of social ratings or “likes” of the product being offered to the user.
    case downloads  = 5 /// Number downloads/installs of this product
    case price      = 6 /// Price for product / app / in-app purchase. Value should include currency symbol in localised format.
    case salePrice  = 7 /// Sale price that can be used together with price to indicate a discounted price compared to a regular price. Value should include currency symbol in localised format.
    case phone      = 8 /// Phone number
    case address    = 9 /// Address
    case desc2      = 10 /// Additional descriptive text associated text with the product or service being advertised
    case displayURL = 11 /// Display URL for the text ad. To be used when sponsoring entity doesn’t own the content. IE sponsored by BRAND on SITE (where SITE is transmitted in this field).
    case ctaText    = 12 /// CTA description - descriptive text describing a ‘call to action’ button for the destination URL.
    
    case custom     = 500 /// Reserved for Exchange specific usage numbered above 500
    
    internal func unwrap() -> NativeDataAssetType {
        NativeDataAssetType(rawValue: self.rawValue) ?? .undefined
    }
    
    init(value: Int) {
        switch value {
        case 0:
            self = .undefined
        case 1:
            self = .sponsored
        case 2:
            self = .desc
        case 3:
            self = .rating
        case 4:
            self = .likes
        case 5:
            self = .downloads
        case 6:
            self = .price
        case 7:
            self = .salePrice
        case 8:
            self = .phone
        case 9:
            self = .address
        case 10:
            self = .desc2
        case 11:
            self = .displayURL
        case 12:
            self = .ctaText
        case 500:
            self = .custom
        default:
            self = .undefined
        }
    }
}
