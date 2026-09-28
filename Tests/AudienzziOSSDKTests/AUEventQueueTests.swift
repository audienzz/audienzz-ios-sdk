import XCTest
@testable import AudienzziOSSDK

final class AUEventQueueTests: XCTestCase {
    private final class Network: AUEventsNetworkManager<AUBatchResultModel> {
        private let lock = NSLock()
        private var requests: [[JSONObject]] = []
        private var handlers: [(Result<AUBatchResultModel, AUAPIError>) -> Void] = []
        var atRequest: (([JSONObject]) -> Void)?
        var sent: [[JSONObject]] { lock.lock(); defer { lock.unlock() }; return requests }
        override func request(_ route: APIRoute<AUBatchResultModel>,
                              handler: @escaping (Result<AUBatchResultModel, AUAPIError>) -> Void) {
            guard case .batchEvents(let events) = route else { return XCTFail("Unexpected route") }
            lock.lock()
            requests.append(events)
            handlers.append(handler)
            lock.unlock()
            atRequest?(events)
        }
        func complete(_ index: Int, _ error: AUAPIError? = nil) {
            lock.lock()
            let handler = handlers[index]
            lock.unlock()
            handler(error.map { .failure($0) } ?? .success(AUBatchResultModel(code: 204)))
        }
    }
    private var directory: URL!
    private var network: Network!
    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        network = Network()
    }
    override func tearDown() {
        network = nil
        try? FileManager.default.removeItem(at: directory)
    }
    private func store() -> AUEventStore { AUEventStore(directory: directory) }
    private func event(_ id: String) -> JSONObject { ["event_id": id, "event_type": "adClick"] }
    private func ids(_ events: [JSONObject]) -> [String] { events.compactMap { $0["event_id"] as? String } }
    private func waitUntil(_ condition: @escaping () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(2)
        while !condition() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.002)) }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    func testFirstEventStartsImmediatelyAndIsPersistedBeforeHTTP() {
        let sent = expectation(description: "immediate send on worker")
        network.atRequest = { events in
            XCTAssertFalse(Thread.isMainThread)
            XCTAssertEqual(self.ids(self.store().loadAll()), ["a"])
            XCTAssertEqual(self.ids(events), ["a"])
            sent.fulfill()
        }
        let queue = AUEventQueue(networkManager: network, store: store())
        queue.enqueue(event("a"))
        withExtendedLifetime(queue) { wait(for: [sent], timeout: 0.5) }
    }

    func testOnlyOneRequestRunsAtATimeAndDuplicateCallbacksCannotDeleteTheNextEvent() {
        let queue = AUEventQueue(networkManager: network, store: store())
        queue.enqueue(event("a")); queue.enqueue(event("b"))
        waitUntil { self.store().loadAll().count == 2 && self.network.sent.count == 1 }
        network.complete(0)
        waitUntil { self.network.sent.count == 2 }
        network.complete(0) // A duplicate completion for "a" cannot acknowledge "b".
        queue.flush()
        XCTAssertEqual(ids(store().loadAll()), ["b"])
        network.complete(1)
        waitUntil { self.store().loadAll().isEmpty }
        XCTAssertEqual(network.sent.map(ids), [["a"], ["b"]])
        withExtendedLifetime(queue) {}
    }

    func testFailuresStayOnDiskBeyondThreeAttemptsAndBackoffCannotBeBypassed() {
        let queue = AUEventQueue(networkManager: network, store: store(),
            config: .init(maxQueueSize: 500, retryBaseDelayMs: 30, maxRetryDelayMs: 60))
        queue.enqueue(event("a"))
        for attempt in 0..<5 {
            waitUntil { self.network.sent.count == attempt + 1 }
            let started = Date()
            network.complete(attempt, .httpStatus(503))
            for _ in 0..<20 { queue.flush() }
            waitUntil { self.network.sent.count == attempt + 2 }
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), attempt == 0 ? 0.025 : 0.05)
            XCTAssertEqual(ids(store().loadAll()), ["a"])
        }
        network.complete(5)
        waitUntil { self.store().loadAll().isEmpty }
        withExtendedLifetime(queue) {}
    }

    func testANewEventDuringBackoffIsSavedButDoesNotTriggerAnEarlyRetry() {
        let queue = AUEventQueue(networkManager: network, store: store(),
            config: .init(maxQueueSize: 500, retryBaseDelayMs: 100, maxRetryDelayMs: 100))
        queue.enqueue(event("a"))
        waitUntil { self.network.sent.count == 1 }
        network.complete(0, .httpStatus(400))
        queue.enqueue(event("b"))
        waitUntil { self.store().loadAll().count == 2 }
        XCTAssertEqual(network.sent.count, 1)
        waitUntil { self.network.sent.count == 2 }
        XCTAssertEqual(ids(network.sent[1]), ["a"])
        network.complete(1, .httpStatus(400))
        waitUntil { self.network.sent.count == 3 }
        XCTAssertEqual(ids(network.sent[2]), ["b"], "A bad payload must not strand later events")
        network.complete(2)
        waitUntil { self.network.sent.count == 4 }
        XCTAssertEqual(ids(network.sent[3]), ["a"])
        network.complete(3)
        waitUntil { self.store().loadAll().isEmpty }
        withExtendedLifetime(queue) {}
    }

    func testAnInFlightEventSurvivesRestartWithItsOriginalIdentity() {
        var queue: AUEventQueue? = AUEventQueue(networkManager: network, store: store())
        queue?.enqueue(event("old"))
        waitUntil { self.network.sent.count == 1 }
        queue = nil // No acknowledgement: exactly the process-termination ambiguity.
        let nextNetwork = Network()
        let next = AUEventQueue(networkManager: nextNetwork, store: store())
        next.enqueue(event("new"))
        waitUntil { nextNetwork.sent.count == 1 && self.store().loadAll().count == 2 }
        XCTAssertEqual(ids(nextNetwork.sent[0]), ["old"])
        nextNetwork.complete(0)
        waitUntil { nextNetwork.sent.count == 2 }
        XCTAssertEqual(ids(nextNetwork.sent[1]), ["new"])
        nextNetwork.complete(1)
        waitUntil { self.store().loadAll().isEmpty }
        withExtendedLifetime(next) {}
    }

    func testOverflowProtectsTheInFlightEventAndItsAckCannotRemoveANewerEvent() {
        let queue = AUEventQueue(networkManager: network, store: store(),
            config: .init(maxQueueSize: 3))
        queue.enqueue(event("a"))
        waitUntil { self.network.sent.count == 1 }
        for id in ["b", "c", "d", "e"] { queue.enqueue(event(id)) }
        waitUntil { self.ids(self.store().loadAll()) == ["a", "d", "e"] }
        network.complete(0)
        waitUntil { self.network.sent.count == 2 }
        XCTAssertEqual(ids(store().loadAll()), ["d", "e"])
        XCTAssertEqual(ids(network.sent[1]), ["d"])
        withExtendedLifetime(queue) {}
    }

    func testReinitializingAnalyticsReusesItsOutbox() {
        let queue = AUEventQueue(networkManager: network, store: store())
        var created = 0
        let manager = AUEventsManager(makeQueue: { created += 1; return queue })
        manager.configure(companyId: "first")
        manager.configure(companyId: "second")
        XCTAssertEqual(created, 1)
        withExtendedLifetime(manager) {}
    }
}
