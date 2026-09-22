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

    func testAnAlreadyHiddenGAMViewIsNotAdoptedAsOurOwnBlank() {
        // Otherwise the next reveal would show an ad the publisher deliberately hid.
        let (view, gamView) = loadedBanner()
        gamView.isHidden = true

        view.releaseForPage()
        view.restoreFromBlankIfNeeded()

        XCTAssertTrue(gamView.isHidden)
    }
}
