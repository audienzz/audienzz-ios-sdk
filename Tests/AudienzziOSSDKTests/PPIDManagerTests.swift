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
@testable import AudienzziOSSDK

/// A PPID is sent unless the backend turns it off for this publisher — there is no app-facing
/// opt-out. One switch decides it: `ppidEnabled`, a top-level boolean on `GET /publishers/{id}`.
/// Absent means enabled. The app only decides *which* identifier is used, by supplying its own
/// through `setPublisherPPID`; with none supplied the SDK generates and persists a UUID.
///
/// Getting the default wrong is expensive in both directions: defaulting off silently drops every
/// PPID (exactly what shipped before, costing frequency capping and cross-session targeting), and
/// ignoring the switch keeps sending an identifier for a publisher who has turned it off.
final class PPIDManagerTests: AudienzzLifecycleTestCase {

    private var manager: PPIDManager { PPIDManager.shared }

    override func setUp() {
        super.setUp()
        manager.setPublisherPPID(nil)
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: nil)
    }

    override func tearDown() {
        manager.setPublisherPPID(nil)
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: nil)
        super.tearDown()
    }

    func testGeneratesAPPIDWhenTheBackendSaysNothing() {
        // An absent switch means enabled. This is the default every publisher gets.
        XCTAssertNotNil(manager.getPPID())
    }

    func testKeepsTheSameGeneratedPPIDAcrossCalls() {
        let first = manager.getPPID()

        XCTAssertEqual(first, manager.getPPID())
    }

    func testAPublisherSuppliedPPIDWinsOverTheGeneratedOne() {
        let generated = manager.getPPID()
        manager.setPublisherPPID("hashed-email")

        XCTAssertEqual(manager.getPPID(), "hashed-email")
        XCTAssertNotEqual(generated, "hashed-email")
    }

    func testClearingThePublisherPPIDFallsBackToTheGeneratedOne() {
        let generated = manager.getPPID()
        manager.setPublisherPPID("hashed-email")
        manager.setPublisherPPID(nil)

        XCTAssertEqual(manager.getPPID(), generated)
    }

    func testTheSwitchSuppressesTheGeneratedPPID() {
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: false)

        XCTAssertNil(manager.getPPID())
    }

    func testTheSwitchSuppressesAPublisherSuppliedPPIDToo() {
        // It is a per-publisher privacy switch, so honouring it only for the SDK's own identifier
        // would miss the point entirely.
        manager.setPublisherPPID("hashed-email")
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: false)

        XCTAssertNil(manager.getPPID())
    }

    func testTheSwitchExplicitlySetToTrueBehavesAsEnabled() {
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: true)

        XCTAssertNotNil(manager.getPPID())
    }

    /// `automaticPpidEnabled` is gone from the model. The backend never sent it, but a payload
    /// carrying it must still decode — an unknown key is not an error for `Codable`, and this
    /// pins that nobody reintroduces it as a second gate.
    func testAPublisherConfigCarryingAutomaticPpidEnabledStillDecodesAndIsIgnored() throws {
        let json = """
        {
          "id": 35,
          "prebidServer": {
            "url": "https://ib.adnxs.com/openrtb2/prebid",
            "accountId": 3927,
            "statusUrl": "https://ib.adnxs.com/status"
          },
          "ppidEnabled": true,
          "automaticPpidEnabled": false
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(RemotePublisherConfiguration.self, from: json)

        XCTAssertEqual(config.ppidEnabled, true)

        // Re-encoding is what discriminates: a model that still carried the field would decode
        // this payload just as happily and write the key straight back out.
        let reencoded = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(config)
        ) as? [String: Any]
        XCTAssertNil(reencoded?["automaticPpidEnabled"])
    }
}
