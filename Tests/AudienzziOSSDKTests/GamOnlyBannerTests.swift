import XCTest
import UIKit
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

/// A placement sold through GAM alone has no Prebid sizes.
///
/// The remote banner used to build its ad unit with `.zero` in that case, which did not skip header
/// bidding: stock Prebid only rejects negative sizes, so every auction still sent a Prebid request
/// that could never be filled, and reported a bidRequest and a noBid for it.
final class GamOnlyBannerTests: AudienzzLifecycleTestCase {

    private var window: UIWindow!
    private var banner: AUBannerView!
    private var demandCalls = 0
    private var loads = 0
    private var events: [AUAnalyticsEventType] = []

    private static let headerBiddingEvents: Set<AUAnalyticsEventType> = [.bidRequest, .bidResponse, .bidWon, .noBid]

    override func setUp() {
        super.setUp()
        demandCalls = 0
        loads = 0
        events = []
        AUEventsManager.shared.observerForTesting = { [weak self] in self?.events.append($0.type) }
        Audienzz.shared.pageImpression("article")
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
    }

    override func tearDown() {
        AUEventsManager.shared.observerForTesting = nil
        banner?.destroy()
        banner = nil
        window = nil
        super.tearDown()
    }

    private func makeBanner(headerBidding: Bool) {
        banner = AUBannerView(configId: "placement", adSize: CGSize(width: 320, height: 50),
                              adFormats: [.banner], isLazyLoad: false)
        banner.headerBiddingEnabled = headerBidding
        banner.hostScreenOverride = "article" as NSString
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        banner.demand = { [weak self] _, _, reply in
            self?.demandCalls += 1
            reply(.prebidDemandNoBids)
        }
        banner.onLoadRequest = { [weak self] _ in self?.loads += 1 }
        let gam = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        // Analytics name the slot by the GAM view's ad unit; without one nothing is reported at all.
        gam.adUnitID = "/1234/unit"
        banner.createAd(with: AdManagerRequest(), gamBanner: gam,
                        eventHandler: AUBannerEventHandler(adUnitId: "/1234/unit", gamView: gam))
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    func testHeaderBiddingOffNeverReachesPrebid() {
        makeBanner(headerBidding: false)
        XCTAssertEqual(demandCalls, 0, "a GAM-only auction must not ask Prebid for anything")
        XCTAssertEqual(loads, 1, "GAM must still be loaded")
    }

    func testGamOnlyReloadsOnTheNextPageImpressionWithoutPrebid() {
        makeBanner(headerBidding: false)
        banner.notifyAdLoadCompleted(rendered: true)
        Audienzz.shared.pageImpression("article")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(loads, 2, "page ownership still drives GAM-only slots")
        XCTAssertEqual(demandCalls, 0)
        XCTAssertEqual(banner.emittedSlotReload, 1, "the second GAM-only load is a reload")
    }

    func testGamOnlyReportsNoHeaderBiddingEvents() {
        makeBanner(headerBidding: false)
        XCTAssertTrue(Self.headerBiddingEvents.isDisjoint(with: events),
                      "no bid was asked for, so none may be reported: \(events)")
    }

    /// Control: the same banner with header bidding on asks Prebid and reports the auction, so the
    /// assertions above are not passing merely because nothing is observed.
    func testHeaderBiddingOnAsksPrebidAndReportsTheAuction() {
        makeBanner(headerBidding: true)
        XCTAssertEqual(demandCalls, 1)
        XCTAssertEqual(loads, 1)
        XCTAssertTrue(events.contains(.bidRequest), "\(events)")
        XCTAssertTrue(events.contains(.noBid), "\(events)")
    }
}

/// The remote-config owner is what decides a placement is GAM-only.
@MainActor
final class RemoteBannerGamOnlyTests: AudienzzLifecycleTestCase {

    private var container: UIView!
    private var host: UIViewController!
    private var window: UIWindow!

    private static let configJSON = """
    [{
      "id": "gam-only",
      "config": { "adType": "banner", "refreshTimeSeconds": 30 },
      "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["300x250", "320x50"] },
      "prebidConfig": { "placementId": "placement", "adSizes": [] }
    },
    {
      "id": "header-bid",
      "config": { "adType": "banner", "refreshTimeSeconds": 30 },
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
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.isHidden = false
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil)
            window = nil
        }
        super.tearDown()
    }

    private func load(_ id: String) -> AUBannerView? {
        let view = AURemoteConfigBannerView(adConfigId: id)
        view.load(in: container, size: nil, rootViewController: host)
        return container.subviews.compactMap { $0 as? AUBannerView }.first
    }

    func testNoPrebidSizesServesGamOnly() throws {
        let built = try XCTUnwrap(load("gam-only"), "a GAM-only placement must still be built")
        XCTAssertFalse(built.headerBiddingEnabled)
        XCTAssertEqual(built.adSize, CGSize(width: 300, height: 250),
                       "the ad unit takes GAM's primary size rather than .zero")
        built.destroy()
    }

    func testPrebidSizesKeepHeaderBidding() throws {
        let built = try XCTUnwrap(load("header-bid"))
        XCTAssertTrue(built.headerBiddingEnabled)
        built.destroy()
    }
}
