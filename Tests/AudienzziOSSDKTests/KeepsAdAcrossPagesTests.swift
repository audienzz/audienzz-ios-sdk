import XCTest
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

/// `keepsAdAcrossPages`: a page transition pauses a loaded banner instead of releasing it and
/// forcing a new auction on return.
final class KeepsAdAcrossPagesTests: AudienzzLifecycleTestCase {

    private var previousBlank = false

    override func setUp() {
        super.setUp()
        previousBlank = Audienzz.shared.blankOnScreenReload
        Audienzz.shared.blankOnScreenReload = true
        // Any auction the return tries to start is refused and recorded as owed, which is what
        // these tests observe through `pendingLoadReason`.
        Audienzz.shared.prebidConfiguredOverride = false
    }

    override func tearDown() {
        Audienzz.shared.blankOnScreenReload = previousBlank
        Audienzz.shared.prebidConfiguredOverride = nil
        super.tearDown()
    }

    private func loadedBanner(keeps: Bool) -> (AUBannerView, AdManagerBannerView) {
        let view = AUBannerView(
            configId: "config",
            adSize: CGSize(width: 320, height: 50),
            adFormats: [.banner]
        )
        let gamView = AdManagerBannerView(adSize: AdSizeBanner)
        view.eventHandler = AUBannerHandler(auBannerView: view, gamView: gamView)
        view.gamRequest = AdManagerRequest()
        view.lastRefreshTime = Date()
        view.showsCreative = true
        view.keepsAdAcrossPages = keeps
        return (view, gamView)
    }

    private func leave(_ view: AUBannerView) {
        view.screenActive = false
        view.releaseForPage()
    }

    private func comeBack(_ view: AUBannerView) {
        view.screenActive = true
        view.recreateForPage()
    }

    func testLeavingKeepsTheCreativeAndPausesRefresh() {
        let (view, gamView) = loadedBanner(keeps: true)

        leave(view)

        XCTAssertFalse(gamView.isHidden, "the creative stays")
        XCTAssertTrue(view.refreshController.blockReasons.contains(.pageInactive))
    }

    func testComingBackResumesWithoutAnAuction() {
        let (view, gamView) = loadedBanner(keeps: true)
        leave(view)

        comeBack(view)

        XCTAssertNil(view.pendingLoadReason, "no page-impression auction is owed")
        XCTAssertFalse(view.refreshController.blockReasons.contains(.pageInactive))
        XCTAssertFalse(gamView.isHidden)
    }

    func testAReReportOfTheSamePageDoesNotReload() {
        let (view, _) = loadedBanner(keeps: true)

        comeBack(view)

        XCTAssertNil(view.pendingLoadReason)
    }

    func testControlByDefaultLeavingBlanksAndComingBackOwesAnAuction() {
        let (view, gamView) = loadedBanner(keeps: false)

        leave(view)
        XCTAssertTrue(gamView.isHidden)
        comeBack(view)

        XCTAssertEqual(view.pendingLoadReason, .pageImpression)
    }

    func testABannerThatNeverLoadedIsReleasedAsBefore() {
        let (view, gamView) = loadedBanner(keeps: true)
        view.lastRefreshTime = nil
        view.showsCreative = false

        leave(view)

        XCTAssertTrue(gamView.isHidden, "never loaded: the default release applies")
    }

    /// A banner whose last request completed, so its refresh clock is running.
    private func completedLoad(_ view: AUBannerView) {
        view.refreshController.setIntervalMillis(30_000)
        let generation = view.refreshController.onRequestStarted(.firstLoad)
        view.refreshController.onRequestCompleted(generationAtRequest: generation, success: true)
        XCTAssertTrue(view.refreshController.hasRefreshClock)
    }

    func testRefreshCanStillBeScheduledAfterAReturn() {
        let (view, _) = loadedBanner(keeps: true)
        completedLoad(view)

        leave(view)
        comeBack(view)

        XCTAssertTrue(view.refreshController.hasRefreshClock,
                      "a kept ad keeps its refresh clock, or it never refreshes again")
    }

    func testRetiringAnAuctionInFlightRestartsTheRefreshClock() {
        let (view, _) = loadedBanner(keeps: true)
        completedLoad(view)
        _ = view.refreshController.onRequestStarted(.periodicRefresh)
        XCTAssertTrue(view.refreshController.hasRequestInFlight)

        leave(view)
        comeBack(view)

        XCTAssertFalse(view.refreshController.hasRequestInFlight, "the visit's auction was retired")
        XCTAssertTrue(view.refreshController.hasRefreshClock)
    }

    func testABackgroundKeepsTheRefreshClockOfAKeptAd() {
        let (view, _) = loadedBanner(keeps: true)
        completedLoad(view)

        view.blockForBackground()

        XCTAssertTrue(view.refreshController.blockReasons.contains(.appBackground))
        XCTAssertTrue(view.refreshController.hasRefreshClock,
                      "foreground recovery keeps the ad, so the clock must survive the background")
    }

    func testABackgroundStillRetiresAnOrdinaryBannersAuction() {
        let (view, _) = loadedBanner(keeps: false)
        completedLoad(view)

        view.blockForBackground()

        XCTAssertFalse(view.refreshController.hasRefreshClock, "unchanged: recovery reloads it")
    }

    func testASlotWhoseRequestOnlyFailedIsReleasedNotKept() {
        let (view, gamView) = loadedBanner(keeps: true)
        view.showsCreative = false

        leave(view)
        XCTAssertTrue(gamView.isHidden, "no creative to keep: the default release applies")
        comeBack(view)

        XCTAssertEqual(view.pendingLoadReason, .pageImpression, "retried on return")
    }

    func testAGoogleLoadInFlightCompletesBeforeTheHold() {
        let (view, gamView) = loadedBanner(keeps: true)
        completedLoad(view)
        let generation = view.refreshController.onRequestStarted(.periodicRefresh)
        view.googleLoad = AUBannerView.GoogleLoad(auction: view.auctionGeneration, refresh: generation)

        leave(view)
        XCTAssertTrue(view.screenActive, "the visit that started the load owns its completion")
        XCTAssertTrue(view.holdPending)

        XCTAssertTrue(view.completeGoogleLoad(received: true, retryableFailure: false),
                      "creative B is committed, not dropped")
        let held = expectation(description: "hold applied")
        DispatchQueue.main.async { held.fulfill() }
        wait(for: [held], timeout: 1)
        XCTAssertFalse(view.screenActive)
        XCTAssertFalse(view.holdPending)
        XCTAssertFalse(gamView.isHidden)
        XCTAssertTrue(view.refreshController.hasRefreshClock)

        comeBack(view)
        XCTAssertNil(view.pendingLoadReason, "no auction on return")
    }

    func testAnExpiredViewControllerOwnerDoesNotHandTheBannerToAnotherScreen() {
        let banner = AUBannerView(configId: "c", adSize: CGSize(width: 320, height: 50), adFormats: [.banner])
        autoreleasepool {
            let owner = UIViewController()
            banner.setScreen(owner)
        }
        XCTAssertTrue(banner.hostScreenOverrideExpired)
        let other = UIViewController()
        other.view.addSubview(banner)
        XCTAssertFalse(banner.isHostedBy(other), "its explicit owner is gone; it is nobody's")
        banner.setScreen("route-2")
        XCTAssertTrue(banner.isHostedBy("route-2" as NSString), "a new owner can be set")
    }

    func testNothingIsCountedWhileThePageIsAway() {
        let (view, _) = loadedBanner(keeps: true)
        leave(view)
        XCTAssertFalse(view.acceptsGoogleEvents)
        comeBack(view)
        view.googleEventPageGeneration = view.creativePageGeneration
        XCTAssertTrue(view.acceptsGoogleEvents, "the same creative counts again on return")
    }
}
