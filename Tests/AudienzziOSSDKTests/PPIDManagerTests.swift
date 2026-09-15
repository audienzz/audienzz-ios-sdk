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
/// opt-out. Two switches arrive in the publisher config and they mean different things: the master
/// one is a privacy setting and suppresses the publisher's own identifier too, while the automatic
/// one governs only the identifier the SDK would invent.
///
/// Getting the default wrong is expensive in both directions: defaulting off silently drops every
/// PPID (exactly what shipped before, costing frequency capping and cross-session targeting), and
/// ignoring the master switch keeps sending an identifier for a publisher who has turned it off.
final class PPIDManagerTests: AudienzzLifecycleTestCase {

    private var manager: PPIDManager { PPIDManager.shared }

    override func setUp() {
        super.setUp()
        manager.setPublisherPPID(nil)
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: nil, automaticPpidEnabled: nil)
    }

    override func tearDown() {
        manager.setPublisherPPID(nil)
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: nil, automaticPpidEnabled: nil)
        super.tearDown()
    }

    func testGeneratesAPPIDWhenTheBackendSaysNothing() {
        // Absent switches mean enabled. This is the default every publisher gets.
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

    func testTheMasterSwitchSuppressesTheGeneratedPPID() {
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: false, automaticPpidEnabled: nil)

        XCTAssertNil(manager.getPPID())
    }

    func testTheMasterSwitchSuppressesAPublisherSuppliedPPIDToo() {
        // It is a per-publisher privacy switch, so honouring it only for the SDK's own identifier
        // would miss the point entirely.
        manager.setPublisherPPID("hashed-email")
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: false, automaticPpidEnabled: nil)

        XCTAssertNil(manager.getPPID())
    }

    func testTheAutomaticSwitchSuppressesOnlyTheGeneratedPPID() {
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: nil, automaticPpidEnabled: false)

        XCTAssertNil(manager.getPPID())
    }

    func testAPublisherSuppliedPPIDSurvivesTheAutomaticSwitch() {
        // The publisher's own identifier is theirs to send; this switch governs only the one the
        // SDK would invent.
        manager.setPublisherPPID("hashed-email")
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: nil, automaticPpidEnabled: false)

        XCTAssertEqual(manager.getPPID(), "hashed-email")
    }

    func testSwitchesExplicitlySetToTrueBehaveAsEnabled() {
        Audienzz.shared.applyBackendPpidConfig(ppidEnabled: true, automaticPpidEnabled: true)

        XCTAssertNotNil(manager.getPPID())
    }
}
