import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@testable import AudienzziOSSDK

/// Inventory that loads and is then released without ever being seen is the load-to-impression
/// gap. `loaded` with no matching `impression` was silent, and expiry in particular was only
/// evaluated lazily inside `isReady`, so an ad could age out with nothing recorded anywhere.
final class InterstitialDiscardTests: AudienzzLifecycleTestCase {

    private final class Ad: NSObject, AUInterstitialPresenting, FullScreenPresentingAd {
        weak var delegate: FullScreenContentDelegate?
        var responseID: String? = "google-response"
        var googleAd: FullScreenPresentingAd? { self }
        var fullScreenContentDelegate: FullScreenContentDelegate? {
            get { delegate }
            set { delegate = newValue }
        }
        var presentError: Error?
        func canPresent(from controller: UIViewController?) throws {
            if let presentError { throw presentError }
        }
        func present(from controller: UIViewController?) {}
    }

    private var owner: AURemoteConfigInterstitial!
    private var response: ((Result<AUInterstitialPresenting, Error>) -> Void)!
    private var events: [[String: Any]] = []
    private var time: TimeInterval = 0

    override func setUp() {
        super.setUp()
        events = []; time = 0
        owner = AURemoteConfigInterstitial(adConfigId: "probe")
        owner.configuration = { _ in ("probe", "/gam/remote-interstitial", [CGSize(width: 320, height: 480)]) }
        owner.demand = { _, _, reply in reply(.prebidDemandFetchSuccess) }
        owner.now = { [unowned self] in time }
        owner.isForeground = { true }
        owner.loadOverride = { [unowned self] in response = $0 }
        owner.onLifecycleEvent = { [unowned self] in events.append($0) }
    }

    override func tearDown() {
        defer { super.tearDown() }
        owner.finishPresentation()
        owner.destroy()
        owner = nil; response = nil
    }

    // MARK: - Helpers

    private var discards: [[String: Any]] {
        events.filter { $0["event"] as? String == "discardedWithoutImpression" }
    }

    private func names() -> [String] {
        events.compactMap { $0["event"] as? String }
    }

    private func hold() {
        owner.prefetch { _ in }
        response(.success(Ad()))
        XCTAssertTrue(owner.isReady, "fixture must actually hold inventory")
    }

    // MARK: - Discards

    func testExpiryReportsTheDiscardExactlyOnce() {
        hold()
        XCTAssertTrue(discards.isEmpty, "control: held inventory is not a discard")

        time += 3601
        owner.prefetch { _ in }   // observing the expiry is what releases it

        XCTAssertEqual(discards.count, 1)
        XCTAssertEqual(discards.first?["reason"] as? String, "expired")
        XCTAssertGreaterThan(discards.first?["loadAgeMillis"] as? Int ?? 0, 3_600_000)
    }

    func testDisposalOfHeldInventoryReportsADiscard() {
        hold()
        owner.destroy()
        XCTAssertEqual(discards.count, 1)
        XCTAssertEqual(discards.first?["reason"] as? String, "disposed")
    }

    func testABridgeCanReportAReplacementInsteadOfADisposal() {
        hold()
        owner.destroy(reason: "replaced")
        XCTAssertEqual(discards.count, 1)
        XCTAssertEqual(discards.first?["reason"] as? String, "replaced")
    }

    func testAPresentationFailureReportsADiscard() {
        hold()
        let ad = Ad()
        ad.presentError = NSError(domain: "test", code: 1)
        owner.destroy()
        events = []
        owner.prefetch { _ in }
        response(.success(ad))
        owner.show(from: UIViewController(), eligible: true)

        XCTAssertTrue(names().contains("showFailed"))
        XCTAssertEqual(discards.count, 1)
        XCTAssertEqual(discards.first?["reason"] as? String, "presentationFailed")
    }

    func testPresentedAndDismissedWithNoImpressionReportsADiscard() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        owner.adWillPresentFullScreenContent(ad)
        owner.adDidDismissFullScreenContent(ad)

        XCTAssertEqual(discards.count, 1)
        XCTAssertEqual(discards.first?["reason"] as? String, "dismissedWithoutImpression")
    }

    // MARK: - Non-discards

    func testInventoryThatRecordedAnImpressionIsNeverADiscard() {
        let ad = Ad()
        owner.prefetch { _ in }
        response(.success(ad))
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        owner.adWillPresentFullScreenContent(ad)
        owner.adDidRecordImpression(ad)
        owner.adDidDismissFullScreenContent(ad)

        XCTAssertTrue(names().contains("impression"))
        XCTAssertTrue(discards.isEmpty, "inventory that was seen was not wasted")
    }

    func testALoadFailureIsNotAnUnusedSuccessfulLoad() {
        owner.prefetch { _ in }
        response(.failure(NSError(domain: "test", code: 3)))
        owner.destroy()

        XCTAssertTrue(names().contains("loadFailed"))
        XCTAssertTrue(discards.isEmpty, "there was never any inventory to waste")
    }

    func testAnOwnerHoldingNothingReportsNoDiscardOnDisposal() {
        owner.destroy()
        XCTAssertTrue(discards.isEmpty)
    }

    // MARK: - Payload

    func testEveryDiscardCarriesTheLoadIdAndAnAge() {
        hold()
        let loadId = events.first(where: { $0["event"] as? String == "loaded" })?["loadId"] as? String
        XCTAssertNotNil(loadId)
        time += 300
        owner.destroy()

        let discard = try? XCTUnwrap(discards.first)
        XCTAssertEqual(discard?["loadId"] as? String, loadId,
                       "the discard must be correlatable with its load")
        XCTAssertEqual(discard?["loadAgeMillis"] as? Int, 300_000)
        XCTAssertEqual(discard?["configId"] as? String, "probe")
    }
}
