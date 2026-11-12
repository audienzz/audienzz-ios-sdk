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

    /// A kept banner showing creative A whose refresh B is already loading in Google, then leaves.
    private func leaveWithGoogleLoadInFlight() -> (AUBannerView, AdManagerBannerView, AUBannerHandler) {
        let (view, gamView) = loadedBanner(keeps: true)
        let handler = view.eventHandler as! AUBannerHandler
        completedLoad(view)
        view.googleEventPageGeneration = view.creativePageGeneration
        view.renderedDeliveryId = "A"
        view.commitDisplayedCreative(responseId: "response-A")
        // Refresh B reaches Google.
        let generation = view.refreshController.onRequestStarted(.periodicRefresh)
        gamView.adUnitID = "/test/unit"
        view.pendingDeliveryId = "B"
        view.renderAuctionId = "auction-B"
        view.lastRenderEconomics = AURenderEconomics(auctionId: "auction-B")
        view.googleLoad = AUBannerView.GoogleLoad(auction: view.auctionGeneration, refresh: generation)
        leave(view)
        XCTAssertTrue(view.holdPending)
        XCTAssertTrue(view.acceptsGoogleEvents, "the visit that started the load owns its completion")
        return (view, gamView, handler)
    }

    private func drainMain() {
        let done = expectation(description: "main queue")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    func testAGoogleLoadInFlightCommitsItsCreativeThenHolds() {
        let (view, gamView, handler) = leaveWithGoogleLoadInFlight()

        handler.bannerViewDidReceiveAd(gamView)
        XCTAssertEqual(view.renderedDeliveryId, "B", "creative B is what the slot shows")
        XCTAssertEqual(view.displayedEconomics?.auctionId, "auction-B", "and what render events describe")
        XCTAssertNotNil(view.placementTracker, "B's placementVisible watcher is installed")
        XCTAssertFalse(view.countsExposure, "but nothing is counted: the page is already away")

        drainMain()
        XCTAssertFalse(view.screenActive)
        XCTAssertFalse(view.holdPending)
        XCTAssertFalse(gamView.isHidden)
        XCTAssertTrue(view.refreshController.hasRefreshClock)

        comeBack(view)
        XCTAssertNil(view.pendingLoadReason, "no auction on return")
        XCTAssertEqual(view.renderedDeliveryId, "B")
        XCTAssertTrue(view.countsExposure, "B counts once its page is back")
    }

    func testNoExposureIsCountedWhileTheHoldIsPending() {
        let (view, _, _) = leaveWithGoogleLoadInFlight()
        XCTAssertFalse(view.countsExposure)
        XCTAssertTrue(view.keptOnInactivePage)
    }

    func testAReloadCannotRetireTheLoadAHoldIsWaitingFor() {
        let (view, gamView, handler) = leaveWithGoogleLoadInFlight()
        let auction = view.auctionGeneration

        view.reloadAd()
        XCTAssertEqual(view.auctionGeneration, auction, "the protected load is not retired")
        XCTAssertNotNil(view.googleLoad)

        handler.bannerViewDidReceiveAd(gamView)
        XCTAssertEqual(view.renderedDeliveryId, "B")
        drainMain()
        XCTAssertFalse(view.holdPending)
        XCTAssertFalse(view.screenActive)
    }

    func testAFailedLoadStillSettlesTheHold() {
        let (view, gamView, handler) = leaveWithGoogleLoadInFlight()
        handler.bannerView(gamView, didFailToReceiveAdWithError: NSError(domain: GADErrorDomain, code: RequestError.noFill.rawValue))
        XCTAssertEqual(view.renderedDeliveryId, "A", "a failed replacement leaves A displayed")
        drainMain()
        XCTAssertFalse(view.holdPending)
        XCTAssertFalse(view.screenActive)
        comeBack(view)
        XCTAssertNil(view.pendingLoadReason, "A is still kept: no auction on return")
    }

    func testAGoogleLoadThatNeverCompletesStillSettlesTheHold() {
        let (view, _, _) = leaveWithGoogleLoadInFlight()
        view.googleLoadTimeoutSeconds = 0.05
        view.watchGoogleLoad(view.googleLoad!)
        let settled = expectation(description: "hold settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertNil(view.googleLoad)
        XCTAssertFalse(view.holdPending)
        XCTAssertFalse(view.screenActive)
    }

    func testABackgroundWhileTheHoldIsPendingLetsTheLoadComplete() {
        let (view, gamView, handler) = leaveWithGoogleLoadInFlight()
        let auction = view.auctionGeneration
        view.blockForBackground()
        XCTAssertEqual(view.auctionGeneration, auction)
        handler.bannerViewDidReceiveAd(gamView)
        XCTAssertEqual(view.renderedDeliveryId, "B")
        drainMain()
        XCTAssertFalse(view.holdPending)
    }

    func testTheImpressionOfAKeptCreativeIsRecordedWhileItsPageIsAway() {
        let (view, gamView, handler) = leaveWithGoogleLoadInFlight()
        handler.bannerViewDidReceiveAd(gamView)
        drainMain()
        XCTAssertFalse(view.acceptsGoogleEvents)

        // Google records B's impression after the hold applied: it counts (Google counted it too).
        handler.bannerViewDidRecordImpression(gamView)
        XCTAssertTrue(view.displayedImpressionRecorded)
        XCTAssertFalse(view.countsExposure, "its viewability still waits for the return")
    }

    func testAPrebidWinReportedAfterTheHoldStillAttributesTheKeptCreative() {
        let (view, gamView, handler) = leaveWithGoogleLoadInFlight()
        handler.bannerViewDidReceiveAd(gamView)
        drainMain()
        XCTAssertFalse(view.holdPending)
        XCTAssertFalse(view.displayedPrebidLineItemWon)

        handler.adView(gamView, didReceiveAppEvent: "Prebid", with: nil)
        XCTAssertTrue(view.displayedPrebidLineItemWon, "B is credited to Prebid, not the ad server")
    }

    func testALateSuccessAfterTheWatchdogMarksTheSlotAsShowingACreative() {
        let (view, _) = loadedBanner(keeps: true)
        view.showsCreative = false
        view.googleEventPageGeneration = view.creativePageGeneration
        view.googleLoad = nil
        XCTAssertTrue(view.completeGoogleLoad(received: true, retryableFailure: false))
        XCTAssertTrue(view.showsCreative, "a kept slot that shows a creative is kept on return")
    }

    func testAnOrdinaryReleasedBannerRecordsNoImpression() {
        let (view, gamView) = loadedBanner(keeps: false)
        view.googleEventPageGeneration = view.creativePageGeneration
        leave(view)
        (view.eventHandler as! AUBannerHandler).bannerViewDidRecordImpression(gamView)
        XCTAssertFalse(view.displayedImpressionRecorded)
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
