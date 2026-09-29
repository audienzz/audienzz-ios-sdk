import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

@MainActor
final class AdRequestContextTests: AudienzzLifecycleTestCase {
    private func assertRequest(_ request: AdManagerRequest, _ page: Int, _ slot: Int?, _ refresh: Int,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.customTargeting?["au_page_seq"] as? String, String(page), file: file, line: line)
        XCTAssertEqual(request.customTargeting?["au_slot"] as? String, slot.map(String.init), file: file, line: line)
        XCTAssertEqual(request.customTargeting?["hb_refresh_count"] as? String, String(refresh), file: file, line: line)
    }

    func testUnorderedSweepReservesLazySlotsBeforeRequests() {
        let ledger = AUAdRequestLedger()
        let first = AUAdRequestContext(), second = AUAdRequestContext()
        ledger.beginPage(7, retained: [second, first, first])
        XCTAssertEqual(ledger.nextRequest(second), AUAdRequestSnapshot(pageSequence: 7, slot: 2, refresh: 0))
        XCTAssertEqual(ledger.nextRequest(first), AUAdRequestSnapshot(pageSequence: 7, slot: 1, refresh: 0))
        XCTAssertEqual(ledger.nextRequest(second), AUAdRequestSnapshot(pageSequence: 7, slot: 2, refresh: 1))
        ledger.beginPage(8, retained: [second, first])
        XCTAssertEqual(ledger.nextRequest(second), AUAdRequestSnapshot(pageSequence: 8, slot: 2, refresh: 0))
    }

    func testRequestCopiesPreservePublisherFieldsAndEarlierSnapshots() {
        Audienzz.shared.pageImpression("article")
        let context = AUAdRequestContext()
        let template = AdManagerRequest()
        template.customTargeting = ["category": "sports", "hb_refresh_count": "999"]
        template.publisherProvidedID = "publisher-test-id"
        let first = context.nextRequest(from: template)
        let second = context.nextRequest(from: template)
        assertRequest(first, 1, 1, 0)
        assertRequest(second, 1, 1, 1)
        XCTAssertFalse(first === second)
        XCTAssertEqual(first.customTargeting?["category"] as? String, "sports")
        XCTAssertEqual(first.publisherProvidedID, "publisher-test-id")
        Audienzz.shared.pageImpression("article")
        assertRequest(context.nextRequest(from: template), 2, 1, 0)
        assertRequest(first, 1, 1, 0)
        XCTAssertEqual(template.customTargeting?["hb_refresh_count"] as? String, "999")
    }

    func testBridgeRecreationReusesSlotAndPageTransitionResetsIt() {
        Audienzz.shared.pageImpression("article")
        let first = AUAdRequestContext.forSlot("flutter-a")
        let replacement = AUAdRequestContext.forSlot("flutter-a")
        let other = AUAdRequestContext.forSlot("flutter-b")
        XCTAssertTrue(first === replacement)
        assertRequest(first.nextRequest(from: AdManagerRequest()), 1, 1, 0)
        assertRequest(replacement.nextRequest(from: AdManagerRequest()), 1, 1, 1)
        assertRequest(other.nextRequest(from: AdManagerRequest()), 1, 2, 0)
        Audienzz.shared.pageImpression("next")
        assertRequest(AUAdRequestContext.forSlot("flutter-a").nextRequest(from: AdManagerRequest()), 2, 1, 0)
    }

    func testRemoteInterstitialCountsRealRequestsButNotRepeatedPrefetchWhileBusy() throws {
        Audienzz.shared.pageImpression("article")
        let owner = AURemoteConfigInterstitial(adConfigId: "test")
        defer { owner.destroy() }
        owner.configuration = { _ in ("test", "/test", [CGSize(width: 320, height: 480)]) }
        owner.isForeground = { true }
        var requests: [AdManagerRequest] = []
        owner.demand = { _, request, _ in requests.append(request) }
        owner.prefetch { _ in }
        owner.prefetch { _ in }
        XCTAssertEqual(requests.count, 1)
        assertRequest(try XCTUnwrap(requests.first), 1, nil, 0)
        // An unrelated page impression cannot mutate the retained, in-flight request.
        Audienzz.shared.pageImpression("other")
        assertRequest(try XCTUnwrap(requests.first), 1, nil, 0)
    }

    func testInterstitialNeverConsumesABannerPositionAndClearsStaleSlotTargeting() {
        Audienzz.shared.pageImpression("article")
        let interstitial = AUAdRequestContext.forInterstitial("overlay")
        let template = AdManagerRequest()
        template.customTargeting = ["au_slot": "999", "category": "sport"]
        let first = interstitial.nextRequest(from: template, isInterstitial: true)
        assertRequest(first, 1, nil, 0)
        assertRequest(AUAdRequestContext.forSlot("top").nextRequest(from: AdManagerRequest()), 1, 1, 0)
        assertRequest(interstitial.nextRequest(from: template, isInterstitial: true), 1, nil, 1)
        assertRequest(AUAdRequestContext.forSlot("bottom").nextRequest(from: AdManagerRequest()), 1, 2, 0)
        XCTAssertEqual(first.customTargeting?["category"] as? String, "sport")
        Audienzz.shared.pageImpression("article")
        assertRequest(interstitial.nextRequest(from: template, isInterstitial: true), 2, nil, 0)
        assertRequest(first, 1, nil, 0)
        XCTAssertEqual(template.customTargeting?["au_slot"] as? String, "999")
    }

    func testBannerHandoffHasPerSlotCountersAndPageReset() throws {
        Audienzz.shared.pageImpression("article")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        var requests: [AdManagerRequest] = []
        let banner = AUBannerView(configId: "", adSize: CGSize(width: 320, height: 50),
                                  adFormats: [.banner], isLazyLoad: false)
        banner.hostScreenOverride = "article" as NSString
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        banner.onLoadRequest = { requests.append($0 as! AdManagerRequest) }
        banner.createAd(with: AdManagerRequest(), gamBanner: UIView())
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 1)
        let first = try XCTUnwrap(requests.first)
        assertRequest(first, 1, 1, 0)
        banner.notifyAdLoadCompleted(rendered: true)
        banner.reloadAd()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 2)
        assertRequest(try XCTUnwrap(requests.last), 1, 1, 1)
        banner.notifyAdLoadCompleted(rendered: true)
        Audienzz.shared.pageImpression("article")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 3)
        assertRequest(try XCTUnwrap(requests.last), 2, 1, 0)
        assertRequest(first, 1, 1, 0)
        banner.destroy()
    }

    func testBeforeFirstPageReportUsesZeroRatherThanInventingAPage() {
        assertRequest(AUAdRequestContext().nextRequest(from: AdManagerRequest()), 0, 1, 0)
    }
}
