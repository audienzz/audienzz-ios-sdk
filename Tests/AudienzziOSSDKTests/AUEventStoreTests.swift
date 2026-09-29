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

/// The outbox is the only thing standing between a foreground crash and a lost event, so the cases
/// that matter are the ugly ones: a process that died mid-write, and a rewrite that has to keep the
/// events queued behind the batch that just settled.
final class AUEventStoreTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AUEventStoreTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeStore() -> AUEventStore {
        AUEventStore(directory: directory)
    }

    private var fileURL: URL { directory.appendingPathComponent("events.jsonl") }

    private func event(_ id: String) -> JSONObject {
        [
            "event_type": "adClick",
            "event_id": id,
            "session_seq": 0,
            "source": "ios-sdk",
            "attributes": ["ad_unit_id": "/1234/unit"],
        ]
    }

    private func ids(_ events: [JSONObject]) -> [String] {
        events.compactMap { $0["event_id"] as? String }
    }

    func testAnAppendedEventIsReadableByAFreshStore() {
        // A SEPARATE instance, as the next launch would be: nothing in memory carries over. This is
        // what "survives process death" actually means.
        makeStore().append(event("a"))

        XCTAssertEqual(ids(makeStore().loadAll()), ["a"])
    }

    func testEventsComeBackInTheOrderTheyWereAppended() {
        let store = makeStore()
        ["a", "b", "c"].forEach { store.append(event($0)) }

        XCTAssertEqual(ids(makeStore().loadAll()), ["a", "b", "c"])
    }

    func testTheFullPayloadSurvivesTheRoundTripNotJustTheID() {
        makeStore().append(event("a"))

        let restored = makeStore().loadAll().first
        XCTAssertEqual(restored?["source"] as? String, "ios-sdk")
        XCTAssertEqual(restored?["attributes"] as? [String: String], ["ad_unit_id": "/1234/unit"])
    }

    func testOneEventIsOneLine() {
        let store = makeStore()
        ["a", "b", "c"].forEach { store.append(event($0)) }

        let lines = (try? String(contentsOf: fileURL, encoding: .utf8))?
            .split(separator: "\n")
            .filter { !$0.isEmpty }
        XCTAssertEqual(lines?.count, 3)
    }

    func testATornLastLineDoesNotCostTheIntactEventsInFrontOfIt() {
        // Exactly what a process killed mid-append leaves behind.
        let store = makeStore()
        store.append(event("a"))
        store.append(event("b"))
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(#"{"event_type":"adClick","even"#.utf8))
            try? handle.close()
        }

        XCTAssertEqual(ids(makeStore().loadAll()), ["a", "b"])
    }

    func testReplaceAllKeepsExactlyWhatIsStillOwed() {
        let store = makeStore()
        ["a", "b", "c"].forEach { store.append(event($0)) }

        store.replaceAll([event("c")])

        XCTAssertEqual(ids(makeStore().loadAll()), ["c"])
    }

    func testReplacingWithNothingLeavesNoFileBehind() {
        let store = makeStore()
        store.append(event("a"))

        store.replaceAll([])

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(makeStore().loadAll().count, 0)
    }

    func testAppendingAfterAReplaceKeepsBothOldAndNew() {
        // The rewrite closes the append handle; if it did not reopen, every event after the first
        // delivered batch would be silently dropped.
        let store = makeStore()
        store.append(event("a"))
        store.replaceAll([event("a")])
        store.append(event("b"))

        XCTAssertEqual(ids(makeStore().loadAll()), ["a", "b"])
    }

    func testAnAbsentStoreReadsAsEmptyRatherThanFailing() {
        XCTAssertEqual(makeStore().loadAll().count, 0)
    }

    func testAStoreWithNoWritableDirectoryDoesNotCrash() {
        // Analytics is never a reason to take an app down.
        let store = AUEventStore(directory: URL(fileURLWithPath: "/dev/null/nope"))
        store.append(event("a"))
        store.replaceAll([event("a")])

        XCTAssertEqual(AUEventStore(directory: URL(fileURLWithPath: "/dev/null/nope")).loadAll().count, 0)
    }
    func testAcknowledgementsRemoveOnlyTheirEventWithoutRewritingTheBacklog() throws {
        let store = makeStore()
        (0..<100).forEach { store.append(event(String($0))) }
        store.remove(id: "37")
        store.remove(id: "0")
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("_au_ack"), "Per-event success must append a small marker")
        XCTAssertEqual(ids(makeStore().loadAll()), (1..<100).filter { $0 != 37 }.map(String.init))
        // Checkpoints bound journal size while preserving every still-pending event.
        (1..<70).forEach { store.remove(id: String($0)) }
        XCTAssertEqual(ids(makeStore().loadAll()), (70..<100).map(String.init))
        XCTAssertLessThan(try Data(contentsOf: fileURL).count, raw.utf8.count)
    }

    func testAppendingAfterATornTailPreservesTheNewEvent() throws {
        makeStore().append(event("old"))
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"event_id":"unfinished"#.utf8))
        try handle.close()
        let restored = makeStore()
        restored.append(event("new"))
        XCTAssertEqual(ids(makeStore().loadAll()), ["old", "new"])
    }

    func testMeasureABoundedBacklogWithoutPerEventFullRewrites() {
        let store = makeStore()
        let start = Date()
        for i in 0..<500 {
            var json = event(String(i))
            json["payload"] = String(repeating: "x", count: 2048)
            store.append(json)
        }
        for i in 0..<500 { store.remove(id: String(i)) }
        print("Analytics storage benchmark: 500 persisted events + acknowledgements = \(Date().timeIntervalSince(start) * 1000) ms (simulator filesystem)")
        XCTAssertTrue(makeStore().loadAll().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testByteCapacityPreservesExistingEventsAndFreesSpaceOnlyOnAck() {
        let bytes = AUEventStore.encode(event("a"))!.count
        let store = AUEventStore(directory: directory, maxBytes: bytes * 2)
        XCTAssertEqual(store.append(event("a")), .stored)
        XCTAssertEqual(store.append(event("b")), .stored)
        XCTAssertEqual(store.append(event("c")), .full)
        XCTAssertEqual(ids(makeStore().loadAll()), ["a", "b"])
        XCTAssertTrue(store.acknowledge(ids: ["a"]))
        XCTAssertEqual(store.append(event("c")), .stored)
        XCTAssertEqual(ids(makeStore().loadAll()), ["b", "c"])
    }

    func testQuarantineSurvivesCompactionWithoutDiscardingPayload() throws {
        let store = makeStore()
        (0..<100).forEach { store.append(event(String($0))) }
        XCTAssertTrue(store.quarantine(id: "0"))
        XCTAssertTrue(store.acknowledge(ids: (1..<71).map(String.init)))
        let restored = makeStore()
        XCTAssertEqual(ids(restored.loadAll()), (71..<100).map(String.init))
        XCTAssertEqual(restored.quarantinedIDs, ["0"])
        XCTAssertTrue(try String(contentsOf: fileURL, encoding: .utf8).contains("\"event_id\":\"0\""))
    }

    func testFailedWriteDoesNotPoisonCacheOrPretendEventIsDurable() throws {
        try Data("blocked".utf8).write(to: directory)
        let store = makeStore()
        XCTAssertEqual(store.append(event("a")), .ioError)
        XCTAssertTrue(store.loadAll().isEmpty)
        try FileManager.default.removeItem(at: directory)
        XCTAssertEqual(store.append(event("a")), .stored)
        XCTAssertEqual(ids(makeStore().loadAll()), ["a"])
    }

}
