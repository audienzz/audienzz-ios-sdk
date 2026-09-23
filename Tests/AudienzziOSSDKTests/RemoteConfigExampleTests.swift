import XCTest
import UIKit
import GoogleMobileAds
import ObjectiveC
@testable import AudienzziOSSDK

/// ExampleSources links the real demo controller into this target. Keeping a separate example
/// fixture with retained owners would miss the local-variable lifetime bug in the shipped demo.
@MainActor
final class RemoteConfigExampleTests: AudienzzLifecycleTestCase {
    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            let json = """
            [{"id":"46", "config":{"adType":"banner","refreshTimeSeconds":30},
              "gamConfig":{"adUnitPath":"/1234/unit","adSizes":["300x250"]},
              "prebidConfig":{"placementId":"test-placement","adSizes":["300x250"]}}]
            """
            do {
                let configs = try JSONDecoder().decode([RemoteAdConfiguration].self, from: Data(json.utf8))
                AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(configs)
            } catch { XCTFail("Invalid remote config fixture: \(error)") }
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated { AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil) }
        super.tearDown()
    }

    private func makeScreen() -> RemoteConfigViewController {
        let screen = RemoteConfigViewController()
        // Supply the storyboard outlets without loading the rest of the example application.
        // No UIWindow: lazy loading cannot issue live ad requests in these integration tests.
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scroll = UIScrollView(frame: root.bounds)
        let content = UIView(frame: root.bounds)
        root.addSubview(scroll)
        scroll.addSubview(content)
        screen.setValue(scroll, forKey: "scrollView")
        screen.setValue(content, forKey: "contentView")
        screen.view = root
        // Installing a ready-made view bypasses UIKit's loadView/viewDidLoad sequence.
        screen.viewDidLoad()
        return screen
    }

    private func banners(in view: UIView) -> [AUBannerView] {
        view.subviews.flatMap { child in
            if let banner = child as? AUBannerView { return [banner] }
            return banners(in: child)
        }
    }

    private func appear(_ screen: UIViewController) {
        screen.beginAppearanceTransition(true, animated: false)
        screen.endAppearanceTransition()
    }

    private func disappear(_ screen: UIViewController) {
        screen.beginAppearanceTransition(false, animated: false)
        screen.endAppearanceTransition()
    }

    func testAdsAreCreatedOnlyAfterTheInitialPageReport() {
        let screen = makeScreen()
        XCTAssertTrue(banners(in: screen.view).isEmpty, "viewDidLoad must only prepare the layout")
        appear(screen)
        let ads = banners(in: screen.view)
        XCTAssertEqual(ads.count, 2)
        XCTAssertTrue(AUScreenAdCoordinator.shared.activeScreenAndName?.0 === screen)
        XCTAssertTrue(ads.allSatisfy { $0.pageEpoch == AUScreenAdCoordinator.shared.epoch })
    }

    func testBothBannersStillHandOffToGoogleAfterLoadReturns() throws {
        let screen = makeScreen()
        appear(screen)
        let ads = banners(in: screen.view)
        XCTAssertEqual(ads.count, 2)

        // Intercept only Google's final network entry point. Execute the real, already-installed
        // remote banner closures after the example's load methods have returned.
        let method = try XCTUnwrap(class_getInstanceMethod(BannerView.self, #selector(BannerView.load(_:))))
        var loaded: [BannerView] = []
        let block: @convention(block) (BannerView, Request) -> Void = { banner, _ in loaded.append(banner) }
        let replacement = imp_implementationWithBlock(block)
        let original = method_setImplementation(method, replacement)
        defer {
            method_setImplementation(method, original)
            imp_removeBlock(replacement)
        }
        for ad in ads {
            let callback = try XCTUnwrap(ad.onLoadRequest)
            callback(AdManagerRequest())
        }
        XCTAssertEqual(loaded.count, 2, "local remote owners used to die before either Google handoff")
        XCTAssertEqual(Set(loaded.map(ObjectIdentifier.init)).count, 2)
    }

    func testSizeChangesDoNotAddCompetingContainerConstraints() throws {
        let screen = makeScreen()
        appear(screen)
        let ad = try XCTUnwrap(banners(in: screen.view).first)
        let container = try XCTUnwrap(ad.superview)
        let callback = try XCTUnwrap(ad.onAdSizeChanged)
        callback(CGSize(width: 300, height: 600))
        let heights = container.constraints.filter {
            $0.firstItem === container && $0.firstAttribute == .height && $0.secondItem == nil && $0.isActive
        }
        XCTAssertEqual(heights.count, 1)
        XCTAssertEqual(heights.first?.constant, 600, "the retained owner's size callback must still work")

        let google = BannerView(adSize: adSizeFor(cgSize: CGSize(width: 300, height: 600)))
        screen.bannerViewDidReceiveAd(google)
        screen.bannerViewDidReceiveAd(google)
        for banner in banners(in: screen.view) {
            let parent = try XCTUnwrap(banner.superview)
            XCTAssertEqual(parent.constraints.filter {
                $0.firstItem === parent && $0.firstAttribute == .height && $0.secondItem == nil && $0.isActive
            }.count, 1, "the delegate must not add constraints alongside the SDK's size owner")
        }
    }

    func testPushedScreenAndReturnReportTheirOwnPagesWithoutDuplicatingBanners() {
        let screen = makeScreen()
        appear(screen)
        let original = banners(in: screen.view)
        XCTAssertEqual(original.count, 2)
        let child = RemoteConfigAdScreenViewController()
        child.loadViewIfNeeded()
        XCTAssertTrue(banners(in: child.view).isEmpty)
        disappear(screen)
        appear(child)
        let childAds = banners(in: child.view)
        XCTAssertEqual(childAds.count, 1)
        XCTAssertTrue(AUScreenAdCoordinator.shared.activeScreenAndName?.0 === child)
        XCTAssertTrue(original.allSatisfy { !$0.screenActive })
        XCTAssertTrue(childAds.allSatisfy { $0.screenActive })

        disappear(child)
        appear(screen)
        XCTAssertTrue(AUScreenAdCoordinator.shared.activeScreenAndName?.0 === screen)
        XCTAssertEqual(banners(in: screen.view), original)
        XCTAssertTrue(original.allSatisfy { $0.screenActive })
        XCTAssertTrue(childAds.allSatisfy { !$0.screenActive })
    }

    func testFinishingTheScreenDestroysBothSlots() throws {
        var screen: RemoteConfigViewController? = makeScreen()
        weak var releasedScreen = screen
        appear(try XCTUnwrap(screen))
        let ads = banners(in: try XCTUnwrap(screen).view)
        XCTAssertEqual(ads.count, 2)
        XCTAssertTrue(ads.allSatisfy { !$0.refreshController.isDestroyed })
        screen = nil
        XCTAssertNil(releasedScreen, "banner ownership must not retain the screen")
        XCTAssertTrue(ads.allSatisfy { $0.refreshController.isDestroyed })
        XCTAssertTrue(ads.allSatisfy { $0.onLoadRequest == nil && $0.superview == nil })
    }
}
