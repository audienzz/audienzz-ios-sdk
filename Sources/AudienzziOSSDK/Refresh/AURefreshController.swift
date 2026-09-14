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

/// The single owner of periodic banner refresh.
///
/// ## Why this exists
///
/// Refresh used to be scheduled by two parties at once. Prebid ran its own `Dispatcher` (a repeating
/// main-run-loop `Timer` that re-fetches through the *last* completion handler it saw), while the
/// SDK separately posted its own delayed `DispatchWorkItem` fetches. Neither could see the other's
/// state, so a pause could be undone by an in-flight response, and a page transition, a pending
/// stale-aware refresh and a deferred retry could each issue their own replacement for the same
/// transition.
///
/// Prebid is now never given a refresh interval. Its `dispatcher` is created only by
/// `initDispatcher(refreshTime:)`, which is called only from `AdUnit.setAutoRefreshMillis` — so with
/// that call removed the dispatcher stays `nil` for the life of the ad unit, `startDispatcher()` and
/// `resumeAutoRefresh()` log "Dispatcher is nil" and return, and no Prebid timer can exist. The
/// configured interval lives here instead, and every periodic request is scheduled, gated and
/// counted by this class.
///
/// ## Timing rules
///
/// - The interval is measured from the moment a request **completes**, not from when it starts, so a
///   slow auction does not shorten the gap between creatives.
/// - Durations use a monotonic clock (`AURefreshScheduler.now()`). Wall-clock time would let a
///   device clock change fire a refresh instantly or suppress it indefinitely.
/// - Blocking cancels the pending task but does **not** move the due time: elapsed time keeps
///   counting while a banner is off screen, which preserves the existing stale-aware resume. When
///   the last block clears, an overdue banner refreshes immediately and an in-date one waits out the
///   remainder. (Charging only visible time is deliberately out of scope for this migration.)
/// - An interval of 0 disables periodic refresh entirely; nothing is ever scheduled.
///
/// ## Ownership rules
///
/// - At most one request is in flight per banner. While one is, nothing new is scheduled.
/// - Every block reason is independent; clearing one never clears another.
/// - Eligibility is re-checked when scheduled work runs, not only when it is scheduled, because the
///   banner can be paged out, hidden or backgrounded in between.
/// - A generation is stamped on each request. A response from a superseded generation, or any
///   callback after `destroy()`, must not load an ad, mutate state or schedule a successor.
///
/// Main-thread confined, like every other banner path in the SDK.
internal final class AURefreshController {

    /// Issues one request. The controller never loads ads itself.
    private let onRequestDue: (AURefreshRequestReason, Int) -> Void

    private let scheduler: AURefreshScheduler
    private let label: String

    init(
        label: String,
        scheduler: AURefreshScheduler = AUMainQueueRefreshScheduler(),
        onRequestDue: @escaping (AURefreshRequestReason, Int) -> Void
    ) {
        self.label = label
        self.scheduler = scheduler
        self.onRequestDue = onRequestDue
    }

    /// Configured interval in **milliseconds**; 0 (or negative) disables periodic refresh.
    ///
    /// Held here rather than read back from Prebid's ad unit, which is deliberately never given an
    /// interval so it schedules nothing. The public API stays in milliseconds because
    /// `setAutoRefreshMillis` always took milliseconds.
    private(set) var intervalMillis: Double = 0

    private var intervalSeconds: TimeInterval { intervalMillis / 1000.0 }

    private var blocks: [AURefreshBlockReason] = []

    /// Monotonic time the last request completed, or nil before the first completion.
    private var lastCompletionAt: TimeInterval?

    /// Generation of the outstanding request, or nil when none is.
    ///
    /// Tracked per generation rather than as a bare flag. A superseded request's completion must not
    /// clear the flag belonging to the replacement that overtook it, and — the failure that made
    /// this necessary — a superseded completion that never cleared the flag at all left the
    /// controller believing a request was forever outstanding, so it never scheduled again and the
    /// slot was stranded empty.
    private var inFlightGeneration: Int?

    private var consecutiveFailures = 0

    private(set) var isDestroyed = false

    /// Increments whenever outstanding work is invalidated (a page transition, destruction).
    /// A callback carrying an older generation is stale and must do nothing.
    private(set) var generation: Int = 0

    // MARK: - Configuration

    /// Applies the configured interval. Passing 0 disables refresh and cancels pending work.
    func setIntervalMillis(_ millis: Double) {
        intervalMillis = millis > 0 ? millis : 0
        if intervalMillis == 0 {
            scheduler.cancel()
        } else {
            scheduleNext()
        }
    }

    // MARK: - Block state

    var isBlocked: Bool { !blocks.isEmpty }

    /// The reasons currently blocking refresh, for logging and tests.
    var blockReasons: Set<AURefreshBlockReason> { Set(blocks) }

    /// Adds a block reason. Any pending periodic work is cancelled, so a response that arrives after
    /// this cannot schedule a successor.
    func block(_ reason: AURefreshBlockReason) {
        guard !isDestroyed else { return }
        if !blocks.contains(reason) {
            blocks.append(reason)
            AULogEvent.logDebug("[AURefresh] \(label) blocked by \(reason.rawValue) (now \(blocks.map(\.rawValue)))")
        }
        scheduler.cancel()
        // Deliberately NOT a generation bump. A request in flight when the banner scrolls out of
        // view is still legitimate — its creative belongs to this page — so it should complete and
        // restart the interval normally; the block is what stops the NEXT one being scheduled.
        // Superseding it instead made the banner look permanently overdue, so scrolling away and
        // back refreshed twice in quick succession. Generations are for page transitions and
        // destruction, where the response really does belong to a context that no longer applies.
    }

    /// Removes one block reason. Refresh resumes only when every reason has been cleared, so a
    /// visibility resume cannot undo a publisher pause.
    func unblock(_ reason: AURefreshBlockReason) {
        guard !isDestroyed else { return }
        guard let index = blocks.firstIndex(of: reason) else { return }
        blocks.remove(at: index)
        AULogEvent.logDebug("[AURefresh] \(label) unblocked from \(reason.rawValue) (remaining \(blocks.map(\.rawValue)))")
        if blocks.isEmpty {
            scheduleNext()
        }
    }

    /// Clears every block reason. Used when a banner joins a fresh page.
    func unblockAll() {
        guard !isDestroyed, !blocks.isEmpty else { return }
        blocks.removeAll()
        AULogEvent.logDebug("[AURefresh] \(label) unblocked from all reasons")
        scheduleNext()
    }

    // MARK: - Request lifecycle

    /// Records that a request has started, whatever its reason. Returns the generation it belongs
    /// to; the caller passes that back on completion so a superseded response can be recognised.
    @discardableResult
    func onRequestStarted(_ reason: AURefreshRequestReason) -> Int {
        inFlightGeneration = generation
        scheduler.cancel()
        if reason != .loadRetry {
            consecutiveFailures = 0
        }
        AULogEvent.logDebug("[AURefresh] \(label) request started: \(reason.rawValue) (generation \(generation))")
        return generation
    }

    /// Records a completed request and arranges what follows.
    ///
    /// A response from a superseded generation is ignored entirely — it must not restart the clock
    /// or schedule anything, since its page or eligibility no longer applies.
    func onRequestCompleted(generationAtRequest: Int, success: Bool) {
        guard !isDestroyed else { return }
        if inFlightGeneration == generationAtRequest {
            inFlightGeneration = nil
        }
        guard generationAtRequest == generation else {
            AULogEvent.logDebug("[AURefresh] \(label) ignoring completion from superseded generation \(generationAtRequest)")
            return
        }
        lastCompletionAt = scheduler.now()

        if success {
            consecutiveFailures = 0
            scheduleNext()
            return
        }

        consecutiveFailures += 1
        if consecutiveFailures > Self.maxConsecutiveFailures {
            // Stop retrying rather than hammer a failing endpoint. The slot is not stranded: the
            // next page impression, visibility resume or foreground still starts a fresh request.
            AULogEvent.logWarn(
                "[AURefresh] \(label) giving up after \(consecutiveFailures) consecutive failures; " +
                "the next page impression or resume will try again"
            )
            scheduleNext()
            return
        }
        scheduleRetry()
    }

    /// True while a request of the CURRENT generation is outstanding, so callers never start a
    /// second one. A request left over from a superseded generation does not count: its callback is
    /// already inert, so waiting for it would strand the banner.
    var hasRequestInFlight: Bool { inFlightGeneration == generation }

    // MARK: - Scheduling

    /// Schedules the next periodic refresh, or fires one immediately if the banner is already
    /// overdue. Safe to call repeatedly; the scheduler keeps at most one pending task.
    func scheduleNext() {
        guard !isDestroyed, intervalMillis > 0, !isBlocked, !hasRequestInFlight else { return }
        guard let last = lastCompletionAt else {
            // Nothing has loaded yet, so there is no interval to measure from. The first load is
            // driven by lazy loading or an explicit load, not by this controller.
            return
        }
        let delay = max(0, last + intervalSeconds - scheduler.now())
        AULogEvent.logDebug("[AURefresh] \(label) next refresh in \(String(format: "%.1f", delay))s")
        scheduler.schedule(after: delay) { [weak self] in
            self?.fireIfStillEligible(.periodicRefresh)
        }
    }

    private func scheduleRetry() {
        guard !isDestroyed, !isBlocked else { return }
        let delay = Self.retryBaseDelay * pow(2, Double(consecutiveFailures - 1))
        AULogEvent.logDebug("[AURefresh] \(label) retry \(consecutiveFailures) in \(delay)s")
        scheduler.schedule(after: delay) { [weak self] in
            self?.fireIfStillEligible(.loadRetry)
        }
    }

    /// Re-checks eligibility at execution time. A task scheduled while the banner was eligible can
    /// come due after it has been hidden, backgrounded or paged out.
    private func fireIfStillEligible(_ reason: AURefreshRequestReason) {
        guard !isDestroyed else { return }
        guard !isBlocked else {
            AULogEvent.logDebug("[AURefresh] \(label) \(reason.rawValue) due but blocked by \(blocks.map(\.rawValue)); skipping")
            return
        }
        guard !hasRequestInFlight else {
            AULogEvent.logDebug("[AURefresh] \(label) \(reason.rawValue) due but a request is already in flight; skipping")
            return
        }
        if reason == .periodicRefresh, intervalMillis <= 0 { return }
        onRequestDue(reason, generation)
    }

    /// Invalidates outstanding work without blocking. Used by a page transition, which issues its
    /// own replacement and must not also let a pending periodic refresh or retry fire.
    func invalidatePending() {
        scheduler.cancel()
        generation += 1
        inFlightGeneration = nil
    }

    /// Marks the banner as having just loaded, so the interval is measured from now. Used when a
    /// load is issued outside the controller (a first load or a page replacement).
    func noteLoadedNow() {
        lastCompletionAt = scheduler.now()
    }

    func destroy() {
        isDestroyed = true
        scheduler.cancel()
        generation += 1
        blocks.removeAll()
    }

    // MARK: - Constants

    /// Bounded so a persistently failing slot cannot retry forever.
    private static let maxConsecutiveFailures = 3

    /// Doubles per attempt: 2s, 4s, 8s.
    private static let retryBaseDelay: TimeInterval = 2
}
