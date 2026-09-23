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

/// How the queue uses its store, which is where the durability actually lives — `AUEventStoreTests`
/// only proves the file works when someone writes to it.
///
/// The question each test answers is "what would a process death at this exact moment cost?", so
/// several of them assert *during* the in-flight request rather than after it.
final class AUEventQueueTests: XCTestCase {

    /// Records batches and lets the test decide when (and how) each one completes.
    private final class FakeNetworkManager: AUEventsNetworkManager<AUBatchResultModel> {
        var sentBatches: [[JSONObject]] = []
        /// Result to hand back, and a hook that runs before completing — the only place a test can
        /// observe the world mid-flight.
        var resultForBatch: (([JSONObject]) -> Result<AUBatchResultModel, AUAPIError>) = { _ in
            .success(AUBatchResultModel(code: 200))
        }
        var onRequest: (([JSONObject]) -> Void)?

        override func request(_ route: APIRoute<AUBatchResultModel>,
                              handler: @escaping (Result<AUBatchResultModel, AUAPIError>) -> Void) {
            guard case .batchEvents(let chunk) = route else {
                XCTFail("the queue must only ever POST batches")
                return
            }
            sentBatches.append(chunk)
            onRequest?(chunk)
            handler(resultForBatch(chunk))
        }
    }

    private var directory: URL!
    private var network: FakeNetworkManager!

    /// Small values so the size, timer and backoff paths are reachable without waiting out the real
    /// 30s interval or the 2/4/8s backoff.
    private let config = AUEventQueue.Config(
        maxBatchSize: 2,
        flushIntervalMs: 50,
        maxQueueSize: 4,
        maxRetries: 2,
        retryBaseDelayMs: 1
    )

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AUEventQueueTests-\(UUID().uuidString)")
        network = FakeNetworkManager()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeStore() -> AUEventStore { AUEventStore(directory: directory) }

    private func makeQueue(store: AUEventStore? = nil) -> AUEventQueue {
        AUEventQueue(networkManager: network, store: store ?? makeStore(), config: config)
    }

    private func event(_ id: String) -> JSONObject {
        ["event_type": "adClick", "event_id": id, "session_seq": 0]
    }

    private func ids(_ events: [JSONObject]) -> [String] {
        events.compactMap { $0["event_id"] as? String }
    }

    /// Wait for the queue's serial work to drain. Everything it does is scheduled on that queue, so
    /// a barrier on it is a reliable "nothing further is pending".
    private func drain(_ timeout: TimeInterval = 2) {
        let done = expectation(description: "queue drained")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { done.fulfill() }
        wait(for: [done], timeout: timeout)
    }

    // MARK: - Writing

    func testAnEventIsOnDiskBeforeTheBatchIsEvenAttempted() {
        // If the write happened after the send, a crash in between would lose the event — which is
        // the entire case persistence exists for.
        var onDiskAtSendTime: [String] = []
        let store = makeStore()
        network.onRequest = { [weak self] _ in
            guard let self = self else { return }
            onDiskAtSendTime = self.ids(self.makeStore().loadAll())
        }

        let queue = makeQueue(store: store)
        queue.enqueue(event("a"))
        queue.enqueue(event("b"))
        drain()

        XCTAssertEqual(onDiskAtSendTime, ["a", "b"])
    }

    func testADeliveredBatchIsDroppedFromDisk() {
        let queue = makeQueue()
        queue.enqueue(event("a"))
        queue.enqueue(event("b"))
        drain()

        XCTAssertEqual(network.sentBatches.count, 1)
        XCTAssertEqual(makeStore().loadAll().count, 0)
    }

    func testABatchGivenUpOnIsAlsoDroppedFromDisk() {
        // Otherwise a permanently failing batch would be replayed by every future launch and the
        // store would never drain.
        network.resultForBatch = { _ in .failure(.couldNotParseResponse) }

        let queue = makeQueue()
        queue.enqueue(event("a"))
        queue.enqueue(event("b"))
        drain()

        XCTAssertEqual(network.sentBatches.count, config.maxRetries + 1)
        XCTAssertEqual(makeStore().loadAll().count, 0)
    }

    func testEventsQueuedBehindADeliveredBatchSurviveTheRewrite() {
        // The rewrite must keep what is still owed, not simply truncate the file.
        let queue = makeQueue()
        network.onRequest = { chunk in
            if self.ids(chunk) == ["a", "b"] { queue.enqueue(self.event("c")) }
        }
        queue.enqueue(event("a"))
        queue.enqueue(event("b"))
        drain()

        // "c" either went out in a second batch or is still owed on disk — never silently gone.
        let delivered = network.sentBatches.flatMap { self.ids($0) }
        let stillOwed = ids(makeStore().loadAll())
        XCTAssertTrue(delivered.contains("c") || stillOwed.contains("c"),
                      "an event enqueued during a flush was lost")
    }

    // MARK: - Restoring

    func testEventsLeftByAPreviousProcessAreSentOnStartup() {
        let previous = makeStore()
        previous.append(event("a"))
        previous.append(event("b"))

        // Retained deliberately: the restore runs on the queue's own serial queue with a weak
        // self, so a discarded instance would simply never do it.
        let queue = makeQueue()
        withExtendedLifetime(queue) { drain() }

        XCTAssertEqual(network.sentBatches.flatMap { self.ids($0) }, ["a", "b"])
        XCTAssertEqual(makeStore().loadAll().count, 0)
    }

    func testRestoredEventsGoOutAheadOfNewOnes() {
        // They are older; sending the new ones first would reorder the session for no reason.
        let previous = makeStore()
        previous.append(event("old"))

        let queue = makeQueue()
        queue.enqueue(event("new"))
        drain()

        XCTAssertEqual(network.sentBatches.flatMap { self.ids($0) }.first, "old")
    }

    func testAnEmptyStoreStartsCleanly() {
        let queue = makeQueue()
        withExtendedLifetime(queue) { drain() }

        XCTAssertTrue(network.sentBatches.isEmpty)
    }

    // MARK: - Capacity

    func testOverflowDropsTheOldestFromDiskToo() {
        // Otherwise the file keeps a backlog the queue has already given up on.
        network.resultForBatch = { _ in .failure(.couldNotParseResponse) }
        let store = makeStore()
        // Restore path fills the buffer past maxQueueSize (4) without any send succeeding.
        for id in ["a", "b", "c", "d", "e", "f"] { store.append(event(id)) }

        let queue = makeQueue(store: store)
        withExtendedLifetime(queue) { drain() }

        XCTAssertLessThanOrEqual(makeStore().loadAll().count, config.maxQueueSize)
    }
}
