import XCTest
import UIKit
@testable import AudienzziOSSDK

/// Lazy loading and the prefetch margin of a remote-config banner are backend-driven only: the ad
/// config's `lazyLoad` and `prefetchDistanceDp`, else the SDK defaults. There is no publisher
/// override, so one placement behaves the same in every app and on every platform.
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
      "config": { "adType": "banner", "refreshTimeSeconds": 30, "lazyLoad": true, "prefetchDistanceDp": 600 },
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

    // MARK: - The resolved values reach the banner

    func testTheAdConfigSettingsAreAppliedToTheBannerThatIsBuilt() {
        let view = AURemoteConfigBannerView(adConfigId: "configured-lazy")
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)

        let built = banner()
        XCTAssertNotNil(built, "a banner should have been built")
        XCTAssertTrue(built?.isLazyLoad == true, "the ad config asked for lazy loading")
        XCTAssertEqual(built?.prefetchMarginPoints, 600)
    }

    func testAnUnconfiguredPlacementBuildsALazyBanner() {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)
        XCTAssertTrue(banner()?.isLazyLoad ?? false,
                      "with nothing configured the banner must wait for the viewport")
    }

    func testAnAdConfigCanStillChooseEagerLoading() {
        let view = AURemoteConfigBannerView(adConfigId: "configured-eager")
        view.load(in: container, size: CGSize(width: 320, height: 50), rootViewController: host)
        XCTAssertFalse(banner()?.isLazyLoad ?? true,
                       "a placement must be switchable to eager from the backend alone")
    }

    // MARK: - A changed setting is not coalesced away

    func testARefreshedAdConfigThatChangesASettingReplacesTheBanner() throws {
        let view = AURemoteConfigBannerView(adConfigId: "unconfigured")
        let size = CGSize(width: 320, height: 50)
        view.load(in: container, size: size, rootViewController: host)
        let first = banner()
        XCTAssertEqual(first?.isLazyLoad, true)

        // Same container, same size — identical in every respect except the backend's setting.
        let refreshed = try JSONDecoder().decode([RemoteAdConfiguration].self, from: Data("""
        [{"id": "unconfigured",
          "config": { "adType": "banner", "refreshTimeSeconds": 30, "lazyLoad": false },
          "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["320x50"] },
          "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }}]
        """.utf8))
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(refreshed)
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

    // MARK: - The backend payload

    private static func decodeConfig(_ config: String) throws -> RemoteAdConfiguration {
        let json = """
        {"id": "x", "config": \(config),
         "gamConfig": {"adUnitPath": "/1234/unit", "adSizes": ["320x50"]},
         "prebidConfig": {"placementId": "placement", "adSizes": ["320x50"]}}
        """
        return try JSONDecoder().decode(RemoteAdConfiguration.self, from: Data(json.utf8))
    }

    /// The backend sends one key for every platform. Android, Flutter and React Native read
    /// `prefetchDistanceDp`; iOS read `prefetchDistancePt`, so a margin set in the backend
    /// silently never reached iOS.
    func testDeliverySettingsDecodeFromTheKeysEveryPlatformReads() throws {
        let decoded = try Self.decodeConfig(
            #"{"adType": "banner", "lazyLoad": false, "prefetchDistanceDp": 50}"#)
        XCTAssertEqual(decoded.config.prefetchDistancePt, 50)
        XCTAssertEqual(decoded.config.lazyLoad, false)
    }

    func testTheOldIosOnlyKeyIsNotRead() throws {
        let decoded = try Self.decodeConfig(#"{"adType": "banner", "prefetchDistancePt": 50}"#)
        XCTAssertNil(decoded.config.prefetchDistancePt,
                     "one backend key for all platforms, not a second iOS-only one")
    }

    /// The 24h cache re-encodes the decoded struct; the margin must survive the round trip.
    func testTheMarginSurvivesTheLocalCache() throws {
        let decoded = try Self.decodeConfig(
            #"{"adType": "banner", "lazyLoad": true, "prefetchDistanceDp": 50}"#)
        let cached = try JSONDecoder().decode(RemoteAdConfiguration.self,
                                              from: JSONEncoder().encode(decoded))
        XCTAssertEqual(cached.config.prefetchDistancePt, 50)
        XCTAssertEqual(cached.config.lazyLoad, true)
    }
}
