import XCTest
import UIKit
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

/// Adopted from the independent audit probe.
///
/// Remote interstitials built a bare `AdManagerRequest`, so a publisher's configured global
/// targeting — and the SDK's own `au_sdk` / `au_v` keys, which travel through the same manager —
/// never reached them. Line items keyed on that targeting could not be selected for remote
/// interstitial inventory at all.
///
/// The request is captured where it is actually handed to demand, and the assertions run after the
/// demand completion so that a later stage overwriting `customTargeting` would also be caught.
final class InterstitialRequestTargetingTests: AudienzzLifecycleTestCase {
    private var owner: AURemoteConfigInterstitial!

    override func setUp() {
        super.setUp()
        owner = AURemoteConfigInterstitial(adConfigId: "audit")
        owner.configuration = { _ in ("audit", "/audit/interstitial", [CGSize(width: 320, height: 480)]) }
        owner.isForeground = { true }
        // Never reach Google; the request is what is under test.
        owner.loadOverride = { _ in }
    }

    override func tearDown() {
        AUTargeting.shared.removeGlobalTargeting(key: "audit_category")
        owner.destroy()
        owner = nil
        super.tearDown()
    }

    func testPrefetchedRequestCarriesGlobalTargeting() {
        AUTargeting.shared.addGlobalTargeting(key: "audit_category", value: "sports")
        var captured: AdManagerRequest?
        owner.demand = { _, request, _ in captured = request }

        owner.prefetch { _ in }

        XCTAssertNotNil(captured, "control: a request really was produced")
        XCTAssertEqual(captured?.customTargeting?["audit_category"] as? String, "sports")
        // The same manager is what adds the SDK's own identification keys.
        XCTAssertNotNil(captured?.customTargeting?["au_sdk"])
    }

    func testGlobalTargetingSurvivesTheDemandCompletion() {
        AUTargeting.shared.addGlobalTargeting(key: "audit_category", value: "sports")
        var captured: AdManagerRequest?
        owner.demand = { _, request, reply in
            captured = request
            // What Prebid does on a win: it adds its keywords to the same request.
            request.customTargeting?["hb_bidder"] = "prebid-bidder"
            reply(.prebidDemandFetchSuccess)
        }

        owner.prefetch { _ in }

        XCTAssertEqual(captured?.customTargeting?["hb_bidder"] as? String, "prebid-bidder",
                       "control: the completion really ran against this request")
        XCTAssertEqual(captured?.customTargeting?["audit_category"] as? String, "sports")
    }

    /// The interstitial has to tell the exchange what size it is.
    ///
    /// Prebid builds `banner.format` from the ad unit's banner parameters for interstitials as
    /// well as banners. With none set it sends no format at all, which downstream reads as a 1x1
    /// slot — so a 320x480 placement asked for a size it was never going to fill, and bidders
    /// size their response to the format they are given.
    func testTheConfiguredSizeReachesThePrebidAdUnit() {
        var captured: InterstitialAdUnit?
        owner.configuration = { _ in ("audit", "/audit/interstitial",
                                      [CGSize(width: 320, height: 480)]) }
        owner.demand = { unit, _, _ in captured = unit }

        owner.prefetch { _ in }

        XCTAssertEqual(captured?.bannerParameters.adSizes, [CGSize(width: 320, height: 480)],
                       "the request must describe the ad, not a 1x1 placeholder")
    }

    func testSeveralConfiguredSizesAllTravel() {
        var captured: InterstitialAdUnit?
        owner.configuration = { _ in ("audit", "/audit/interstitial",
                                      [CGSize(width: 320, height: 480),
                                       CGSize(width: 320, height: 460)]) }
        owner.demand = { unit, _, _ in captured = unit }

        owner.prefetch { _ in }

        XCTAssertEqual(captured?.bannerParameters.adSizes?.count, 2)
    }

    /// A placement with no configured sizes must not invent one.
    func testNoConfiguredSizesLeavesTheBannerParametersAlone() {
        var captured: InterstitialAdUnit?
        owner.configuration = { _ in ("audit", "/audit/interstitial", []) }
        owner.demand = { unit, _, _ in captured = unit }

        owner.prefetch { _ in }

        XCTAssertNil(captured?.bannerParameters.adSizes)
    }

    func testPrefetchAndShowUsesTheSameRequestPolicy() {
        AUTargeting.shared.addGlobalTargeting(key: "audit_category", value: "sports")
        var captured: AdManagerRequest?
        owner.demand = { _, request, _ in captured = request }

        owner.prefetchAndShow(from: UIViewController()) { _ in }

        XCTAssertEqual(captured?.customTargeting?["audit_category"] as? String, "sports")
    }

    /// The impression has to declare the API frameworks the SDK can render.
    ///
    /// Prebid writes `banner.api` only from the ad unit's banner parameters, and a bare Prebid
    /// interstitial unit has none — so the remote interstitial's request carried no `api` at all,
    /// unlike every banner and Android. The expected list is Android's: MRAID 1/2/3 and OMID 1.
    func testTheRequestDeclaresTheSupportedApiFrameworks() {
        var api: [Int]?
        var sizes: [CGSize]?
        owner.demand = { unit, _, _ in
            api = unit.bannerParameters.api?.map { $0.value }
            sizes = unit.bannerParameters.adSizes
        }

        owner.prefetch { _ in }

        XCTAssertEqual(api, [3, 5, 6, 7], "MRAID_1, MRAID_2, MRAID_3, OMID_1")
        XCTAssertEqual(sizes, [CGSize(width: 320, height: 480)], "the sizes still come from the config")
    }

    func testTheApiFrameworksAreDeclaredEvenWithoutConfiguredSizes() {
        owner.configuration = { _ in ("audit", "/audit/interstitial", []) }
        var api: [Int]?
        owner.demand = { unit, _, _ in api = unit.bannerParameters.api?.map { $0.value } }

        owner.prefetch { _ in }

        XCTAssertEqual(api, [3, 5, 6, 7])
    }
}
