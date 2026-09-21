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
    func testPrefetchAndShowPresentsOnceEvenIfTheCompletionAlsoShows() {
        let ad = Ad()
        owner.prefetchAndShow(from: UIViewController()) { [unowned self] _ in
            owner.show(from: UIViewController())
        }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 1)
        XCTAssertFalse(owner.isReady)
        XCTAssertNotNil(ad.delegate)
        XCTAssertEqual(events.prefix(3), ["loadRequested", "loaded", "showAttempted"])
    }
    /// The contract this API exists for: the verb decides whether anything is presented.
    func testPrefetchNeverPresentsAndPrefetchAndShowDoes() {
        let prefetched = Ad()
        owner.prefetch { _ in }
        response(.success(prefetched))
        XCTAssertEqual(prefetched.shows, 0, "a prefetch must not present")
        XCTAssertTrue(owner.isReady)

        // Already in hand: prefetchAndShow reuses it rather than buying another request.
        owner.prefetchAndShow(from: UIViewController()) { _ in }
        XCTAssertEqual(prefetched.shows, 1)
        XCTAssertEqual(requests, 1)
    }
    func testRepeatedPrefetchReusesReadyInventoryWithoutAnotherRequest() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        var second: Result<Void, Error>?
        owner.prefetch { second = $0 }
        guard case .success = second else { return XCTFail("ready inventory must satisfy a prefetch") }
        XCTAssertTrue(owner.isReady)
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(ad.shows, 0)
    }
    func testConcurrentPrefetchAndShowCoalescesOntoOneRequestAndShowsOnce() {
        let ad = Ad()
        var completions = 0
        owner.prefetch { _ in completions += 1 }
        owner.prefetchAndShow(from: UIViewController()) { _ in completions += 1 }
        owner.prefetchAndShow(from: UIViewController()) { _ in completions += 1 }
        XCTAssertEqual(requests, 1, "repeated calls must share the load in flight")
        response(.success(ad))
        XCTAssertEqual(completions, 3)
        XCTAssertEqual(ad.shows, 1, "one presentation, not one per caller")
    }
    func testExpiryIsRejectedAndCanBeReloaded() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        time = 3600
        XCTAssertFalse(owner.isReady)
        var skipped: String?
        owner.onLifecycleEvent = { event in
            if event["event"] as? String == "opportunitySkipped" { skipped = event["reason"] as? String }
        }
        XCTAssertFalse(owner.show(from: UIViewController()))
        XCTAssertEqual(ad.shows, 0)
        XCTAssertEqual(skipped, "notReady", "the outcome is reported, not swallowed")
        owner.prefetch { _ in }
        XCTAssertEqual(requests, 2)
    }
    /// An explicit show at an opportunity the publisher rules out reports that and stops. It must
    /// not become a presentation later, when the reader is somewhere else entirely.
    func testIneligibleShowIsReportedAndNeverQueued() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        var skips: [String] = []
        owner.onLifecycleEvent = { event in
            if event["event"] as? String == "opportunitySkipped",
               let reason = event["reason"] as? String { skips.append(reason) }
        }
        XCTAssertFalse(owner.show(from: UIViewController(), eligible: false))
        XCTAssertEqual(skips, ["ineligible"])
        XCTAssertEqual(ad.shows, 0)
        XCTAssertTrue(owner.isReady, "the ad is kept for a later opportunity")
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        XCTAssertEqual(ad.shows, 1)
    }
    func testRepeatedShowCannotPresentTwice() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        XCTAssertTrue(owner.show(from: UIViewController()))
        XCTAssertFalse(owner.show(from: UIViewController()))
        XCTAssertFalse(owner.show(from: UIViewController()))
        XCTAssertEqual(ad.shows, 1)
    }
    func testDestroyedLoadCompletesOnceAndDropsLateGoogleAd() {
        var completions = 0
        owner.prefetch { result in
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
        instance?.prefetch { _ in completions += 1 }
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
        // A presentation has to be attempted for a preflight error to exist at all.
        owner.prefetchAndShow(from: UIViewController()) { _ in }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 0)
        XCTAssertEqual(error?.domain, "google.test")
        XCTAssertEqual(error?.code, 7)
    }
    /// A call that is REJECTED must leave nothing behind. Remembering the presentation on the way
    /// out let an unrelated later `prefetch` present on its back, which is the one thing a prefetch
    /// promises never to do.
    func testRejectedPrefetchAndShowLeavesNoPresentationIntent() {
        let first = Ad()
        owner.prefetchAndShow(from: UIViewController()) { _ in }
        response(.success(first))
        XCTAssertEqual(first.shows, 1, "control: the first request really did present")

        // Asked for again while that ad is on screen: rejected.
        var rejected = false
        owner.prefetchAndShow(from: UIViewController()) { if case .failure = $0 { rejected = true } }
        XCTAssertTrue(rejected)

        owner.finishPresentation()

        let second = Ad()
        owner.prefetch { _ in }
        response(.success(second))
        XCTAssertEqual(second.shows, 0,
                       "a plain prefetch must not inherit a rejected request's presentation")
        XCTAssertTrue(owner.isReady)
    }

    /// The completion of `prefetchAndShow` may present the ad itself. The outer call must then do
    /// nothing — it must NOT treat "already presenting" as a failed presentation, because clearing
    /// `loadedAd` orphans the ad that is on screen and every delegate callback, dismissal included,
    /// is then ignored.
    func testCompletionThatShowsCachedInventoryKeepsOwnershipOfTheOnScreenAd() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        XCTAssertTrue(owner.isReady, "control: inventory is in hand before the request")

        var presentationErrors = 0
        owner.onPresentationError = { _ in presentationErrors += 1 }
        owner.prefetchAndShow(from: UIViewController()) { [unowned self] _ in
            owner.show(from: UIViewController())
        }
        XCTAssertEqual(ad.shows, 1)
        XCTAssertEqual(presentationErrors, 0,
                       "the ad IS on screen; that is not a presentation failure")

        // The owner still owns it, so Google's terminal callback is observed.
        owner.adDidDismissFullScreenContent(ad)
        XCTAssertFalse(owner.isReady)

        // And loading is not blocked afterwards.
        let next = Ad()
        owner.prefetch { _ in }
        response(.success(next))
        XCTAssertTrue(owner.isReady)
        XCTAssertEqual(requests, 2)
    }

    func testNoAutomaticPresentationAfterPublisherCancelsInLoadedCallback() {
        let ad = Ad()
        owner.prefetchAndShow(from: UIViewController()) { [unowned self] _ in owner.destroy() }
        response(.success(ad))
        XCTAssertEqual(ad.shows, 0)
    }
    func testInactiveAppFailsShowWithoutMisreportingLoadFailure() {
        owner.isForeground = { false }
        let ad = Ad()
        var loaded = false
        var showFailed = false
        owner.onPresentationError = { _ in showFailed = true }
        owner.prefetchAndShow(from: UIViewController()) { loaded = (try? $0.get()) != nil }
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
        owner.prefetch { _ in completions += 1 }
        owner.prefetch { _ in completions += 1 }
        XCTAssertFalse(owner.show(from: UIViewController(), eligible: true))
        let ad = Ad()
        response(.success(ad))
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(ad.shows, 0)
        owner.prefetch { _ in completions += 1 }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(completions, 3)
        XCTAssertFalse(owner.show(from: UIViewController(), eligible: false))
        XCTAssertTrue(owner.isReady)
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        XCTAssertFalse(owner.show(from: UIViewController(), eligible: true))
        XCTAssertEqual(ad.shows, 1)
    }

    func testPreloadSurvivesInactiveOpportunityWithoutAnAutomaticForegroundShow() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        owner.isForeground = { false }
        XCTAssertFalse(owner.show(from: UIViewController(), eligible: true))
        XCTAssertTrue(owner.isReady)
        owner.isForeground = { true }
        XCTAssertEqual(ad.shows, 0)
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
    }

    func testExpiredPreloadDoesNotCreateRequestUntilExplicitPreload() {
        owner.prefetch { _ in }
        response(.success(Ad()))
        time = 3600
        XCTAssertFalse(owner.show(from: UIViewController(), eligible: true))
        XCTAssertEqual(requests, 1)
        owner.prefetch { _ in }
        XCTAssertEqual(requests, 2)
    }

    func testPreloadCancellationCompletesEveryWaiterOnce() {
        var cancellations = 0
        owner.prefetch { if case .failure = $0 { cancellations += 1 } }
        owner.prefetch { if case .failure = $0 { cancellations += 1 } }
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
        instance?.prefetch { if case .failure = $0 { resultCount += 1 } }
        instance = nil
        pending?(.success(Ad()))
        XCTAssertEqual(resultCount, 1)
    }

    func testAnotherPresentationSkipsOpportunityAndPreservesPreload() {
        owner.prefetch { _ in }
        response(.success(Ad()))
        let second = AURemoteConfigInterstitial(adConfigId: "second")
        let ad = Ad()
        second.isForeground = { true }
        stubDemand(second)
        second.loadOverride = { $0(.success(ad)) }
        second.prefetch { _ in }
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        XCTAssertFalse(second.show(from: UIViewController(), eligible: true))
        XCTAssertTrue(second.isReady)
        owner.finishPresentation()
        XCTAssertTrue(second.show(from: UIViewController(), eligible: true))
        second.finishPresentation()
        second.destroy()
    }

    /// A prefetch issued while an earlier prefetchAndShow has already completed must not inherit
    /// that request's presentation.
    func testPresentationIntentDoesNotLeakToTheNextPrefetch() {
        let first = Ad()
        owner.prefetchAndShow(from: UIViewController()) { _ in }
        response(.success(first))
        XCTAssertEqual(first.shows, 1)
        owner.finishPresentation()

        let second = Ad()
        owner.prefetch { _ in }
        response(.success(second))
        XCTAssertEqual(second.shows, 0, "a prefetch must never present")
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
        owner.prefetch { _ in }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(logged.map(\.type), [.bidRequest, .bidResponse, .bidWon])
        XCTAssertEqual(logged.first?.mediaTypes, "[\"banner\",\"video\"]")
        let auction = logged.first?.auctionId
        let ad = Ad()
        response(.success(ad))
        XCTAssertFalse(logged.contains { $0.type == .adImpression })
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
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
        owner.prefetch { _ in }
        XCTAssertNotEqual(logged.last?.auctionId, auction)
    }

    func testNoBidStillLoadsGoogleWithoutInventingAnImpression() {
        var logged: [AUEventDomain] = []
        owner.analytics = { logged.append($0) }
        owner.prefetch { _ in }
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
        owner.prefetch { _ in }
        owner.destroy()
        reply?(.prebidDemandFetchSuccess)
        XCTAssertEqual(logged.map(\.type), [.bidRequest])
        XCTAssertEqual(requests, 0)
    }

}
