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
/// (`AUEventsManager.logEvent`), so the backend orders by sequence, not arrival.
///
/// The buffer is mirrored to disk by `AUEventStore`, so it survives process death: events are
/// appended as they arrive and the file is rewritten once a batch settles. What is on disk is
/// always what is still owed to the collector.
final class AUEventQueue {

    // MARK: - Config (kept in sync with the Android EventBatcher)

    /// Injectable only so tests can drive the size, timer and backoff paths without waiting out the
    /// real intervals. Production always uses `.default`.
    struct Config {
        /// Sized against what a real screen produces. One ad slot emits roughly six events per
        /// auction (bidRequest, bidResponse/noBid, bidWon, adImpression, viewability start/success),
        /// so a four-slot screen is ~25 events per page impression — about one request per screen
        /// visit rather than the several that a batch of 20 forced.
        var maxBatchSize = 50
        /// The ceiling on how long an event waits when traffic is too thin to fill a batch. At 5s a
        /// trickle of one or two events still cost a request every five seconds, which is most of
        /// what made the old behaviour chatty. Backgrounding still flushes immediately, so this
        /// delays delivery rather than risking it — and now the buffer is on disk while it waits.
        var flushIntervalMs = 30_000
        var maxQueueSize = 500
        var maxRetries = 3
        var retryBaseDelayMs = 2000

        static let `default` = Config()
    }

    private let config: Config

    private let networkManager: AUEventsNetworkManager<AUBatchResultModel>
    private let store: AUEventStore

    /// Serial queue guarding every access to `buffer`, `inFlight`, `retryCount`, and `flushTimer`.
    private let queue = DispatchQueue(label: "com.audienzz.eventqueue")
    private var buffer: [JSONObject] = []
    private var flushTimer: DispatchSourceTimer?
    private var inFlight = false
    /// The batch currently being POSTed. Held separately from `buffer` because it is still *owed*
    /// to the collector — it must stay on disk until the send settles, or a process death mid-flight
    /// would lose it.
    private var inFlightChunk: [JSONObject] = []
    private var retryCount = 0

    init(networkManager: AUEventsNetworkManager<AUBatchResultModel>,
         store: AUEventStore = AUEventStore(),
         config: Config = .default) {
        self.networkManager = networkManager
        self.store = store
        self.config = config

        // Anything the previous process did not get to send is owed to the collector; pick it up
        // before accepting new events so it keeps its place at the front of the queue.
        queue.async { [weak self] in
            guard let self = self else { return }
            let restored = self.store.loadAll()
            guard !restored.isEmpty else { return }
            self.buffer.insert(contentsOf: restored, at: 0)
            if self.trimToCapacity() { self.persistBuffer() }
            self.scheduleTimerIfNeeded()
        }

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
            // Persist before anything else can go wrong with it.
            self.store.append(json)

            if self.trimToCapacity() {
                // Dropping from the middle of the file cannot be done by appending; rewrite it.
                self.persistBuffer()
            }

            if self.buffer.count >= config.maxBatchSize {
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

        let n = min(config.maxBatchSize, buffer.count)
        let chunk = Array(buffer.prefix(n))
        buffer.removeFirst(n)
        inFlight = true
        // Deliberately left on disk: it is in flight, not delivered. If the process dies now, the
        // next launch resends it — a duplicate the backend can dedupe on `event_id` is recoverable,
        // a silently dropped event is not.
        inFlightChunk = chunk
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
                    // Delivered — no longer owed, so drop it from disk.
                    self.inFlightChunk = []
                    self.persistBuffer()
                    AULogEvent.logDebug("[AUAnalytics] ✓ batch sent (\(chunk.count) events)")
                    if !self.buffer.isEmpty { self.sendNextBatch() }

                case .failure(let error):
                    if self.retryCount < self.config.maxRetries {
                        self.retryCount += 1
                        // Back into the buffer; still owed, and still on disk where it already is.
                        self.inFlightChunk = []
                        self.buffer.insert(contentsOf: chunk, at: 0)
                        let delayMs = self.config.retryBaseDelayMs * (1 << (self.retryCount - 1)) // 2s, 4s, 8s
                        AULogEvent.logDebug(
                            "[AUAnalytics] ✗ batch FAILED (\(error.localizedDescription)) — retry \(self.retryCount)/\(self.config.maxRetries) in \(delayMs)ms")
                        self.queue.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                            self?.sendNextBatch()
                        }
                    } else {
                        self.retryCount = 0
                        // Given up on: stop owing it, or it would be retried forever across launches.
                        self.inFlightChunk = []
                        self.persistBuffer()
                        AULogEvent.logDebug(
                            "[AUAnalytics] ✗ batch dropped after \(self.config.maxRetries) retries (\(chunk.count) events)")
                        if !self.buffer.isEmpty { self.scheduleTimerIfNeeded() }
                    }
                }
            }
        }
    }

    // MARK: - Capacity and persistence (all on `queue`)

    /// Drop the oldest events beyond `maxQueueSize`. Returns whether anything was dropped.
    @discardableResult
    private func trimToCapacity() -> Bool {
        guard buffer.count > config.maxQueueSize else { return false }
        let overflow = buffer.count - config.maxQueueSize
        buffer.removeFirst(overflow)
        AULogEvent.logDebug("[AUAnalytics] queue overflow — dropped \(overflow) oldest event(s)")
        return true
    }

    /// Make the file match what is still owed: the in-flight batch, then everything queued behind
    /// it. Writing only `buffer` would drop an in-flight batch from disk while it can still fail.
    private func persistBuffer() {
        store.replaceAll(inFlightChunk + buffer)
    }

    // MARK: - Debounce timer (all on `queue`)

    private func scheduleTimerIfNeeded() {
        guard flushTimer == nil, !buffer.isEmpty, !inFlight else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(config.flushIntervalMs))
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
