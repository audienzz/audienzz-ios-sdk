import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

@MainActor
final class BannerRefreshLimitTests: AudienzzLifecycleTestCase {
    private var window: UIWindow!
    private var banners: [AUBannerView] = []
    private var requests: [AdManagerRequest] = []
    private var handoff: XCTestExpectation?

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            Audienzz.shared.pageImpression("article")
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = UIViewController()
            window.isHidden = false
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            banners.forEach { $0.destroy() }
            banners.removeAll()
            requests.removeAll()
            handoff = nil
            window.isHidden = true
            window = nil
        }
        super.tearDown()
    }

    private func banner(context: AUAdRequestContext = AUAdRequestContext()) -> AUBannerView {
        // An empty Prebid config completes locally. Google is driven through the real custom-
        // renderer completion API, including failures; no network/timer sleeps are needed.
        let banner = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        banner.requestContext = context
        banner.hostScreenOverride = "article" as NSString
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        banner.onLoadRequest = { [weak self] request in
            self?.requests.append(request as! AdManagerRequest)
            self?.handoff?.fulfill()
            self?.handoff = nil
        }
        banners.append(banner)
        return banner
    }

    private func expectHandoff(_ action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let before = requests.count
        let expected = expectation(description: "Google receives one admitted request")
        handoff = expected
        action()
        wait(for: [expected], timeout: 2)
        XCTAssertEqual(requests.count, before + 1, file: file, line: line)
    }

    private func start(_ banner: AUBannerView) {
        expectHandoff { banner.createAd(with: AdManagerRequest(), gamBanner: UIView()) }
    }

    private func reachLimit(_ banner: AUBannerView) {
        start(banner)
        for refresh in 1...10 {
            banner.notifyAdLoadCompleted(rendered: true)
            expectHandoff { banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation) }
            XCTAssertEqual(requests.last?.customTargeting?["au_refresh"] as? String, String(refresh))
        }
    }

    func testLastAllowedGoogleLoadSurvivesReloadAndAllResumeSignals() {
        let banner = banner()
        reachLimit(banner)
        XCTAssertEqual(requests.count, 11)
        XCTAssertTrue(banner.refreshController.hasRequestInFlight)
        let generation = banner.refreshController.generation
        for _ in 0..<100 {
            banner.reloadAd()
            banner.adUnitConfiguration.stopAutoRefresh(); banner.adUnitConfiguration.resumeAutoRefresh()
            banner.pauseSmartRefresh(); banner.resumeSmartRefresh()
            banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        }
        XCTAssertEqual(banner.refreshController.generation, generation)
        XCTAssertTrue(banner.acceptsGoogleEvents)
        banner.notifyAdLoadCompleted(rendered: true)
        XCTAssertFalse(banner.refreshController.hasRequestInFlight)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.refreshLimit))
        XCTAssertEqual(requests.count, 11)
        XCTAssertFalse(banner.isHidden)

        // A page transition resets only the quota, never the publisher's durable pause.
        banner.adUnitConfiguration.stopAutoRefresh()
        Audienzz.shared.pageImpression("article")
        XCTAssertFalse(banner.refreshController.blockReasons.contains(.refreshLimit))
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.publisher))
        XCTAssertEqual(requests.count, 11)
        expectHandoff { banner.adUnitConfiguration.resumeAutoRefresh() }
        XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, "2")
        XCTAssertEqual(requests.last?.customTargeting?["au_refresh"] as? String, "0")
    }

    private final class GoogleDelegate: NSObject, BannerViewDelegate {
        var loads = 0
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { loads += 1 }
    }

    func testGoogleCreativeAndPublisherCallbacksSurviveCapWithBlankOnReloadEnabled() throws {
        let original = Audienzz.shared.blankOnScreenReload
        Audienzz.shared.blankOnScreenReload = true
        defer { Audienzz.shared.blankOnScreenReload = original }
        let banner = banner()
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        let publisher = GoogleDelegate()
        google.delegate = publisher
        expectHandoff { banner.createAd(with: AdManagerRequest(), gamBanner: google) }
        XCTAssertTrue(banner.eventHandler?.gamView === google)
        for _ in 0..<10 {
            google.delegate?.bannerViewDidReceiveAd?(google)
            expectHandoff { banner.reloadAd() }
            XCTAssertTrue(google.isHidden, "fixture must exercise real creative blanking")
        }
        let generation = banner.refreshController.generation
        banner.reloadAd()
        XCTAssertEqual(banner.refreshController.generation, generation)
        google.delegate?.bannerViewDidReceiveAd?(google)
        XCTAssertEqual(publisher.loads, 11)
        XCTAssertFalse(google.isHidden)
        for _ in 0..<100 { banner.reloadAd() }
        XCTAssertEqual(requests.count, 11)
        XCTAssertFalse(google.isHidden)
    }

    func testFinalTransportFailureCannotRetryEvenIfCancelledTimerRuns() {
        let banner = banner()
        reachLimit(banner)
        banner.notifyAdLoadCompleted(rendered: false, retryableFailure: true)
        XCTAssertFalse(banner.refreshController.hasRequestInFlight)
        for _ in 0..<100 {
            banner.onRefreshDue(.loadRetry, banner.refreshController.generation)
            banner.reloadAd()
        }
        XCTAssertEqual(requests.count, 11)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.refreshLimit))
    }

    func testNativeReplacementKeepsTheBudgetAndNewPageRecoversItsFirstLoad() {
        let context = AUAdRequestContext.forSlot("flutter-slot")
        let old = banner(context: context)
        reachLimit(old)
        old.notifyAdLoadCompleted(rendered: true)
        old.destroy()
        let replacement = banner(context: AUAdRequestContext.forSlot("flutter-slot"))
        replacement.createAd(with: AdManagerRequest(), gamBanner: UIView())
        XCTAssertTrue(replacement.refreshController.blockReasons.contains(.refreshLimit))
        XCTAssertFalse(replacement.initialLoadRequested)
        XCTAssertEqual(requests.count, 11)
        let other = banner()
        start(other)
        XCTAssertEqual(requests.last?.customTargeting?["au_slot"] as? String, "2")
        other.destroy()
        expectHandoff { Audienzz.shared.pageImpression("article") }
        XCTAssertEqual(requests.last?.customTargeting?["au_refresh"] as? String, "0")
        XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, "2")
    }

    func testAutomaticForegroundPageResetsAllowanceOnce() {
        let banner = banner()
        reachLimit(banner)
        banner.notifyAdLoadCompleted(rendered: true)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(Audienzz.shared.isAppBackgrounded)
        banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        XCTAssertEqual(requests.count, 11)
        expectHandoff {
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, "2")
        XCTAssertEqual(requests.last?.customTargeting?["au_refresh"] as? String, "0")
    }

    func testForegroundWithoutAReportedPageDoesNotResetTheCap() {
        Audienzz.shared.resetLifecycleForTesting()
        let banner = banner()
        reachLimit(banner)
        banner.notifyAdLoadCompleted(rendered: true)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(Audienzz.shared.isAppBackgrounded)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(Audienzz.shared.hasPendingForegroundReimpression)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.refreshLimit))
        banner.onRefreshDue(.periodicRefresh, banner.refreshController.generation)
        XCTAssertEqual(requests.count, 11)
        XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, "0")
    }

    func testLedgerLimitsUnreportedPagesRetriesAndRecreatedBridgeContexts() {
        let ledger = AUAdRequestLedger()
        let first = ledger.forSlot("slot")
        for refresh in 0...10 {
            XCTAssertEqual(ledger.nextBannerRequest(first), AUAdRequestSnapshot(pageSequence: 0, slot: 1, refresh: refresh))
        }
        for _ in 0..<100 {
            XCTAssertNil(ledger.nextBannerRequest(ledger.forSlot("slot")))
        }
        let second = AUAdRequestContext()
        XCTAssertEqual(ledger.nextBannerRequest(second), AUAdRequestSnapshot(pageSequence: 0, slot: 2, refresh: 0))
        ledger.beginPage(1, retained: [second, first])
        XCTAssertEqual(ledger.nextBannerRequest(first), AUAdRequestSnapshot(pageSequence: 1, slot: 1, refresh: 0))
        // Interstitial calls are explicit opportunities; this idle-refresh limit is banner-only.
        for refresh in 1...20 { XCTAssertEqual(ledger.nextRequest(first).refresh, refresh) }
    }
}
