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
import GoogleMobileAds

/// DEBUG-only diagnostics that dump what GAM/Prebid actually hand us at runtime, so we can decide
/// empirically whether a served creative id or currency is recoverable without the Prebid fork.
/// Compiled out of release builds. Nothing here feeds the analytics payload.
enum AUAnalyticsDebugProbe {

    /// Every keyword Prebid attached to the GAM request. Reveals all `hb_*` keys — including any
    /// bidder-specific `*creative_id` variant — so we know exactly what's available from targeting.
    static func logTargeting(_ raw: [AnyHashable: Any], context: String) {
        #if DEBUG
        guard !raw.isEmpty else {
            AULogEvent.logDebug("[AUProbe][\(context)] GAM targeting: <empty>")
            return
        }
        let keys = raw.keys.compactMap { $0 as? String }.sorted()
        AULogEvent.logDebug("[AUProbe][\(context)] GAM targeting keys (\(keys.count)): \(keys.joined(separator: ", "))")
        for k in keys {
            let v = raw[k]
            AULogEvent.logDebug("[AUProbe][\(context)]   \(k) = \(String(describing: v))")
        }
        #endif
    }

    /// The GMA paid event — the fork-free source for currency (and cpm on a direct fill).
    static func logAdValue(_ value: AdValue, context: String) {
        #if DEBUG
        AULogEvent.logDebug("[AUProbe][\(context)] paidEvent value=\(value.value) currency=\(value.currencyCode) precision=\(value.precision.rawValue)")
        #endif
    }

    /// Everything GAM exposes about the served ad at impression time. `dictionaryRepresentation`
    /// and `extras` are untyped runtime dicts — if GAM leaks a served creative id anywhere, it shows
    /// up here. `loadedAdNetworkResponseInfo` names the rendering ad source (google vs a mediated SSP).
    static func logResponseInfo(_ info: ResponseInfo?, context: String) {
        #if DEBUG
        guard let info else {
            AULogEvent.logDebug("[AUProbe][\(context)] responseInfo: nil")
            return
        }
        AULogEvent.logDebug("[AUProbe][\(context)] responseInfo.responseIdentifier = \(String(describing: info.responseIdentifier))")
        AULogEvent.logDebug("[AUProbe][\(context)] responseInfo.extras = \(info.extras)")
        AULogEvent.logDebug("[AUProbe][\(context)] responseInfo.dictionaryRepresentation = \(info.dictionaryRepresentation)")
        if let loaded = info.loadedAdNetworkResponseInfo {
            AULogEvent.logDebug("[AUProbe][\(context)] loaded.adSourceName = \(String(describing: loaded.adSourceName))")
            AULogEvent.logDebug("[AUProbe][\(context)] loaded.adSourceID = \(String(describing: loaded.adSourceID))")
            AULogEvent.logDebug("[AUProbe][\(context)] loaded.adNetworkClassName = \(String(describing: loaded.adNetworkClassName))")
            AULogEvent.logDebug("[AUProbe][\(context)] loaded.adUnitMapping = \(String(describing: loaded.adUnitMapping))")
            AULogEvent.logDebug("[AUProbe][\(context)] loaded.dictionaryRepresentation = \(loaded.dictionaryRepresentation)")
        }
        #endif
    }
}
