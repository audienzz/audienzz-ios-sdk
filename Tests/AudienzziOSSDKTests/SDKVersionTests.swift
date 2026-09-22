/*   Copyright 2018-2025 Audienzz.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest
import GoogleMobileAds
@testable import AudienzziOSSDK

/// The version the SDK *reports* and the version CocoaPods *publishes* are two independent
/// literals, and nothing else makes them agree.
///
/// When they drift, every ad request and every analytics event is labelled with a version that was
/// never released — and there is no way to tell after the fact, because the label is the only
/// record. `docs/analytics-contract.md` already asks that the constant be bumped in the same commit
/// as the release tag "so the two can never disagree again"; this is what makes that enforceable
/// rather than a note.
///
/// Android needs no equivalent: its version has a single source in `build.gradle.kts`, which feeds
/// both the Maven coordinate and `BuildConfig.AUDIENZZ_SDK_VERSION`.
final class SDKVersionTests: XCTestCase {

    private func podspecText() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // AudienzziOSSDKTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("AudienzziOSSDK.podspec")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func match(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    func testThePodspecVersionIsTheVersionTheSDKReports() throws {
        let text = try podspecText()

        let specVersion = match(#"spec\.version\s*=\s*'([^']+)'"#, in: text)

        XCTAssertEqual(
            specVersion, AUSDKVersion,
            "AudienzziOSSDK.podspec publishes \(specVersion ?? "nil") but every request and event "
                + "is labelled \(AUSDKVersion). Bump both in the same commit."
        )
    }

    func testThePodspecTagIsTheVersionTheSDKReports() throws {
        // The tag is what CocoaPods actually checks out. A tag that disagrees with spec.version
        // ships the wrong source under the right version number.
        let text = try podspecText()

        let tag = match(#":tag\s*=>\s*'([^']+)'"#, in: text)

        XCTAssertEqual(tag, AUSDKVersion, "the podspec's git tag must match the reported version")
    }

    func testTheReportedVersionReachesTheTargetingKey() throws {
        // au_sdk is what Ad Manager line items target, so a stale constant is not just a label.
        let manager = CustomTargetingManager(sdkPlatform: "ios", sdkVersion: AUSDKVersion)
        let request = manager.applyToGamRequest(request: AdManagerRequest())
        let keys = (request.customTargeting as? [String: String]) ?? [:]

        XCTAssertEqual(keys["au_sdk"], "ios-\(AUSDKVersion)")
    }
}
