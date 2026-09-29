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

protocol AUAnalyticsScheduler {
    var now: TimeInterval { get }
    func schedule(on queue: DispatchQueue, after delay: TimeInterval, _ action: @escaping () -> Void) -> () -> Void
}

private struct AUAnalyticsSystemScheduler: AUAnalyticsScheduler {
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    func schedule(on queue: DispatchQueue, after delay: TimeInterval, _ action: @escaping () -> Void) -> () -> Void {
        let work = DispatchWorkItem(block: action)
        queue.asyncAfter(deadline: .now() + delay, execute: work)
        return { work.cancel() }
    }
}

/// Persist immediately on a utility worker, then send bounded batches. No disk/network work on UI.
final class AUEventQueue {
    struct Config {
        var batchSize = AUAnalyticsBatchSettings.defaultSize
        var batchBytes = 128 * 1024
        var batchDelayMs = 2000
        var minIntervalMs = 2000
        var retryBaseDelayMs = 2000
        var maxRetryDelayMs = 60_000
        static let `default` = Config()
    }
    private let config: Config
    private let networkManager: AUEventsNetworkManager<AUBatchResultModel>
    private let store: AUEventStore
    private let scheduler: AUAnalyticsScheduler
    private let jitter: () -> Double
    private let backendBatchSize: (() -> Int?)?
    private let queue = DispatchQueue(label: "com.audienzz.eventqueue", qos: .utility)
    private let admissionLock = NSLock()
    private var enqueuedCount = 0
    private var buffer: [JSONObject] = []
    private var unsaved: [JSONObject] = []
    private var unsavedBytes = 0
    private var arrived: [String: TimeInterval] = [:]
    // Flush/recovery applies only to events already queued, never to later arrivals.
    private var flushIDs = Set<String>()
    private var restoredIDs = Set<String>()
    // A known HTTP success only retries its local acknowledgement during this process.
    private var acceptedIDs = Set<String>()
    private var ackRetryAt: TimeInterval = 0
    private var ackFailures = 0
    private var lastWasBacklog = false
    private struct GroupKey: Hashable { let auction: String; let restored: Bool }
    private var plans: [[JSONObject]] = []
    private var restored = false
    private var inFlight = false
    private var cancelWake: (() -> Void)?
    private var wakeGeneration = 0
    private var lastStart: TimeInterval?
    private var retryAt: TimeInterval = 0
    private var storageRetryAt: TimeInterval = 0
    private var failureCount = 0

    init(networkManager: AUEventsNetworkManager<AUBatchResultModel>, store: AUEventStore = AUEventStore(),
         config: Config = .default, scheduler: AUAnalyticsScheduler? = nil,
         jitter: @escaping () -> Double = { Double.random(in: 0.5...1) },
         backendBatchSize: (() -> Int?)? = nil) {
        self.networkManager = networkManager; self.store = store; self.config = config
        self.scheduler = scheduler ?? AUAnalyticsSystemScheduler(); self.jitter = jitter
        self.backendBatchSize = backendBatchSize
        queue.async { [weak self] in self?.pump() }
        networkManager.onConnectionRestored = { [weak self] in self?.wake() }
    }
    deinit { cancelWake?() }

    func enqueue(_ event: JSONObject) {
        admissionLock.lock()
        guard enqueuedCount < 1024 else { admissionLock.unlock(); dropped("ingressCapacity"); return }
        enqueuedCount += 1
        admissionLock.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            defer { self.admissionLock.lock(); self.enqueuedCount -= 1; self.admissionLock.unlock() }
            guard let id = event["event_id"] as? String else { return }
            guard self.arrived[id] == nil else { return }
            guard let bytes = AUEventStore.encode(event)?.count else { self.dropped("invalidPayload"); return }
            guard self.unsavedBytes + bytes <= 1024 * 1024 else { self.dropped("memoryCapacity"); return }
            self.unsaved.append(event); self.unsavedBytes += bytes; self.arrived[id] = self.scheduler.now
            AUDiagnostics.log("analytics", "queued", [("type", event["event_type"])])
            self.pump()
        }
    }
    /// Background can flush existing events early, without bypassing rate limits or backoff.
    func flush() {
        queue.async { [weak self] in
            guard let self else { return }
            self.flushIDs.formUnion(self.arrived.keys)
            self.pump()
        }
    }
    /// Foreground/connectivity must not interrupt an auction's active debounce window.
    func wake() { queue.async { [weak self] in self?.pump() } }
    /// Test barrier: production scheduling still executes on the same serial worker.
    func syncForTesting() { queue.sync {} }

    private func forget(_ ids: Set<String>) {
        buffer.removeAll { ids.contains($0["event_id"] as? String ?? "") }
        ids.forEach { arrived.removeValue(forKey: $0) }
        flushIDs.subtract(ids); restoredIDs.subtract(ids)
    }
    private func persistAcknowledgements() {
        guard !acceptedIDs.isEmpty, scheduler.now >= ackRetryAt else { return }
        if store.acknowledge(ids: Array(acceptedIDs)) {
            forget(acceptedIDs); acceptedIDs.removeAll(); ackFailures = 0
        } else {
            ackFailures = min(ackFailures + 1, 21)
            let delay = min(config.maxRetryDelayMs, config.retryBaseDelayMs * (1 << (ackFailures - 1)))
            ackRetryAt = scheduler.now + Double(delay) / 1000
            AUDiagnostics.log("analytics", "ackRetryScheduled", [("count", acceptedIDs.count), ("delayMs", delay)])
        }
    }
    private func persist() {
        guard scheduler.now >= storageRetryAt else { return }
        if !restored {
            buffer = store.loadAll()
            guard !store.readFailed else { storageRetryAt = scheduler.now + Double(config.retryBaseDelayMs) / 1000; return }
            restored = true
            if !buffer.isEmpty {
                AUDiagnostics.log("analytics", "restored", [("count", buffer.count),
                    ("oldestEventTimestamp", buffer.compactMap { $0["event_timestamp"] as? String }.min())])
            }
            for event in buffer {
                if let id = event["event_id"] as? String { arrived[id] = scheduler.now; flushIDs.insert(id); restoredIDs.insert(id) }
            }
        }
        while let event = unsaved.first {
            let id = event["event_id"] as? String ?? ""
            switch store.append(event) {
            case .ioError: storageRetryAt = scheduler.now + Double(config.retryBaseDelayMs) / 1000; return
            case .full: dropped("storageCapacity"); arrived.removeValue(forKey: id); flushIDs.remove(id)
            case .invalid: dropped("invalidPayload"); arrived.removeValue(forKey: id); flushIDs.remove(id)
            case .stored:
                if !buffer.contains(where: { $0["event_id"] as? String == id }) { buffer.append(event) }
            }
            unsaved.removeFirst(); unsavedBytes -= AUEventStore.encode(event)?.count ?? 0
        }
    }
    private func later(_ deadline: TimeInterval) {
        let deadline = min(deadline, acceptedIDs.isEmpty ? .greatestFiniteMagnitude : ackRetryAt)
        let generation = wakeGeneration
        cancelWake = scheduler.schedule(on: queue, after: min(86400, max(0.001, deadline - scheduler.now))) { [weak self] in
            guard let self, generation == self.wakeGeneration else { return }
            self.pump()
        }
    }
    private func auction(_ event: JSONObject) -> String {
        ((event["attributes"] as? JSONObject)?["auction_id"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private func pump() {
        cancelWake?(); cancelWake = nil; wakeGeneration += 1
        persistAcknowledgements()
        persist()
        guard !inFlight else {
            if !acceptedIDs.isEmpty { later(ackRetryAt) }
            return
        }
        let ready = buffer.filter { !acceptedIDs.contains($0["event_id"] as? String ?? "") }
        guard !ready.isEmpty else {
            if !unsaved.isEmpty || !restored { later(storageRetryAt) }
            else if !acceptedIDs.isEmpty { later(ackRetryAt) }
            return
        }
        let batchSize = AUAnalyticsBatchSettings.resolve(backendBatchSize?() ?? config.batchSize)
        if let first = plans.first, first.count > batchSize {
            plans.removeFirst()
            let chunks = stride(from: 0, to: first.count, by: batchSize).map {
                Array(first[$0..<min($0 + batchSize, first.count)])
            }
            plans.insert(contentsOf: chunks, at: 0)
        }
        var batch = plans.first ?? []
        var deadline = scheduler.now
        if batch.isEmpty {
            // Independent trailing-edge debounce per auction, including one no-auction bucket.
            // Preserve first-arrival order when deadlines tie; never let a busy group block a
            // different auction that is already quiet.
            // Keep restored and fresh lanes separate, even within one auction. Alternate due
            // lanes so neither a long backlog nor continuously arriving new work can starve.
            func groupKey(_ event: JSONObject) -> GroupKey {
                GroupKey(auction: auction(event), restored: restoredIDs.contains(event["event_id"] as? String ?? ""))
            }
            var groups: [GroupKey: [JSONObject]] = [:]
            var order: [GroupKey] = []
            var latest: [GroupKey: TimeInterval] = [:]
            for event in ready {
                let key = groupKey(event)
                if groups[key] == nil { order.append(key) }
                groups[key, default: []].append(event)
            }
            for event in ready + unsaved {
                let key = groupKey(event)
                latest[key] = max(latest[key] ?? -.greatestFiniteMagnitude,
                                  arrived[event["event_id"] as? String ?? ""] ?? scheduler.now)
            }
            func forced(_ event: JSONObject) -> Bool { flushIDs.contains(event["event_id"] as? String ?? "") }
            func due(_ key: GroupKey) -> TimeInterval {
                let events = groups[key]!
                let quietAt = (latest[key] ?? scheduler.now) + Double(config.batchDelayMs) / 1000
                // A continuously full auction must yield to older, already-due groups.
                let fullAt = events.count >= batchSize ?
                    (arrived[events[batchSize - 1]["event_id"] as? String ?? ""] ?? scheduler.now) : .greatestFiniteMagnitude
                let forcedAt = events.first(where: forced).flatMap { arrived[$0["event_id"] as? String ?? ""] } ?? .greatestFiniteMagnitude
                return min(quietAt, fullAt, forcedAt)
            }
            let otherLane = order.filter { due($0) <= scheduler.now && $0.restored != lastWasBacklog }
            let key = (otherLane.isEmpty ? order : otherLane).min { due($0) < due($1) }!
            deadline = due(key)
            let group = groups[key]!
            let quiet = scheduler.now >= (latest[key] ?? scheduler.now) + Double(config.batchDelayMs) / 1000
            let candidates = !quiet && group.count < batchSize && group.contains(where: forced) ?
                group.filter(forced) : group
            var bytes = 2
            for event in candidates {
                let added = (AUEventStore.encode(event)?.count ?? config.batchBytes) + (batch.isEmpty ? 0 : 1)
                if batch.count >= batchSize || bytes + added > config.batchBytes { break }
                batch.append(event); bytes += added
            }
            if batch.isEmpty {
                let id = candidates[0]["event_id"] as? String ?? ""
                if store.quarantine(id: id) {
                    forget([id])
                    AUDiagnostics.log("analytics", "quarantined", [("count", 1), ("reason", "payloadTooLarge")])
                    later(scheduler.now + 0.001)
                } else { later(scheduler.now + Double(config.retryBaseDelayMs) / 1000) }
                return
            }
        }
        let allowed = max(deadline, retryAt, (lastStart ?? -Double.greatestFiniteMagnitude) + Double(config.minIntervalMs) / 1000)
        if scheduler.now < allowed {
            later(min(allowed, unsaved.isEmpty ? Double.greatestFiniteMagnitude : storageRetryAt)); return
        }
        if !plans.isEmpty { plans.removeFirst() }
        inFlight = true; lastStart = scheduler.now
        lastWasBacklog = restoredIDs.contains(batch[0]["event_id"] as? String ?? "")
        let sent = batch
        AUDiagnostics.log("analytics", "sending", [("count", sent.count), ("attempt", failureCount + 1),
            ("oldestEventTimestamp", sent.compactMap { $0["event_timestamp"] as? String }.min())])
        var completed = false
        networkManager.request(.batchEvents(sent)) { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard !completed else { return }; completed = true; self.inFlight = false
                let ids = sent.compactMap { $0["event_id"] as? String }
                if case .success = result {
                    self.acceptedIDs.formUnion(ids)
                    self.persistAcknowledgements()
                    self.failureCount = 0; self.retryAt = 0
                    AUDiagnostics.log("analytics", "sent", [("count", ids.count)])
                } else {
                    var status: Int?; var retryAfter: TimeInterval = 0
                    if case .failure(.httpStatus(let code, let wait)) = result { status = code; retryAfter = wait ?? 0 }
                    AUDiagnostics.log("analytics", "failed", [("count", ids.count), ("status", status),
                        ("reason", "transportOrHTTP")])
                    if let status, [400, 413, 422].contains(status) {
                        if sent.count > 1 {
                            let middle = (sent.count + 1) / 2
                            self.plans.insert(contentsOf: [Array(sent.prefix(middle)), Array(sent.dropFirst(middle))], at: 0)
                        } else if self.store.quarantine(id: ids[0]) {
                            self.forget([ids[0]])
                            AUDiagnostics.log("analytics", "quarantined", [("count", 1), ("status", status)])
                        } else { self.plans.insert(sent, at: 0) }
                    } else { self.plans.insert(sent, at: 0) }
                    self.failureCount = min(self.failureCount + 1, 21)
                    let exponential = min(self.config.maxRetryDelayMs, self.config.retryBaseDelayMs * (1 << (self.failureCount - 1)))
                    let wait = max(Double(exponential) * self.jitter() / 1000, retryAfter)
                    self.retryAt = self.scheduler.now + wait
                    AUDiagnostics.log("analytics", "retryScheduled", [("delayMs", wait * 1000)])
                }
                self.pump()
            }
        }
    }
    private func dropped(_ reason: String) { AUDiagnostics.log("analytics", "dropped", [("count", 1), ("reason", reason)]) }
}
