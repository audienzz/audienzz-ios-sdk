import XCTest
import UIKit
@testable import AudienzziOSSDK

/// The IDFA lookup is a blocking XPC call into `lsd`. Logging an event must never make it, on any
/// thread: events take the cached value, which is refreshed in the background (audienzz-ios-sdk#62).
final class DeviceIdRefreshTests: XCTestCase {
    private final class Network: AUEventsNetworkManager<AUBatchResultModel> {
        init() { super.init(monitorConnectivity: false) }
        private let lock = NSLock()
        private var values: [JSONObject] = []
        var sent: [JSONObject] { lock.lock(); defer { lock.unlock() }; return values }
        override func request(_ route: APIRoute<AUBatchResultModel>, handler: @escaping (Result<AUBatchResultModel, AUAPIError>) -> Void) {
            guard case .batchEvents(let events) = route else { return XCTFail("Unexpected route") }
            lock.lock(); values.append(contentsOf: events); lock.unlock()
            handler(.success(AUBatchResultModel(code: 204)))
        }
    }

    /// Stands in for `ASIdentifierManager`: records every read and can be held to act like a slow `lsd`.
    private final class Lookup {
        private let lock = NSLock()
        private var value: String
        private var reads: [Bool] = []
        let gate = DispatchSemaphore(value: 0)
        var blocks = false
        init(_ value: String) { self.value = value }
        func set(_ newValue: String) { lock.lock(); value = newValue; lock.unlock() }
        var readCount: Int { lock.lock(); defer { lock.unlock() }; return reads.count }
        var readOnMain: Bool { lock.lock(); defer { lock.unlock() }; return reads.contains(true) }
        func read() -> String? {
            if blocks { gate.wait() }
            lock.lock(); defer { lock.unlock() }
            reads.append(Thread.isMainThread)
            return value
        }
    }

    private var directory: URL!
    private var network: Network!
    private var queue: AUEventQueue!
    private var lookup: Lookup!
    private var manager: AUEventsManager!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        network = Network()
        queue = AUEventQueue(networkManager: network, store: AUEventStore(directory: directory),
                             config: .init(batchDelayMs: 0, minIntervalMs: 0))
        lookup = Lookup("AB12CD34-0000-1111-2222-333344445555")
        let eventQueue = queue!, lookup = lookup!
        manager = AUEventsManager(makeQueue: { eventQueue }, readAdvertisingId: { lookup.read() })
    }

    override func tearDown() {
        lookup.blocks = false
        lookup.gate.signal()
        manager.waitForDeviceIdRefreshForTesting()
        queue.syncForTesting(); manager = nil; queue = nil; network = nil; lookup = nil
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func sent() -> [JSONObject] {
        queue.flush()
        for _ in 0..<8 { queue.syncForTesting() }
        return network.sent
    }

    private func background() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func activate() {
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func testEventsTakeTheCachedIdentifierAndNeverReadItThemselves() {
        manager.configure(companyId: "fixture")
        manager.waitForDeviceIdRefreshForTesting()
        for index in 0..<20 { manager.onScreenResumed(screenName: "screen-\(index)") }

        XCTAssertEqual(lookup.readCount, 1, "one read per refresh, not one per event")
        XCTAssertFalse(lookup.readOnMain, "the lookup blocks on lsd and must stay off the main thread")
        let events = sent()
        XCTAssertEqual(events.count, 20)
        XCTAssertTrue(events.allSatisfy { $0["device_id"] as? String == "ab12cd34-0000-1111-2222-333344445555" })
    }

    func testASlowLookupDoesNotHoldUpLogging() {
        lookup.blocks = true
        manager.configure(companyId: "fixture")

        let start = Date()
        manager.onScreenResumed(screenName: "A")
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5, "logging waited for the IDFA lookup")
        XCTAssertNil(sent().first?["device_id"], "an event logged before the lookup returns omits the field")

        lookup.gate.signal()
        manager.waitForDeviceIdRefreshForTesting()
        XCTAssertEqual(manager.deviceIdForTesting, "ab12cd34-0000-1111-2222-333344445555")
    }

    func testTheAllZeroIdentifierIsCachedAsAbsentWithoutRereadingPerEvent() {
        lookup.set("00000000-0000-0000-0000-000000000000")
        manager.configure(companyId: "fixture")
        manager.waitForDeviceIdRefreshForTesting()
        for _ in 0..<5 { manager.onScreenResumed(screenName: "A") }

        XCTAssertEqual(lookup.readCount, 1, "ATT-denied users must not pay for a lookup on every event")
        XCTAssertTrue(sent().allSatisfy { $0["device_id"] == nil })
    }

    func testAuthorizationChangesArePickedUpOnTheNextActivation() {
        manager.configure(companyId: "fixture")
        manager.waitForDeviceIdRefreshForTesting()
        XCTAssertEqual(manager.deviceIdForTesting, "ab12cd34-0000-1111-2222-333344445555")

        // Revoked in Settings: the app was in the background, and comes back without an identity.
        background()
        XCTAssertNil(manager.deviceIdForTesting, "a possibly withdrawn identifier must not outlive the background")
        lookup.set("00000000-0000-0000-0000-000000000000")
        activate()
        manager.waitForDeviceIdRefreshForTesting()
        XCTAssertNil(manager.deviceIdForTesting)

        // Granted again (prompt or Settings): the next activation reads the new identifier.
        lookup.set("FFFF0000-0000-1111-2222-333344445555")
        activate()
        manager.waitForDeviceIdRefreshForTesting()
        XCTAssertEqual(manager.deviceIdForTesting, "ffff0000-0000-1111-2222-333344445555")
    }

    func testALookupStartedBeforeBackgroundCannotRestoreTheIdentifier() {
        lookup.blocks = true
        manager.configure(companyId: "fixture")
        background()
        lookup.gate.signal()
        manager.waitForDeviceIdRefreshForTesting()
        XCTAssertNil(manager.deviceIdForTesting,
                     "a read that began before the app left must not repopulate the dropped identifier")
    }
}
