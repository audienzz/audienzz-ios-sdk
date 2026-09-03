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
#if canImport(UIKit)
import UIKit
#endif

fileprivate let keyVisitorId = "keyVisitorId"

/// Clickstream analytics logger. Each event is enriched with identity/session data, serialized, and
/// handed to `AUEventQueue`, which coalesces events into batched POSTs to the collector (mirrors the
/// Android `EventLoggerImpl` + `EventBatcher`).
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
    private var currentScreenName: String?

    private let mapper = AUEventNetworkMapper()
    private var eventQueue: AUEventQueue?
    private var lifecycleObserved = false

    func configure(companyId: String) {
        let networkManager = AUEventsNetworkManager<AUBatchResultModel>()
        eventQueue = AUEventQueue(networkManager: networkManager)
        visitorId = makeVisitorId()
        self.companyId = companyId
        observeAppLifecycle()
    }

    // MARK: - Screen tracking

    /// Call from every screen (UIViewController) that shows ads. Generates a fresh page-impression
    /// id and fires a `pageImpression`; subsequent ad events are tagged with that id.
    func onScreenResumed(screenName: String) {
        currentPageImpressionId = AUUniqHelper.makeUniqID()
        currentScreenName = screenName
        var event = AUEventDomain(type: .pageImpression)
        event.screenName = screenName
        event.consentString = AUTargeting.shared.gdprConsentString
        logEvent(event)
    }

    // MARK: - Logging

    func logEvent(_ event: AUEventDomain) {
        guard let eventQueue = eventQueue else { return }
        requestDeviceId()

        // Safety net: if an ad event fires before any onScreenResumed (e.g. a banner prefetches
        // during layout, before the host's viewWillAppear), lazily start a page-impression id so the
        // event is never orphaned. onScreenResumed normally sets this first, so this rarely triggers.
        if currentPageImpressionId == nil, event.type != .pageImpression {
            currentPageImpressionId = AUUniqHelper.makeUniqID()
        }

        var enriched = event
        enriched.uuid = AUUniqHelper.makeUniqID()
        enriched.visitorId = visitorId
        enriched.companyId = companyId
        enriched.sessionId = sessionId
        enriched.sessionStartTimestamp = sessionStartTimestamp
        enriched.deviceId = deviceId
        enriched.pageImpressionId = currentPageImpressionId
        // Screen name of the current visit rides on every event (not just pageImpression).
        enriched.screenName = enriched.screenName ?? currentScreenName
        // website_id — the remote-config publisher id (resolved async; nil for very early events).
        enriched.websiteId = AudienzzRemoteConfig.shared.publisherId
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
        // Enqueue for batched delivery; the queue coalesces events and POSTs them to /submit/batch
        // on size/time/background triggers, with bounded retry.
        eventQueue.enqueue(json)
    }

    // MARK: - App lifecycle (batch flush)

    /// Flush the event queue when the app backgrounds (so a pending buffer isn't stranded) and again
    /// when it returns to the foreground (drains anything left after a failed/backoff cycle). Uses
    /// block-based observers (added once) since `AUEventsManager` is not an `NSObject`.
    private func observeAppLifecycle() {
        #if canImport(UIKit)
        guard !lifecycleObserved else { return }
        lifecycleObserved = true
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                       object: nil, queue: .main) { [weak self] _ in
            self?.flushOnBackground()
        }
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification,
                       object: nil, queue: .main) { [weak self] _ in
            self?.eventQueue?.flush()
        }
        #endif
    }

    #if canImport(UIKit)
    private func flushOnBackground() {
        // Buy a little time for the in-flight batch to complete after the app leaves the foreground.
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "AUEventsFlush") {
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
        }
        eventQueue?.flush()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
        }
    }
    #endif

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
