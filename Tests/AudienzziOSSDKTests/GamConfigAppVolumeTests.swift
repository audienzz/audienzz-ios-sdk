import XCTest
@testable import AudienzziOSSDK

/// The backend publisher config sends `gamConfig.appVolume`; the SDK once read `setAppVolume`.
final class GamConfigAppVolumeTests: XCTestCase {
    private func config(_ gamConfig: String) throws -> RemotePublisherConfiguration {
        let data = Data("""
        {"id":35,"prebidServer":{"url":"https://example.test","accountId":1,"statusUrl":"https://example.test/status"},"gamConfig":\(gamConfig)}
        """.utf8)
        return try JSONDecoder().decode(RemotePublisherConfiguration.self, from: data)
    }

    func testReadsTheKeyTheBackendSends() throws {
        XCTAssertEqual(try config(#"{"appVolume":0.4}"#).gamConfig?.appVolume, 0.4)
    }

    func testStillReadsTheLegacyKey() throws {
        XCTAssertEqual(try config(#"{"setAppVolume":0.4}"#).gamConfig?.appVolume, 0.4)
    }

    func testAbsentVolumeIsNil() throws {
        XCTAssertNil(try config("{}").gamConfig?.appVolume)
    }

    func testVolumeSurvivesThePublisherCache() throws {
        let original = try config(#"{"appVolume":0.7}"#)
        let cached = try JSONDecoder().decode(
            RemotePublisherConfiguration.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(cached.gamConfig?.appVolume, 0.7)
    }
}
