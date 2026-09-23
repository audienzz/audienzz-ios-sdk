import XCTest
import GoogleMobileAds
@testable import AudienzziOSSDK

/// The SDK-owned GAM targeting key.
///
/// Ad-ops line items and reporting are keyed on this, so its exact shape is a contract with people
/// outside this repository — worth a test rather than a comment. Android asserts the same four
/// things about the identical shape.
final class CustomTargetingManagerTests: XCTestCase {

    private func applied(_ manager: CustomTargetingManager) -> [String: String] {
        let request = manager.applyToGamRequest(request: AdManagerRequest())
        return (request.customTargeting as? [String: String]) ?? [:]
    }

    func testPlatformAndVersionAreOneKey() {
        let keys = applied(CustomTargetingManager(sdkPlatform: "ios", sdkVersion: "0.3.2"))
        XCTAssertEqual(keys["au_sdk"], "ios-0.3.2")
    }

    func testTheSeparateVersionKeyIsGone() {
        let keys = applied(CustomTargetingManager(sdkPlatform: "ios", sdkVersion: "0.3.2"))
        // Anything in Ad Manager keyed on au_v has to move to au_sdk matching <platform>-<version>.
        XCTAssertNil(keys["au_v"])
    }

    func testAnUnresolvedVersionLeavesTheBarePlatformRatherThanATrailingDash() {
        let keys = applied(CustomTargetingManager(sdkPlatform: "ios", sdkVersion: ""))
        XCTAssertEqual(keys["au_sdk"], "ios")
    }

    func testPublisherTargetingStillTravelsAndCannotOverwriteTheSDKKey() {
        let manager = CustomTargetingManager(sdkPlatform: "ios", sdkVersion: "0.3.2")
        manager.addCustomTargeting(key: "section", value: "sport")
        manager.addCustomTargeting(key: "au_sdk", value: "spoofed")
        let keys = applied(manager)
        XCTAssertEqual(keys["section"], "sport")
        XCTAssertEqual(keys["au_sdk"], "ios-0.3.2")
    }
}
