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

    func testNothingIsCountedWhileThePageIsAway() {
        let (view, _) = loadedBanner(keeps: true)
        leave(view)
        XCTAssertFalse(view.acceptsGoogleEvents)
        comeBack(view)
        view.googleEventPageGeneration = view.creativePageGeneration
        XCTAssertTrue(view.acceptsGoogleEvents, "the same creative counts again on return")
    }
}
