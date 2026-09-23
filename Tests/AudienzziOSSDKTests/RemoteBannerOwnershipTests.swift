import XCTest
import UIKit
@testable import AudienzziOSSDK

/// One placement must be served by one banner.
///
/// `AURemoteConfigBannerView` held its banner weakly, so the only thing keeping one alive was the
/// container's subview list — a second `load(in:)` simply added another. Both stayed registered
/// with the page coordinator and both kept their own interval running, so a single slot issued two
/// streams of requests while only the newest could be seen.
@MainActor
final class RemoteBannerOwnershipTests: AudienzzLifecycleTestCase {

    private let configId = "remote-banner"
    private var container: UIView!
    private var host: UIViewController!

    private static let configJSON = """
    [{
      "id": "remote-banner",
      "config": { "adType": "banner", "refreshTimeSeconds": 30, "prefetchDistanceDp": 200 },
      "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["320x50"] },
      "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }
    },
    {
      "id": "adaptive-banner",
      "config": { "adType": "banner", "refreshTimeSeconds": 30, "prefetchDistanceDp": 200 },
      "gamConfig": {
        "adUnitPath": "/1234/adaptive",
        "adSizes": ["320x50"],
        "adaptiveBannerConfig": { "enabled": true, "widthStrategy": "FULL_WIDTH" }
      },
      "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }
    }]
    """

    private func seedConfig(_ present: Bool) {
        var configs: [RemoteAdConfiguration]?
        if present {
            do {
                configs = try JSONDecoder().decode([RemoteAdConfiguration].self,
                                                   from: Data(Self.configJSON.utf8))
            } catch {
                XCTFail("fixture does not decode: \(error)")
            }
        }
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(configs)
    }

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            seedConfig(true)
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

    private func banners() -> [AUBannerView] {
        container.subviews.compactMap { $0 as? AUBannerView }
    }

    private func makeView() -> AURemoteConfigBannerView {
        AURemoteConfigBannerView(adConfigId: configId)
    }

    private func load(_ view: AURemoteConfigBannerView, size: CGSize? = nil) {
        view.load(in: container, size: size, rootViewController: host, delegate: nil)
    }

    // MARK: - After loading

    func testRepeatedIdenticalLoadsServeOnePlacementWithOneBanner() {
        let view = makeView()
        load(view)
        load(view)
        load(view)
        XCTAssertEqual(banners().count, 1,
                       "three identical load(in:) calls must leave one live banner, not three")
    }

    func testAReplacementRetiresTheBannerItReplaces() {
        let view = makeView()
        load(view, size: CGSize(width: 320, height: 50))
        guard let first = banners().first else { return XCTFail("no banner built") }

        // A different requested size is a genuinely different load, not a repeat.
        load(view, size: CGSize(width: 300, height: 250))

        XCTAssertEqual(banners().count, 1, "the replaced banner must not stay in the container")
        XCTAssertFalse(banners().contains(first), "the container must hold the replacement")
        XCTAssertTrue(first.refreshController.isDestroyed,
                      "a retired banner must stop its own refresh, not just leave the view tree")
    }

    func testARetiredBannerCannotDriveTheCurrentSlot() {
        let view = makeView()
        load(view)
        guard let first = banners().first else { return XCTFail("no banner built") }

        load(view, size: CGSize(width: 300, height: 250))

        XCTAssertNil(first.onLoadRequest,
                     "a retired banner's demand callback must not reach the current GAM view")
        XCTAssertNil(first.onAdSizeChanged,
                     "a retired banner must not resize the container it no longer owns")
    }

    // MARK: - While config is pending

    func testRepeatedLoadsBeforeConfigArrivesDoNotAccumulate() {
        seedConfig(false)
        let view = makeView()
        load(view)
        load(view)
        XCTAssertEqual(banners().count, 0, "no config means no banner")

        seedConfig(true)
        load(view)
        XCTAssertEqual(banners().count, 1,
                       "the first load after config arrives builds exactly one banner")
    }

    // MARK: - After disposal

    func testDestroyReleasesTheBannerAndLoadingAgainWorks() {
        let view = makeView()
        load(view)
        guard let first = banners().first else { return XCTFail("no banner built") }

        view.destroy()
        XCTAssertEqual(banners().count, 0)
        XCTAssertTrue(first.refreshController.isDestroyed)

        load(view)
        XCTAssertEqual(banners().count, 1, "the placement is reusable after disposal")
    }

    func testDestroyIsIdempotentAndSafeBeforeAnyLoad() {
        let view = makeView()
        view.destroy()
        view.destroy()
        load(view)
        view.destroy()
        view.destroy()
        XCTAssertEqual(banners().count, 0)
    }

    // MARK: - The banner we are holding may stop being usable

    func testLoadingAgainAfterThePublisherClearedTheContainerRebuildsTheBanner() {
        let view = makeView()
        load(view)
        XCTAssertEqual(banners().count, 1)

        // A publisher clearing the slot detaches and destroys our banner without telling us.
        container.subviews.forEach { $0.removeFromSuperview() }

        load(view)

        XCTAssertEqual(banners().count, 1,
                       "coalescing against a banner that is no longer in the container left the "
                        + "slot permanently empty")
    }

    func testARepeatAfterDestroyRebuildsRatherThanCoalescing() {
        let view = makeView()
        load(view)
        view.destroy()
        load(view)
        XCTAssertEqual(banners().count, 1)
    }

    // MARK: - Adaptive sizing

    func testAWiderContainerIsANewLoadNotARepeat() {
        // An adaptive banner derives its size from the container, so the caller passing nil twice
        // is not the same request twice. Keying on the requested size treated it as a repeat and
        // left the banner pinned to the width it was first built for.
        let view = AURemoteConfigBannerView(adConfigId: "adaptive-banner")
        container.frame = CGRect(x: 0, y: 0, width: 500, height: 250)
        view.load(in: container, size: nil, rootViewController: host, delegate: nil)
        guard let first = banners().first else { return XCTFail("no banner built") }

        container.frame = CGRect(x: 0, y: 0, width: 700, height: 250)
        view.load(in: container, size: nil, rootViewController: host, delegate: nil)

        XCTAssertEqual(banners().count, 1)
        XCTAssertFalse(banners().contains(first),
                       "a container that resized must not keep the banner built for the old width")
    }

    // MARK: - The publisher's own container

    func testRetirementLeavesUnrelatedContainerChildrenAlone() {
        let publisherLabel = UILabel()
        container.addSubview(publisherLabel)
        let pinned = publisherLabel.heightAnchor.constraint(equalToConstant: 12)
        pinned.isActive = true

        let view = makeView()
        load(view)
        view.destroy()

        XCTAssertTrue(container.subviews.contains(publisherLabel),
                      "only our own banner may be removed from a container we do not own")
        XCTAssertTrue(pinned.isActive,
                      "only constraints we created may be deactivated")
    }
}
