import XCTest
import GoogleMobileAds
import PrebidMobile
@testable import AudienzziOSSDK

@MainActor
final class PageImpressionAttributionTests: AudienzzLifecycleTestCase {
    private func payload(_ event: AUEventDomain) throws -> [String: Any] {
        let network = AUEventNetworkMapper().toNetwork(event)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(network)) as? [String: Any])
    }

    func testAllAdEventsKeepTheirVisitThroughNavigationAndReturn() throws {
        let manager = AUEventsManager() // unconfigured: no fixture traffic leaves this process
        var events: [AUEventDomain] = []
        manager.observerForTesting = { events.append($0) }
        manager.onScreenResumed(screenName: "A")
        let firstA = manager.capturePageContext()
        let firstID = try XCTUnwrap(firstA.pageImpressionId)
        manager.onScreenResumed(screenName: "B")
        let b = try XCTUnwrap(manager.capturePageContext().pageImpressionId)
        manager.onScreenResumed(screenName: "A")
        let nextA = try XCTUnwrap(manager.capturePageContext().pageImpressionId)
        XCTAssertEqual(Set([firstID, b, nextA]).count, 3)
        let types: [AUAnalyticsEventType] = [.bidRequest, .bidResponse, .bidWon, .noBid,
            .adImpression, .adClick, .viewabilityStart, .viewabilitySuccess]
        for type in types {
            var event = AUEventDomain(type: type)
            event.pageContext = firstA
            manager.logEvent(event)
        }
        XCTAssertEqual(events.count, 11)
        XCTAssertEqual(try payload(events[0])["page_impression_id"] as? String, firstID)
        for event in events.dropFirst(3) {
            let wire = try payload(event)
            XCTAssertEqual(wire["page_impression_id"] as? String, firstID)
            XCTAssertEqual(wire["screen_name"] as? String, "A")
        }
        manager.logEvent(AUEventDomain(type: .bidRequest))
        manager.logEvent(AUEventDomain(type: .bidRequest)) // refresh does not create a page
        XCTAssertEqual(events.suffix(2).map(\.pageImpressionId), [nextA, nextA])
    }

    func testBackgroundBridgeReportWaitsForTheMainThreadTransition() throws {
        Audienzz.shared.pageImpression("A")
        let old = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        let submitted = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            Audienzz.shared.pageImpression("B")
            submitted.signal()
        }
        XCTAssertEqual(submitted.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, old)
        XCTAssertEqual(AUScreenAdCoordinator.shared.activeScreenAndName?.1, "A")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(AUEventsManager.shared.capturePageContext().screenName, "B")
        XCTAssertNotEqual(AUEventsManager.shared.capturePageContext().pageImpressionId, old)
        XCTAssertEqual(AUScreenAdCoordinator.shared.activeScreenAndName?.1, "B")
    }

    func testAnEarlyRequestDoesNotInventAPageOrAdoptALaterVisit() throws {
        let manager = AUEventsManager()
        var events: [AUEventDomain] = []
        manager.observerForTesting = { events.append($0) }
        var event = AUEventDomain(type: .bidRequest)
        event.pageContext = manager.capturePageContext()
        manager.logEvent(event)
        manager.onScreenResumed(screenName: "first real visit")
        manager.logEvent(event)
        XCTAssertEqual(events.count, 3)
        XCTAssertNil(try payload(events[0])["page_impression_id"])
        XCTAssertNotNil(try payload(events[1])["page_impression_id"])
        XCTAssertNil(try payload(events[2])["page_impression_id"])
    }

    func testRemoteInterstitialKeepsPrefetchVisitAcrossNavigation() throws {
        var events: [AUEventDomain] = []
        AUEventsManager.shared.observerForTesting = { events.append($0) }
        let owner = AURemoteConfigInterstitial(adConfigId: "fixture")
        defer { owner.finishPresentation(); owner.destroy(); AUEventsManager.shared.observerForTesting = nil }
        owner.configuration = { _ in ("fixture", "/fixture/interstitial", [CGSize(width: 320, height: 480)]) }
        owner.isForeground = { true }
        var replies: [(ResultCode) -> Void] = []
        var googleReply: ((Result<AUInterstitialPresenting, Error>) -> Void)?
        owner.demand = { _, _, reply in replies.append(reply) }
        owner.loadOverride = { googleReply = $0 }
        Audienzz.shared.pageImpression("A")
        owner.prefetch { _ in }
        Audienzz.shared.pageImpression("B")
        XCTAssertEqual(replies.count, 1)
        replies[0](.prebidDemandNoBids)
        let firstAd = InterstitialLifecycleTests.Ad()
        try XCTUnwrap(googleReply)(.success(firstAd))
        XCTAssertTrue(owner.show(from: UIViewController()))
        let delegate = try XCTUnwrap(firstAd.delegate)
        delegate.adDidRecordImpression?(firstAd)
        delegate.adDidRecordClick?(firstAd)
        delegate.adDidDismissFullScreenContent?(firstAd)
        let firstPage = try XCTUnwrap(events.first { $0.type == .pageImpression }?.pageImpressionId)
        let firstCycle = events.filter { $0.type != .pageImpression }
        XCTAssertEqual(firstCycle.map(\.type), [.bidRequest, .bidResponse, .noBid, .adImpression, .adClick])
        XCTAssertTrue(firstCycle.allSatisfy { $0.pageImpressionId == firstPage && $0.screenName == "A" })
        owner.prefetch { _ in }
        XCTAssertEqual(replies.count, 2)
        let secondPage = try XCTUnwrap(events.filter { $0.type == .pageImpression }.last?.pageImpressionId)
        XCTAssertNotEqual(secondPage, firstPage)
        XCTAssertEqual(events.last?.type, .bidRequest)
        XCTAssertEqual(events.last?.pageImpressionId, secondPage)
    }

    func testBannerGoogleCallbacksAndRefreshesFollowTheirPageVisit() throws {
        var events: [AUEventDomain] = []
        AUEventsManager.shared.observerForTesting = { events.append($0) }
        Audienzz.shared.pageImpression("A")
        let firstID = try XCTUnwrap(events.first?.pageImpressionId)
        let banner = AUBannerView(configId: "fixture", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: false)
        banner.setScreen("A")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        let google = AdManagerBannerView(adSize: AdSizeBanner)
        google.adUnitID = "/fixture/banner"
        var handoffs = 0
        banner.demand = { _, _, reply in reply(.prebidDemandNoBids) }
        banner.onLoadRequest = { _ in handoffs += 1 }
        defer { banner.destroy(); AUEventsManager.shared.observerForTesting = nil }
        banner.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(handoffs, 1)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.delegate?.bannerViewDidRecordImpression?(google)
        banner.reloadAd()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(handoffs, 2)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.delegate?.bannerViewDidRecordImpression?(google)
        let firstCycle = events.filter { $0.type != .pageImpression }
        XCTAssertEqual(firstCycle.filter { $0.type == .bidRequest }.count, 2)
        XCTAssertEqual(firstCycle.filter { $0.type == .adImpression }.count, 2)
        XCTAssertTrue(firstCycle.allSatisfy { $0.pageImpressionId == firstID })
        Audienzz.shared.pageImpression("B")
        Audienzz.shared.pageImpression("A")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(handoffs, 3)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.delegate?.bannerViewDidRecordImpression?(google)
        let nextID = try XCTUnwrap(events.filter { $0.type == .pageImpression }.last?.pageImpressionId)
        XCTAssertNotEqual(nextID, firstID)
        XCTAssertEqual(events.last { $0.type == .adImpression }?.pageImpressionId, nextID)
        XCTAssertEqual(events.last { $0.type == .bidRequest }?.pageImpressionId, nextID)
    }
}
