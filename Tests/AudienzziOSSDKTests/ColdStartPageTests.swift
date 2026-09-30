import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

/// Cold-start ordering and analytics through the real banner lifecycle and mapper.
final class ColdStartPageTests: AudienzzLifecycleTestCase {
    private final class Network: AUEventsNetworkManager<AUBatchResultModel> {
        init() { super.init(monitorConnectivity: false) }
        private let lock = NSLock()
        private var values: [JSONObject] = []
        var sent: [JSONObject] { lock.lock(); defer { lock.unlock() }; return values }
        override func request(_ route: APIRoute<AUBatchResultModel>, handler: @escaping (Result<AUBatchResultModel, AUAPIError>) -> Void) {
            guard case .batchEvents(let events) = route else { return XCTFail("Unexpected route") }
            lock.lock(); values.append(contentsOf: events); lock.unlock()
            handler(.success(AUBatchResultModel(code: 204)))
        }
    }
    private var directory: URL!
    private var network: Network!
    private var queue: AUEventQueue!
    private var recorder: AUEventsManager!
    private var window: UIWindow!
    private var banner: AUBannerView!
    private var google: AdManagerBannerView!
    private var replies: [(ResultCode) -> Void] = []
    private var handoffs = 0

    override func setUp() {
        super.setUp()
        AUEventsManager.shared.resetPageForTesting()
        XCTAssertNil(AUEventsManager.shared.capturePageContext().pageImpressionId)
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        network = Network()
        queue = AUEventQueue(networkManager: network, store: AUEventStore(directory: directory),
                             config: .init(batchDelayMs: 0, minIntervalMs: 0))
        let eventQueue = queue!
        recorder = AUEventsManager(makeQueue: { eventQueue })
        recorder.configure(companyId: "fixture")
        // Capture real native event emissions and run them through the production logger,
        // mapper and queue with an isolated store and fake transport. No fixture leaves the device.
        AUEventsManager.shared.observerForTesting = { [unowned self] event in recorder.logEvent(event) }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844)); window.isHidden = false
        banner = AUBannerView(configId: "fixture", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: false)
        banner.setScreen("A"); banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        google = AdManagerBannerView(adSize: AdSizeBanner); google.adUnitID = "/fixture/cold-start"
        banner.demand = { [unowned self] _, _, reply in replies.append(reply) }
        banner.onLoadRequest = { [unowned self] _ in handoffs += 1 }
    }
    override func tearDown() {
        AUEventsManager.shared.observerForTesting = nil
        AUEventsManager.shared.resetPageForTesting()
        banner.destroy(); banner.removeFromSuperview(); banner = nil; google = nil
        window.isHidden = true; window = nil
        queue.syncForTesting(); recorder = nil; queue = nil; network = nil
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }
    private func load() {
        banner.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    private func captured(_ label: String) throws -> [JSONObject] {
        queue.flush()
        for _ in 0..<8 { queue.syncForTesting() }
        let result = network.sent.sorted { ($0["session_seq"] as? Int ?? -1) < ($1["session_seq"] as? Int ?? -1) }
        for event in result {
            var brief = event.filter { ["event_type", "event_id", "page_impression_id", "session_seq", "event_timestamp"].contains($0.key) }
            brief["attributes"] = (event["attributes"] as? [String: String] ?? [:]).filter {
                ["auction_id", "refresh", "slot_reload"].contains($0.key)
            }
            let data = try JSONSerialization.data(withJSONObject: brief, options: [.sortedKeys])
            print("COLD_START \(label) \(String(decoding: data, as: UTF8.self))")
        }
        return result
    }
    private func attributes(_ event: JSONObject) -> [String: String] { event["attributes"] as? [String: String] ?? [:] }

    func testLateFirstPageDuringPrebidRetiresAuctionButKeepsReplacementInitial() throws {
        load(); XCTAssertEqual(replies.count, 1)
        Audienzz.shared.pageImpression("A")
        XCTAssertEqual(replies.count, 2)
        replies[0](.prebidDemandNoBids); XCTAssertEqual(handoffs, 0)
        replies[1](.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google)
        XCTAssertEqual(handoffs, 1)
        let all = try captured("late-page-prebid")
        XCTAssertEqual(all.compactMap { $0["event_type"] as? String }, ["bidRequest", "pageImpression", "bidRequest", "bidResponse", "noBid"])
        XCTAssertEqual(all.compactMap { $0["session_seq"] as? Int }, [0, 1, 2, 3, 4])
        guard all.count == 5 else { return }
        XCTAssertNil(all[0]["page_impression_id"])
        let page = try XCTUnwrap(all[1]["page_impression_id"] as? String)
        XCTAssertEqual(all[2]["page_impression_id"] as? String, page)
        XCTAssertEqual(attributes(all[0])["refresh"], "false")
        XCTAssertEqual(attributes(all[2])["refresh"], "false")
        let firstAuction = try XCTUnwrap(attributes(all[0])["auction_id"])
        let secondAuction = try XCTUnwrap(attributes(all[2])["auction_id"])
        XCTAssertNotEqual(firstAuction, secondAuction)
        XCTAssertEqual(attributes(all[3])["auction_id"], secondAuction)
    }

    func testCanceledGoogleDeliveryStaysInitialAndACompletedDeliveryRefreshes() throws {
        load(); XCTAssertEqual(replies.count, 1)
        replies[0](.prebidDemandNoBids); XCTAssertEqual(handoffs, 1)
        Audienzz.shared.pageImpression("A")
        XCTAssertEqual(replies.count, 1) // Google serialization still holds.
        google.delegate?.bannerViewDidReceiveAd?(google)
        XCTAssertEqual(replies.count, 2)
        replies[1](.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google)
        XCTAssertEqual(handoffs, 2)
        let all = try captured("late-page-google")
        XCTAssertEqual(all.compactMap { $0["event_type"] as? String }, ["bidRequest", "bidResponse", "noBid", "pageImpression", "bidRequest", "bidResponse", "noBid"])
        let bids = all.filter { $0["event_type"] as? String == "bidRequest" }
        XCTAssertEqual(bids.count, 2)
        guard bids.count == 2 else { return }
        XCTAssertNil(bids[0]["page_impression_id"])
        XCTAssertNotNil(bids[1]["page_impression_id"])
        XCTAssertEqual(attributes(bids[0])["refresh"], "false")
        XCTAssertEqual(attributes(bids[1])["refresh"], "false")
        banner.reloadAd()
        XCTAssertEqual(replies.count, 3)
        replies[2](.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google)
        let refreshed = try captured("completed-delivery")
        let requests = refreshed.filter { $0["event_type"] as? String == "bidRequest" }
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(attributes(try XCTUnwrap(requests.last))["refresh"], "true")
    }

    func testReportBeforeCreateWhilePrebidIsUnconfiguredAvoidsDuplicateAuction() throws {
        Audienzz.shared.prebidConfiguredOverride = false
        Audienzz.shared.pageImpression("A")
        let page = try XCTUnwrap(AUEventsManager.shared.capturePageContext().pageImpressionId)
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
        load(); XCTAssertTrue(replies.isEmpty)
        Audienzz.shared.prebidConfiguredOverride = true
        AUScreenAdCoordinator.shared.resumeAllAfterPrebidConfigured()
        XCTAssertEqual(replies.count, 1)
        replies[0](.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google)
        let all = try captured("ordered-page")
        XCTAssertEqual(all.compactMap { $0["event_type"] as? String }, ["pageImpression", "bidRequest", "bidResponse", "noBid"])
        XCTAssertTrue(all.allSatisfy { $0["page_impression_id"] as? String == page })
        XCTAssertEqual(attributes(try XCTUnwrap(all.first { $0["event_type"] as? String == "bidRequest" }))["refresh"], "false")
        XCTAssertEqual(handoffs, 1)
    }

    func testPagesBeforeAnalyticsConfigurationAreReplayedOnceWithOriginalIdentityAndTime() throws {
        // Public API honors page ownership before configureSDK, independently of the recorder.
        AUEventsManager.shared.observerForTesting = nil
        Audienzz.shared.prebidConfiguredOverride = false
        Audienzz.shared.pageImpression("A")
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, 1)
        XCTAssertNotNil(AUEventsManager.shared.capturePageContext().pageImpressionId)
        // Exercise that same manager implementation with its queue absent, then configured.
        let eventQueue = queue!
        let manager = AUEventsManager(makeQueue: { eventQueue })
        var observed: [AUEventDomain] = []
        manager.observerForTesting = { observed.append($0) }
        manager.onScreenResumed(screenName: "earlier-page")
        let oldPage = try XCTUnwrap(manager.capturePageContext().pageImpressionId)
        manager.onScreenResumed(screenName: "A")
        let page = try XCTUnwrap(manager.capturePageContext().pageImpressionId)
        // Separate occurrence from configuration by more than the wire timestamp's precision.
        // Otherwise re-stamping during configuration could accidentally compare equal.
        Thread.sleep(forTimeInterval: 0.01)
        manager.configure(companyId: "fixture")
        manager.configure(companyId: "fixture")
        manager.logEvent(AUEventDomain(type: .bidRequest))
        let all = try captured("before-analytics-config")
        XCTAssertEqual(all.compactMap { $0["event_type"] as? String }, ["pageImpression", "pageImpression", "bidRequest"])
        XCTAssertEqual(all.compactMap { $0["page_impression_id"] as? String }, [oldPage, page, page])
        XCTAssertEqual(all.compactMap { $0["session_seq"] as? Int }, [0, 1, 2])
        XCTAssertEqual(observed.count, 3, "Configuration must not fire a second page report")
        XCTAssertNotEqual(oldPage, page)
        let original = AUEventNetworkMapper().toNetwork(try XCTUnwrap(observed.first))
        XCTAssertEqual(all.first?["event_timestamp"] as? String, original.eventTimestamp)
    }
    func testTerminalNoFillCountsAsCompletedForTheNextRequest() throws {
        Audienzz.shared.pageImpression("A")
        load(); replies[0](.prebidDemandNoBids)
        google.delegate?.bannerView?(google, didFailToReceiveAdWithError: NSError(domain: "com.google.admob", code: 1))
        banner.reloadAd(); XCTAssertEqual(replies.count, 2)
        replies[1](.prebidDemandNoBids)
        google.delegate?.bannerViewDidReceiveAd?(google)
        let requests = try captured("no-fill").filter { $0["event_type"] as? String == "bidRequest" }
        XCTAssertEqual(requests.map { attributes($0)["refresh"] }, ["false", "true"])
    }

}
