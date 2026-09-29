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
/// handed to `AUEventQueue` for durable batched delivery to the collector (mirrors the
/// Android `EventLoggerImpl` + `EventBatcher`).
final class AUEventsManager: AULogEventType {
    static let shared = AUEventsManager()

    private var visitorId: String = "visitorId"
    private var companyId: String = "companyId"
    private let sessionId: String = AUUniqHelper.makeUniqID()
    /// Unix time in **seconds**, fixed for the life of the session.
    ///
    /// It was milliseconds until this release, which is why historical rows are ~1e12 and new ones
    /// are ~1e9. A consumer can tell them apart by magnitude — see `docs/analytics-contract.md`
    /// for the migration rule. Durations (`time_to_respond`, `autorefresh_time`) are unchanged and
    /// remain milliseconds; only this absolute timestamp moved.
    private let sessionStartTimestamp: Int64 = Int64(Date().timeIntervalSince1970)

    /// The advertising identifier, re-read per event rather than cached for the session.
    ///
    /// `nil` means "not available" and the field is omitted from the payload: analytics must work
    /// without it. Nothing is substituted — not the PPID, not the IDFV, not a fingerprint — and the
    /// all-zero IDFA that ATT returns when tracking is not authorized is not an identity, so it is
    /// never sent either.
    private var deviceId: String?

    /// Monotonic per-session counter so the backend can order events regardless of POST arrival.
    private var sessionSeq: Int = 0
    private let seqLock = NSLock()

    /// Regenerated on every `onScreenResumed`; tags all ad events with the current screen visit.
    private var currentPageContext = AUAnalyticsPageContext()
    private let pageLock = NSLock()

    func capturePageContext() -> AUAnalyticsPageContext {
        pageLock.lock(); defer { pageLock.unlock() }
        return currentPageContext
    }

    private let mapper = AUEventNetworkMapper()
    private var eventQueue: AUEventQueue?
    private let makeQueue: () -> AUEventQueue
    private let configureLock = NSLock()
    private var lifecycleObserved = false

    init(makeQueue: @escaping () -> AUEventQueue = {
        AUEventQueue(networkManager: AUEventsNetworkManager<AUBatchResultModel>())
    }) {
        self.makeQueue = makeQueue
    }

    func configure(companyId: String) {
        configureLock.lock()
        defer { configureLock.unlock() }
        // Reinitializing the SDK must not create a second writer for the same durable outbox.
        if eventQueue == nil { eventQueue = makeQueue() }
        visitorId = makeVisitorId()
        self.companyId = companyId
        observeAppLifecycle()
    }

    // MARK: - Screen tracking

    /// Report every screen visit, including screens without ads. Refreshes retain the visit ID;
    /// another page impression (including returning to the same screen) creates a new one.
    func onScreenResumed(screenName: String) {
        let page = AUAnalyticsPageContext(pageImpressionId: AUUniqHelper.makeUniqID(), screenName: screenName)
        pageLock.lock()
        currentPageContext = page
        pageLock.unlock()
        var event = AUEventDomain(type: .pageImpression)
        event.pageContext = page
        event.screenName = screenName
        event.consentString = AUTargeting.shared.gdprConsentString
        logEvent(event)
    }

    // MARK: - Logging

    /// Sees every event handed to ``logEvent(_:)``, before anything decides whether it is sent.
    /// Tests only: it is how a test proves an event was — or was not — reported.
    var observerForTesting: ((AUEventDomain) -> Void)?

    func logEvent(_ event: AUEventDomain) {
        var enriched = event
        let page = event.pageContext ?? capturePageContext()
        enriched.pageImpressionId = event.pageImpressionId ?? page.pageImpressionId
        enriched.screenName = event.screenName ?? page.screenName
        observerForTesting?(enriched)
        guard let eventQueue = eventQueue else { return }
        requestDeviceId()

        enriched.uuid = AUUniqHelper.makeUniqID()
        enriched.visitorId = visitorId
        let context = AUAnalyticsContext.shared.snapshot()
        enriched.publisherId = context.publisherId
        enriched.environment = context.environment
        enriched.sessionId = sessionId
        enriched.sessionStartTimestamp = sessionStartTimestamp
        enriched.deviceId = deviceId
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
        // Persist off the UI thread, then batch delivery with persistent retries.
        eventQueue.enqueue(json)
    }

    // MARK: - App lifecycle (delivery hint)

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

    /// Re-read the advertising identifier for every event.
    ///
    /// Caching it for the session was wrong in both directions: authorization granted after the
    /// first event was never picked up, and — worse — authorization *revoked* after an authorized
    /// event left the SDK emitting an identifier the user had withdrawn. `ASIdentifierManager` is a
    /// cheap local read, so there is nothing to gain by holding it.
    ///
    /// The all-zero UUID is what ATT returns when tracking is not authorized (and what the
    /// simulator returns by default). It is a sentinel, not an identity, so it becomes `nil` and
    /// the field is omitted. The SDK never prompts for ATT on the publisher's behalf.
    private func requestDeviceId() {
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString.lowercased()
        deviceId = Self.usableDeviceId(idfa)
    }

    /// Exposed for tests: the session-start value the manager actually emits, so its UNIT can be
    /// asserted where it is chosen rather than where it is merely copied.
    var sessionStartTimestampForTesting: Int64 { sessionStartTimestamp }

    /// Exposed for tests: the rule that turns a raw IDFA into either an identity or nothing.
    static func usableDeviceId(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let normalized = raw.lowercased()
        guard normalized != "00000000-0000-0000-0000-000000000000" else { return nil }
        return normalized
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
