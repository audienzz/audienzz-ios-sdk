import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

final class AnalyticsLifecycleTests: AudienzzLifecycleTestCase {
    var events: [AUEventDomain] = []
    var window: UIWindow!
    var banner: AUBannerView!
    var google: AdManagerBannerView!
    var handoffs = 0
    override func setUp() {
        super.setUp()
        events = []; handoffs = 0
        Audienzz.shared.pageImpression("A")
        AUEventsManager.shared.observerForTesting = { [unowned self] in events.append($0) }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844)); window.isHidden = false
        banner = AUBannerView(configId: "fixture", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: false)
        banner.setScreen("A"); banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        google = AdManagerBannerView(adSize: AdSizeBanner); google.adUnitID = "/fixture/banner"
        banner.demand = { _, _, complete in complete(.prebidDemandNoBids) }
        banner.onLoadRequest = { [unowned self] _ in handoffs += 1 }
    }
    override func tearDown() {
        banner.viewabilityTracker?.stop(); banner.destroy(); banner.removeFromSuperview()
        banner = nil; google = nil; window.isHidden = true; window = nil
        AUEventsManager.shared.observerForTesting = nil
        super.tearDown()
    }
    func wait(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    func loaded() {
        banner.createAd(with: AdManagerRequest(), gamBanner: google); wait(0.05)
        XCTAssertEqual(handoffs, 1); XCTAssertNotNil(google.delegate)
        google.delegate?.bannerViewDidReceiveAd?(google)
    }
    func impression() { google.delegate?.bannerViewDidRecordImpression?(google) }
    func count(_ type: AUAnalyticsEventType) -> Int { events.filter { $0.type == type }.count }
    func testFirstGoogleFillRetainsFirstLoadFlag() throws {
        loaded(); impression()
        XCTAssertEqual(try XCTUnwrap(events.first { $0.type == .bidRequest }).slotReload, 0)
        XCTAssertEqual(try XCTUnwrap(events.first { $0.type == .adImpression }).slotReload, 0)
    }
    func testRepeatedLoadForSameResponsePreservesMeasurementAndNewResponseRearmsIt() {
        let fixture = ProbeBannerAd(adSize: AdSizeBanner)
        fixture.adUnitID = "/fixture/banner"
        google = fixture
        loaded(); impression(); wait(0.1)
        google.delegate?.bannerViewDidReceiveAd?(google); impression(); wait(1.1)
        XCTAssertEqual(count(.adImpression), 1)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        banner.reloadAd(); wait(0.1); XCTAssertEqual(handoffs, 2)
        fixture.info.identifier = "creative-B"
        google.delegate?.bannerViewDidReceiveAd?(google); impression(); wait(1.2)
        XCTAssertEqual(count(.adImpression), 2)
        XCTAssertEqual(count(.viewabilitySuccess), 2)
    }
    func testHiddenBannerCannotGetViewabilitySuccess() {
        loaded(); impression(); XCTAssertEqual(count(.viewabilityStart), 1)
        banner.isHidden = true
        wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
    }
    func testBannerViewabilityStartIsOncePerAuctionAcrossInterruptedExposure() throws {
        loaded(); impression()
        XCTAssertEqual(count(.viewabilityStart), 1)
        let auction = try XCTUnwrap(events.first { $0.type == .viewabilityStart }?.auctionId)
        let tracker = try XCTUnwrap(banner.viewabilityTracker)
        for _ in 0..<2 {
            wait(0.6)
            banner.frame.origin.y = 2000
            tracker.refreshVisibility()
            wait(1.1)
            XCTAssertEqual(count(.viewabilitySuccess), 0)
            banner.frame.origin.y = 100
            tracker.refreshVisibility()
            XCTAssertEqual(count(.viewabilityStart), 1)
        }
        // Exposure before scrolling away must not count toward the new continuous second.
        wait(0.6)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        wait(0.6)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        XCTAssertEqual(events.first { $0.type == .viewabilitySuccess }?.auctionId, auction)
        banner.frame.origin.y = 2000; tracker.refreshVisibility()
        banner.frame.origin.y = 100; tracker.refreshVisibility(); wait(1.1)
        XCTAssertEqual(count(.viewabilityStart), 1)
        XCTAssertEqual(count(.viewabilitySuccess), 1)

        banner.reloadAd(); wait(0.1); XCTAssertEqual(handoffs, 2)
        google.delegate?.bannerViewDidReceiveAd?(google); impression(); wait(1.2)
        XCTAssertEqual(count(.viewabilityStart), 2)
        XCTAssertEqual(count(.viewabilitySuccess), 2)
        let replacementAuction = try XCTUnwrap(events.last { $0.type == .viewabilityStart }?.auctionId)
        XCTAssertNotEqual(auction, replacementAuction)
        XCTAssertEqual(events.last { $0.type == .viewabilitySuccess }?.auctionId, replacementAuction)
    }
    func testRemoteInterstitialViewabilityStartIsOncePerAuctionAcrossBackgroundReturns() throws {
        let owner = AURemoteConfigInterstitial(adConfigId: "probe")
        owner.configuration = { _ in ("probe", "/gam/remote-interstitial", [CGSize(width: 320, height: 480)]) }
        owner.demand = { _, _, reply in reply(.prebidDemandNoBids) }
        owner.isForeground = { true }
        var receive: ((Result<AUInterstitialPresenting, Error>) -> Void)?
        owner.loadOverride = { receive = $0 }
        defer { owner.finishPresentation(); owner.destroy() }
        var auctions = Set<String>()
        for index in 0..<2 {
            owner.prefetch { _ in }
            let ad = InterstitialLifecycleTests.Ad()
            try XCTUnwrap(receive)(.success(ad))
            XCTAssertTrue(owner.show(from: UIViewController()))
            let delegate = try XCTUnwrap(ad.delegate)
            delegate.adWillPresentFullScreenContent?(ad)
            delegate.adDidRecordImpression?(ad)
            let auction = try XCTUnwrap(events.last { $0.type == .viewabilityStart }?.auctionId)
            XCTAssertTrue(auctions.insert(auction).inserted)
            for _ in 0..<2 {
                wait(0.6)
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                wait(1.1)
                XCTAssertEqual(count(.viewabilitySuccess), index)
                NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                delegate.adWillPresentFullScreenContent?(ad)
                XCTAssertEqual(count(.viewabilityStart), index + 1)
            }
            wait(0.6); XCTAssertEqual(count(.viewabilitySuccess), index)
            wait(0.6); XCTAssertEqual(count(.viewabilitySuccess), index + 1)
            XCTAssertEqual(events.last { $0.type == .viewabilitySuccess }?.auctionId, auction)
            delegate.adDidDismissFullScreenContent?(ad)
        }
    }
    func testBackgroundPollingCannotRearmViewability() {
        loaded(); impression(); XCTAssertEqual(count(.viewabilityStart), 1)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(Audienzz.shared.isAppBackgrounded)
        wait(1.5)
        XCTAssertEqual(count(.viewabilityStart), 1)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
    }
    func testPageReleaseCancelsViewabilitySuccess() {
        loaded(); impression(); XCTAssertEqual(count(.viewabilityStart), 1)
        Audienzz.shared.pageImpression("B")
        XCTAssertFalse(banner.screenActive)
        wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
    }
    func testReplacementMustEarnItsOwnViewabilitySuccess() throws {
        loaded(); impression()
        let original = try XCTUnwrap(events.first { $0.type == .adImpression }?.auctionId)
        banner.reloadAd(); wait(0.1); XCTAssertEqual(handoffs, 2)
        google.delegate?.bannerViewDidReceiveAd?(google)
        wait(1.2)
        XCTAssertEqual(count(.adImpression), 1)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        impression(); wait(0.2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        wait(1.0)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        XCTAssertNotEqual(original, try XCTUnwrap(events.first { $0.type == .viewabilitySuccess }?.auctionId))
    }
    func testDestroyCancelsViewabilitySuccess() {
        loaded(); impression(); XCTAssertEqual(count(.viewabilityStart), 1)
        banner.destroy(); wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
    }
    func testVisibleCreativeKeepsItsMeasurementWhileReplacementIsOnlyAnAuction() throws {
        loaded(); impression()
        let original = try XCTUnwrap(events.first { $0.type == .adImpression }?.auctionId)
        var reply: ((ResultCode) -> Void)?
        banner.demand = { _, _, complete in reply = complete }
        banner.reloadAd(); wait(1.2)
        XCTAssertNotNil(reply)
        XCTAssertEqual(handoffs, 1)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        XCTAssertEqual(events.first { $0.type == .viewabilitySuccess }?.auctionId, original)
        try XCTUnwrap(reply)(.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google); impression(); wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 2)
        XCTAssertNotEqual(events.last { $0.type == .viewabilitySuccess }?.auctionId, original)
    }
    func testRemoteInterstitialReportsOneImpressionAndOneViewabilitySuccess() throws {
        let owner = AURemoteConfigInterstitial(adConfigId: "probe")
        owner.configuration = { _ in ("probe", "/gam/remote-interstitial", [CGSize(width: 320, height: 480)]) }
        owner.demand = { _, _, reply in reply(.prebidDemandNoBids) }
        owner.isForeground = { true }
        var receive: ((Result<AUInterstitialPresenting, Error>) -> Void)?
        owner.loadOverride = { receive = $0 }
        defer { owner.finishPresentation(); owner.destroy() }
        owner.prefetch { _ in }
        let ad = InterstitialLifecycleTests.Ad()
        try XCTUnwrap(receive)(.success(ad))
        XCTAssertTrue(owner.show(from: UIViewController()))
        let delegate = try XCTUnwrap(ad.delegate)
        for _ in 0..<3 { delegate.adWillPresentFullScreenContent?(ad) }
        for _ in 0..<3 { delegate.adDidRecordImpression?(ad) }
        wait(1.2)
        XCTAssertEqual(count(.adImpression), 1)
        XCTAssertEqual(count(.bidRequest), 1)
        XCTAssertEqual(count(.viewabilityStart), 1)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        delegate.adDidDismissFullScreenContent?(ad)
    }

    func testSuccessWithoutBidderReportsNoBidsAndKeepsResponseAuction() throws {
        banner.demand = { _, _, complete in
            complete(.prebidDemandFetchSuccess)
            complete(.prebidDemandFetchSuccess)
        }
        loaded()
        XCTAssertEqual(count(.bidRequest), 1)
        XCTAssertEqual(count(.bidResponse), 1)
        XCTAssertEqual(count(.noBid), 1)
        XCTAssertEqual(count(.bidWon), 0)
        let request = try XCTUnwrap(events.first { $0.type == .bidRequest })
        let response = try XCTUnwrap(events.first { $0.type == .bidResponse })
        let noBid = try XCTUnwrap(events.first { $0.type == .noBid })
        XCTAssertNotNil(request.auctionId)
        XCTAssertEqual(response.auctionId, request.auctionId)
        XCTAssertEqual(noBid.auctionId, request.auctionId)
        XCTAssertEqual(noBid.resultCode, "NO_BIDS")
    }

    func testHostCoverInterruptsExposureButReturningCanEarnSuccess() throws {
        loaded(); impression()
        XCTAssertEqual(count(.viewabilityStart), 1)
        let auction = try XCTUnwrap(events.first { $0.type == .viewabilityStart }?.auctionId)
        banner.pauseSmartRefresh(); wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        banner.resumeSmartRefresh(); wait(0.2)
        XCTAssertEqual(count(.viewabilityStart), 1)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        wait(1.0)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        banner.pauseSmartRefresh(); banner.resumeSmartRefresh(); wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        XCTAssertEqual(count(.viewabilityStart), 1)
        XCTAssertEqual(events.first { $0.type == .viewabilitySuccess }?.auctionId, auction)
    }

    func testOriginalInterstitialKeepsItsOwnAuctionAfterOwnerReuse() throws {
        let owner = AUInterstitialView(configId: "probe", isLazyLoad: false)
        owner.demand = { _, _, complete in complete(.prebidDemandNoBids) }
        owner.onLoadRequest = { _ in }
        defer { owner.destroy() }
        owner.createAd(with: AdManagerRequest(), adUnitID: "/probe")
        let originalAuction = try XCTUnwrap(owner.currentAuctionId)
        let ad = ProbeInterstitialAd()
        owner.connectHandler(AUInterstitialEventHandler(adUnit: ad))
        let installed = try XCTUnwrap(ad.fullScreenContentDelegate)
        // The public owner accepts another prefetch after demand completes, even while ad A is held.
        owner.createAd(with: AdManagerRequest(), adUnitID: "/probe")
        let nextAuction = try XCTUnwrap(owner.currentAuctionId)
        XCTAssertNotEqual(originalAuction, nextAuction)
        installed.adDidRecordImpression?(ad)
        XCTAssertEqual(count(.adImpression), 1)
        XCTAssertEqual(events.last { $0.type == .adImpression }?.auctionId, originalAuction)
    }
    func testRewardedViewabilityKeepsPrefetchContext() throws {
        let owner = AURewardedView(configId: "probe", isLazyLoad: false)
        owner.currentAuctionId = "auction-A"
        owner.currentAnalyticsPage = AUEventsManager.shared.capturePageContext()
        let oldPage = try XCTUnwrap(owner.currentAnalyticsPage.pageImpressionId)
        let ad = ProbeRewardedAd()
        let handler = AURewardedHandler(handler: AURewardedEventHandler(adUnit: ad), adView: owner)
        defer { handler.cancelMeasurement(); owner.destroy(); withExtendedLifetime(handler) {} }
        Audienzz.shared.pageImpression("B")
        let newPage = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        XCTAssertNotEqual(oldPage, newPage)
        let installed = try XCTUnwrap(ad.fullScreenContentDelegate)
        installed.adWillPresentFullScreenContent?(ad)
        installed.adDidRecordImpression?(ad)
        wait(1.2)
        let impression = try XCTUnwrap(events.first { $0.type == .adImpression })
        let start = try XCTUnwrap(events.first { $0.type == .viewabilityStart })
        let success = try XCTUnwrap(events.first { $0.type == .viewabilitySuccess })
        XCTAssertEqual(impression.pageImpressionId, oldPage)
        XCTAssertEqual(start.pageImpressionId, oldPage); XCTAssertEqual(start.auctionId, "auction-A")
        XCTAssertEqual(success.pageImpressionId, oldPage); XCTAssertEqual(success.auctionId, "auction-A")
    }

    private func backgroundAndRecover() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(0.6)
    }

    func testForegroundBlanksAndReloadsWithoutResettingPageTargetingOrAnalytics() throws {
        let oldBlank = Audienzz.shared.blankOnScreenReload
        Audienzz.shared.blankOnScreenReload = true
        defer { Audienzz.shared.blankOnScreenReload = oldBlank }
        var requests: [AdManagerRequest] = []
        banner.onLoadRequest = { [unowned self] request in
            handoffs += 1
            requests.append(request as! AdManagerRequest)
        }
        loaded(); impression()
        let page = try XCTUnwrap(events.first { $0.type == .bidRequest }?.pageImpressionId)
        let seq = try XCTUnwrap(requests.first?.customTargeting?["au_page_seq"] as? String)
        let slot = try XCTUnwrap(requests.first?.customTargeting?["au_slot"] as? String)
        for index in 1...2 {
            backgroundAndRecover()
            XCTAssertEqual(handoffs, index + 1)
            XCTAssertTrue(google.isHidden, "slot stays blank until Google completes")
            XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
            google.delegate?.bannerViewDidReceiveAd?(google); impression()
            XCTAssertFalse(google.isHidden)
            XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, seq)
            XCTAssertEqual(requests.last?.customTargeting?["au_slot"] as? String, slot)
            XCTAssertEqual(requests.last?.customTargeting?["hb_refresh_count"] as? String, String(index))
        }
        XCTAssertEqual(count(.pageImpression), 0, "observer starts after the original page report")
        XCTAssertEqual(count(.bidRequest), 3); XCTAssertEqual(count(.adImpression), 3)
        let bids = events.filter { $0.type == .bidRequest }
        let auctionIds = try bids.map { try XCTUnwrap($0.auctionId) }
        XCTAssertEqual(Set(auctionIds).count, 3)
        for event in events { XCTAssertEqual(event.pageImpressionId, page) }
    }

    func testForegroundOffscreenReplacementWaitsThenRecoversWithoutAnotherPage() {
        loaded()
        banner.smartRefresh = true
        banner.frame.origin.y = 2000
        banner.refreshVisibilityNow()
        backgroundAndRecover()
        XCTAssertEqual(handoffs, 1)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
        banner.frame.origin.y = 100
        banner.refreshVisibilityNow()
        wait(0.1)
        XCTAssertEqual(handoffs, 2)
        XCTAssertEqual(count(.pageImpression), 0)
    }

    func testForegroundCannotReactivateOtherPageOrUndoPublisherPause() {
        loaded()
        banner.adUnitConfiguration.stopAutoRefresh()
        backgroundAndRecover()
        XCTAssertEqual(handoffs, 1)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.publisher))
        Audienzz.shared.pageImpression("B")
        backgroundAndRecover()
        XCTAssertEqual(handoffs, 1)
        XCTAssertFalse(banner.screenActive)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.pageInactive))
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 2)
    }

    private func originalInterstitial() throws -> (AUInterstitialView, ProbeInterstitialAd, FullScreenContentDelegate) {
        let owner = AUInterstitialView(configId: "probe", isLazyLoad: false)
        owner.demand = { _, _, done in done(.prebidDemandNoBids) }
        owner.onLoadRequest = { _ in }
        owner.createAd(with: AdManagerRequest(), adUnitID: "/probe")
        let ad = ProbeInterstitialAd()
        owner.connectHandler(AUInterstitialEventHandler(adUnit: ad))
        return (owner, ad, try XCTUnwrap(ad.fullScreenContentDelegate))
    }

    func testInterstitialReturnPreservesPageAndReloadsExactlyOnceForRepeatedShows() throws {
        Audienzz.shared.blankOnScreenReload = true
        defer { Audienzz.shared.blankOnScreenReload = false }
        var requests: [AdManagerRequest] = []
        banner.onLoadRequest = { [unowned self] request in handoffs += 1; requests.append(request as! AdManagerRequest) }
        loaded(); impression()
        let page = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        let seq = try XCTUnwrap(requests.first?.customTargeting?["au_page_seq"] as? String)
        let slot = try XCTUnwrap(requests.first?.customTargeting?["au_slot"] as? String)
        for cycle in 1...3 {
            let (owner, ad, delegate) = try originalInterstitial()
            defer { owner.destroy() }
            delegate.adWillPresentFullScreenContent?(ad)
            XCTAssertTrue(banner.refreshController.blockReasons.contains(.interstitial))
            delegate.adDidRecordImpression?(ad)
            delegate.adDidDismissFullScreenContent?(ad)
            delegate.adDidDismissFullScreenContent?(ad)
            wait(0.05)
            XCTAssertEqual(handoffs, cycle + 1)
            XCTAssertTrue(google.isHidden)
            XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
            google.delegate?.bannerViewDidReceiveAd?(google); impression()
            XCTAssertFalse(google.isHidden)
            XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, seq)
            XCTAssertEqual(requests.last?.customTargeting?["au_slot"] as? String, slot)
            XCTAssertEqual(requests.last?.customTargeting?["hb_refresh_count"] as? String, String(cycle))
        }
        XCTAssertEqual(count(.pageImpression), 0)
        for event in events { XCTAssertEqual(event.pageImpressionId, page) }
        let bannerBids = events.filter { $0.type == .bidRequest && $0.adUnitId == "/fixture/banner" }
        XCTAssertEqual(bannerBids.count, 4)
        XCTAssertEqual(Set(try bannerBids.map { try XCTUnwrap($0.auctionId) }).count, 4)
    }

    func testInterstitialCoverInterruptsBannerViewabilityAndFailureReleasesIt() throws {
        loaded(); impression()
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        delegate.adWillPresentFullScreenContent?(ad)
        wait(1.2)
        XCTAssertEqual(events.filter { $0.type == .viewabilitySuccess && $0.adUnitId == "/fixture/banner" }.count, 0)
        delegate.ad?(ad, didFailToPresentFullScreenContentWithError: NSError(domain: "test", code: 1))
        XCTAssertFalse(banner.refreshController.blockReasons.contains(.interstitial))
        XCTAssertEqual(handoffs, 1)
        XCTAssertEqual(count(.pageImpression), 0)
    }

    func testInstalledRenderingInterstitialDelegateRecoversBannerWithoutANewPage() throws {
        var requests: [AdManagerRequest] = []
        banner.onLoadRequest = { [unowned self] request in
            handoffs += 1; requests.append(request as! AdManagerRequest)
        }
        loaded(); impression()
        let page = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        let sequence = try XCTUnwrap(requests.first?.customTargeting?["au_page_seq"] as? String)
        let slot = try XCTUnwrap(requests.first?.customTargeting?["au_slot"] as? String)
        XCTAssertEqual(requests.first?.customTargeting?["hb_refresh_count"] as? String, "0")

        // Keep the lazy owner unattached to avoid a real network load. createAd installs
        // the production delegate on its real Prebid unit; invoke THAT delegate, not a helper.
        let owner = AUInterstitialRenderingView(configId: "probe", isLazyLoad: true,
            adFormat: .banner, eventHandler: AUGAMInterstitialEventHandler(adUnitID: "/probe/rendering"))
        owner.createAd()
        let unit = try XCTUnwrap(Mirror(reflecting: owner).children.first { $0.label == "adUnit" }?.value as? InterstitialRenderingAdUnit)
        let delegate = try XCTUnwrap(unit.delegate)
        defer { delegate.interstitialDidDismissAd?(unit); owner.removeFromSuperview() }
        delegate.interstitialWillPresentAd?(unit)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.interstitial))
        XCTAssertEqual(handoffs, 1)
        delegate.interstitialDidDismissAd?(unit)
        delegate.interstitialDidDismissAd?(unit)
        wait(0.05)
        XCTAssertFalse(banner.refreshController.blockReasons.contains(.interstitial))
        XCTAssertEqual(handoffs, 2)
        XCTAssertEqual(requests.count, 2)
        google.delegate?.bannerViewDidReceiveAd?(google); impression()
        XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, sequence)
        XCTAssertEqual(requests.last?.customTargeting?["au_slot"] as? String, slot)
        XCTAssertEqual(requests.last?.customTargeting?["hb_refresh_count"] as? String, "1")
        XCTAssertEqual(count(.bidRequest), 2)
        XCTAssertEqual(count(.adImpression), 2)
        XCTAssertEqual(count(.pageImpression), 0)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, page)
        for event in events { XCTAssertEqual(try XCTUnwrap(event.pageImpressionId), page) }
    }

    func testOverdueBannerRefreshAndDismissalProduceOnlyOneReplacement() throws {
        try assertOneReplacementAfterOverdueInterstitial(deferManualReload: false)
    }

    func testDismissalRecoversBeforeUncoverCanStartADeferredReload() throws {
        try assertOneReplacementAfterOverdueInterstitial(deferManualReload: true)
    }

    private func assertOneReplacementAfterOverdueInterstitial(deferManualReload: Bool) throws {
        var requests: [AdManagerRequest] = []
        banner.onLoadRequest = { [unowned self] request in
            handoffs += 1; requests.append(request as! AdManagerRequest)
        }
        loaded()
        let page = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        let sequence = try XCTUnwrap(requests.first?.customTargeting?["au_page_seq"] as? String)
        let slot = try XCTUnwrap(requests.first?.customTargeting?["au_slot"] as? String)
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        var replies: [(ResultCode) -> Void] = []
        banner.demand = { _, _, reply in replies.append(reply) }
        // Shorten only the test controller's interval; retain the real main-queue scheduler.
        banner.refreshController.setIntervalMillis(50)
        delegate.adWillPresentFullScreenContent?(ad)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.interstitial))
        wait(0.15)
        XCTAssertTrue(replies.isEmpty)
        XCTAssertEqual(handoffs, 1)
        if deferManualReload {
            // A publisher reload under the cover is deferred. Unlike the periodic timer,
            // it resumes synchronously on uncover, so this catches incorrect sweep ordering.
            banner.reloadAd()
            XCTAssertTrue(replies.isEmpty)
        }
        delegate.adDidDismissFullScreenContent?(ad)
        wait(0.05)
        XCTAssertEqual(replies.count, 1, "Recovery must retire deferred work before uncover can start it")
        let bids = events.filter { $0.type == .bidRequest && $0.adUnitId == "/fixture/banner" }
        XCTAssertEqual(bids.count, 2) // original + one recovery, including requests still awaiting Prebid
        XCTAssertEqual(Set(try bids.map { try XCTUnwrap($0.auctionId) }).count, 2)
        banner.refreshController.setIntervalMillis(0) // isolate recovery from subsequent normal refreshes
        try XCTUnwrap(replies.last)(.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google)
        wait(0.05)
        XCTAssertEqual(handoffs, 2)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.customTargeting?["au_page_seq"] as? String, sequence)
        XCTAssertEqual(requests.last?.customTargeting?["au_slot"] as? String, slot)
        XCTAssertEqual(requests.last?.customTargeting?["hb_refresh_count"] as? String, "1")
        XCTAssertEqual(count(.pageImpression), 0)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
        for event in events { XCTAssertEqual(try XCTUnwrap(event.pageImpressionId), page) }
    }

    func testInterstitialPrefetchedOnAKeepsAWhileRecoveryUsesB() throws {
        loaded()
        let pageA = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        Audienzz.shared.pageImpression("B")
        let pageB = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        XCTAssertNotEqual(pageA, pageB)
        delegate.adWillPresentFullScreenContent?(ad)
        delegate.adDidRecordImpression?(ad)
        let revision = AUScreenAdCoordinator.shared.adRevision
        delegate.adDidDismissFullScreenContent?(ad)
        XCTAssertEqual(AUScreenAdCoordinator.shared.adRevision, revision + 1)
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, pageB)
        XCTAssertEqual(try XCTUnwrap(events.last { $0.type == .adImpression }).pageImpressionId, pageA)
        XCTAssertEqual(count(.pageImpression), 1)
        XCTAssertFalse(banner.screenActive)
        XCTAssertEqual(handoffs, 1)
    }

    func testNavigationDuringPresentationDoesNotRecoverOrReclaimOldPage() throws {
        loaded()
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        delegate.adWillPresentFullScreenContent?(ad)
        Audienzz.shared.pageImpression("B")
        let revision = AUScreenAdCoordinator.shared.adRevision
        delegate.adDidDismissFullScreenContent?(ad)
        XCTAssertEqual(AUScreenAdCoordinator.shared.adRevision, revision)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 2)
        XCTAssertFalse(banner.screenActive)
        XCTAssertEqual(handoffs, 1)
        XCTAssertEqual(count(.pageImpression), 1)
    }

    func testForegroundAndInterstitialDismissalCoalesceInEitherOrder() throws {
        loaded()
        for foregroundFirst in [true, false] {
            let before = handoffs
            let (owner, ad, delegate) = try originalInterstitial()
            defer { owner.destroy() }
            delegate.adWillPresentFullScreenContent?(ad)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            if foregroundFirst {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                wait(0.5)
                XCTAssertEqual(handoffs, before)
                delegate.adDidDismissFullScreenContent?(ad)
            } else {
                delegate.adDidDismissFullScreenContent?(ad)
                XCTAssertEqual(handoffs, before)
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            wait(0.6)
            XCTAssertEqual(handoffs, before + 1)
            google.delegate?.bannerViewDidReceiveAd?(google)
            XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
            XCTAssertEqual(count(.pageImpression), 0)
        }
    }

    func testRemoteInterstitialDismissalUsesTheSameRecoveryAsOriginal() throws {
        loaded()
        let owner = AURemoteConfigInterstitial(adConfigId: "probe")
        owner.configuration = { _ in ("probe", "/gam/remote-interstitial", [CGSize(width: 320, height: 480)]) }
        owner.demand = { _, _, reply in reply(.prebidDemandNoBids) }
        owner.isForeground = { true }
        var receive: ((Result<AUInterstitialPresenting, Error>) -> Void)?
        owner.loadOverride = { receive = $0 }
        defer { owner.finishPresentation(); owner.destroy() }
        for cycle in 1...2 {
            owner.prefetch { _ in }
            let ad = InterstitialLifecycleTests.Ad()
            try XCTUnwrap(receive)(.success(ad))
            XCTAssertTrue(owner.show(from: UIViewController()))
            let delegate = try XCTUnwrap(ad.delegate)
            delegate.adWillPresentFullScreenContent?(ad)
            XCTAssertTrue(banner.refreshController.blockReasons.contains(.interstitial))
            delegate.adDidDismissFullScreenContent?(ad)
            wait(0.05)
            XCTAssertEqual(handoffs, cycle + 1)
            google.delegate?.bannerViewDidReceiveAd?(google)
        }
        XCTAssertEqual(count(.pageImpression), 0)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
    }

    func testBannerFirstLoadWaitsWhenRegisteredUnderInterstitial() throws {
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        delegate.adWillPresentFullScreenContent?(ad)
        banner.createAd(with: AdManagerRequest(), gamBanner: google)
        wait(0.05)
        XCTAssertEqual(handoffs, 0)
        XCTAssertTrue(banner.refreshController.blockReasons.contains(.interstitial))
        delegate.adDidDismissFullScreenContent?(ad)
        wait(0.05)
        XCTAssertEqual(handoffs, 1)
        XCTAssertEqual(count(.pageImpression), 0)
    }

    func testDismissalConsumesPendingForegroundDelayWithoutDoubleLoading() throws {
        loaded()
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        delegate.adWillPresentFullScreenContent?(ad)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(Audienzz.shared.hasPendingForegroundRecovery)
        delegate.adDidDismissFullScreenContent?(ad)
        wait(0.6)
        XCTAssertEqual(handoffs, 2)
        XCTAssertFalse(Audienzz.shared.hasPendingForegroundRecovery)
        XCTAssertEqual(count(.pageImpression), 0)
    }

    func testInterstitialRecoveryRetainsOffscreenAndPublisherBlocks() throws {
        loaded()
        banner.smartRefresh = true
        let (owner, ad, delegate) = try originalInterstitial()
        defer { owner.destroy() }
        delegate.adWillPresentFullScreenContent?(ad)
        banner.adUnitConfiguration.stopAutoRefresh()
        banner.frame.origin.y = 2000; banner.refreshVisibilityNow()
        delegate.adDidDismissFullScreenContent?(ad)
        wait(0.05)
        XCTAssertEqual(handoffs, 1)
        banner.frame.origin.y = 100; banner.refreshVisibilityNow()
        wait(0.05)
        XCTAssertEqual(handoffs, 1)
        banner.adUnitConfiguration.resumeAutoRefresh()
        wait(0.05)
        XCTAssertEqual(handoffs, 2)
        XCTAssertEqual(count(.pageImpression), 0)
    }

}
private final class ProbeInterstitialAd: GoogleMobileAds.InterstitialAd {
    override var adUnitID: String { "/probe/interstitial" }
}
private final class ProbeRewardedAd: GoogleMobileAds.RewardedAd {
    override var adUnitID: String { "/probe/rewarded" }
}
private final class ProbeResponseInfo: GoogleMobileAds.ResponseInfo {
    var identifier = "creative-A"
    override var responseIdentifier: String? { identifier }
}
private final class ProbeBannerAd: AdManagerBannerView {
    let info = ProbeResponseInfo()
    override var responseInfo: GoogleMobileAds.ResponseInfo? { info }
}
