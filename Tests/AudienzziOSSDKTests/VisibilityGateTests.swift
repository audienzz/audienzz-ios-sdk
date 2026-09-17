import XCTest
import UIKit
import GoogleMobileAds
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

/// Signals that change what the user sees without touching the properties the gate first observed.
@MainActor
final class VisibilityGateSignalTests: AudienzzLifecycleTestCase {

    private var window: UIWindow!
    private var page: UIView!

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    private func makeAd() -> VisibilityGateTests.ProbeView {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        page = UIView(frame: window.bounds)
        window.addSubview(page)
        window.isHidden = false
        let ad = VisibilityGateTests.ProbeView(frame: CGRect(x: 0, y: 100, width: 320, height: 50))
        ad.directional = true
        ad.prefetchMarginPoints = 0
        page.addSubview(ad)
        settle()
        return ad
    }

    func testATransformThatMovesTheAdOffscreenMakesItIneligible() {
        let ad = makeAd()
        XCTAssertEqual(ad.eligible, true)

        // A transform moves the ad without changing its frame.
        ad.transform = CGAffineTransform(translationX: 0, y: -2000)
        settle()

        XCTAssertEqual(ad.eligible, false, "a transformed-away ad is not on screen")
    }

    func testTurningOnClippingOnAnAncestorMakesItIneligible() {
        let ad = makeAd()
        page.frame = CGRect(x: 0, y: 0, width: 390, height: 10)
        settle()
        // The ad now hangs outside its parent's bounds but the parent does not clip yet.
        page.clipsToBounds = true
        settle()

        XCTAssertEqual(ad.eligible, false,
                       "enabling clipping changes what is shown without changing any geometry")
    }

    func testCollapsingTheAdToZeroSizeMakesItIneligible() {
        let ad = makeAd()
        XCTAssertEqual(ad.eligible, true)

        ad.frame = CGRect(x: 0, y: 100, width: 320, height: 0)
        settle()

        XCTAssertEqual(ad.eligible, false, "an ad with no size shows nothing")
    }

    func testASlotInsideACollapsedClippingContainerDoesNotPrefetch() {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let collapsed = UIView(frame: CGRect(x: 0, y: 100, width: 390, height: 0))
        collapsed.clipsToBounds = true
        window.addSubview(collapsed)
        window.isHidden = false
        let ad = VisibilityGateTests.ProbeView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        ad.prefetchMarginPoints = 200
        collapsed.addSubview(ad)
        settle()

        XCTAssertEqual(ad.prefetchCount, 0,
                       "nothing inside a collapsed container can come into view")
    }

    func testASlotBelowTheFoldInsideAScrollViewStillPrefetches() {
        // A UIScrollView clips by default. Requiring an unclipped rect meant the prefetch margin
        // never applied to the one arrangement it exists for.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scroll = UIScrollView(frame: window.bounds)
        scroll.contentSize = CGSize(width: 390, height: 3000)
        window.addSubview(scroll)
        window.isHidden = false
        let ad = VisibilityGateTests.ProbeView(frame: CGRect(x: 0, y: 900, width: 320, height: 50))
        ad.prefetchMarginPoints = 200
        scroll.addSubview(ad)
        settle()

        XCTAssertEqual(ad.prefetchCount, 1,
                       "a slot 56pt below the fold is inside a 200pt prefetch margin")
    }
}

/// The gate that runs when a refresh is about to be spent.
///
/// Exercised through `onRefreshDue` rather than through the geometry helper it calls: a test that
/// calls the helper itself still passes when the call site goes back to reading the cached flag,
/// which is exactly what it is supposed to catch.
@MainActor
final class RefreshTimeVisibilityTests: AudienzzLifecycleTestCase {

    private func spin(_ seconds: TimeInterval = 0.3) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Builds a loaded, smart-refresh banner on the active page.
    private func loadedBanner(in window: UIWindow) -> AUBannerView {
        let banner = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        banner.smartRefresh = true
        window.addSubview(banner)
        banner.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        spin()
        banner.notifyAdLoadCompleted(rendered: true)
        return banner
    }

    func testAPageImpressionClearsAHoldTakenFromAStaleVerdict() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = loadedBanner(in: window)

        // Moved away by the layer, so the request-time gate holds the refresh.
        banner.layer.position = CGPoint(x: banner.layer.position.x, y: -5000)
        banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.notVisible))

        // Moved back the same way — again nothing observable fires. The automatic foreground
        // page impression owns recovery, so `resumeAfterForeground` stands down and this is the
        // only path left that can clear the hold.
        banner.layer.position = CGPoint(x: banner.layer.position.x, y: 125)
        banner.recreateForPage()
        spin()

        XCTAssertFalse(banner.refreshController.blockReasons.contains(.notVisible),
                       "a hold taken from a verdict that is no longer true must not outlive the "
                        + "page transition")
    }

    func testAPageImpressionDoesNotClearAHoldForAnAdThatIsStillAway() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = loadedBanner(in: window)

        banner.layer.position = CGPoint(x: banner.layer.position.x, y: -5000)
        banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.notVisible))

        banner.recreateForPage()
        spin()

        XCTAssertTrue(banner.refreshController.blockReasons.contains(.notVisible),
                      "a page impression does not make an off-screen banner visible")
    }

    func testAHoldTakenAtRequestTimeIsReleasedByAnOrdinaryReturn() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = loadedBanner(in: window)

        banner.layer.position = CGPoint(x: banner.layer.position.x, y: -5000)
        banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.notVisible))

        // Back on screen through an ordinary, observed frame change. If the hold were recorded
        // without moving the cached verdict, there would be no false-to-true transition here and
        // nothing would ever release it.
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        spin()

        XCTAssertFalse(banner.refreshController.blockReasons.contains(.notVisible),
                       "an ordinary return must release a hold taken at request time")
    }

    func testAPageImpressionDoesNotReleaseAHostReportedPause() {
        // Flutter and React Native report visibility themselves; native geometry cannot see an
        // overlay drawn above the platform view. A page transition recomputes geometry, and must
        // not read that as permission to resume something it cannot see behind.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = loadedBanner(in: window)

        banner.pauseSmartRefresh()
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.hostReportedHidden))

        banner.recreateForPage()
        spin()

        XCTAssertTrue(banner.refreshController.blockReasons.contains(.hostReportedHidden),
                      "only the host that reported the pause may clear it")
    }

    func testTheHostResumeClearsItsOwnPause() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = loadedBanner(in: window)

        banner.pauseSmartRefresh()
        banner.resumeSmartRefresh()
        spin()

        XCTAssertFalse(banner.refreshController.isBlocked,
                       "the host's own resume must release it")
    }

    func testARefreshIsNotSpentOnAnAdMovedOffscreenByItsLayer() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        // Empty config id: Prebid completes demand immediately, so no network is involved.
        let banner = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        banner.smartRefresh = true
        window.addSubview(banner)
        banner.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        var loads = 0
        banner.onLoadRequest = { _ in loads += 1 }
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        spin()
        XCTAssertTrue(banner.isViewRefreshEligible, "control — the ad starts on screen")
        let afterFirstLoad = loads

        // layer.position moves the ad without emitting anything observable, so the cached verdict
        // stays "eligible" and only a fresh read can tell.
        banner.layer.position = CGPoint(x: banner.layer.position.x, y: -5000)
        XCTAssertTrue(banner.isViewRefreshEligible, "nothing fired — the cached flag is stale")

        banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        spin()

        XCTAssertEqual(loads, afterFirstLoad,
                       "a refresh must not be spent on an ad that is no longer on screen")
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.notVisible),
                      "and it must record why it held")
    }
}
