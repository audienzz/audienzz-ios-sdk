import XCTest
@testable import AudienzziOSSDK

final class AnalyticsBatchSettingsTests: XCTestCase {
    private func config(_ value: String? = nil) throws -> RemotePublisherConfiguration {
        let field = value.map { ",\"analyticsBatchSize\":" + $0 } ?? ""
        let data = Data("""
        {"id":35,"prebidServer":{"url":"https://example.test","accountId":1,"statusUrl":"https://example.test/status"}\(field)}
        """.utf8)
        return try JSONDecoder().decode(RemotePublisherConfiguration.self, from: data)
    }
    func testOptionalFieldCannotBreakPublisherConfiguration() throws {
        for value in ["null", "\"\"", "\"  \"", "0", "-2", "false", "{}", "[]", "3.5"] {
            let parsed = try config(value)
            XCTAssertEqual(parsed.id, 35)
            XCTAssertEqual(AUAnalyticsBatchSettings.resolve(parsed.analyticsBatchSize), 10, value)
        }
        XCTAssertEqual(AUAnalyticsBatchSettings.resolve(try config().analyticsBatchSize), 10)
        XCTAssertEqual(try config("1").analyticsBatchSize, 1)
        XCTAssertEqual(try config("\" 7 \"").analyticsBatchSize, 7)
        XCTAssertEqual(try config("999").analyticsBatchSize, 15)
    }
    func testCacheRoundTripKeepsBatchSize() throws {
        let cached = try JSONDecoder().decode(RemotePublisherConfiguration.self, from: JSONEncoder().encode(config("8")))
        XCTAssertEqual(cached.analyticsBatchSize, 8)
    }
    func testFlutterBackendEntryPointSetsAndClearsPolicy() {
        defer { Audienzz.shared.applyBackendAnalyticsConfig(batchSize: nil) }
        Audienzz.shared.applyBackendAnalyticsConfig(batchSize: 8)
        XCTAssertEqual(AUAnalyticsBatchSettings.shared.current, 8)
        Audienzz.shared.applyBackendAnalyticsConfig(batchSize: 30)
        XCTAssertEqual(AUAnalyticsBatchSettings.shared.current, 15)
        Audienzz.shared.applyBackendAnalyticsConfig(batchSize: nil)
        XCTAssertEqual(AUAnalyticsBatchSettings.shared.current, 10)
    }
}
