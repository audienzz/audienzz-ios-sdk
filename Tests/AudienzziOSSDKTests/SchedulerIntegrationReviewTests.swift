import XCTest
import GoogleMobileAds
@testable import AudienzziOSSDK

final class SchedulerIntegrationReviewTests: XCTestCase {
    var view: AUBannerView!
    var loads = 0
    func post(_ name: Notification.Name) { NotificationCenter.default.post(name: name, object: nil) }
    override func setUp() {
        super.setUp()
        post(UIApplication.willEnterForegroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        Audienzz.shared.pageImpression("A")
        // Invalid config yields an immediate Prebid completion without any live ad request.
        view = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: false)
        view.setScreen("A")
        view.onLoadRequest = { [weak self] _ in self?.loads += 1; self?.view.notifyAdLoadCompleted() }
    }
    override func tearDown() {
        view.destroy()
        Audienzz.shared.cancelPendingForegroundReimpression()
        post(UIApplication.willEnterForegroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        Audienzz.shared.cancelPendingForegroundReimpression()
        super.tearDown()
    }
    func testPublisherReportBeforeGateOpensMustStillRecoverFirstLoad() {
        post(UIApplication.didEnterBackgroundNotification)
        Audienzz.shared.pageImpression("A") // publisher observer runs before SDK willEnterForeground
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        XCTAssertEqual(loads, 0)
        post(UIApplication.willEnterForegroundNotification)
        post(UIApplication.didBecomeActiveNotification)
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(loads, 1, "Explicit impression suppressed the automatic one; rejected first load still needs recovery")
    }
    func testPublisherResumeRecoversFirstLoadThatWasPaused() {
        view.adUnitConfiguration.stopAutoRefresh()
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        XCTAssertEqual(loads, 0)
        view.adUnitConfiguration.resumeAutoRefresh()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1, "Clearing publisher pause must recover the admitted first load")
    }
    func testInitialDetachedBannerDoesNotIssuePeriodicRequests() {
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        XCTAssertNil(view.window)
        RunLoop.main.run(until: Date().addingTimeInterval(31.0))
        XCTAssertEqual(loads, 1, "Only the admitted first load may run before attachment; periodic requests cannot render")
    }

    func testGoogleCompletionOwnsTheIntervalAndInFlightState() {
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1)
        XCTAssertTrue(view.refreshController.hasRequestInFlight)
        XCTAssertNotNil(view.eventHandler, "GAM must be observed even without the optional event wrapper")
        view.eventHandler?.bannerViewDidReceiveAd(google)
        XCTAssertFalse(view.refreshController.hasRequestInFlight)
    }

    func testPageReplacementWaitsForOldGoogleLoadToDrain() {
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1)
        Audienzz.shared.pageImpression("A")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1, "GAM loads must be serialized across page transitions")
        view.eventHandler?.bannerViewDidReceiveAd(google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 2)
        XCTAssertTrue(view.refreshController.hasRequestInFlight, "the old result cannot complete the replacement")
        view.eventHandler?.bannerViewDidReceiveAd(google)
        XCTAssertFalse(view.refreshController.hasRequestInFlight)
    }

    func testNativeBannerUsesTheSameRefreshAndGoogleLifecycle() {
        let parameters = AUNativeRequestParameter()
        let native = AUNativeBannerView(configId: "", configuration: parameters, isLazyLoad: false)
        native.setScreen("A")
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        var nativeLoads = 0
        native.onLoadRequest = { _ in nativeLoads += 1 }
        native.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)
        native.createAd(with: AdManagerRequest(), gamBanner: google, configuration: parameters)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(native.refreshController.intervalMillis, 30_000)
        XCTAssertEqual(nativeLoads, 1)
        XCTAssertTrue(native.refreshController.hasRequestInFlight)
        native.eventHandler?.bannerViewDidReceiveAd(google)
        XCTAssertFalse(native.refreshController.hasRequestInFlight)
        native.adUnitConfiguration.stopAutoRefresh()
        native.resumeSmartRefresh()
        XCTAssertTrue(native.refreshController.blockReasons.contains(.publisher))
        native.destroy()
    }

    func testGoogleTransportFailureRetriesOnlyAfterItsTerminalCallback() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(view)
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1)
        let error = NSError(domain: GADErrorDomain, code: RequestError.networkError.rawValue)
        view.eventHandler?.bannerView(google, didFailToReceiveAdWithError: error)
        RunLoop.main.run(until: Date().addingTimeInterval(2.1))
        XCTAssertEqual(loads, 2)
        XCTAssertTrue(view.refreshController.hasRequestInFlight)
        withExtendedLifetime(window) {}
    }

    func testFirstPrefetchIsAllowedBeforeRefreshVisibilityAndAttachment() {
        view.destroy()
        view = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: true)
        view.setScreen("A")
        view.pauseSmartRefresh()
        view.onLoadRequest = { [weak self] _ in
            self?.loads += 1
            self?.view.notifyAdLoadCompleted()
        }
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        XCTAssertEqual(loads, 0)
        view.onEnteredPrefetchZone()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1)
        XCTAssertTrue(view.refreshController.blockReasons.contains(.notVisible))
        XCTAssertTrue(view.refreshController.blockReasons.contains(.detached))
    }
    final class GoogleDelegate: NSObject, BannerViewDelegate {
        var loaded = 0; var failed = 0; var clicked = 0; var impressed = 0
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { loaded += 1 }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { failed += 1 }
        func bannerViewDidRecordClick(_ bannerView: BannerView) { clicked += 1 }
        func bannerViewDidRecordImpression(_ bannerView: BannerView) { impressed += 1 }
    }

    func testMissingGoogleCallbackExpiresAndReleasesPendingPageReplacement() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(view)
        view.googleLoadTimeoutSeconds = 0.2
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(loads, 1)
        Audienzz.shared.pageImpression("A")
        XCTAssertEqual(loads, 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(loads, 2)
        google.delegate?.bannerViewDidReceiveAd?(google)
        XCTAssertFalse(view.refreshController.hasRequestInFlight)
        withExtendedLifetime(window) {}
    }

    func testMissingGoogleCallbackClearsFlightWithoutFastRetryAndAllowsManualReload() {
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        let window = UIWindow(); window.addSubview(view)
        view.googleLoadTimeoutSeconds = 0.05
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        XCTAssertNil(view.googleLoad)
        XCTAssertFalse(view.refreshController.hasRequestInFlight)
        XCTAssertEqual(loads, 1)
        view.reloadAd()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(loads, 2)
        withExtendedLifetime(window) {}
    }

    func testWrappedGoogleBannerIsObservedAndUnsolicitedTerminalsAreForwarded() {
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        let publisher = GoogleDelegate(); google.delegate = publisher
        let wrapper = UIView(); let inner = UIView(); wrapper.addSubview(inner); inner.addSubview(google)
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: wrapper)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(google.delegate === view.eventHandler)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.delegate?.bannerView?(google, didFailToReceiveAdWithError: NSError(domain: GADErrorDomain, code: RequestError.noFill.rawValue))
        XCTAssertEqual(publisher.loaded, 2)
        XCTAssertEqual(publisher.failed, 1)
        XCTAssertFalse(view.refreshController.hasRequestInFlight)
    }

    func testDisplayedCreativeEventsAndAuctionIdentitySurviveDeferredSamePageReload() {
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        let publisher = GoogleDelegate(); google.delegate = publisher
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        google.delegate?.bannerViewDidReceiveAd?(google)
        let auction = view.resolvedRenderEconomics().auctionId
        view.adUnitConfiguration.stopAutoRefresh()
        Audienzz.shared.pageImpression("A")
        google.delegate?.bannerViewDidRecordClick?(google)
        google.delegate?.bannerViewDidRecordImpression?(google)
        XCTAssertEqual(publisher.clicked, 1)
        XCTAssertEqual(publisher.impressed, 1)
        XCTAssertEqual(view.resolvedRenderEconomics().auctionId, auction)
        Audienzz.shared.pageImpression("B")
        google.delegate?.bannerViewDidRecordClick?(google)
        XCTAssertEqual(publisher.clicked, 1)
    }

    func testTimeoutDoesNotReviveDestroyedView() {
        view.googleLoadTimeoutSeconds = 0.05
        view.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        view.destroy()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(loads, 1)
        XCTAssertNil(view.googleLoad)
    }

}
