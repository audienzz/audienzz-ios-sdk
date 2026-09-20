import XCTest
import UIKit
import GoogleMobileAds
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
        owner.configuration = { _ in ("audit", "/audit/interstitial") }
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

    func testPrefetchAndShowUsesTheSameRequestPolicy() {
        AUTargeting.shared.addGlobalTargeting(key: "audit_category", value: "sports")
        var captured: AdManagerRequest?
        owner.demand = { _, request, _ in captured = request }

        owner.prefetchAndShow(from: UIViewController()) { _ in }

        XCTAssertEqual(captured?.customTargeting?["audit_category"] as? String, "sports")
    }
}
