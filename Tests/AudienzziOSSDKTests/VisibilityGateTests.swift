import XCTest
import UIKit
@testable import AudienzziOSSDK

/// What the viewport gates count as "on screen".
///
/// They used to compare the ad's raw frame against the window, which answers a different question:
/// a banner reads as fully visible while it sits inside a hidden container, under a faded-out
/// parent, clipped away by an ancestor, or scrolled off sideways. Android has always clipped
/// against every ancestor and rejected non-visible views outright.
@MainActor
final class VisibilityGateTests: AudienzzLifecycleTestCase {

    /// Records the gate transitions instead of loading ads.
    final class ProbeView: VisibleView {
        var directional = false
        override var usesDirectionalRefreshGate: Bool { directional }
        private(set) var visible: Bool?
        private(set) var eligible: Bool?
        private(set) var prefetchCount = 0
        override func onBecameVisible() { visible = true }
        override func onBecameHidden() { visible = false }
        override func onRefreshBecameEligible() { eligible = true }
        override func onRefreshBecameIneligible() { eligible = false }
        override func onEnteredPrefetchZone() { prefetchCount += 1 }
    }

    private var window: UIWindow!
    private var page: UIView!

    /// Settles the async visibility check `didMoveToWindow` and the KVO observers schedule.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    /// A 390x844 screen holding `page`, with an ad slot at `top` inside it.
    private func makeAd(top: CGFloat = 100, height: CGFloat = 50, directional: Bool = true) -> ProbeView {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        page = UIView(frame: window.bounds)
        window.addSubview(page)
        window.isHidden = false
        let ad = ProbeView(frame: CGRect(x: 0, y: top, width: 320, height: height))
        ad.directional = directional
        ad.prefetchMarginPoints = 0
        page.addSubview(ad)
        settle()
        return ad
    }

    // MARK: - Concealment

    func testAHiddenParentMakesTheAdIneligible() {
        let ad = makeAd()
        XCTAssertEqual(ad.eligible, true, "control — an on-screen ad is eligible")

        page.isHidden = true
        settle()

        XCTAssertEqual(ad.eligible, false, "an ad inside a hidden container is not on screen")
        XCTAssertEqual(ad.visible, false)
    }

    func testFadingTheAdOutMakesItIneligible() {
        let ad = makeAd()
        XCTAssertEqual(ad.eligible, true)

        ad.alpha = 0
        settle()

        XCTAssertEqual(ad.eligible, false, "a fully transparent ad cannot be seen")
    }

    func testFadingAnAncestorOutMakesItIneligible() {
        let ad = makeAd()
        page.alpha = 0
        settle()
        XCTAssertEqual(ad.eligible, false)
    }

    func testConcealmentIsDetectedWithoutAnyScrolling() {
        // The hierarchy here has no scroll view at all, so the only signal available is the
        // concealment observation. Before it existed the ad kept its last verdict forever.
        let ad = makeAd()
        XCTAssertEqual(ad.eligible, true)
        page.isHidden = true
        settle()
        XCTAssertEqual(ad.eligible, false, "no scroll event occurs in this hierarchy")
    }

    func testRevealingTheAdAgainRestoresEligibility() {
        let ad = makeAd()
        page.isHidden = true
        settle()
        XCTAssertEqual(ad.eligible, false)

        page.isHidden = false
        settle()

        XCTAssertEqual(ad.eligible, true, "revealing the ad must bring it back")
    }

    // MARK: - Clipping

    func testAnAncestorThatClipsTheAdAwayMakesItIneligible() {
        let ad = makeAd(top: 0)
        // A collapsed section: the clipping ancestor keeps its position but shows nothing.
        page.clipsToBounds = true
        page.frame = CGRect(x: 0, y: 0, width: 390, height: 0)
        settle()

        XCTAssertEqual(ad.eligible, false, "an ad clipped away by its container is not on screen")
    }

    func testNestedClippingIsHonoured() {
        let ad = makeAd(top: 0)
        let inner = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 50))
        inner.clipsToBounds = true
        page.addSubview(inner)
        ad.removeFromSuperview()
        inner.addSubview(ad)
        settle()
        XCTAssertEqual(ad.eligible, true, "control — fully inside the inner clip")

        // The outer container now clips the inner one away entirely.
        page.clipsToBounds = true
        page.frame = CGRect(x: 0, y: 0, width: 390, height: 0)
        settle()

        XCTAssertEqual(ad.eligible, false, "clipping by any ancestor counts, not just the parent")
    }

    // MARK: - Horizontal

    func testAnAdScrolledOffSidewaysIsIneligible() {
        let ad = makeAd(top: 100)
        XCTAssertEqual(ad.eligible, true)

        // A horizontal pager moves the page off to the left; the ad still overlaps the window
        // vertically, which is all the old check looked at.
        ad.frame = CGRect(x: -400, y: 100, width: 320, height: 50)
        settle()

        XCTAssertEqual(ad.eligible, false, "an ad off the side of the screen is not on screen")
    }

    // MARK: - v1 / v2 difference preserved

    func testLegacyGateStillUsesTheTwentyPercentThreshold() {
        // v1: eligibility follows the same >=20%-visible rule as the load path, so an ad whose top
        // is clipped is still eligible while enough of it shows. v2 would refuse it.
        let ad = makeAd(top: -30, height: 50, directional: false)
        XCTAssertEqual(ad.eligible, true, "40% of the ad is on screen")

        let strict = makeAd(top: -30, height: 50, directional: true)
        XCTAssertNotEqual(strict.eligible, true, "v2 requires the top edge fully on screen")
    }

    // MARK: - Prefetch

    func testAConcealedSlotDoesNotPrefetchUntilItIsRevealed() {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        page = UIView(frame: window.bounds)
        page.isHidden = true
        window.addSubview(page)
        window.isHidden = false
        let ad = ProbeView(frame: CGRect(x: 0, y: 100, width: 320, height: 50))
        ad.prefetchMarginPoints = 0
        page.addSubview(ad)
        settle()

        XCTAssertEqual(ad.prefetchCount, 0, "a hidden slot has no position worth buying an ad for")

        page.isHidden = false
        settle()

        XCTAssertEqual(ad.prefetchCount, 1, "revealing it defers the load rather than losing it")
    }
}
