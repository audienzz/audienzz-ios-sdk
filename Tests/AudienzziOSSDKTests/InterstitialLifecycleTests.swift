import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

final class InterstitialLifecycleTests: AudienzzLifecycleTestCase {
    final class Ad: NSObject, AUInterstitialPresenting, FullScreenPresentingAd {
        weak var delegate: FullScreenContentDelegate?
        var responseID: String? = "google-response"
        var googleAd: FullScreenPresentingAd? { self }
        var fullScreenContentDelegate: FullScreenContentDelegate? {
            get { delegate }
            set { delegate = newValue }
        }
        var shows = 0
        var preflightError: Error?
        func canPresent(from controller: UIViewController?) throws {
            if let preflightError { throw preflightError }
        }
        func present(from controller: UIViewController?) { shows += 1 }
    }
    var owner: AURemoteConfigInterstitial!
    var response: ((Result<AUInterstitialPresenting, Error>) -> Void)!
    var requests = 0
    var time: TimeInterval = 0
    var events: [String] = []
    private func stubDemand(_ instance: AURemoteConfigInterstitial) {
        instance.configuration = { _ in ("probe", "/gam/remote-interstitial") }
        instance.demand = { _, _, reply in reply(.prebidDemandFetchSuccess) }
    }
    override func setUp() {
        super.setUp()
        requests = 0; time = 0; events = []
        owner = AURemoteConfigInterstitial(adConfigId: "probe")
        stubDemand(owner)
        owner.now = { [unowned self] in time }
        owner.isForeground = { true }
        owner.onLifecycleEvent = { [unowned self] in events.append($0["event"] as! String) }
        owner.loadOverride = { [unowned self] in requests += 1; response = $0 }
    }
    override func tearDown() {
        defer { super.tearDown() }
        owner.finishPresentation()
        owner.destroy()
        owner = nil; response = nil
    }
    func testDefaultLoadShowsExactlyOnceEvenWithLegacyShowInCompletion() {
        let ad = Ad()
        owner.load { [unowned self] _ in owner.show(from: UIViewController()) }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 1)
        XCTAssertFalse(owner.isReady)
        XCTAssertNotNil(ad.delegate)
        XCTAssertEqual(events.prefix(3), ["loadRequested", "loaded", "showAttempted"])
    }
    func testDefaultLoadShowsWithoutAnyPublisherShowCall() {
        let ad = Ad()
        owner.load { _ in }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 1)
        owner.show(from: UIViewController())
        XCTAssertEqual(ad.shows, 1)
    }
    func testPreloadOptOutDoesNotReplaceReadyInventory() {
        owner.automaticallyShowOnLoad = false
        let ad = Ad()
        owner.load { _ in }
        response(.success(ad))
        owner.load { result in
            if case .success = result { XCTFail("Expected busy") }
        }
        XCTAssertTrue(owner.isReady)
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(ad.shows, 0)
    }
    func testExpiryIsRejectedAndCanBeReloaded() {
        owner.automaticallyShowOnLoad = false
        let ad = Ad()
        owner.load { _ in }
        response(.success(ad))
        time = 3600
        XCTAssertFalse(owner.isReady)
        var failed = false
        owner.onPresentationError = { _ in failed = true }
        owner.show(from: UIViewController())
        XCTAssertEqual(ad.shows, 0)
        XCTAssertTrue(failed)
        owner.load { _ in }
        XCTAssertEqual(requests, 2)
    }
    func testDestroyedLoadCompletesOnceAndDropsLateGoogleAd() {
        var completions = 0
        owner.load { result in
            completions += 1
            if case .success = result { XCTFail("Expected cancellation") }
        }
        owner.destroy()
        let ad = Ad()
        response(.success(ad))
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(ad.shows, 0)
    }
    func testCancelThenDeallocateStillCompletesOnlyOnce() {
        var completions = 0
        var pending: ((Result<AUInterstitialPresenting, Error>) -> Void)?
        var instance: AURemoteConfigInterstitial? = AURemoteConfigInterstitial(adConfigId: "probe")
        stubDemand(instance!)
        instance?.loadOverride = { pending = $0 }
        instance?.load { _ in completions += 1 }
        instance?.destroy()
        instance = nil
        pending?(.success(Ad()))
        XCTAssertEqual(completions, 1)
    }
    func testPreflightErrorKeepsNativeErrorDetails() {
        let ad = Ad()
        ad.preflightError = NSError(domain: "google.test", code: 7)
        var error: NSError?
        owner.onPresentationError = { error = $0 }
        owner.load { _ in }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 0)
        XCTAssertEqual(error?.domain, "google.test")
        XCTAssertEqual(error?.code, 7)
    }
    func testNoAutomaticPresentationAfterPublisherCancelsInLoadedCallback() {
        let ad = Ad()
        owner.load { [unowned self] _ in owner.destroy() }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 0)
    }
    func testInactiveAppFailsShowWithoutMisreportingLoadFailure() {
        owner.isForeground = { false }
        let ad = Ad()
        var loaded = false
        var showFailed = false
        owner.onPresentationError = { _ in showFailed = true }
        owner.load { loaded = (try? $0.get()) != nil }
        response(.success(ad))
        XCTAssertTrue(loaded)
        XCTAssertTrue(showFailed)
        XCTAssertEqual(ad.shows, 0)
        XCTAssertFalse(owner.isReady)
    }
    func testPagesAndAttachmentDoNotOwnFullscreenDemand() {
        Audienzz.shared.pageImpression("interstitial-A")
        let view = AUInterstitialView(configId: "probe", adFormats: [.banner], isLazyLoad: false)
        XCTAssertNil(view.configuredDemandRefresh)
        let token = view.fullscreenDemand.begin()!
        XCTAssertNil(view.fullscreenDemand.begin())
        Audienzz.shared.pageImpression("interstitial-B")
        XCTAssertTrue(view.fullscreenDemand.finish(token))
        let window = UIWindow()
        window.addSubview(view)
        Audienzz.shared.pageImpression("interstitial-B")
        // No automatic request consumed the next explicit load opportunity.
        XCTAssertNotNil(view.fullscreenDemand.begin())
        view.removeFromSuperview()
    }
    func testDestroyedFullscreenDemandRejectsLateCompletion() {
        let view = AUInterstitialView(configId: "probe", adFormats: [.banner], isLazyLoad: false)
        let token = view.fullscreenDemand.begin()!
        view.destroy()
        XCTAssertFalse(view.fullscreenDemand.finish(token))
        XCTAssertNil(view.fullscreenDemand.begin())
    }
    func testPreloadCoalescesWithoutRememberingAnUnavailableOpportunity() {
        var completions = 0
        owner.preload { _ in completions += 1 }
        owner.preload { _ in completions += 1 }
        XCTAssertFalse(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        let ad = Ad()
        response(.success(ad))
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(ad.shows, 0)
        owner.preload { _ in completions += 1 }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(completions, 3)
        XCTAssertFalse(owner.showAtOpportunity(from: UIViewController(), eligible: false))
        XCTAssertTrue(owner.isReady)
        XCTAssertTrue(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        XCTAssertFalse(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        XCTAssertEqual(ad.shows, 1)
    }

    func testPreloadSurvivesInactiveOpportunityWithoutAnAutomaticForegroundShow() {
        let ad = Ad()
        owner.preload { _ in }
        response(.success(ad))
        owner.isForeground = { false }
        XCTAssertFalse(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        XCTAssertTrue(owner.isReady)
        owner.isForeground = { true }
        XCTAssertEqual(ad.shows, 0)
        XCTAssertTrue(owner.showAtOpportunity(from: UIViewController(), eligible: true))
    }

    func testExpiredPreloadDoesNotCreateRequestUntilExplicitPreload() {
        owner.preload { _ in }
        response(.success(Ad()))
        time = 3600
        XCTAssertFalse(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        XCTAssertEqual(requests, 1)
        owner.preload { _ in }
        XCTAssertEqual(requests, 2)
    }

    func testPreloadCancellationCompletesEveryWaiterOnce() {
        var cancellations = 0
        owner.preload { if case .failure = $0 { cancellations += 1 } }
        owner.preload { if case .failure = $0 { cancellations += 1 } }
        owner.destroy()
        response(.success(Ad()))
        XCTAssertEqual(cancellations, 2)
        XCTAssertFalse(owner.isReady)
    }

    func testDeallocatedPreloadCompletesWaiters() {
        var pending: ((Result<AUInterstitialPresenting, Error>) -> Void)?
        var resultCount = 0
        var instance: AURemoteConfigInterstitial? = AURemoteConfigInterstitial(adConfigId: "probe")
        stubDemand(instance!)
        instance?.loadOverride = { pending = $0 }
        instance?.preload { if case .failure = $0 { resultCount += 1 } }
        instance = nil
        pending?(.success(Ad()))
        XCTAssertEqual(resultCount, 1)
    }

    func testAnotherPresentationSkipsOpportunityAndPreservesPreload() {
        owner.preload { _ in }
        response(.success(Ad()))
        let second = AURemoteConfigInterstitial(adConfigId: "second")
        let ad = Ad()
        second.isForeground = { true }
        stubDemand(second)
        second.loadOverride = { $0(.success(ad)) }
        second.preload { _ in }
        XCTAssertTrue(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        XCTAssertFalse(second.showAtOpportunity(from: UIViewController(), eligible: true))
        XCTAssertTrue(second.isReady)
        owner.finishPresentation()
        XCTAssertTrue(second.showAtOpportunity(from: UIViewController(), eligible: true))
        second.finishPresentation()
        second.destroy()
    }

    func testLegacyCompletionCanStillDisableAutomaticPresentation() {
        let ad = Ad()
        owner.load { [unowned self] _ in owner.automaticallyShowOnLoad = false }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 0)
        XCTAssertTrue(owner.isReady)
    }

    func testRemoteAnalyticsUsesGoogleCallbacksAndStableAuctionIdentity() {
        var logged: [AUEventDomain] = []
        owner.analytics = { logged.append($0) }
        owner.demand = { _, request, reply in
            request.customTargeting = ["hb_bidder": "prebid-bidder"]
            reply(.prebidDemandFetchSuccess)
            reply(.prebidDemandFetchSuccess) // Duplicate response must not request another Google ad.
        }
        owner.preload { _ in }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(logged.map(\.type), [.bidRequest, .bidResponse, .bidWon])
        XCTAssertEqual(logged.first?.mediaTypes, "[\"banner\",\"video\"]")
        let auction = logged.first?.auctionId
        let ad = Ad()
        response(.success(ad))
        XCTAssertFalse(logged.contains { $0.type == .adImpression })
        XCTAssertTrue(owner.showAtOpportunity(from: UIViewController(), eligible: true))
        ad.delegate?.adDidRecordImpression?(Ad()) // Foreign ad cannot supply an impression.
        XCTAssertEqual(logged.count, 3)
        ad.delegate?.adDidRecordImpression?(ad)
        ad.delegate?.adDidRecordImpression?(ad)
        ad.delegate?.adDidRecordClick?(ad)
        XCTAssertEqual(logged.map(\.type), [.bidRequest, .bidResponse, .bidWon, .adImpression, .adClick])
        XCTAssertEqual(Set(logged.compactMap(\.auctionId)), Set([auction!]))
        XCTAssertTrue(logged.allSatisfy { $0.adUnitId == "/gam/remote-interstitial" })
        XCTAssertTrue(logged.allSatisfy { $0.adType == "INTERSTITIAL" })
        XCTAssertEqual(logged[2].bidderCode, "prebid-bidder")
        XCTAssertNil(logged[3].bidderCode, "Prebid bid does not establish Google's render winner")
        XCTAssertNil(logged[3].winnerBidderCode)
        ad.delegate?.adDidDismissFullScreenContent?(ad)
        ad.delegate?.adDidRecordImpression?(ad)
        XCTAssertEqual(logged.count, 5)
        owner.preload { _ in }
        XCTAssertNotEqual(logged.last?.auctionId, auction)
    }

    func testNoBidStillLoadsGoogleWithoutInventingAnImpression() {
        var logged: [AUEventDomain] = []
        owner.analytics = { logged.append($0) }
        owner.preload { _ in }
        XCTAssertEqual(logged.map(\.type), [.bidRequest, .bidResponse, .noBid])
        XCTAssertEqual(logged.last?.resultCode, "NO_BIDS")
        XCTAssertEqual(requests, 1)
        response(.failure(NSError(domain: "google", code: 1)))
        XCTAssertEqual(logged.count, 3)
    }

    func testCancelledAuctionDropsLateAnalyticsAndGoogleLoad() {
        var logged: [AUEventDomain] = []
        var reply: ((ResultCode) -> Void)?
        owner.analytics = { logged.append($0) }
        owner.demand = { _, _, completion in reply = completion }
        owner.preload { _ in }
        owner.destroy()
        reply?(.prebidDemandFetchSuccess)
        XCTAssertEqual(logged.map(\.type), [.bidRequest])
        XCTAssertEqual(requests, 0)
    }

}
