import XCTest
import UIKit
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

/// Publisher key-values and the SDK's live side by side: the SDK never removes a publisher's, and a
/// publisher can never remove or override the SDK's.
///
/// These run REAL Prebid. An empty config id makes it return at once without a network request —
/// but only after `Utils.removeHBKeywords`, the step that deletes every `hb_` key from the GAM
/// request, which is exactly the behaviour under test.
final class PublisherTargetingTests: AudienzzLifecycleTestCase {

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        Audienzz.shared.pageImpression("article")
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        AUTargeting.shared.clearGlobalTargeting()
    }

    override func tearDown() {
        AUTargeting.shared.clearGlobalTargeting()
        window = nil
        super.tearDown()
    }

    /// A publisher request with its own keys — including an `hb_`-prefixed one, and attempts to
    /// set the SDK's key names.
    private func publisherRequest() -> AdManagerRequest {
        let request = AdManagerRequest()
        request.customTargeting = [
            "category": "sports",
            "hb_custom": "keep",
            "au_slot": "999",
            "hb_refresh_count": "999",
            "au_sdk": "spoofed",
        ]
        return request
    }

    private func value(_ key: String, _ request: AdManagerRequest?) -> String? {
        request?.customTargeting?[key] as? String
    }

    /// Everything the contract promises about one request that reached GAM.
    private func assertContract(_ sent: AdManagerRequest?, refresh: Int = 0,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(sent, "control: a request reached GAM", file: file, line: line)
        XCTAssertEqual(value("category", sent), "sports", "publisher per-request key", file: file, line: line)
        XCTAssertEqual(value("hb_custom", sent), "keep", "a publisher `hb_` key survives Prebid", file: file, line: line)
        XCTAssertEqual(value("section", sent), "news", "publisher global key", file: file, line: line)
        XCTAssertNotEqual(value("au_slot", sent), "999", "a publisher cannot override the SDK's keys", file: file, line: line)
        XCTAssertNotNil(value("au_slot", sent), file: file, line: line)
        XCTAssertEqual(value("hb_refresh_count", sent), String(refresh), file: file, line: line)
        XCTAssertTrue(value("au_sdk", sent)?.hasPrefix("ios") == true, "\(String(describing: value("au_sdk", sent)))", file: file, line: line)
    }

    private func banner(headerBidding: Bool = true) -> (AUBannerView, () -> [AdManagerRequest]) {
        let banner = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        banner.headerBiddingEnabled = headerBidding
        banner.hostScreenOverride = "article" as NSString
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        var sent: [AdManagerRequest] = []
        banner.onLoadRequest = { sent.append($0 as! AdManagerRequest) }
        return (banner, { sent })
    }

    private func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }

    func testBannerKeepsBothSidesThroughARealPrebidAuction() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        AUTargeting.shared.addGlobalTargeting(key: "au_sdk", value: "spoofed-global")
        let publisher = publisherRequest()
        let (view, sent) = banner()
        defer { view.destroy() }
        view.createAd(with: publisher, gamBanner: UIView())
        settle()

        assertContract(sent().first)
        XCTAssertEqual(publisher.customTargeting?.count, 5, "the publisher's request object is not modified")
        XCTAssertNil(publisher.customTargeting?["section"])
    }

    func testAGamOnlyBannerKeepsBothSides() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        let (view, sent) = banner(headerBidding: false)
        defer { view.destroy() }
        view.createAd(with: publisherRequest(), gamBanner: UIView())
        settle()
        assertContract(sent().first)
    }

    /// Global targeting was merged once at createAd, so a refresh kept sending a key the publisher
    /// had removed and never sent one added later.
    func testGlobalChangesReachTheNextAuction() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        let (view, sent) = banner()
        defer { view.destroy() }
        view.createAd(with: publisherRequest(), gamBanner: UIView())
        settle()
        XCTAssertEqual(value("section", sent().first), "news")

        AUTargeting.shared.removeGlobalTargeting(key: "section")
        AUTargeting.shared.addGlobalTargeting(key: "late", value: "1")
        view.notifyAdLoadCompleted(rendered: true)
        view.reloadAd()
        settle()

        XCTAssertEqual(sent().count, 2)
        XCTAssertNil(value("section", sent().last), "a removed global key is no longer sent")
        XCTAssertEqual(value("late", sent().last), "1", "a global key added later is sent")
        XCTAssertEqual(value("category", sent().last), "sports")
        XCTAssertEqual(value("hb_custom", sent().last), "keep")
    }

    func testClearingGlobalTargetingCannotRemoveTheSdkKeys() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        AUTargeting.shared.clearGlobalTargeting()
        AUTargeting.shared.removeGlobalTargeting(key: "au_sdk")
        let (view, sent) = banner()
        defer { view.destroy() }
        view.createAd(with: AdManagerRequest(), gamBanner: UIView())
        settle()
        XCTAssertNotNil(value("au_sdk", sent().first))
        XCTAssertNotNil(value("au_page_seq", sent().first))
        XCTAssertNotNil(value("hb_refresh_count", sent().first))
    }

    /// Prebid's own bid keys win on their own names — a publisher key cannot fake a bid.
    func testAPrebidBidKeyWinsOverAPublisherKeyOfTheSameName() {
        let request = AdManagerRequest()
        request.customTargeting = ["hb_pb": "0.01", "category": "sports"]
        let guardian = AUAuctionTargeting.PrebidGuard(request)
        request.customTargeting = ["hb_pb": "1.00", "hb_bidder": "appnexus"]   // what Prebid leaves
        guardian.restore(into: request)
        XCTAssertEqual(value("hb_pb", request), "1.00")
        XCTAssertEqual(value("hb_bidder", request), "appnexus")
        XCTAssertEqual(value("category", request), "sports")
    }

    func testInterstitialKeepsBothSides() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        let view = AUInterstitialView(configId: "", isLazyLoad: false)
        defer { view.destroy() }
        var sent: AdManagerRequest?
        view.onLoadRequest = { sent = $0 as? AdManagerRequest }
        view.createAd(with: publisherRequest(), adUnitID: "/gam/int")
        settle()
        assertContract(sent)
    }

    func testRemoteInterstitialKeepsBothSides() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        AUTargeting.shared.addGlobalTargeting(key: "hb_custom", value: "keep")
        AUTargeting.shared.addGlobalTargeting(key: "category", value: "sports")
        let owner = AURemoteConfigInterstitial(adConfigId: "probe")
        defer { owner.destroy() }
        owner.configuration = { _ in ("", "/gam/int", [CGSize(width: 320, height: 480)]) }
        owner.isForeground = { true }
        var sent: AdManagerRequest?
        let realDemand = owner.demand
        owner.demand = { unit, request, reply in
            sent = request
            realDemand(unit, request, reply)
        }
        owner.loadOverride = { _ in }
        owner.prefetch { _ in }
        settle()
        assertContract(sent)
    }

    func testRewardedKeepsTheSidesThroughPrebid() {
        AUTargeting.shared.addGlobalTargeting(key: "section", value: "news")
        let view = AURewardedView(configId: "", isLazyLoad: false)
        defer { view.destroy() }
        var sent: AdManagerRequest?
        view.onLoadRequest = { sent = $0 as? AdManagerRequest }
        let publisher = publisherRequest()
        view.createAd(with: publisher, adUnitID: "/gam/rewarded")
        settle()
        XCTAssertNotNil(sent, "control: a request reached GAM")
        XCTAssertEqual(value("category", sent), "sports")
        XCTAssertEqual(value("hb_custom", sent), "keep", "a publisher `hb_` key survives Prebid")
        XCTAssertEqual(value("section", sent), "news")
        XCTAssertTrue(value("au_sdk", sent)?.hasPrefix("ios") == true)
        XCTAssertNil(publisher.customTargeting?["section"], "the publisher's request object is not modified")
    }
}
