import Foundation
import XCTest
@testable import AudienzziOSSDK

/// ws-sdk-config moved to `sdks/{sdkId}`; `publishers/` stays only for released SDKs. The config's
/// own `sdkId` is what analytics reports as `sdk_id`.
final class SdkConfigRouteTests: XCTestCase {
    private final class StubProtocol: URLProtocol {
        static var statusForPath: ((String) -> Int)!
        static var requested: [String] = []
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let path = request.url!.path
            Self.requested.append(path)
            let status = Self.statusForPath(path)
            let body = path.hasSuffix("ad-configs") ? Data("[]".utf8) : SdkConfigRouteTests.publisherJSON(sdkId: "\"35\"")
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
                                                                  httpVersion: nil, headerFields: nil)!,
                                cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private var fetcher: RemoteConfigFetcher!
    private let base = URL(string: "https://config.test/public/v1")!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self] // Never call the real config service.
        fetcher = RemoteConfigFetcher(session: URLSession(configuration: config))
        StubProtocol.requested = []
    }

    override func tearDown() {
        StubProtocol.statusForPath = nil
        AUAnalyticsContext.shared.configure(publisherId: nil, environment: "production")
        super.tearDown()
    }

    static func publisherJSON(sdkId: String?) -> Data {
        let field = sdkId.map { "\"sdkId\":\($0)," } ?? ""
        return Data("""
        {"id":35,\(field)"prebidServer":{"url":"https://pbs.test","accountId":1,"statusUrl":"https://pbs.test/status"}}
        """.utf8)
    }

    func testReadsTheSdksRoute() async throws {
        StubProtocol.statusForPath = { _ in 200 }
        let config = try await fetcher.fetchPublisherConfig(remoteUrl: base, publisherId: "35")
        _ = try await fetcher.fetchAdUnitConfigs(remoteUrl: base, publisherId: "35")
        XCTAssertEqual(StubProtocol.requested, ["/public/v1/sdks/35", "/public/v1/sdks/35/ad-configs"])
        XCTAssertEqual(config.sdkId, "35")
    }

    func testAServerWithoutTheSdksRouteFallsBackToPublishers() async throws {
        StubProtocol.statusForPath = { $0.contains("/sdks/") ? 404 : 200 }
        _ = try await fetcher.fetchPublisherConfig(remoteUrl: base, publisherId: "35")
        _ = try await fetcher.fetchAdUnitConfigs(remoteUrl: base, publisherId: "35")
        XCTAssertEqual(StubProtocol.requested, ["/public/v1/sdks/35", "/public/v1/publishers/35",
                                                "/public/v1/sdks/35/ad-configs", "/public/v1/publishers/35/ad-configs"])
    }

    func testAnyOtherFailureIsNotRetriedOnTheOldRoute() async {
        StubProtocol.statusForPath = { _ in 500 }
        do {
            _ = try await fetcher.fetchPublisherConfig(remoteUrl: base, publisherId: "35")
            XCTFail("A server error must surface")
        } catch {}
        XCTAssertEqual(StubProtocol.requested, ["/public/v1/sdks/35"])
    }

    func testSdkIdDecodesFromAStringOrANumberAndSurvivesTheCache() throws {
        let decode = { try JSONDecoder().decode(RemotePublisherConfiguration.self, from: Self.publisherJSON(sdkId: $0)) }
        XCTAssertEqual(try decode("\"sdk-7\"").sdkId, "sdk-7")
        XCTAssertEqual(try decode("35").sdkId, "35")
        XCTAssertNil(try decode(nil).sdkId)
        XCTAssertNil(try decode("\" \"").sdkId)
        XCTAssertNil(try decode("null").sdkId)
        let cached = try JSONDecoder().decode(RemotePublisherConfiguration.self,
                                              from: JSONEncoder().encode(try decode("\"sdk-7\"")))
        XCTAssertEqual(cached.sdkId, "sdk-7")
    }

    func testAnalyticsReportsTheConfigsSdkIdAndOtherwiseKeepsTheInitId() throws {
        AUAnalyticsContext.shared.setPublisherId("init-id")
        Audienzz.shared.applyConfiguredSdkId(nil)
        XCTAssertEqual(AUAnalyticsContext.shared.snapshot().publisherId, "init-id")
        Audienzz.shared.applyConfiguredSdkId(try JSONDecoder().decode(RemotePublisherConfiguration.self,
                                                                       from: Self.publisherJSON(sdkId: nil)))
        XCTAssertEqual(AUAnalyticsContext.shared.snapshot().publisherId, "init-id")
        Audienzz.shared.applyConfiguredSdkId(try JSONDecoder().decode(RemotePublisherConfiguration.self,
                                                                       from: Self.publisherJSON(sdkId: "\"sdk-7\"")))
        XCTAssertEqual(AUAnalyticsContext.shared.snapshot().publisherId, "sdk-7")
    }
}
