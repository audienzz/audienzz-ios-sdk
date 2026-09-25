import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

@MainActor
final class AdaptiveBannerSizeDeliveryTests: AudienzzLifecycleTestCase {
    private final class SizeObserver: NSObject, BannerViewDelegate, AdSizeDelegate {
        var sizes: [CGSize] = []
        var loads = 0
        func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) { sizes.append(size.size) }
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { loads += 1 }
    }
    private var observer: SizeObserver!
    private var owner: AURemoteConfigBannerView!
    private var window: UIWindow!
    private var container: UIView!
    private var banner: AUBannerView!
    private var google: AdManagerBannerView!
    private var handler: AUBannerHandler!
    private var loads = 0

    private func loadSlot() throws {
        let config = try JSONDecoder().decode(RemoteAdConfiguration.self, from: Data("""
        {"id":"adaptive", "config":{"adType":"banner","lazyLoad":true},
         "gamConfig":{"adUnitPath":"/test/adaptive","adSizes":["300x250","320x50"],
           "adaptiveBannerConfig":{"enabled":true,"type":"INLINE","widthStrategy":"CUSTOM","customWidth":320}},
         "prebidConfig":{"placementId":"","adSizes":[]}}
        """.utf8))
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting([config])
        let host = UIViewController()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        // RN supplies a frame and initially reserves only 50 points for an adaptive banner.
        container = UIView(frame: CGRect(x: 0, y: 100, width: 390, height: 50))
        host.view.addSubview(container)
        Audienzz.shared.pageImpression(host)
        owner = AURemoteConfigBannerView(adConfigId: "adaptive")
        observer = SizeObserver()
        let requested = expectation(description: "visible lazy banner reaches Google")
        owner.loadGoogle = { [unowned self] view, _ in
            google = view
            loads += 1
            requested.fulfill()
        }
        owner.load(in: container, rootViewController: host, delegate: observer)
        banner = try XCTUnwrap(container.subviews.compactMap { $0 as? AUBannerView }.first)
        host.view.layoutIfNeeded()
        banner.refreshVisibilityNow()
        wait(for: [requested], timeout: 2)
        handler = try XCTUnwrap(banner.eventHandler)
        XCTAssertEqual(loads, 1)
        XCTAssertGreaterThan(banner.bounds.height, 0)
        XCTAssertEqual(google.adSize.size.height, 0, "an inline request descriptor has no creative height yet")
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            owner?.destroy()
            window?.isHidden = true
            owner = nil; window = nil; container = nil; banner = nil; google = nil; handler = nil
            AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil)
        }
        super.tearDown()
    }

    func testLoadedBeforeSizeDoesNotCollapseTheSlotAndLateSizeExpandsIt() throws {
        try loadSlot()
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertGreaterThan(banner.bounds.height, 0, "320x0 is not a rendered creative size")
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 180)))
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 180, "a late size callback must update the live slot")
        XCTAssertEqual(observer.sizes, [CGSize(width: 320, height: 180)], "the bridge's size delegate must be wired")
        XCTAssertEqual(observer.loads, 1)
        XCTAssertEqual(loads, 1, "a resize must not buy another ad")
    }

    func testSizeBeforeLoadAndLaterCreativeResizeBothReachTheSlot() throws {
        try loadSlot()
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 180)))
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 180)
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 280)))
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 280)
        XCTAssertEqual(observer.sizes, [CGSize(width: 320, height: 180), CGSize(width: 320, height: 280)])
        XCTAssertEqual(observer.loads, 1)
        XCTAssertEqual(loads, 1)
    }

    func testGoogleInitiatedLoadStillUsesItsAnnouncedSize() throws {
        try loadSlot()
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 180)))
        handler.bannerViewDidReceiveAd(google)
        XCTAssertNil(banner.googleLoad)
        XCTAssertEqual(google.adSize.size.height, 180)
        // An unsolicited Google terminal callback is still supported. Its announced size wins
        // even when there is no SDK-owned request, and Google's adSize still names the old ad.
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 280)))
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 280)
        XCTAssertEqual(observer.loads, 2)
        XCTAssertEqual(loads, 1)
    }

    func testSizeCallbacksAfterPageReleaseDoNotResizeOrReachThePublisher() throws {
        try loadSlot()
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 180)))
        handler.bannerViewDidReceiveAd(google)
        Audienzz.shared.pageImpression("another-page")
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 320, height: 280)))
        window.layoutIfNeeded()
        XCTAssertEqual(banner.bounds.height, 180)
        XCTAssertEqual(observer.sizes, [CGSize(width: 320, height: 180)])
    }
}
