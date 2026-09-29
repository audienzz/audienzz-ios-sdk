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

    func testHostCoverInterruptsExposureButReturningCanEarnSuccess() {
        loaded(); impression()
        XCTAssertEqual(count(.viewabilityStart), 1)
        banner.pauseSmartRefresh(); wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        banner.resumeSmartRefresh(); wait(0.2)
        XCTAssertEqual(count(.viewabilityStart), 2)
        XCTAssertEqual(count(.viewabilitySuccess), 0)
        wait(1.0)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        banner.pauseSmartRefresh(); banner.resumeSmartRefresh(); wait(1.2)
        XCTAssertEqual(count(.viewabilitySuccess), 1)
        XCTAssertEqual(count(.viewabilityStart), 2)
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
