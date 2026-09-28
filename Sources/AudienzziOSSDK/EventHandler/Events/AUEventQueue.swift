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

/// Immediate delivery backed by a durable outbox. No batching delay: each POST contains one event.
/// Disk work and state changes run on one utility queue, with at most one HTTP request in flight.
/// Failures remain on disk and retry with capped backoff; new events/flushes cannot bypass it.
final class AUEventQueue {
    struct Config {
        var maxQueueSize = 500
        var retryBaseDelayMs = 2000
        var maxRetryDelayMs = 60_000
        static let `default` = Config()
    }

    private let config: Config
    private let networkManager: AUEventsNetworkManager<AUBatchResultModel>
    private let store: AUEventStore
    private let queue = DispatchQueue(label: "com.audienzz.eventqueue", qos: .utility)
    private var buffer: [JSONObject] = []
    private var inFlightID: String?
    private var retryTimer: DispatchSourceTimer?
    private var failureCount = 0

    init(networkManager: AUEventsNetworkManager<AUBatchResultModel>,
         store: AUEventStore = AUEventStore(), config: Config = .default) {
        self.networkManager = networkManager
        self.store = store
        self.config = config
        queue.async { [weak self] in
            guard let self else { return }
            self.buffer = self.store.loadAll()
            self.trimToCapacity()
            self.sendNextEvent()
        }
        networkManager.onConnectionRestored = { [weak self] in self?.flush() }
    }

    deinit { retryTimer?.cancel() }

    /// Returns without disk or network I/O on the calling thread.
    func enqueue(_ json: JSONObject) {
        queue.async { [weak self] in
            guard let self, let id = json["event_id"] as? String else { return }
            guard !self.buffer.contains(where: { $0["event_id"] as? String == id }) else { return }
            self.store.append(json) // Persist BEFORE handing the event to the network.
            self.buffer.append(json)
            self.trimToCapacity()
            AUDiagnostics.log("analytics", "queued", [("type", json["event_type"]), ("count", self.buffer.count)])
            self.sendNextEvent()
        }
    }

    /// Lifecycle/connectivity hint. It never defeats the current retry backoff.
    func flush() {
        queue.async { [weak self] in self?.sendNextEvent() }
    }

    private func sendNextEvent() {
        guard inFlightID == nil, retryTimer == nil, let event = buffer.first,
              let id = event["event_id"] as? String else { return }
        inFlightID = id
        AUDiagnostics.log("analytics", "sending", [("count", 1), ("attempt", failureCount + 1)])
        // Keep the event on disk until the acknowledgement. Replays retain the same event_id so
        // the collector can deduplicate a response lost after the server accepted the event.
        var completed = false
        networkManager.request(.batchEvents([event])) { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard !completed else { return }
                completed = true
                self.inFlightID = nil
                switch result {
                case .success(let acknowledgement):
                    self.failureCount = 0
                    self.buffer.removeAll { $0["event_id"] as? String == id }
                    self.store.remove(id: id)
                    AUDiagnostics.log("analytics", "sent", [("count", 1), ("status", acknowledgement.code)])
                    self.sendNextEvent()
                case .failure(let error):
                    self.failureCount += 1
                    var fields: [(String, Any?)] = [("count", 1), ("attempt", self.failureCount)]
                    switch error {
                    case .httpStatus(let status): fields.append(("status", status))
                    case .connectionError(let cause): fields.append(("code", (cause as NSError).code))
                    case .couldNotParseResponse: fields.append(("reason", "invalidResponse"))
                    }
                    AUDiagnostics.log("analytics", "failed", fields)
                    // A permanently rejected event must not strand all later events. Rotate it,
                    // keeping its original payload/identity, and apply backoff to the whole sender.
                    self.buffer.removeAll { $0["event_id"] as? String == id }
                    self.buffer.append(event)
                    self.scheduleRetry()
                }
            }
        }
    }

    private func scheduleRetry() {
        let delay = min(config.maxRetryDelayMs,
                        config.retryBaseDelayMs * (1 << min(failureCount - 1, 20)))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(delay))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.retryTimer?.cancel()
            self.retryTimer = nil
            self.sendNextEvent()
        }
        retryTimer = timer
        timer.resume()
        AUDiagnostics.log("analytics", "retryScheduled", [("delayMs", delay)])
    }

    private func trimToCapacity() {
        while buffer.count > config.maxQueueSize,
              let index = buffer.firstIndex(where: { $0["event_id"] as? String != inFlightID }) {
            let removed = buffer.remove(at: index)
            if let id = removed["event_id"] as? String { store.remove(id: id) }
            AUDiagnostics.log("analytics", "dropped", [("count", 1), ("reason", "capacity")])
        }
    }
}
