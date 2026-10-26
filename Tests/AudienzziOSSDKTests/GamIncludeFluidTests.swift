import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

/// `gamConfig.includeFluid` adds GAM's fluid size next to the slot's fixed sizes (e.g. for fluid
/// GAM native styles); Prebid keeps bidding on its fixed sizes only.
@MainActor
final class GamIncludeFluidTests: AudienzzLifecycleTestCase {
    private var owner: AURemoteConfigBannerView!
    private var window: UIWindow!
    private var container: UIView!
    private var banner: AUBannerView!
    private var google: AdManagerBannerView!
    private var handler: AUBannerHandler!

    private func config(includeFluid: String?, prebidSizes: String = "\"300x250\"") throws
        -> RemoteAdConfiguration {
        let field = includeFluid.map { ",\"includeFluid\":\($0)" } ?? ""
        return try JSONDecoder().decode(RemoteAdConfiguration.self, from: Data("""
        {"id":"fluid", "config":{"adType":"banner","lazyLoad":true},
         "gamConfig":{"adUnitPath":"/test/fluid","adSizes":["300x250","320x50"]\(field)},
         "prebidConfig":{"placementId":"p","adSizes":[\(prebidSizes)]}}
        """.utf8))
    }

    private func loadSlot(includeFluid: String?, prebidSizes: String = "\"300x250\"") throws {
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(
            [try config(includeFluid: includeFluid, prebidSizes: prebidSizes)]
        )
        let host = UIViewController()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        // The host owns the slot's width, as the RN bridge and native callers do.
        container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            container.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 100),
        ])
        Audienzz.shared.pageImpression(host)
        owner = AURemoteConfigBannerView(adConfigId: "fluid")
        let requested = expectation(description: "visible lazy banner reaches Google")
        owner.loadGoogle = { [unowned self] view, _ in
            google = view
            requested.fulfill()
        }
        owner.load(in: container, rootViewController: host)
        banner = try XCTUnwrap(container.subviews.compactMap { $0 as? AUBannerView }.first)
        host.view.layoutIfNeeded()
        banner.refreshVisibilityNow()
        wait(for: [requested], timeout: 2)
        handler = try XCTUnwrap(banner.eventHandler)
    }

    override func setUp() {
        super.setUp()
        // Exercise the real ad config value, not the temporary mock.
        MainActor.assumeIsolated { AURemoteConfigBannerView.mockIncludeFluid = false }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            owner?.destroy()
            window?.isHidden = true
            owner = nil; window = nil; container = nil; banner = nil; google = nil; handler = nil
            AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil)
            AURemoteConfigBannerView.mockIncludeFluid = true
        }
        super.tearDown()
    }

    private func requestsFluid() -> Bool {
        (google.validAdSizes ?? []).contains { isAdSizeFluid(size: adSizeFor(nsValue: $0)) }
    }

    // MARK: - Config parsing

    func testAbsentIsOff() throws {
        XCTAssertFalse(try config(includeFluid: nil).gamConfig.includeFluid)
    }

    func testTrueIsOn() throws {
        XCTAssertTrue(try config(includeFluid: "true").gamConfig.includeFluid)
    }

    func testMalformedValuesAreOffAndTheConfigStillDecodes() throws {
        for raw in ["false", "\"true\"", "1", "null", "{}", "[]"] {
            let decoded = try config(includeFluid: raw)
            XCTAssertFalse(decoded.gamConfig.includeFluid, raw)
            XCTAssertEqual(decoded.gamConfig.adUnitPath, "/test/fluid", raw)
        }
    }

    func testTheCachedCopyKeepsTheFlag() throws {
        let original = try config(includeFluid: "true")
        let cached = try JSONDecoder().decode(
            RemoteAdConfiguration.self, from: try JSONEncoder().encode(original)
        )
        XCTAssertTrue(cached.gamConfig.includeFluid)
    }

    // MARK: - GAM request and layout

    func testOffRequestsOnlyTheFixedSizesAndKeepsTheCreativeWidth() throws {
        try loadSlot(includeFluid: nil)
        XCTAssertFalse(requestsFluid())
        XCTAssertEqual(google.validAdSizes?.count, 2)
        XCTAssertEqual(banner.bounds.width, 300)
    }

    func testOnAddsFluidAfterTheFixedSizesAndSpansTheContainer() throws {
        try loadSlot(includeFluid: "true")
        XCTAssertTrue(requestsFluid())
        XCTAssertEqual(google.validAdSizes?.count, 3, "the two fixed sizes stay")
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.width, 390, "a fluid ad takes the slot's full width")
        XCTAssertEqual(google.frame.width, 390, "Google's view spans the slot")
    }

    func testOnPrebidKeepsItsFixedSize() throws {
        try loadSlot(includeFluid: "true")
        XCTAssertEqual(banner.adSize, CGSize(width: 300, height: 250))
    }

    func testOnAGamOnlySlotAlsoRequestsFluid() throws {
        try loadSlot(includeFluid: "true", prebidSizes: "")
        XCTAssertTrue(requestsFluid())
    }

    func testFluidCreativeHeightReachesTheSlotWithoutNarrowingIt() throws {
        try loadSlot(includeFluid: "true")
        // A fluid size carries the creative's height; its width need not be set.
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 0, height: 410)))
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 410)
        XCTAssertEqual(banner.bounds.width, 390)
        XCTAssertEqual(google.frame.width, 390)
    }

    func testFixedCreativeInAFluidSlotKeepsTheFullWidth() throws {
        try loadSlot(includeFluid: "true")
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 50)))
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 50)
        XCTAssertEqual(banner.bounds.width, 390, "Google centers a fixed creative in the fluid container")
    }

    func testTemporaryMockRequestsFluidWhenTheConfigOmitsIt() throws {
        AURemoteConfigBannerView.mockIncludeFluid = true
        try loadSlot(includeFluid: nil)
        XCTAssertTrue(requestsFluid())
    }
}
