import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

/// The iOS half of the lifecycle matrix the managed integration rests on.
///
/// The first-load prefetch exemption exists so a banner can auction before it is attached or
/// visible. It must never mean "ignore every block": background, inactive page, destroyed and
/// publisher-stop are not geometry. Existing tests cover the publisher and foreground cases; these
/// cover the rest.
final class LifecycleGuaranteeTests: AudienzzLifecycleTestCase {
    private var view: AUBannerView!
    private var loads = 0

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    override func setUp() {
        super.setUp()
        loads = 0
        Audienzz.shared.pageImpression("A")
        // An invalid config yields an immediate Prebid completion with no live ad request.
        view = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                            adFormats: [.banner], isLazyLoad: false)
        view.setScreen("A")
        view.onLoadRequest = { [weak self] _ in
            self?.loads += 1
            self?.view.notifyAdLoadCompleted(rendered: true)
        }
    }

    override func tearDown() {
        view?.destroy()
        super.tearDown()
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testAnInactivePageBlocksTheFirstLoad() {
        Audienzz.shared.pageImpression("B")
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        settle(0.2)
        XCTAssertEqual(loads, 0, "a prefetch exemption is geometry, not page ownership")
    }

    func testReturningToThePageRecoversTheBlockedFirstLoad() {
        Audienzz.shared.pageImpression("B")
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        XCTAssertEqual(loads, 0)

        Audienzz.shared.pageImpression("A")
        settle(0.2)
        XCTAssertEqual(loads, 1, "and the slot is not stranded once its page comes back")
    }

    func testADestroyedBannerBlocksTheFirstLoad() {
        view.destroy()
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        settle(0.2)
        XCTAssertEqual(loads, 0)
    }

    func testStayingBackgroundedAcrossRefreshIntervalsBuysNothing() {
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        // The first load is asynchronous; assert it actually ran before claiming anything about
        // what follows, or "no periodic auction" would pass on a banner that never loaded at all.
        settle(0.3)
        XCTAssertEqual(loads, 1, "control: the first load ran")

        post(UIApplication.didEnterBackgroundNotification)
        settle(31.0)
        XCTAssertEqual(loads, 1, "no periodic auction while backgrounded")
    }

    func testBackgroundingBeforeTheFirstLoadStopsTheAuctionEntirely() {
        post(UIApplication.didEnterBackgroundNotification)
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        settle(0.2)
        XCTAssertEqual(loads, 0)
    }

    func testAPublisherStopBlocksTheFirstLoad() {
        // The publisher block is the one lifecycle reason the explicit guards at the top of
        // canStartAuction do NOT cover, so this is what holds the first-load exemption narrow.
        view.adUnitConfiguration.stopAutoRefresh()
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        settle(0.3)
        XCTAssertEqual(loads, 0, "a prefetch exemption is geometry, not a publisher override")
        XCTAssertTrue(view.refreshController.blockReasons.contains(.publisher))
    }

    func testAPublisherStopSurvivesAPageActivation() {
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        settle(0.3)
        XCTAssertEqual(loads, 1, "control")
        view.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)
        view.adUnitConfiguration.stopAutoRefresh()

        Audienzz.shared.pageImpression("A")
        settle(0.5)

        XCTAssertEqual(loads, 1, "activating a page must not clear a publisher stop")
    }
}
