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
        var batchSize = 25
        var batchBytes = 128 * 1024
        var batchDelayMs = 5000
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
    private let queue = DispatchQueue(label: "com.audienzz.eventqueue", qos: .utility)
    private let admissionLock = NSLock()
    private var enqueuedCount = 0
    private var buffer: [JSONObject] = []
    private var unsaved: [JSONObject] = []
    private var unsavedBytes = 0
    private var arrived: [String: TimeInterval] = [:]
    private var plans: [[JSONObject]] = []
    private var restored = false
    private var inFlight = false
    private var cancelWake: (() -> Void)?
    private var wakeGeneration = 0
    private var lastStart: TimeInterval?
    private var retryAt: TimeInterval = 0
    private var storageRetryAt: TimeInterval = 0
    private var failureCount = 0
    private var drain = false

    init(networkManager: AUEventsNetworkManager<AUBatchResultModel>, store: AUEventStore = AUEventStore(),
         config: Config = .default, scheduler: AUAnalyticsScheduler? = nil,
         jitter: @escaping () -> Double = { Double.random(in: 0.5...1) }) {
        self.networkManager = networkManager; self.store = store; self.config = config
        self.scheduler = scheduler ?? AUAnalyticsSystemScheduler(); self.jitter = jitter
        queue.async { [weak self] in self?.pump() }
        networkManager.onConnectionRestored = { [weak self] in self?.flush() }
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
    /// Background/foreground/connectivity hints never bypass rate limits or failure backoff.
    func flush() { queue.async { [weak self] in self?.drain = true; self?.pump() } }
    /// Test barrier: production scheduling still executes on the same serial worker.
    func syncForTesting() { queue.sync {} }

    private func persist() {
        guard scheduler.now >= storageRetryAt else { return }
        if !restored {
            buffer = store.loadAll()
            guard !store.readFailed else { storageRetryAt = scheduler.now + Double(config.retryBaseDelayMs) / 1000; return }
            restored = true; drain = !buffer.isEmpty
            for event in buffer { if let id = event["event_id"] as? String { arrived[id] = scheduler.now } }
        }
        while let event = unsaved.first {
            let id = event["event_id"] as? String ?? ""
            switch store.append(event) {
            case .ioError: storageRetryAt = scheduler.now + Double(config.retryBaseDelayMs) / 1000; return
            case .full: dropped("storageCapacity"); arrived.removeValue(forKey: id)
            case .invalid: dropped("invalidPayload"); arrived.removeValue(forKey: id)
            case .stored:
                if !buffer.contains(where: { $0["event_id"] as? String == id }) { buffer.append(event) }
            }
            unsaved.removeFirst(); unsavedBytes -= AUEventStore.encode(event)?.count ?? 0
        }
    }
    private func later(_ deadline: TimeInterval) {
        let generation = wakeGeneration
        cancelWake = scheduler.schedule(on: queue, after: min(86400, max(0.001, deadline - scheduler.now))) { [weak self] in
            guard let self, generation == self.wakeGeneration else { return }
            self.pump()
        }
    }
    private func pump() {
        cancelWake?(); cancelWake = nil; wakeGeneration += 1
        persist()
        guard !inFlight else { return }
        guard !buffer.isEmpty else {
            if !unsaved.isEmpty || !restored { later(storageRetryAt) } else { drain = false }
            return
        }
        var batch = plans.first ?? []
        if batch.isEmpty {
            var bytes = 2
            for event in buffer {
                let added = (AUEventStore.encode(event)?.count ?? config.batchBytes) + (batch.isEmpty ? 0 : 1)
                if batch.count >= config.batchSize || bytes + added > config.batchBytes { break }
                batch.append(event); bytes += added
            }
            if batch.isEmpty {
                let id = buffer[0]["event_id"] as? String ?? ""
                if store.quarantine(id: id) {
                    buffer.removeFirst(); arrived.removeValue(forKey: id)
                    AUDiagnostics.log("analytics", "quarantined", [("count", 1), ("reason", "payloadTooLarge")])
                    later(scheduler.now + 0.001)
                } else { later(scheduler.now + Double(config.retryBaseDelayMs) / 1000) }
                return
            }
        }
        let full = batch.count >= config.batchSize || batch.count < buffer.count
        let deadline = drain || !plans.isEmpty || full ? scheduler.now :
            (arrived[batch[0]["event_id"] as? String ?? ""] ?? scheduler.now) + Double(config.batchDelayMs) / 1000
        let allowed = max(deadline, retryAt, (lastStart ?? -Double.greatestFiniteMagnitude) + Double(config.minIntervalMs) / 1000)
        if scheduler.now < allowed {
            later(min(allowed, unsaved.isEmpty ? Double.greatestFiniteMagnitude : storageRetryAt)); return
        }
        if !plans.isEmpty { plans.removeFirst() }
        inFlight = true; drain = true; lastStart = scheduler.now
        let sent = batch
        AUDiagnostics.log("analytics", "sending", [("count", sent.count), ("attempt", failureCount + 1)])
        var completed = false
        networkManager.request(.batchEvents(sent)) { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard !completed else { return }; completed = true; self.inFlight = false
                let ids = sent.compactMap { $0["event_id"] as? String }
                if case .success = result, self.store.acknowledge(ids: ids) {
                    let set = Set(ids)
                    self.buffer.removeAll { set.contains($0["event_id"] as? String ?? "") }
                    ids.forEach { self.arrived.removeValue(forKey: $0) }
                    self.failureCount = 0; self.retryAt = 0
                    AUDiagnostics.log("analytics", "sent", [("count", ids.count)])
                } else {
                    var status: Int?; var retryAfter: TimeInterval = 0
                    if case .failure(.httpStatus(let code, let wait)) = result { status = code; retryAfter = wait ?? 0 }
                    AUDiagnostics.log("analytics", "failed", [("count", ids.count), ("status", status),
                        ("reason", result.isSuccess ? "ackPersistence" : "transportOrHTTP")])
                    if let status, [400, 413, 422].contains(status) {
                        if sent.count > 1 {
                            let middle = (sent.count + 1) / 2
                            self.plans.insert(contentsOf: [Array(sent.prefix(middle)), Array(sent.dropFirst(middle))], at: 0)
                        } else if self.store.quarantine(id: ids[0]) {
                            self.buffer.removeAll { $0["event_id"] as? String == ids[0] }; self.arrived.removeValue(forKey: ids[0])
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

private extension Result {
    var isSuccess: Bool { if case .success = self { return true }; return false }
}
