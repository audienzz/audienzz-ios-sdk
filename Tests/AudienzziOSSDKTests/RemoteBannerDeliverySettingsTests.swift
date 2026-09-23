import XCTest
import UIKit
@testable import AudienzziOSSDK

/// Lazy loading and the prefetch margin are delivery decisions a publisher has to be able to make.
///
/// `AURemoteConfigBannerView` used to hardcode `isLazyLoad: true` and read the margin only from the
/// ad config, so a publisher whose slot auctioned too late had no lever at all — the inner banner is
/// private and the inherited `prefetchMarginPoints` is not exposed to Objective-C, so neither the
/// app nor a bridge could reach either value.
@MainActor
final class RemoteBannerDeliverySettingsTests: AudienzzLifecycleTestCase {

    private var container: UIView!
    private var host: UIViewController!

    /// `unconfigured` deliberately omits both keys, so it exercises the SDK defaults.
    private static let configJSON = """
    [{
      "id": "unconfigured",
      "config": { "adType": "banner", "refreshTimeSeconds": 30 },
      "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["320x50"] },
      "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }
    },
    {
      "id": "configured-eager",
      "config": { "adType": "banner", "refreshTimeSeconds": 30, "lazyLoad": false },
      "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["320x50"] },
      "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }
    },
    {
      "id": "configured-lazy",
      "config": { "adType": "banner", "refreshTimeSeconds": 30, "lazyLoad": true, "prefetchDistancePt": 600 },
      "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["320x50"] },
      "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }
    }]
    """

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            do {
                let configs = try JSONDecoder().decode([RemoteAdConfiguration].self,
                                                       from: Data(Self.configJSON.utf8))
                AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(configs)
            } catch {
                XCTFail("fixture does not decode: \(error)")
            }
            host = UIViewController()
            container = UIView()
            host.view.addSubview(container)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.isHidden = false
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil)
        }
        super.tearDown()
    }

    private func config(_ id: String) -> RemoteAdConfiguration {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: id) else {
            fatalError("fixture \(id) missing")
        }
        return config
    }

    private func banner() -> AUBannerView? {
        container.subviews.compactMap { $0 as? AUBannerView }.first
    }

    // MARK: - Resolution precedence

    func testAnAdConfigThatSaysNothingGetsTheSdkDefaults() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        XCTAssertTrue(view.resolvedLazyLoad(for: config("unconfigured")),
                      "remote-config banners wait for the viewport unless something asks otherwise")
        XCTAssertEqual(view.resolvedPrefetchMarginPoints(for: config("unconfigured")), 200)
    }

    func testTheAdConfigOverridesTheSdkDefaults() {
        let view = AURemoteConfigBannerView(adConfigId: "configured-lazy")
        XCTAssertTrue(view.resolvedLazyLoad(for: config("configured-lazy")))
        XCTAssertEqual(view.resolvedPrefetchMarginPoints(for: config("configured-lazy")), 600)
    }

    func testThePublisherOverridesTheAdConfig() {
        let view = AURemoteConfigBannerView(adConfigId: "configured-lazy")
        view.lazyLoadOverride = false
        view.prefetchMarginPointsOverride = 900
        XCTAssertFalse(view.resolvedLazyLoad(for: config("configured-lazy")))
        XCTAssertEqual(view.resolvedPrefetchMarginPoints(for: config("configured-lazy")), 900)
    }

    func testClearingAnOverrideRestoresTheAdConfigValue() {
        let view = AURemoteConfigBannerView(adConfigId: "configured-lazy")
        view.setLazyLoadOverride(false)
        view.setPrefetchMarginPointsOverride(900)
        view.clearLazyLoadOverride()
        view.clearPrefetchMarginPointsOverride()
        XCTAssertTrue(view.resolvedLazyLoad(for: config("configured-lazy")))
        XCTAssertEqual(view.resolvedPrefetchMarginPoints(for: config("configured-lazy")), 600)
    }

    // MARK: - The resolved values reach the banner

    func testTheResolvedSettingsAreAppliedToTheBannerThatIsBuilt() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        view.lazyLoadOverride = true
        view.prefetchMarginPointsOverride = 750
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)

        let built = banner()
        XCTAssertNotNil(built, "a banner should have been built")
        XCTAssertTrue(built?.isLazyLoad == true, "the publisher asked for lazy loading")
        XCTAssertEqual(built?.prefetchMarginPoints, 750)
    }

    func testAnUnconfiguredPlacementBuildsALazyBanner() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)
        XCTAssertTrue(banner()?.isLazyLoad ?? false,
                      "with nothing configured the banner must wait for the viewport")
    }

    func testAPublisherCanStillChooseEagerLoading() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        view.lazyLoadOverride = false
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)
        XCTAssertFalse(banner()?.isLazyLoad ?? true,
                       "eager loading must remain reachable as an explicit choice")
    }

    func testAnAdConfigCanStillChooseEagerLoading() {
        let view = AURemoteConfigBannerView(adConfigId: "configured-eager")
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)
        XCTAssertFalse(banner()?.isLazyLoad ?? true,
                       "a placement must be switchable to eager from the backend alone")
    }

    // MARK: - Changing a setting is not coalesced away

    func testChangingAnOverrideAndReloadingReplacesTheBanner() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        let size = CGSize(width: 320, height: 50)
        view.load(in: container, size: size, rootViewController: host)
        let first = banner()
        XCTAssertEqual(first?.isLazyLoad, true)

        // Same container, same size — identical in every respect except the delivery setting.
        view.lazyLoadOverride = false
        view.load(in: container, size: size, rootViewController: host)

        let second = banner()
        XCTAssertNotNil(second)
        XCTAssertFalse(second === first, "the load must not be coalesced into the old banner")
        XCTAssertEqual(second?.isLazyLoad, false)
        XCTAssertEqual(container.subviews.compactMap { $0 as? AUBannerView }.count, 1,
                       "the predecessor must be retired, not left alongside")
    }

    func testAnIdenticalReloadIsStillCoalesced() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        let size = CGSize(width: 320, height: 50)
        view.load(in: container, size: size, rootViewController: host)
        let first = banner()
        view.load(in: container, size: size, rootViewController: host)
        XCTAssertTrue(banner() === first, "nothing changed, so the banner must be reused")
    }
}
