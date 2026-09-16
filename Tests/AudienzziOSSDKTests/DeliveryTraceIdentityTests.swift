import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

/// Whether one delivery can be followed from request to impression.
///
/// The counter used before collided between two banners on the same placement, restarted whenever
/// a slot was replaced, and was read live — so an impression of the creative still on screen was
/// labelled with whatever auction happened to be running at the time.
@MainActor
final class DeliveryTraceIdentityTests: AudienzzLifecycleTestCase {

    private func spin(_ seconds: TimeInterval = 0.3) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func makeBanner(in window: UIWindow) -> AUBannerView {
        let banner = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        return banner
    }

    func testTwoBannersOnOnePlacementHaveDistinctIdentities() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let first = makeBanner(in: window)
        let second = makeBanner(in: window)
        XCTAssertNotEqual(first.traceSlotId, second.traceSlotId,
                          "two slots serving one placement must be distinguishable")
    }

    func testEachAuctionGetsItsOwnDeliveryIdentity() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = makeBanner(in: window)
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        spin()
        guard let first = banner.pendingDeliveryId else { return XCTFail("no delivery started") }
        // The Google load has to terminate before a replacement is admitted.
        banner.notifyAdLoadCompleted()

        banner.reloadAd()
        spin()

        XCTAssertNotEqual(banner.pendingDeliveryId, first,
                          "a refresh is a new delivery, not a repeat of the same id")
        XCTAssertTrue(banner.pendingDeliveryId?.hasPrefix(banner.traceSlotId) == true,
                      "and it still names the slot it belongs to")
    }

    func testTheRenderedCreativeKeepsItsIdentityWhileTheNextAuctionRuns() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = makeBanner(in: window)
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        spin()
        // The Google load for the first delivery terminates: that creative is now on screen.
        banner.notifyAdLoadCompleted()
        let rendered = banner.renderedDeliveryId
        XCTAssertNotNil(rendered)

        // A refresh starts. The old creative is still displayed, so its impression belongs to it.
        banner.reloadAd()
        spin()

        XCTAssertNotEqual(banner.pendingDeliveryId, rendered, "control — a new delivery is in flight")
        XCTAssertEqual(banner.renderedDeliveryId, rendered,
                       "the displayed creative's identity must not follow the running auction")
    }

    func testAFailedReplacementDoesNotBecomeTheRenderedDelivery() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = makeBanner(in: window)
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        spin()
        banner.notifyAdLoadCompleted()                 // creative A is on screen
        let creativeA = banner.renderedDeliveryId
        XCTAssertNotNil(creativeA)

        banner.reloadAd()                              // delivery B starts
        spin()
        XCTAssertNotEqual(banner.pendingDeliveryId, creativeA)
        banner.notifyAdLoadCompleted(retryableFailure: true)   // Google errors; B never loads

        XCTAssertEqual(banner.renderedDeliveryId, creativeA,
                       "creative A is still displayed, so its impression belongs to A — not to a "
                        + "replacement that never arrived")
    }
}
