import XCTest
import UIKit
import PrebidMobile
import GoogleMobileAds
@_spi(AudienzzBridge) @testable import AudienzziOSSDK

/// Interstitial formats and API frameworks are backend-controlled (`prebidConfig.format`,
/// `prebidConfig.apis`), validated identically on every platform, and resolved per accepted load.
final class InterstitialCapabilitiesTests: AudienzzLifecycleTestCase {

    private typealias Caps = AUInterstitialCapabilities

    // MARK: - Validation table (the same rows are asserted by Android's InterstitialCapabilitiesTest)

    private static let table: [(format: String?, apis: [Int]?, expectFormat: Caps.Format, expectApis: [Int])] = [
        (nil, nil, .bannerAndVideo, [3, 5, 6, 7]),
        ("banner", [7], .banner, [7]),
        ("video", [3, 7], .video, [3, 7]),
        ("bannerAndVideo", [5], .bannerAndVideo, [5]),
        ("BANNER", nil, .bannerAndVideo, [3, 5, 6, 7]),
        ("native", [3], .bannerAndVideo, [3]),
        ("", [], .bannerAndVideo, [3, 5, 6, 7]),
        (nil, [1, 2, 4], .bannerAndVideo, [3, 5, 6, 7]),
        (nil, [7, 3, 7, 99], .bannerAndVideo, [7, 3]),
        (nil, [-1, 0], .bannerAndVideo, [3, 5, 6, 7]),
    ]

    func testTheSharedValidationTable() {
        for row in Self.table {
            let caps = Caps.resolve(format: row.format, apis: row.apis)
            XCTAssertEqual(caps.format, row.expectFormat, "format for \(String(describing: row.format))")
            XCTAssertEqual(caps.apis, row.expectApis, "apis for \(String(describing: row.apis))")
        }
    }

    // MARK: - Decoding the backend payload

    private func decode(_ prebidConfig: String) throws -> RemoteAdConfiguration {
        let json = """
        {"id": 47, "config": {"adType": "interstitial"},
         "gamConfig": {"adUnitPath": "/1/int", "adSizes": ["320x480"]},
         "prebidConfig": \(prebidConfig)}
        """
        return try JSONDecoder().decode(RemoteAdConfiguration.self, from: Data(json.utf8))
    }

    func testTheSchemaDecodes() throws {
        let config = try decode(#"{"placementId": "p", "adSizes": ["320x480"], "format": "video", "apis": [7, 3]}"#)
        XCTAssertEqual(config.config.adType, "interstitial", "the placement type stays separate from its format")
        XCTAssertEqual(Caps.resolve(config.prebidConfig), Caps(format: .video, apis: [7, 3]))
    }

    func testMalformedValuesFallBackWithoutFailingTheConfig() throws {
        let wrongTypes = try decode(#"{"placementId": "p", "adSizes": [], "format": 5, "apis": "3,5"}"#)
        XCTAssertNil(wrongTypes.prebidConfig.format)
        XCTAssertNil(wrongTypes.prebidConfig.apis)
        XCTAssertEqual(Caps.resolve(wrongTypes.prebidConfig), .default)

        let mixed = try decode(#"{"placementId": "p", "adSizes": [], "apis": [3, "5", true, 6.5, 7.0, null]}"#)
        XCTAssertEqual(mixed.prebidConfig.apis, [3, 7], "only integral numbers survive")

        let nulls = try decode(#"{"placementId": "p", "adSizes": [], "format": null, "apis": null}"#)
        XCTAssertEqual(Caps.resolve(nulls.prebidConfig), .default)
    }

    /// One malformed interstitial must not cost the publisher its other placements.
    func testAMalformedInterstitialDoesNotBreakOtherConfigs() throws {
        let json = """
        [{"id": 47, "config": {"adType": "interstitial"},
          "gamConfig": {"adUnitPath": "/1/int", "adSizes": ["320x480"]},
          "prebidConfig": {"placementId": "p", "adSizes": ["320x480"], "format": ["banner"], "apis": {"a": 1}}},
         {"id": 46, "config": {"adType": "banner"},
          "gamConfig": {"adUnitPath": "/1/ban", "adSizes": ["320x50"]},
          "prebidConfig": {"placementId": "q", "adSizes": ["320x50"]}}]
        """
        let configs = try JSONDecoder().decode([RemoteAdConfiguration].self, from: Data(json.utf8))
        XCTAssertEqual(configs.map(\.id), ["47", "46"])
        XCTAssertEqual(Caps.resolve(configs[0].prebidConfig), .default)
    }

    func testTheValuesSurviveTheLocalCache() throws {
        let config = try decode(#"{"placementId": "p", "adSizes": [], "format": "banner", "apis": [7]}"#)
        let cached = try JSONDecoder().decode(RemoteAdConfiguration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(Caps.resolve(cached.prebidConfig), Caps(format: .banner, apis: [7]))
    }

    // MARK: - What the remote interstitial requests

    private final class Ad: NSObject, AUInterstitialPresenting, FullScreenPresentingAd {
        weak var delegate: FullScreenContentDelegate?
        var responseID: String? = "google-response"
        var googleAd: FullScreenPresentingAd? { self }
        var fullScreenContentDelegate: FullScreenContentDelegate? {
            get { delegate }
            set { delegate = newValue }
        }
        func canPresent(from controller: UIViewController?) throws {}
        func present(from controller: UIViewController?) {}
    }

    private struct Sent {
        let formats: Set<PrebidMobile.AdFormat>
        let bannerApi: [Int]?
        let videoApi: [Int]?
        let videoMimes: [String]
        let videoPlacement: Int?
    }

    private var owner: AURemoteConfigInterstitial!
    private var backend = Caps.default
    private var capabilityReads = 0
    private var requests: [Sent] = []
    private var response: ((Result<AUInterstitialPresenting, Error>) -> Void)?
    private var events: [[String: Any]] = []

    override func setUp() {
        super.setUp()
        backend = .default; capabilityReads = 0; requests = []; response = nil; events = []
        owner = AURemoteConfigInterstitial(adConfigId: "caps")
        owner.configuration = { _ in ("caps", "/gam/int", [CGSize(width: 320, height: 480)]) }
        owner.capabilities = { [unowned self] _ in capabilityReads += 1; return backend }
        owner.isForeground = { true }
        owner.demand = { [unowned self] unit, _, reply in
            requests.append(Sent(formats: unit.adFormats,
                                 bannerApi: unit.bannerParameters.api?.map(\.value),
                                 videoApi: unit.videoParameters.api?.map(\.value),
                                 videoMimes: unit.videoParameters.mimes,
                                 videoPlacement: unit.videoParameters.placement?.value))
            reply(.prebidDemandFetchSuccess)
        }
        owner.loadOverride = { [unowned self] in response = $0 }
        owner.onLifecycleEvent = { [unowned self] in events.append($0) }
    }

    override func tearDown() {
        owner.finishPresentation()
        owner.destroy()
        owner = nil
        super.tearDown()
    }

    func testWithNoConfigurationItAsksForBannerAndVideoWithEveryApi() {
        owner.prefetch { _ in }
        let sent = try? XCTUnwrap(requests.first)
        XCTAssertEqual(sent?.formats, [.banner, .video])
        XCTAssertEqual(sent?.bannerApi, [3, 5, 6, 7])
        XCTAssertEqual(sent?.videoApi, [3, 5, 6, 7])
        XCTAssertEqual(sent?.videoMimes, ["video/mp4"], "a video request is always playable")
        XCTAssertEqual(sent?.videoPlacement, 5, "interstitial placement")
    }

    func testTheBackendChoosesFormatAndApis() {
        backend = Caps.resolve(format: "banner", apis: [7])
        owner.prefetch { _ in }
        XCTAssertEqual(requests.first?.formats, [.banner])
        XCTAssertEqual(requests.first?.bannerApi, [7])
    }

    func testAVideoOnlyBackendAsksForVideoOnly() {
        backend = Caps.resolve(format: "video", apis: [3, 7])
        owner.prefetch { _ in }
        XCTAssertEqual(requests.first?.formats, [.video])
        XCTAssertEqual(requests.first?.videoApi, [3, 7])
    }

    /// Point 5: resolved once per accepted load, and a config change never touches what is held.
    func testAConfigChangeNeitherDiscardsReadyInventoryNorRequests() {
        owner.prefetch { _ in }
        owner.prefetch { _ in }
        XCTAssertEqual(capabilityReads, 1, "coalesced prefetches resolve nothing new")
        response?(.success(Ad()))
        XCTAssertTrue(owner.isReady)

        backend = Caps.resolve(format: "banner", apis: [7])
        owner.prefetch { _ in }

        XCTAssertTrue(owner.isReady, "the ready ad is kept")
        XCTAssertEqual(requests.count, 1, "no request because the config changed")
        XCTAssertEqual(capabilityReads, 1)
        XCTAssertFalse(events.contains { $0["event"] as? String == "discardedWithoutImpression" })
    }

    func testAConfigChangeDoesNotInterruptAPresentation() {
        owner.prefetch { _ in }
        let ad = Ad()
        response?(.success(ad))
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        owner.adWillPresentFullScreenContent(ad)

        backend = Caps.resolve(format: "video", apis: [7])
        owner.prefetch { _ in }

        XCTAssertEqual(requests.count, 1, "nothing is requested over a presentation")
        XCTAssertEqual(capabilityReads, 1)
        XCTAssertFalse(events.contains { $0["event"] as? String == "dismissed" }, "still on screen")
    }

    func testTheNextAcceptedLoadUsesTheNewConfig() {
        owner.prefetch { _ in }
        let ad = Ad()
        response?(.success(ad))
        XCTAssertTrue(owner.show(from: UIViewController(), eligible: true))
        owner.adWillPresentFullScreenContent(ad)
        owner.adDidDismissFullScreenContent(ad)

        backend = Caps.resolve(format: "banner", apis: [7])
        owner.prefetch { _ in }

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.formats, [.banner])
        XCTAssertEqual(requests.last?.bannerApi, [7])
    }

    func testAnalyticsDescribeTheFormatThatWasRequested() {
        var subtypes: [String?] = []
        owner.analytics = { subtypes.append($0.adSubtype) }
        backend = Caps.resolve(format: "banner", apis: nil)
        owner.prefetch { _ in }
        XCTAssertFalse(subtypes.isEmpty)
        XCTAssertTrue(subtypes.allSatisfy { $0 == AUAdSubtype.html }, "\(subtypes)")
    }

    // MARK: - Hand-built interstitials cannot override

    private func handBuiltRequest(configure: (AUInterstitialView) -> Void) -> (InterstitialAdUnit?, String?) {
        Audienzz.shared.pageImpression("caps")
        let view = AUInterstitialView(configId: "probe", isLazyLoad: false)
        defer { view.destroy() }
        configure(view)
        var unit: InterstitialAdUnit?
        var ortb: String?
        view.demand = { captured, _, _ in unit = captured; ortb = captured.getImpORTBConfig() }
        view.createAd(with: AdManagerRequest(), adUnitID: "/gam/int")
        return (unit, ortb)
    }

    func testPublisherApiSettingsAreIgnored() throws {
        let (unit, _) = handBuiltRequest { view in
            view.bannerParameters.api = [AUApi(apiType: .VPAID_1)]
            let video = AUVideoParameters(mimes: ["video/mp4"])
            video.api = [AUApi(apiType: .VPAID_2)]
            video.maxDuration = 42
            view.videoParameters = video
        }
        let sent = try XCTUnwrap(unit, "control: a request was made")
        XCTAssertEqual(sent.adFormats, [.banner, .video])
        XCTAssertEqual(sent.bannerParameters.api?.map(\.value), [3, 5, 6, 7])
        XCTAssertEqual(sent.videoParameters.api?.map(\.value), [3, 5, 6, 7])
        XCTAssertEqual(sent.videoParameters.maxDuration?.value, 42, "unrelated video settings are kept")
    }

    func testImpOrtbCannotOverrideTheApiListOrAddAFormat() throws {
        Audienzz.shared.pageImpression("caps")
        let view = AUInterstitialView(configId: "probe", isLazyLoad: false)
        defer { view.destroy() }
        view.setImpOrtbConfig(ortbConfig: #"{"banner":{"api":[1],"format":[{"w":320,"h":480}]},"video":{"api":[2]},"ext":{"k":"v"}}"#)
        view.setBackendCapabilities(format: "banner", apis: [7])
        var ortb: String?
        var unit: InterstitialAdUnit?
        view.demand = { captured, _, _ in unit = captured; ortb = captured.getImpORTBConfig() }
        view.createAd(with: AdManagerRequest(), adUnitID: "/gam/int")

        XCTAssertEqual(unit?.adFormats, [.banner])
        XCTAssertEqual(unit?.bannerParameters.api?.map(\.value), [7])
        let imp = try XCTUnwrap(ortb.flatMap { try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })
        let banner = try XCTUnwrap(imp["banner"] as? [String: Any])
        XCTAssertNil(banner["api"])
        XCTAssertNotNil(banner["format"], "the sizes the React Native bridge sends this way are kept")
        XCTAssertNil(imp["video"], "a banner-only interstitial cannot be made to request video")
        XCTAssertNotNil(imp["ext"])
    }

    func testBridgeValuesAreValidatedLikeTheBackend() {
        let (unit, _) = handBuiltRequest { $0.setBackendCapabilities(format: "native", apis: [1, 2]) }
        XCTAssertEqual(unit?.adFormats, [.banner, .video])
        XCTAssertEqual(unit?.bannerParameters.api?.map(\.value), [3, 5, 6, 7])
    }

    func testUnparseableImpOrtbIsDropped() {
        XCTAssertNil(Caps.sanitizedImpORTB("{not json", for: .bannerAndVideo))
        XCTAssertNil(Caps.sanitizedImpORTB(nil, for: .bannerAndVideo))
    }
}
