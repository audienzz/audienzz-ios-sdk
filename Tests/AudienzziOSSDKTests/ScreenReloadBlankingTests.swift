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
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

/// Leaving a page clears its creative, so returning to the page never shows the previous ad.
///
/// Blanking used to begin when the *replacement auction* started, which left the outgoing creative
/// on screen for the whole transition: the user saw the old ad, then a blank, then the new one.
/// Moving it to the page release is only safe because of what is hidden — the GAM view *inside* the
/// container, never the container the visibility gate measures. Hiding the container would mark the
/// slot ineligible for the very auction meant to refill it.
final class ScreenReloadBlankingTests: AudienzzLifecycleTestCase {

    private var previousSetting = false

    override func setUp() {
        super.setUp()
        previousSetting = Audienzz.shared.blankOnScreenReload
        Audienzz.shared.blankOnScreenReload = true
    }

    override func tearDown() {
        Audienzz.shared.blankOnScreenReload = previousSetting
        super.tearDown()
    }

    /// A banner with a real GAM view attached, as it is once a creative has rendered.
    private func loadedBanner() -> (AUBannerView, AdManagerBannerView) {
        let view = AUBannerView(
            configId: "config",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )
        let gamView = AdManagerBannerView(adSize: AdSizeBanner)
        view.eventHandler = AUBannerHandler(auBannerView: view, gamView: gamView)
        return (view, gamView)
    }

    func testLeavingAPageBlanksTheCreativeImmediately() {
        let (view, gamView) = loadedBanner()

        view.releaseForPage()

        XCTAssertTrue(gamView.isHidden, "the outgoing creative must not survive the transition")
    }

    func testLeavingAPageNeverHidesTheContainerTheGateMeasures() {
        // The container's own `isHidden` is what `refreshVisibilityNow` reads. Hiding it is what
        // made a blanked slot ineligible, so the replacement never ran and the slot stayed empty.
        let (view, _) = loadedBanner()

        view.releaseForPage()

        XCTAssertFalse(view.isHidden)
    }

    func testTheCreativeIsRevealedAgainWhenAFreshOneArrives() {
        let (view, gamView) = loadedBanner()
        view.releaseForPage()

        view.restoreFromBlankIfNeeded()

        XCTAssertFalse(gamView.isHidden)
    }

    func testBlankingIsSkippedWhenThePublisherHasNotAskedForIt() {
        Audienzz.shared.blankOnScreenReload = false
        let (view, gamView) = loadedBanner()

        view.releaseForPage()

        XCTAssertFalse(gamView.isHidden)
    }

    func testRevealingASlotThisBannerDidNotBlankDoesNothing() {
        // A publisher who hid the GAM view themselves must not have it revealed by our reload.
        Audienzz.shared.blankOnScreenReload = false
        let (view, gamView) = loadedBanner()
        gamView.isHidden = true

        view.restoreFromBlankIfNeeded()

        XCTAssertTrue(gamView.isHidden)
    }

    func testBlankingTwiceStillRevealsOnce() {
        // A page re-reported without an intervening release blanks again; the flag must not latch
        // in a way that leaves the slot stuck.
        let (view, gamView) = loadedBanner()

        view.releaseForPage()
        view.blankForReloadIfNeeded()
        view.restoreFromBlankIfNeeded()

        XCTAssertFalse(gamView.isHidden)
    }

    // ── parity with Android: a blank is never left with nothing coming ──────

    func testARefusedAuctionReleasesTheBlank() {
        // Android reveals inside its fetch gate, so EVERY refusal releases the blank. iOS used to
        // reveal only at the two callers that checked the result, which left any other refused
        // path (a resume, a rearm) holding a blank slot that nothing would refill.
        let (view, gamView) = loadedBanner()
        Audienzz.shared.prebidConfiguredOverride = false
        view.blankForReloadIfNeeded()
        XCTAssertTrue(gamView.isHidden)

        XCTAssertFalse(view.fetchRequest(AdManagerRequest(), reason: .pageImpression))

        XCTAssertFalse(gamView.isHidden, "a refused auction must not leave the slot blank")
    }

    func testLeavingAPageStillBlanksEvenThoughRetiringReveals() {
        // releaseForPage retires (which now reveals) and then deliberately blanks again, so the
        // return trip still shows no stale creative. Order matters; this pins it.
        let (view, gamView) = loadedBanner()

        view.releaseForPage()

        XCTAssertTrue(gamView.isHidden)
    }

    func testRetiringAnAuctionOnItsOwnReleasesTheBlank() {
        // A cancelled replacement never reaches the Google callback that would reveal it. Android
        // has had this inside retireCurrentAuction all along; iOS did not. Driven with the flag
        // turned off for the release, so the retire is NOT followed by a deliberate re-blank.
        let (view, gamView) = loadedBanner()
        view.blankForReloadIfNeeded()
        XCTAssertTrue(gamView.isHidden)

        Audienzz.shared.blankOnScreenReload = false
        view.releaseForPage()

        XCTAssertFalse(gamView.isHidden)
    }

    func testAnAlreadyHiddenGAMViewIsNotAdoptedAsOurOwnBlank() {
        // Otherwise the next reveal would show an ad the publisher deliberately hid.
        let (view, gamView) = loadedBanner()
        gamView.isHidden = true

        view.releaseForPage()
        view.restoreFromBlankIfNeeded()

        XCTAssertTrue(gamView.isHidden)
    }
}

/// A banner must not auction before Prebid has its account id.
///
/// The failure this prevents is quieter on iOS than on Android. Android's Prebid never calls back
/// at all, so the slot stayed empty for the session; iOS answers `.prebidInvalidAccountId` and the
/// SDK still loads GAM, so the slot fills — but with no header-bidding demand behind it. The ad is
/// not lost, the auction is, and it is the above-the-fold impression that loses it.
final class PrebidConfiguredGateTests: AudienzzLifecycleTestCase {

    private func banner() -> AUBannerView {
        AUBannerView(
            configId: "config",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )
    }

    func testAnAuctionIsRefusedWhilePrebidIsUnconfigured() {
        Audienzz.shared.prebidConfiguredOverride = false
        let view = banner()

        XCTAssertFalse(view.canStartAuction(.firstLoad))
    }

    func testAnAuctionIsAdmittedOncePrebidIsConfigured() {
        Audienzz.shared.prebidConfiguredOverride = true
        let view = banner()

        XCTAssertTrue(view.canStartAuction(.firstLoad))
    }

    func testTheGateAppliesToEveryReasonNotJustTheFirstLoad() {
        // A periodic refresh landing in the same window would waste an auction just as a first load
        // would; the first-load exemptions are about visibility and attachment, not about this.
        Audienzz.shared.prebidConfiguredOverride = false
        let view = banner()

        XCTAssertFalse(view.canStartAuction(.periodicRefresh))
        XCTAssertFalse(view.canStartAuction(.pageImpression))
    }

    func testARefusedFirstLoadIsRememberedSoItCanBeResumed() {
        // Refusing is only safe because the reason is recorded — otherwise the deferred load would
        // simply be dropped, which is the bug in a different costume.
        Audienzz.shared.prebidConfiguredOverride = false
        let view = banner()
        let request = AdManagerRequest()

        XCTAssertFalse(view.fetchRequest(request, reason: .firstLoad))
        XCTAssertEqual(view.pendingLoadReason, .firstLoad)
    }

    func testTheCoordinatorResumeReachesRegisteredBannersWithoutCrashing() {
        // The resume path runs over a weak registry that may contain banners in any state; it must
        // be safe to call at any time, since initialization decides when it happens.
        Audienzz.shared.prebidConfiguredOverride = false
        let view = banner()
        AUScreenAdCoordinator.shared.register(view)

        Audienzz.shared.prebidConfiguredOverride = true
        AUScreenAdCoordinator.shared.resumeAllAfterPrebidConfigured()

        XCTAssertTrue(view.canStartAuction(.firstLoad))
    }
}
