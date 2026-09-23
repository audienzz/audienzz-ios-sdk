import XCTest
import UIKit
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

/// `hb_refresh_count` must reach GAM on every request, header-bid ones included.
///
/// It shares Prebid's `hb_` prefix, and Prebid iOS removes every `hb_` key from the GAM request at
/// the start of each auction (`Utils.removeHBKeywords`) before adding its own bid keys. The fake
/// Prebid below does exactly that, so each test fails if the SDK stops re-applying the counter.
final class HbRefreshCountTests: AudienzzLifecycleTestCase {

    /// What Prebid iOS does to the GAM request: drop every `hb_` key, then add the bid's keys.
    private static func fakePrebid(_ request: AdManagerRequest) {
        var targeting = request.customTargeting ?? [:]
        for key in targeting.keys where key.hasPrefix("hb_") { targeting[key] = nil }
        targeting["hb_pb"] = "1.00"
        targeting["hb_bidder"] = "appnexus"
        request.customTargeting = targeting
    }

    private func assertReachesGam(_ request: AdManagerRequest?, refresh: Int,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let targeting = request?.customTargeting ?? [:]
        XCTAssertEqual(targeting["hb_refresh_count"] as? String, String(refresh),
                       "stripped by Prebid and never put back", file: file, line: line)
        XCTAssertEqual(targeting["hb_pb"] as? String, "1.00", "Prebid's own keys are left as it set them",
                       file: file, line: line)
        XCTAssertNil(targeting["au_refresh"], "the old key is gone", file: file, line: line)
    }

    func testBannerRequestsKeepTheCounterThroughPrebid() {
        Audienzz.shared.pageImpression("article")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = AUBannerView(configId: "placement", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        defer { banner.destroy() }
        banner.hostScreenOverride = "article" as NSString
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        banner.demand = { _, request, reply in Self.fakePrebid(request); reply(.prebidDemandFetchSuccess) }
        var requests: [AdManagerRequest] = []
        banner.onLoadRequest = { requests.append($0 as! AdManagerRequest) }
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        assertReachesGam(requests.first, refresh: 0)

        banner.notifyAdLoadCompleted(rendered: true)
        banner.reloadAd()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 2)
        assertReachesGam(requests.last, refresh: 1)
    }

    func testRemoteInterstitialRequestsKeepTheCounterThroughPrebid() {
        let owner = AURemoteConfigInterstitial(adConfigId: "probe")
        defer { owner.destroy() }
        owner.configuration = { _ in ("probe", "/gam/remote-interstitial", [CGSize(width: 320, height: 480)]) }
        owner.isForeground = { true }
        var sent: AdManagerRequest?
        owner.demand = { _, request, reply in
            sent = request
            Self.fakePrebid(request)
            reply(.prebidDemandFetchSuccess)
        }
        var reachedGam = false
        // The GAM load happens after the demand completion, which is where the counter is restored.
        owner.loadOverride = { _ in reachedGam = true }
        owner.prefetch { _ in }
        XCTAssertTrue(reachedGam)
        assertReachesGam(sent, refresh: 0)
    }

    func testInterstitialViewRequestsKeepTheCounterThroughPrebid() {
        Audienzz.shared.pageImpression("interstitial")
        let view = AUInterstitialView(configId: "probe", isLazyLoad: false)
        defer { view.destroy() }
        view.demand = { _, request, reply in Self.fakePrebid(request); reply(.prebidDemandFetchSuccess) }
        var sent: AdManagerRequest?
        view.onLoadRequest = { sent = $0 as? AdManagerRequest }
        view.fetchRequest(AdManagerRequest())
        XCTAssertNotNil(sent, "the request must reach GAM")
        assertReachesGam(sent, refresh: 0)
    }
}
