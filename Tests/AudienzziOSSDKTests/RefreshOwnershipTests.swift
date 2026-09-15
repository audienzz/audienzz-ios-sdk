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
import PrebidMobile
@testable import AudienzziOSSDK

/// The SDK owns refresh; Prebid must never own a timer.
///
/// This is the load-bearing invariant of the migration and it is asserted against Prebid's own
/// object graph rather than against our state. Prebid's `Dispatcher` — a repeating main-run-loop
/// `Timer` that re-fetches through the *last* completion handler it saw — is created only by
/// `AdUnit.initDispatcher(refreshTime:)`, which is called only from `AdUnit.setAutoRefreshMillis`.
/// So a nil `dispatcher` is proof that no Prebid timer exists, and `startDispatcher()` /
/// `resumeAutoRefresh()` are both no-ops for the life of the ad unit.
final class RefreshOwnershipTests: AudienzzLifecycleTestCase {

    private func banner() -> AUBannerView {
        AUBannerView(
            configId: "config",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )
    }

    /// Prebid's own view of whether it holds a refresh timer. Reflection, because `dispatcher` is
    /// internal to PrebidMobile — the point of the test is to read Prebid's state, not a mirror of
    /// it that we maintain ourselves.
    private func prebidDispatcher(of adUnit: AdUnit) -> Any? {
        // `dispatcher` is declared on `AdUnit`, and every ad unit we build is a subclass, so the
        // superclass mirrors have to be walked — a plain `Mirror` only shows the leaf class.
        var mirror: Mirror? = Mirror(reflecting: adUnit)
        while let current = mirror {
            for child in current.children where child.label == "dispatcher" {
                // A nil Optional reflects as a child whose value is `Optional<Dispatcher>.none`;
                // unwrap rather than compare against nil, which an `Any` box would always fail.
                return Mirror(reflecting: child.value).children.first?.value
            }
            mirror = current.superclassMirror
        }
        XCTFail("PrebidMobile's AdUnit no longer has a `dispatcher` property — re-verify this invariant")
        return nil
    }

    func testConfiguringAnIntervalNeverReachesPrebid() {
        let view = banner()

        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        XCTAssertNil(
            prebidDispatcher(of: view.adUnit),
            "Prebid must hold no dispatcher, or its timer can auction on its own schedule through a "
                + "completion handler the SDK cannot gate"
        )
    }

    func testTheConfiguredIntervalIsStoredByTheSDK() {
        let view = banner()

        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        XCTAssertEqual(view.refreshController.intervalMillis, 30_000)
    }

    func testAnIntervalOfZeroDisablesRefresh() {
        let view = banner()
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        view.adUnitConfiguration.setAutoRefreshMillis(time: 0)

        XCTAssertEqual(view.refreshController.intervalMillis, 0, "0 means no refresh, unchanged for publishers")
        XCTAssertNil(prebidDispatcher(of: view.adUnit))
    }

    func testTheIntervalIsClampedToTheSupportedMinimum() {
        let view = banner()

        view.adUnitConfiguration.setAutoRefreshMillis(time: 5_000)

        XCTAssertEqual(
            view.refreshController.intervalMillis,
            AUAdUnitConfiguration.minimumRefreshMillis,
            "below the floor Prebid's original API enforced, clamped rather than silently sped up"
        )
    }

    func testResumingRefreshCannotArmAPrebidTimer() {
        // The end-to-end version of the invariant. `resumeAutoRefresh()` is what the SDK used to
        // call after every load; with no dispatcher it can do nothing, whatever the call order.
        let view = banner()
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        view.adUnit.resumeAutoRefresh()
        view.adUnit.stopAutoRefresh()
        view.adUnit.resumeAutoRefresh()

        XCTAssertNil(prebidDispatcher(of: view.adUnit))
    }

    func testAPublisherPauseIsNotClearedByAViewportResume() {
        // Independent reasons are the whole point of the block set: a scroll back into view must
        // not undo `stopAutoRefresh()`.
        let view = banner()
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        view.adUnitConfiguration.stopAutoRefresh()
        view.resumeSmartRefresh()

        XCTAssertTrue(view.refreshController.isBlocked)
        XCTAssertEqual(view.refreshController.blockReasons, [.publisher])
    }

    func testAViewportPauseIsClearedByItsOwnResume() {
        let view = banner()
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        view.pauseSmartRefresh()
        view.resumeSmartRefresh()

        XCTAssertFalse(view.refreshController.isBlocked)
    }

    func testTheServerCannotReEnablePrebidRefresh() {
        // The bid response can change some SDK settings through `ext.prebid.passthrough`. On iOS
        // that path reaches only the creative-factory timeouts and the video controls — there is no
        // field that can set a refresh delay for the original API. This fails if a Prebid upgrade
        // ever adds one, which would silently hand the timer back to Prebid.
        let configurableKeys = Set(
            Mirror(reflecting: ORTBSDKConfiguration()).children.compactMap(\.label)
        )

        XCTAssertEqual(
            configurableKeys,
            ["cftBanner", "cftPreRender"],
            "PrebidMobile's server-configurable SDK settings changed; re-check that none of them can "
                + "arm a refresh timer"
        )
    }
}
