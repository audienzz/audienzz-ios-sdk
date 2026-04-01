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

protocol AUEventHandlerType: BodyObjectEncodable {
    var type: AUAdEventType { get }
    var visitorId: String { get set }
    var companyId: String { get set }
    var sessionId: String { get set }
    var deviceId: String { get set }
}

enum AUAdEventType: String, Codable, CaseIterable, Equatable {
    case HEADER_LOADED       = "headerLoaded"
    case PAGE_IMPRESSION     = "pageImpression"
    case BID_REQUEST         = "bidRequest"
    case BID_RESPONSE        = "bidResponse"
    case BID_WON             = "bidWon"
    case NO_BID              = "noBid"
    case AD_IMPRESSION       = "adImpression"
    case AD_VIEW             = "adView"
    case AD_CLICK            = "adClick"
    case VIEWABILITY_MEASURED = "viewabilityMeasured"
}
