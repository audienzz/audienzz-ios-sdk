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

/// Page ownership decides which banners keep auctioning and which fall silent, so a wrong answer
/// here either strands a slot or lets a screen the user has left keep buying inventory.
///
/// Banners are matched by route key (`setScreen`), the same path the Flutter and React Native
/// bridges take, which keeps these independent of the view hierarchy — a bridge banner lives in the
/// single host view controller and can never be told apart by host identity.
final class AUScreenAdCoordinatorTests: AudienzzLifecycleTestCase {

    private var coordinator: AUScreenAdCoordinator { AUScreenAdCoordinator.shared }

    private func banner(on page: String) -> AUBannerView {
        let view = AUBannerView(
            configId: "config-\(page)",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )
        view.setScreen(page)
        coordinator.register(view)
        return view
    }

    private func openPage(_ name: String) {
        coordinator.onScreenResumed(name as AnyObject, name: name)
    }

    // ── Matching ────────────────────────────────────────────────────────────

    func testBannerOnTheReportedPageStaysActive() {
        let article = banner(on: "Article")

        openPage("Article")

        XCTAssertTrue(article.screenActive)
    }

    func testBannerOnAnotherPageIsReleased() {
        let article = banner(on: "Article")

        openPage("Home")

        XCTAssertFalse(article.screenActive, "a banner whose page the user left must fall silent")
    }

    func testReleasedBannerBecomesActiveAgainWhenItsPageReturns() {
        let article = banner(on: "Article")
        openPage("Home")
        XCTAssertFalse(article.screenActive)

        openPage("Article")

        XCTAssertTrue(article.screenActive)
    }

    func testEachPageOnlyActivatesItsOwnBanners() {
        let article = banner(on: "Article")
        let home = banner(on: "Home")

        openPage("Home")

        XCTAssertFalse(article.screenActive)
        XCTAssertTrue(home.screenActive)
    }

    // ── Epoch and generation ────────────────────────────────────────────────

    func testEveryPageImpressionAdvancesTheEpoch() {
        let before = coordinator.epoch

        openPage("Article")
        openPage("Home")

        XCTAssertEqual(coordinator.epoch, before + 2)
    }

    func testReReportingTheSamePageIsStillATransition() {
        // Back navigation and returning from the background both re-report the page the user is
        // already on, and both must serve a fresh creative rather than being treated as a no-op.
        let article = banner(on: "Article")
        openPage("Article")
        let generation = article.auctionGeneration

        openPage("Article")

        XCTAssertGreaterThan(
            article.auctionGeneration,
            generation,
            "the outgoing auction must be superseded even for the same page"
        )
    }

    func testLeavingAPageSupersedesTheOutgoingAuction() {
        // A response still in flight when the page is left must be recognisable as stale, or it
        // loads a creative into a slot the user is no longer looking at.
        let article = banner(on: "Article")
        openPage("Article")
        let generation = article.auctionGeneration

        openPage("Home")

        XCTAssertGreaterThan(article.auctionGeneration, generation)
    }

    // ── The auction gate ────────────────────────────────────────────────────

    func testAReleasedBannerCannotStartAnAuction() {
        let article = banner(on: "Article")

        openPage("Home")

        XCTAssertFalse(article.canStartAuction())
    }

    func testABannerOnTheActivePageCanStartAnAuction() {
        let article = banner(on: "Article")

        openPage("Article")

        XCTAssertTrue(article.canStartAuction())
    }

    // ── Refresh ownership across page transitions ───────────────────────────

    func testLeavingAPageBlocksRefreshOnTheReasonThePageOwns() {
        // A released banner must be held by a reason only a page activation can clear. Holding it
        // on the visibility reason instead — which an earlier revision did — meant a scroll back
        // into view revived a banner on a screen the user had left.
        let article = banner(on: "Article")
        openPage("Article")

        openPage("Home")

        XCTAssertEqual(article.refreshController.blockReasons, [.pageInactive])
    }

    func testReturningToAPageClearsThePageBlock() {
        // The mirror image: the activation is the only thing that lifts it, and it must actually
        // lift it or the slot stays dormant for the rest of the process.
        let article = banner(on: "Article")
        openPage("Article")
        openPage("Home")

        openPage("Article")

        XCTAssertFalse(article.refreshController.isBlocked)
    }

    func testAViewportPauseDoesNotSurviveAsAPageBlock() {
        // The two reasons are independent: leaving the page adds its own, and coming back clears
        // only that one, leaving a genuine publisher pause in force.
        let article = banner(on: "Article")
        openPage("Article")
        article.adUnitConfiguration.stopAutoRefresh()

        openPage("Home")
        openPage("Article")

        XCTAssertEqual(
            article.refreshController.blockReasons,
            [.publisher],
            "a page round trip must not clear a publisher pause"
        )
    }

    // ── Before any page impression ──────────────────────────────────────────

    func testANewBannerDefaultsToActive() {
        // Apps that never call pageImpression must behave exactly as they did before page scoping,
        // so "active" has to be the resting state rather than something a sweep grants.
        let standalone = AUBannerView(
            configId: "config",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )

        XCTAssertTrue(standalone.screenActive)
        XCTAssertTrue(standalone.canStartAuction())
    }

    func testAnUntaggedBannerIsNotClaimedByAnyPage() {
        // Without a route key and without a resolvable host view controller there is nothing to
        // match on, so a sweep must not silently adopt the banner into whatever page is current.
        let untagged = AUBannerView(
            configId: "config",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )

        XCTAssertFalse(untagged.isHostedBy("Article" as AnyObject))
    }
}
