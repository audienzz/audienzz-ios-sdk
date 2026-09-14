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

import XCTest
@testable import AudienzziOSSDK

/// The controller is the single owner of periodic refresh, so these pin the rules the rest of the
/// SDK relies on: when the interval starts, what blocking does to it, and which callbacks are
/// allowed to schedule a successor.
///
/// Time and scheduling are faked outright rather than waiting on the run loop, so every assertion is
/// about the decision rather than about how long a test slept.
final class AURefreshControllerTests: XCTestCase {

    /// Deterministic stand-in: one pending task, and a clock the test advances by hand.
    private final class FakeScheduler: AURefreshScheduler {
        var current: TimeInterval = 1_000
        private var dueAt: TimeInterval?
        private var action: (() -> Void)?

        /// Kept past a cancel so `fireIgnoringCancellation` can model a cancel that didn't work.
        private var lastScheduled: (() -> Void)?

        var hasPending: Bool { action != nil }
        var pendingDelay: TimeInterval? { dueAt.map { $0 - current } }

        func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
            dueAt = current + delay
            self.action = action
            lastScheduled = action
        }

        func cancel() {
            dueAt = nil
            action = nil
        }

        func now() -> TimeInterval { current }

        /// Runs the most recently scheduled task as if a cancel had failed to take effect —
        /// deliberately ignoring `cancel()`, which is the whole point. Not hypothetical: a
        /// cancellation that silently did nothing shipped once on Android, so the controller
        /// re-checks eligibility when work executes rather than trusting that cancelled work stays
        /// cancelled.
        func fireIgnoringCancellation() {
            lastScheduled?()
        }

        /// Advances the clock, running the pending task if it comes due.
        func advance(_ seconds: TimeInterval) {
            let target = current + seconds
            while let due = dueAt, due <= target {
                current = due
                let toRun = action
                dueAt = nil
                action = nil
                toRun?()
            }
            current = target
        }
    }

    private var scheduler: FakeScheduler!
    private var requests: [AURefreshRequestReason]!
    private var controller: AURefreshController!

    /// 30s, expressed the way the public API takes it.
    private let intervalMillis: Double = 30_000
    private var interval: TimeInterval { intervalMillis / 1000 }

    override func setUp() {
        super.setUp()
        scheduler = FakeScheduler()
        requests = []
        controller = AURefreshController(label: "test", scheduler: scheduler) { [weak self] reason, _ in
            self?.requests.append(reason)
        }
        controller.setIntervalMillis(intervalMillis)
    }

    /// Drives a full request round trip, as the banner does.
    private func completeARequest(
        reason: AURefreshRequestReason = .firstLoad,
        success: Bool = true
    ) {
        let generation = controller.onRequestStarted(reason)
        controller.onRequestCompleted(generationAtRequest: generation, success: success)
    }

    // MARK: - The interval

    func testNothingIsScheduledBeforeTheFirstLoadCompletes() {
        // The first load is owned by lazy loading or an explicit load, not by this controller.
        XCTAssertFalse(scheduler.hasPending)
        XCTAssertEqual(requests, [])
    }

    func testTheIntervalIsMeasuredFromCompletionNotFromTheRequest() {
        // A slow auction must not shorten the gap between creatives.
        let generation = controller.onRequestStarted(.firstLoad)
        scheduler.advance(5)
        controller.onRequestCompleted(generationAtRequest: generation, success: true)

        XCTAssertEqual(scheduler.pendingDelay, interval)
    }

    func testAPeriodicRefreshFiresOnceTheIntervalElapses() {
        completeARequest()

        scheduler.advance(interval)

        XCTAssertEqual(requests, [.periodicRefresh])
    }

    func testAnIntervalOfZeroDisablesRefreshEntirely() {
        controller.setIntervalMillis(0)
        completeARequest()

        scheduler.advance(10 * interval)

        XCTAssertFalse(scheduler.hasPending)
        XCTAssertEqual(requests, [])
    }

    // MARK: - Blocking

    func testBlockingCancelsThePendingRefresh() {
        completeARequest()

        controller.block(.notVisible)

        XCTAssertFalse(scheduler.hasPending)
        scheduler.advance(10 * interval)
        XCTAssertEqual(requests, [])
    }

    func testClearingOneReasonDoesNotClearAnother() {
        // A single boolean could not express this, and a visibility resume silently undid a
        // publisher pause.
        completeARequest()
        controller.block(.publisher)
        controller.block(.notVisible)

        controller.unblock(.notVisible)

        XCTAssertTrue(controller.isBlocked)
        XCTAssertEqual(controller.blockReasons, [.publisher])
        scheduler.advance(10 * interval)
        XCTAssertEqual(requests, [])
    }

    func testRefreshResumesOnlyOnceEveryReasonIsCleared() {
        completeARequest()
        controller.block(.publisher)
        controller.block(.appBackground)

        controller.unblock(.appBackground)
        controller.unblock(.publisher)
        scheduler.advance(interval)

        XCTAssertEqual(requests, [.periodicRefresh])
    }

    func testAnOverdueBannerRefreshesAsSoonAsItIsUnblocked() {
        // Elapsed time keeps counting while blocked, which is the existing stale-aware resume.
        completeARequest()
        controller.block(.notVisible)
        scheduler.advance(interval * 2)

        controller.unblock(.notVisible)

        XCTAssertEqual(scheduler.pendingDelay, 0)
        scheduler.advance(0)
        XCTAssertEqual(requests, [.periodicRefresh])
    }

    func testAnInDateBannerWaitsOutTheRemainderAfterUnblocking() {
        completeARequest()
        controller.block(.notVisible)
        scheduler.advance(10)

        controller.unblock(.notVisible)

        XCTAssertEqual(scheduler.pendingDelay, interval - 10)
    }

    func testEligibilityIsRecheckedWhenTheScheduledTaskRuns() {
        // The banner can be hidden between scheduling and execution, so checking only at schedule
        // time is not enough.
        completeARequest()
        controller.block(.notVisible)
        controller.unblock(.notVisible)
        XCTAssertTrue(scheduler.hasPending)

        // Hidden again after the task was scheduled, without cancelling it explicitly.
        scheduler.advance(interval - 1)
        controller.block(.notVisible)
        scheduler.advance(2)

        XCTAssertEqual(requests, [])
    }

    // MARK: - In-flight requests

    func testARefreshDueDespiteCancellationIsStillRefusedWhileBlocked() {
        completeARequest()
        controller.block(.notVisible)
        controller.unblock(.notVisible)
        controller.block(.publisher)

        scheduler.fireIgnoringCancellation()

        XCTAssertEqual(requests, [])
    }

    func testAnInFlightRequestStillRestartsTheIntervalWhenTheBannerIsMerelyHidden() {
        // Scrolling away does not invalidate the request: its creative belongs to this page.
        // Treating it as superseded left the banner looking permanently overdue, so scrolling back
        // refreshed immediately and then again a moment later.
        let generation = controller.onRequestStarted(.periodicRefresh)
        controller.block(.notVisible)
        controller.onRequestCompleted(generationAtRequest: generation, success: true)

        controller.unblock(.notVisible)

        XCTAssertEqual(scheduler.pendingDelay, interval, "a full interval from the response, not an instant refresh")
    }

    func testAPauseSurvivesASuccessfulResponse() {
        // Prebid re-armed its own timer from its response handlers; a completion arriving after a
        // pause must not schedule the next request.
        let generation = controller.onRequestStarted(.periodicRefresh)
        controller.block(.notVisible)

        controller.onRequestCompleted(generationAtRequest: generation, success: true)
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [])
    }

    func testAPauseSurvivesAFailedResponse() {
        let generation = controller.onRequestStarted(.periodicRefresh)
        controller.block(.notVisible)

        controller.onRequestCompleted(generationAtRequest: generation, success: false)
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [])
    }

    func testOnlyOneRequestIsInFlightAtATime() {
        completeARequest()
        controller.onRequestStarted(.periodicRefresh)

        controller.scheduleNext()
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [], "nothing may be scheduled while a request is outstanding")
    }

    func testAResponseFromASupersededGenerationSchedulesNothing() {
        completeARequest()
        let stale = controller.onRequestStarted(.periodicRefresh)
        controller.invalidatePending()

        controller.onRequestCompleted(generationAtRequest: stale, success: true)
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [])
    }

    func testASupersededResponseDoesNotRestartTheInterval() {
        // Supersession comes from a page transition, not from being hidden: the replacement it
        // issues owns the clock, so the outgoing response must not push the next refresh out.
        completeARequest()
        let stale = controller.onRequestStarted(.periodicRefresh)
        scheduler.advance(interval * 2)
        controller.invalidatePending()

        controller.onRequestCompleted(generationAtRequest: stale, success: true)
        controller.scheduleNext()

        XCTAssertEqual(scheduler.pendingDelay, 0, "the banner was already overdue and must stay overdue")
    }

    // MARK: - Failures and retries

    func testAFailedRequestRetriesWithBackoff() {
        completeARequest(success: false)

        XCTAssertEqual(scheduler.pendingDelay, 2)
        scheduler.advance(2)
        XCTAssertEqual(requests, [.loadRetry])
    }

    func testRetriesAreBounded() {
        completeARequest(success: false)
        for _ in 0..<5 {
            scheduler.advance(60)
            if !controller.hasRequestInFlight {
                let generation = controller.onRequestStarted(.loadRetry)
                controller.onRequestCompleted(generationAtRequest: generation, success: false)
            }
        }

        let retries = requests.filter { $0 == .loadRetry }.count
        XCTAssertLessThanOrEqual(retries, 3, "expected a bounded number of retries, got \(retries)")
    }

    func testASuccessfulRequestClearsTheFailureCount() {
        completeARequest(success: false)
        scheduler.advance(2)
        let generation = controller.onRequestStarted(.loadRetry)
        controller.onRequestCompleted(generationAtRequest: generation, success: true)

        XCTAssertEqual(scheduler.pendingDelay, interval, "back to the normal cadence")
    }

    // MARK: - Destruction

    func testADestroyedControllerSchedulesNothing() {
        completeARequest()

        controller.destroy()
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [])
    }

    func testALateCallbackAfterDestroyDoesNothing() {
        let generation = controller.onRequestStarted(.periodicRefresh)
        controller.destroy()

        controller.onRequestCompleted(generationAtRequest: generation, success: true)
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [])
    }

    func testBlockingADestroyedControllerIsInert() {
        controller.destroy()

        controller.block(.notVisible)
        controller.unblockAll()
        scheduler.advance(10 * interval)

        XCTAssertEqual(requests, [])
    }
}
