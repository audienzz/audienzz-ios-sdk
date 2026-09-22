import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

/// What repeated prefetching costs on the API publishers are required to use.
///
/// One ad is held at a time, an ad older than an hour stops counting as inventory, and prefetching
/// again while one is held or in flight buys nothing.
final class InterstitialPrefetchCacheTests: AudienzzLifecycleTestCase {

    private final class Ad: NSObject, AUInterstitialPresenting, FullScreenPresentingAd {
        weak var delegate: FullScreenContentDelegate?
        var responseID: String? = "google-response"
        var googleAd: FullScreenPresentingAd? { self }
        var fullScreenContentDelegate: FullScreenContentDelegate? {
            get { delegate }
            set { delegate = newValue }
        }
        var shows = 0
        func canPresent(from controller: UIViewController?) throws {}
        func present(from controller: UIViewController?) { shows += 1 }
    }

    private var owner: AURemoteConfigInterstitial!
    private var response: ((Result<AUInterstitialPresenting, Error>) -> Void)!
    private var requests = 0
    private var completions = 0
    private var time: TimeInterval = 0

    override func setUp() {
        super.setUp()
        requests = 0; completions = 0; time = 0
        owner = AURemoteConfigInterstitial(adConfigId: "probe")
        owner.configuration = { _ in ("probe", "/gam/remote-interstitial", [CGSize(width: 320, height: 480)]) }
        owner.demand = { _, _, reply in reply(.prebidDemandFetchSuccess) }
        owner.now = { [unowned self] in time }
        owner.isForeground = { true }
        owner.loadOverride = { [unowned self] in requests += 1; response = $0 }
    }

    override func tearDown() {
        defer { super.tearDown() }
        owner.finishPresentation()
        owner.destroy()
        owner = nil; response = nil
    }

    private func prefetch() {
        owner.prefetch { [unowned self] _ in completions += 1 }
    }

    func testFourPrefetchesInARowBuyOneAd() {
        prefetch(); prefetch(); prefetch(); prefetch()
        XCTAssertEqual(requests, 1, "only the first may reach the ad server")

        response(.success(Ad()))
        XCTAssertTrue(owner.isReady)
        XCTAssertEqual(completions, 4, "every caller is still answered by the one load")
    }

    func testPrefetchingAgainDoesNotReplaceHeldInventory() {
        prefetch()
        response(.success(Ad()))
        XCTAssertTrue(owner.isReady)

        prefetch(); prefetch()

        XCTAssertEqual(requests, 1, "a cached ad is not replaced by another prefetch")
        XCTAssertTrue(owner.isReady)
    }

    func testAnExpiredAdIsReplacedExactlyOnce() {
        prefetch()
        response(.success(Ad()))
        XCTAssertTrue(owner.isReady)

        time += 3601   // past the one-hour expiry
        XCTAssertFalse(owner.isReady, "an ad older than an hour is not inventory")

        prefetch(); prefetch(); prefetch()

        XCTAssertEqual(requests, 2, "expiry allows one replacement, not one per call")
    }
}
