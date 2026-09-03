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

/// In-memory batching queue for clickstream events.
///
/// Events are enriched and serialized by `AUEventsManager`, then handed here as flat JSON objects.
/// Instead of one HTTP POST per event, this coalesces them and POSTs a batch to `/submit/batch`
/// when the buffer reaches `maxBatchSize`, after `flushIntervalMs` of inactivity, or on an explicit
/// `flush()` (e.g. app backgrounding). Failed batches are re-enqueued and retried with exponential
/// backoff up to `maxRetries`, then dropped. The buffer is capped at `maxQueueSize` (drop oldest).
///
/// Ordering is safe to reorder/retry because `session_seq` is assigned at event creation time
/// (`AUEventsManager.logEvent`), so the backend orders by sequence, not arrival. In-memory only —
/// a buffer not yet flushed is lost if the process is killed.
final class AUEventQueue {

    // MARK: - Config (kept in sync with the Android EventBatcher)
    private static let maxBatchSize = 20
    private static let flushIntervalMs = 5000
    private static let maxQueueSize = 500
    private static let maxRetries = 3
    private static let retryBaseDelayMs = 2000

    private let networkManager: AUEventsNetworkManager<AUBatchResultModel>

    /// Serial queue guarding every access to `buffer`, `inFlight`, `retryCount`, and `flushTimer`.
    private let queue = DispatchQueue(label: "com.audienzz.eventqueue")
    private var buffer: [JSONObject] = []
    private var flushTimer: DispatchSourceTimer?
    private var inFlight = false
    private var retryCount = 0

    init(networkManager: AUEventsNetworkManager<AUBatchResultModel>) {
        self.networkManager = networkManager
        // When connectivity is regained, try to drain any backed-up events immediately.
        networkManager.onConnectionRestored = { [weak self] in
            self?.flush()
        }
    }

    // MARK: - Public API

    /// Append an already-enriched, serialized event. Sends immediately if the batch is full,
    /// otherwise arms the debounce flush timer.
    func enqueue(_ json: JSONObject) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.buffer.append(json)

            if self.buffer.count > Self.maxQueueSize {
                let overflow = self.buffer.count - Self.maxQueueSize
                self.buffer.removeFirst(overflow)
                AULogEvent.logDebug("[AUAnalytics] queue overflow — dropped \(overflow) oldest event(s)")
            }

            if self.buffer.count >= Self.maxBatchSize {
                self.cancelTimer()
                self.sendNextBatch()
            } else {
                self.scheduleTimerIfNeeded()
            }
        }
    }

    /// Flush now (e.g. on app background / foreground). Best-effort; returns immediately.
    func flush() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.cancelTimer()
            self.sendNextBatch()
        }
    }

    // MARK: - Sending (all on `queue`)

    private func sendNextBatch() {
        guard !inFlight, !buffer.isEmpty else { return }

        let n = min(Self.maxBatchSize, buffer.count)
        let chunk = Array(buffer.prefix(n))
        buffer.removeFirst(n)
        inFlight = true
        AULogEvent.logDebug("[AUAnalytics] flushing batch of \(chunk.count) (\(buffer.count) still queued)")

        // `AUEventsNetworkManager` can invoke the completion more than once; guard so a batch is
        // accounted exactly once. All state mutation hops back onto the serial queue.
        var completed = false
        networkManager.request(.batchEvents(chunk)) { [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                guard !completed else { return }
                completed = true
                self.inFlight = false

                switch result {
                case .success:
                    self.retryCount = 0
                    AULogEvent.logDebug("[AUAnalytics] ✓ batch sent (\(chunk.count) events)")
                    if !self.buffer.isEmpty { self.sendNextBatch() }

                case .failure(let error):
                    if self.retryCount < Self.maxRetries {
                        self.retryCount += 1
                        self.buffer.insert(contentsOf: chunk, at: 0)
                        let delayMs = Self.retryBaseDelayMs * (1 << (self.retryCount - 1)) // 2s, 4s, 8s
                        AULogEvent.logDebug(
                            "[AUAnalytics] ✗ batch FAILED (\(error.localizedDescription)) — retry \(self.retryCount)/\(Self.maxRetries) in \(delayMs)ms")
                        self.queue.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                            self?.sendNextBatch()
                        }
                    } else {
                        self.retryCount = 0
                        AULogEvent.logDebug(
                            "[AUAnalytics] ✗ batch dropped after \(Self.maxRetries) retries (\(chunk.count) events)")
                        if !self.buffer.isEmpty { self.scheduleTimerIfNeeded() }
                    }
                }
            }
        }
    }

    // MARK: - Debounce timer (all on `queue`)

    private func scheduleTimerIfNeeded() {
        guard flushTimer == nil, !buffer.isEmpty, !inFlight else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(Self.flushIntervalMs))
        timer.setEventHandler { [weak self] in
            self?.flushTimer = nil
            self?.sendNextBatch()
        }
        flushTimer = timer
        timer.resume()
    }

    private func cancelTimer() {
        flushTimer?.cancel()
        flushTimer = nil
    }
}
