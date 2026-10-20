import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

/// `placementVisible`, the fill-rate denominator: once per auction, the first time at least one
/// pixel of the slot is on screen after the auction ended with the app in the foreground. Nothing
/// for a slot that never shows; the next auction or leaving the page closes the window.
final class PlacementVisibleTests: AudienzzLifecycleTestCase {
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
        banner.setScreen("A")
        window.addSubview(banner)
        offScreen()
        google = AdManagerBannerView(adSize: AdSizeBanner); google.adUnitID = "/fixture/banner"
        banner.demand = { _, _, complete in complete(.prebidDemandNoBids) }
        banner.onLoadRequest = { [unowned self] _ in handoffs += 1 }
    }

    override func tearDown() {
        banner.destroy(); banner.removeFromSuperview()
        banner = nil; google = nil; window.isHidden = true; window = nil
        AUEventsManager.shared.observerForTesting = nil
        super.tearDown()
    }

    func wait(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    func placements() -> [AUEventDomain] { events.filter { $0.type == .placementVisible } }
    /// [points] rows of the 50pt slot inside the window.
    func onScreen(points: CGFloat = 50) {
        banner.frame = CGRect(x: 0, y: 844 - points, width: 320, height: 50)
        banner.placementTracker?.refreshVisibility()
    }
    func offScreen() {
        banner.frame = CGRect(x: 0, y: 2000, width: 320, height: 50)
        banner.placementTracker?.refreshVisibility()
    }
    func startAuction() {
        banner.createAd(with: AdManagerRequest(), gamBanner: google); wait(0.05)
        XCTAssertEqual(handoffs, 1)
    }
    func filled() { google.delegate?.bannerViewDidReceiveAd?(google) }
    func noFill() {
        google.delegate?.bannerView?(google, didFailToReceiveAdWithError:
            NSError(domain: GADErrorDomain, code: RequestError.noFill.rawValue))
    }

    func testSentOnceWithTheAuctionOfItsImpression() throws {
        startAuction(); filled(); google.delegate?.bannerViewDidRecordImpression?(google)
        XCTAssertTrue(placements().isEmpty)
        onScreen(); offScreen(); onScreen(); wait(0.5)
        let placement = try XCTUnwrap(placements().first)
        XCTAssertEqual(placements().count, 1)
        let impression = try XCTUnwrap(events.first { $0.type == .adImpression })
        XCTAssertNotNil(placement.auctionId)
        XCTAssertEqual(placement.auctionId, impression.auctionId)
        XCTAssertEqual(placement.slotReload, 0)
        XCTAssertEqual(placement.adViewId, "fixture")
        XCTAssertEqual(placement.adUnitId, "/fixture/banner")
    }

    func testOnePointIsEnoughAndSentMeansDone() {
        startAuction(); filled()
        XCTAssertNotNil(banner.placementTracker)
        onScreen(points: 1)
        XCTAssertEqual(placements().count, 1)
        XCTAssertNil(banner.placementTracker)
    }

    func testVisibleBeforeTheAuctionEndsWaitsForItsEnd() {
        onScreen(); startAuction(); wait(0.3)
        XCTAssertTrue(placements().isEmpty)
        filled()
        XCTAssertEqual(placements().count, 1)
    }

    func testANoFillThatShowsIsSentToo() {
        startAuction(); noFill()
        onScreen()
        XCTAssertEqual(placements().count, 1)
    }

    func testASlotThatNeverShowsSendsNothingAndRefreshClosesItsAuction() throws {
        startAuction(); filled(); wait(0.3)
        let first = try XCTUnwrap(events.first { $0.type == .bidRequest }?.auctionId)
        banner.reloadAd(); wait(0.1); XCTAssertEqual(handoffs, 2)
        onScreen(); wait(0.3)
        // The first auction was never seen; the refresh's own auction has not ended yet.
        XCTAssertTrue(placements().isEmpty)
        filled()
        let placement = try XCTUnwrap(placements().first)
        XCTAssertEqual(placements().count, 1)
        XCTAssertNotEqual(placement.auctionId, first)
        XCTAssertEqual(placement.slotReload, 1)
    }

    func testLeavingThePageClosesTheAuction() {
        startAuction(); filled()
        XCTAssertNotNil(banner.placementTracker)
        Audienzz.shared.pageImpression("B")
        XCTAssertNil(banner.placementTracker)
        onScreen(); wait(0.3)
        XCTAssertTrue(placements().isEmpty)
    }

    func testWaitsForTheForeground() {
        startAuction(); filled()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(Audienzz.shared.isAppBackgrounded)
        onScreen(); wait(0.3)
        XCTAssertTrue(placements().isEmpty)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(placements().count, 1)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(0.3)
        XCTAssertEqual(placements().count, 1)
    }

    func testDestroyClosesTheAuction() {
        startAuction(); filled()
        XCTAssertNotNil(banner.placementTracker)
        banner.destroy()
        XCTAssertNil(banner.placementTracker)
        onScreen(); wait(0.3)
        XCTAssertTrue(placements().isEmpty)
    }
}
