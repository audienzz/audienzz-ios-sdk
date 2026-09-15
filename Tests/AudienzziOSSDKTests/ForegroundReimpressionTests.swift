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

/// Returning from the background is a new page impression, which recreates the active page's
/// banners. Exactly one has to happen per visit: two means a duplicate auction and a discarded
/// creative, none means a restored app keeps showing a stale ad.
///
/// The app may report the visit itself, in which case the SDK must stand down. Deciding that from
/// how long ago the last report happened failed in both directions, so these drive the real UIKit
/// notifications and count impressions through the public observer.
final class ForegroundReimpressionTests: AudienzzLifecycleTestCase {

    private var impressions: [String] = []

    /// Long enough for the automatic impression's scheduling delay to elapse.
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
        // coordinator an active screen to re-report.
        Audienzz.shared.pageImpression("Article")

        impressions = []
        Audienzz.shared.pageImpressionObserver = { [weak self] name in
            self?.impressions.append(name)
        }
    }

    override func tearDown() {
        super.tearDown()
    }

    func testReportsTheVisitWhenTheAppDoesNot() {
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(impressions, ["Article"], "a restored app must get a fresh impression")
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
            impressions,
            ["Article"],
            "the app owns this visit, however long activation takes to arrive"
        )
    }

    func testReportsANewVisitEvenWhenThePreviousOneWasReportedJustBefore() {
        // A report, then a quick background and return. Judging by elapsed time let the PREVIOUS
        // visit's report suppress this one, leaving the restored app with no impression at all.
        Audienzz.shared.pageImpression("Article")
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(
            impressions,
            ["Article", "Article"],
            "the new visit needs its own impression regardless of how recent the last one was"
        )
    }

    func testDoesNotReportWithoutARealBackgroundRoundTrip() {
        // didBecomeActive also follows Control Centre, a permission prompt or an incoming call.
        // None of those are a new page view.
        post(UIApplication.didBecomeActiveNotification)
        settle()

        XCTAssertEqual(impressions, [])
    }

    func testDoesNotReportWhileStillBackgrounded() {
        // Backgrounding again inside the scheduling window must drop the pending impression rather
        // than recreate the whole active page with the app not on screen.
        post(UIApplication.didEnterBackgroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        post(UIApplication.didEnterBackgroundNotification)
        settle()

        XCTAssertEqual(impressions, [])
    }
}
