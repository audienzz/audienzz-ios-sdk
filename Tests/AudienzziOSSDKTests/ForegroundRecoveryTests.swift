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

/// Real UIKit lifecycle, coordinator and analytics events. The bridge callback is only a refresh signal.
final class ForegroundRecoveryTests: AudienzzLifecycleTestCase {

    private var events: [AUEventDomain] = []
    private var initialPage: AUAnalyticsPageContext!
    private var viewUpdates: [String] = []

    /// Long enough for the automatic recovery's scheduling delay to elapse.
    private let settleDelay: TimeInterval = 0.6

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    private func settle(_ seconds: TimeInterval? = nil) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds ?? settleDelay))
    }

    override func setUp() {
        super.setUp()
        Audienzz.shared.pageImpressionObserver = nil
        // The lifecycle observers are armed by the first page impression, and this also gives the
        // coordinator an active screen to recover.
        events = []
        AUEventsManager.shared.observerForTesting = { [weak self] in self?.events.append($0) }
        Audienzz.shared.pageImpression("Article")
        initialPage = AUEventsManager.shared.capturePageContext()
        XCTAssertNotNil(initialPage.pageImpressionId)

        viewUpdates = []
        Audienzz.shared.pageImpressionObserver = { [weak self] name in
            self?.viewUpdates.append(name)
        }
    }

    override func tearDown() {
        AUEventsManager.shared.observerForTesting = nil
        super.tearDown()
    }

    func testRecoversAdsWithoutReportingAnotherAnalyticsPage() {
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(viewUpdates, ["Article"], "bridge views must still refresh")
        XCTAssertEqual(events.filter { $0.type == .pageImpression }.count, 1)
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, initialPage.pageImpressionId)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
    }

    func testDoesNotReportWhenTheAppAlreadyReportedThisVisit() {
        // The app reports from willEnterForeground, then activation arrives much later. Judging by
        // elapsed time made that report look stale and fired a second impression.
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.willEnterForegroundNotification)
        Audienzz.shared.pageImpression("Article")
        settle(0.75)
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(
            viewUpdates,
            ["Article"],
            "the app owns this visit, however long activation takes to arrive"
        )
    }

    func testQuickReturnRecoversAdsWithoutReplacingTheLatestExplicitVisit() {
        // A report, then a quick background and return. Judging by elapsed time let the PREVIOUS
        // visit's report suppress this one, leaving the restored app with no ad recovery.
        Audienzz.shared.pageImpression("Article")
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(
            viewUpdates,
            ["Article", "Article"],
            "both explicit report and recovery notify bridge views"
        )
    }

    func testDoesNotReportWithoutARealBackgroundRoundTrip() {
        // didBecomeActive also follows Control Centre, a permission prompt or an incoming call.
        // None of those are a new page view.
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(viewUpdates, [])
    }

    func testDoesNotReportWhileStillBackgrounded() {
        // Backgrounding again inside the scheduling window must drop the pending recovery rather
        // than recreate the whole active page with the app not on screen.
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        post(UIApplication.didEnterBackgroundNotification)
        settle()

        XCTAssertEqual(viewUpdates, [])
    }
    func testForegroundPreservesSlotsAndCountersAcrossRepeatedReturns() {
        let ledger = AUScreenAdCoordinator.shared.requestLedger
        let first = AUAdRequestContext.forSlot("flutter:1", pageKey: "Article")
        let second = AUAdRequestContext.forSlot("flutter:2", pageKey: "Article")
        XCTAssertEqual(ledger.nextRequest(first).refresh, 0)
        XCTAssertEqual(ledger.nextRequest(second).refresh, 0)
        for index in 1...3 {
            post(UIApplication.didEnterBackgroundNotification)
            post(UIApplication.didBecomeActiveNotification)
            settle()
            XCTAssertTrue(AUAdRequestContext.forSlot("flutter:1", pageKey: "Article") === first)
            let next = ledger.nextRequest(first)
            XCTAssertEqual(next.pageSequence, 1); XCTAssertEqual(next.slot, 1)
            XCTAssertEqual(next.refresh, index)
            XCTAssertEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, initialPage.pageImpressionId)
        }
        XCTAssertEqual(ledger.nextRequest(second).slot, 2)
        XCTAssertEqual(events.filter { $0.type == .pageImpression }.count, 1)
    }

    func testNavigationDuringDelaySupersedesRecoveryAndStartsANewPage() {
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        Audienzz.shared.pageImpression("Next")
        settle()
        XCTAssertEqual(viewUpdates, ["Next"])
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 2)
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().screenName, "Next")
        XCTAssertNotEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, initialPage.pageImpressionId)
        XCTAssertEqual(events.filter { $0.type == .pageImpression }.count, 2)
    }

    func testRecoveryObserverCanNavigateWithoutRestoringTheOldPageAfterwards() {
        Audienzz.shared.pageImpressionObserver = { [weak self] page in
            self?.viewUpdates.append(page)
            if page == "Article" { Audienzz.shared.pageImpression("Next") }
        }
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        settle()
        XCTAssertEqual(viewUpdates, ["Article", "Next"])
        XCTAssertEqual(AUScreenAdCoordinator.shared.activeScreenAndName?.0 as? String, "Next")
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 2)
        XCTAssertEqual(events.filter { $0.type == .pageImpression }.count, 2)
    }

    func testWithoutAnActivePageForegroundDoesNotInventOne() {
        Audienzz.shared.resetLifecycleForTesting()
        Audienzz.shared.pageImpressionObserver = { [weak self] in self?.viewUpdates.append($0) }
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        settle()
        XCTAssertTrue(viewUpdates.isEmpty)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 0)
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, initialPage.pageImpressionId)
        XCTAssertEqual(events.filter { $0.type == .pageImpression }.count, 1)
    }

}
