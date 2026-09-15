import XCTest
import UIKit
@testable import AudienzziOSSDK

/// Every suite shares the same lifecycle/page cleanup, including suites with their own fixtures.
class AudienzzLifecycleTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        Audienzz.shared.resetLifecycleForTesting()
    }
    override func tearDown() {
        Audienzz.shared.resetLifecycleForTesting()
        super.tearDown()
    }
}

final class LifecycleIsolationTests: AudienzzLifecycleTestCase {
    func testResetCancelsPendingVisitAndLeavesNoPageOrBackgroundState() {
        let sdk = Audienzz.shared
        let coordinator = AUScreenAdCoordinator.shared
        sdk.pageImpression("old")
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(sdk.hasPendingForegroundReimpression)
        sdk.resetLifecycleForTesting()
        XCTAssertFalse(sdk.hasPendingForegroundReimpression)
        XCTAssertFalse(sdk.isAppBackgrounded)
        XCTAssertNil(coordinator.activeScreenAndName)
        XCTAssertEqual(coordinator.epoch, 0)
        var reports = 0
        sdk.pageImpressionObserver = { _ in reports += 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertEqual(reports, 0)
        XCTAssertEqual(coordinator.epoch, 0)
        sdk.pageImpression("fresh")
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(sdk.isAppBackgrounded)
        sdk.resetLifecycleForTesting()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(sdk.isAppBackgrounded)
        XCTAssertFalse(sdk.hasPendingForegroundReimpression)
        XCTAssertNil(coordinator.activeScreenAndName)
    }
}
