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
import AdSupport

fileprivate let keyVisitorId = "keyVisitorId"

/// Clickstream analytics logger. Each event is enriched with identity/session data and POSTed
/// immediately to the collector (mirrors the Android `EventLoggerImpl` — no local queue/batching).
final class AUEventsManager: AULogEventType {
    static let shared = AUEventsManager()

    private var visitorId: String = "visitorId"
    private var companyId: String = "companyId"
    private let sessionId: String = AUUniqHelper.makeUniqID()
    private let sessionStartTimestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    private var deviceId: String = ""

    /// Monotonic per-session counter so the backend can order events regardless of POST arrival.
    private var sessionSeq: Int = 0
    private let seqLock = NSLock()

    /// Regenerated on every `onScreenResumed`; tags all ad events with the current screen visit.
    private var currentPageImpressionId: String?

    private let mapper = AUEventNetworkMapper()
    private var networkManager: AUEventsNetworkManager<AUBatchResultModel>!

    func configure(companyId: String) {
        networkManager = AUEventsNetworkManager<AUBatchResultModel>()
        visitorId = makeVisitorId()
        self.companyId = companyId
    }

    // MARK: - Screen tracking

    /// Call from every screen (UIViewController) that shows ads. Generates a fresh page-impression
    /// id and fires a `pageImpression`; subsequent ad events are tagged with that id.
    func onScreenResumed(screenName: String) {
        currentPageImpressionId = AUUniqHelper.makeUniqID()
        var event = AUEventDomain(type: .pageImpression)
        event.screenName = screenName
        logEvent(event)
    }

    // MARK: - Logging

    func logEvent(_ event: AUEventDomain) {
        guard networkManager != nil else { return }
        requestDeviceId()

        var enriched = event
        enriched.uuid = AUUniqHelper.makeUniqID()
        enriched.visitorId = visitorId
        enriched.companyId = companyId
        enriched.sessionId = sessionId
        enriched.sessionStartTimestamp = sessionStartTimestamp
        enriched.deviceId = deviceId
        enriched.pageImpressionId = currentPageImpressionId
        enriched.sessionSeq = nextSequence()

        let network = mapper.toNetwork(enriched)
        guard let json = Self.jsonObject(from: network) else {
            AULogEvent.logDebug("[AUAnalytics] ✗ failed to encode analytics event")
            return
        }
        // Verification logging: one tagged block per event with the exact flat payload that is
        // POSTed (includes cpm/currency/creative_id/auction_id/ad_id, bidder_code, session_seq,
        // viewability events). Filter the Xcode console by "AUAnalytics" to copy the run.
        #if DEBUG
        if let pretty = try? JSONSerialization.data(
                withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            print("[AUAnalytics] ▶︎ \(network.eventType) seq=\(network.sessionSeq)\n\(str)")
        }
        #endif
        networkManager.request(.batchEvents([json])) { result in
            switch result {
            case .success:
                AULogEvent.logDebug(
                    "[AUAnalytics] ✓ sent \(network.eventType) seq=\(network.sessionSeq)")
            case .failure(let error):
                AULogEvent.logDebug(
                    "[AUAnalytics] ✗ FAILED \(network.eventType) seq=\(network.sessionSeq): \(error.localizedDescription)")
            }
        }
    }

    private func nextSequence() -> Int {
        seqLock.lock()
        defer { seqLock.unlock() }
        let value = sessionSeq
        sessionSeq += 1
        return value
    }

    private static func jsonObject(from network: AUEventNetwork) -> JSONObject? {
        guard let data = try? JSONEncoder().encode(network),
              let obj = try? JSONSerialization.jsonObject(with: data) as? JSONObject
        else { return nil }
        return obj
    }

    private func requestDeviceId() {
        if deviceId.isEmpty || deviceId == "00000000-0000-0000-0000-000000000000" {
            deviceId = ASIdentifierManager.shared().advertisingIdentifier.uuidString.lowercased()
        }
    }

    private func makeVisitorId() -> String {
        if let visId = UserDefaults.standard.string(forKey: keyVisitorId) {
            return visId
        } else {
            let visId = AUUniqHelper.makeUniqID()
            UserDefaults.standard.setValue(visId, forKey: keyVisitorId)
            return visId
        }
    }
}
