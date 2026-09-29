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
    private final class Clock: AUAnalyticsScheduler {
        struct Job { let id: UUID; let at: TimeInterval; let queue: DispatchQueue; let action: () -> Void }
        private let lock = NSLock()
        private var time: TimeInterval = 0
        private var jobs: [Job] = []
        private var cancelled = Set<UUID>()
        var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return time }
        func schedule(on queue: DispatchQueue, after delay: TimeInterval, _ action: @escaping () -> Void) -> () -> Void {
            lock.lock(); let id = UUID(); jobs.append(Job(id: id, at: time + delay, queue: queue, action: action)); lock.unlock()
            return { self.lock.lock(); self.cancelled.insert(id); self.lock.unlock() }
        }
        func advance(_ seconds: TimeInterval) {
            let end = now + seconds
            while true {
                lock.lock()
                jobs.removeAll { cancelled.contains($0.id) }
                guard let next = jobs.filter({ $0.at <= end }).min(by: { $0.at < $1.at }) else {
                    time = end; lock.unlock(); return
                }
                time = next.at; jobs.removeAll { $0.id == next.id }; lock.unlock()
                next.queue.async(execute: next.action); next.queue.sync {}
            }
        }
        var activeJobs: Int { lock.lock(); defer { lock.unlock() }; return jobs.filter { !cancelled.contains($0.id) }.count }
    }
    private var directory: URL!
    private var network: Network!
    private var clock: Clock!
    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        network = Network(); clock = Clock()
    }
    override func tearDown() { network = nil; clock = nil; try? FileManager.default.removeItem(at: directory) }
    private func store() -> AUEventStore { AUEventStore(directory: directory) }
    private func event(_ id: String) -> JSONObject { ["event_id": id, "event_type": "adClick", "page_impression_id": "original"] }
    private func ids(_ events: [JSONObject]) -> [String] { events.compactMap { $0["event_id"] as? String } }
    private func sender(config: AUEventQueue.Config = .default, storage: AUEventStore? = nil) -> AUEventQueue {
        let result = AUEventQueue(networkManager: network, store: storage ?? store(), config: config, scheduler: clock, jitter: { 1 })
        result.syncForTesting(); return result
    }
    private func complete(_ queue: AUEventQueue, _ index: Int, _ error: AUAPIError? = nil) {
        network.complete(index, error); queue.syncForTesting()
    }

    func testTimerStartsAtOldestEventAndPersistencePrecedesHTTP() {
        let queue = sender()
        queue.enqueue(event("a")); queue.syncForTesting()
        XCTAssertEqual(ids(store().loadAll()), ["a"])
        XCTAssertTrue(network.sent.isEmpty)
        clock.advance(4)
        queue.enqueue(event("b")); queue.syncForTesting()
        clock.advance(0.999); XCTAssertTrue(network.sent.isEmpty)
        network.atRequest = { events in
            XCTAssertFalse(Thread.isMainThread)
            XCTAssertEqual(self.ids(self.store().loadAll()), self.ids(events))
        }
        // The fake scheduler executes on the production serial worker via queue.sync.
        clock.advance(0.001)
        XCTAssertEqual(network.sent.map(ids), [["a", "b"]])
        complete(queue, 0)
        XCTAssertTrue(store().loadAll().isEmpty)
        XCTAssertEqual(clock.activeJobs, 0)
    }

    func testThresholdSingleFlightRateLimitAndExactBatchAcknowledgement() {
        let queue = sender()
        (0..<60).forEach { queue.enqueue(event(String($0))) }; queue.syncForTesting()
        XCTAssertEqual(network.sent.map(ids), [(0..<25).map(String.init)])
        clock.advance(1); XCTAssertEqual(network.sent.count, 1)
        complete(queue, 0)
        XCTAssertEqual(ids(store().loadAll()), (25..<60).map(String.init))
        clock.advance(0.999); XCTAssertEqual(network.sent.count, 1)
        clock.advance(0.001); XCTAssertEqual(network.sent.map(ids), [(0..<25).map(String.init), (25..<50).map(String.init)])
        complete(queue, 0) // Duplicate callback must not settle the next batch.
        XCTAssertEqual(ids(store().loadAll()), (25..<60).map(String.init))
        complete(queue, 1); clock.advance(2)
        XCTAssertEqual(ids(network.sent[2]), (50..<60).map(String.init))
        complete(queue, 2); XCTAssertTrue(store().loadAll().isEmpty)
    }

    func testByteLimitUsesUTF8AndOversizedSingletonIsRetainedInQuarantine() {
        let byteLimit = AUEventStore.encode(event("a"))!.count * 2 + 3
        let queue = sender(config: .init(batchBytes: byteLimit))
        var big = event("big"); big["value"] = String(repeating: "ж", count: 50)
        queue.enqueue(big); queue.enqueue(event("a")); queue.enqueue(event("b")); queue.enqueue(event("c")); queue.syncForTesting()
        clock.advance(5)
        XCTAssertEqual(network.sent.count, 1)
        let body = try! JSONSerialization.data(withJSONObject: network.sent[0])
        XCTAssertLessThanOrEqual(body.count, byteLimit)
        XCTAssertEqual(ids(network.sent[0]), ["a", "b"])
        let disk = store(); _ = disk.loadAll()
        XCTAssertEqual(disk.quarantinedIDs, ["big"])
        complete(queue, 0); clock.advance(2)
        XCTAssertEqual(ids(network.sent[1]), ["c"])
    }

    func testRetryAfterCannotBeBypassedByLifecycleOrNewEvents() {
        let queue = sender()
        queue.enqueue(event("a")); queue.flush(); queue.syncForTesting()
        complete(queue, 0, .httpStatus(429, retryAfter: 30))
        queue.enqueue(event("b")); (0..<20).forEach { _ in queue.flush() }; queue.syncForTesting()
        clock.advance(29.999); XCTAssertEqual(network.sent.count, 1)
        clock.advance(0.001); XCTAssertEqual(network.sent.map(ids), [["a"], ["a"]])
        complete(queue, 1); clock.advance(2)
        XCTAssertEqual(ids(network.sent[2]), ["b"])
    }

    func testFailuresRemainDurableBeyondThreeAttempts() {
        let queue = sender()
        queue.enqueue(event("a")); queue.flush(); queue.syncForTesting()
        for (attempt, delay) in [2.0, 4, 8, 16, 32, 60, 60].enumerated() {
            complete(queue, attempt, .httpStatus(503))
            clock.advance(delay - 0.01); XCTAssertEqual(network.sent.count, attempt + 1)
            clock.advance(0.01); XCTAssertEqual(network.sent.count, attempt + 2)
            XCTAssertEqual(ids(store().loadAll()), ["a"])
        }
        complete(queue, 7); XCTAssertTrue(store().loadAll().isEmpty)
    }

    func testRestartReplaysInFlightEventsWithOriginalPayload() {
        var queue: AUEventQueue? = sender()
        queue?.enqueue(event("a")); queue?.enqueue(event("b")); queue?.flush(); queue?.syncForTesting()
        XCTAssertEqual(network.sent.map(ids), [["a", "b"]])
        queue = nil
        network = Network()
        let next = sender()
        XCTAssertEqual(network.sent.map(ids), [["a", "b"]])
        XCTAssertTrue(network.sent[0].allSatisfy { $0["page_impression_id"] as? String == "original" })
        next.enqueue(event("c")); next.syncForTesting()
        complete(next, 0); clock.advance(2)
        XCTAssertEqual(ids(network.sent[1]), ["c"])
    }

    func testRejectedBatchSplitsAndQuarantinesOnlyInvalidSingleton() {
        let queue = sender()
        ["a", "bad", "c", "d"].forEach { queue.enqueue(event($0)) }; queue.flush(); queue.syncForTesting()
        complete(queue, 0, .httpStatus(422)); clock.advance(2)
        XCTAssertEqual(ids(network.sent[1]), ["a", "bad"])
        complete(queue, 1, .httpStatus(422)); clock.advance(4)
        XCTAssertEqual(ids(network.sent[2]), ["a"])
        complete(queue, 2); clock.advance(2)
        XCTAssertEqual(ids(network.sent[3]), ["bad"])
        complete(queue, 3, .httpStatus(422)); clock.advance(2)
        XCTAssertEqual(ids(network.sent[4]), ["c", "d"])
        complete(queue, 4)
        let disk = store(); XCTAssertTrue(disk.loadAll().isEmpty)
        XCTAssertEqual(disk.quarantinedIDs, ["bad"])
        XCTAssertTrue((try! String(contentsOf: directory.appendingPathComponent("events.jsonl"), encoding: .utf8)).contains("adClick"))
    }

    func testFailedPersistenceIsRetriedWithoutSendingVolatileEvents() throws {
        try Data("blocked".utf8).write(to: directory)
        let queue = sender()
        queue.enqueue(event("a")); queue.flush(); queue.syncForTesting()
        XCTAssertTrue(network.sent.isEmpty)
        try FileManager.default.removeItem(at: directory)
        clock.advance(2)
        XCTAssertEqual(network.sent.map(ids), [["a"]])
        XCTAssertEqual(ids(store().loadAll()), ["a"])
    }

    func testFailedAckPersistenceReplaysOnlyTheOriginalBatch() throws {
        let queue = sender()
        queue.enqueue(event("a")); queue.flush(); queue.syncForTesting()
        queue.enqueue(event("b")); queue.syncForTesting()
        let backup = directory.appendingPathExtension("saved")
        defer { try? FileManager.default.removeItem(at: backup) }
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("unwritable".utf8).write(to: directory)
        complete(queue, 0)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        clock.advance(2)
        XCTAssertEqual(network.sent.map(ids), [["a"], ["a"]])
        XCTAssertEqual(ids(store().loadAll()), ["a", "b"])
        complete(queue, 1); clock.advance(2)
        XCTAssertEqual(ids(network.sent[2]), ["b"])
    }

    func testCapacityNeverDeletesAnUnacknowledgedEvent() {
        let size = AUEventStore.encode(event("a"))!.count
        let queue = sender(storage: AUEventStore(directory: directory, maxBytes: size * 2))
        ["a", "b", "c"].forEach { queue.enqueue(event($0)) }; queue.flush(); queue.syncForTesting()
        XCTAssertEqual(network.sent.map(ids), [["a", "b"]])
        XCTAssertEqual(ids(store().loadAll()), ["a", "b"])
        complete(queue, 0); XCTAssertTrue(store().loadAll().isEmpty)
    }

    func testReinitializingAnalyticsReusesItsOutbox() {
        let queue = sender()
        var created = 0
        let manager = AUEventsManager(makeQueue: { created += 1; return queue })
        manager.configure(companyId: "first"); manager.configure(companyId: "second")
        XCTAssertEqual(created, 1)
        withExtendedLifetime(manager) {}
    }
}
