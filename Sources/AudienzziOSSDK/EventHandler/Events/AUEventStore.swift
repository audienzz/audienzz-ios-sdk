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

import Foundation

/// Append-only durable outbox. Event records retain the existing JSONL format; small acknowledgement
/// records remove events by ID. Compact every 64 removals (or when empty), not once per HTTP reply.
/// All access belongs to AUEventQueue's utility queue. Legacy event-only files migrate on read.
final class AUEventStore {

    private let fileURL: URL?
    private var handle: FileHandle?
    private var cached: [JSONObject]?
    private var removals = 0

    /// - Parameter directory: override for tests. Default is Application Support, which is meant
    ///   for data the app recreates as needed but should not lose casually — Caches would let the
    ///   system evict a backlog we are in the middle of retrying.
    init(directory: URL? = nil, fileName: String = "events.jsonl") {
        guard let base = directory ?? Self.defaultDirectory() else {
            self.fileURL = nil
            AULogEvent.logDebug("[AUAnalytics] no writable directory — events will not be persisted")
            return
        }
        self.fileURL = base.appendingPathComponent(fileName)
    }

    deinit {
        try? handle?.close()
    }

    // MARK: - Reading

    /// Every event still on disk, oldest first. Unparseable lines are skipped.
    func loadAll() -> [JSONObject] {
        if let cached { return cached }
        guard let fileURL, let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            cached = []
            return []
        }
        var events: [JSONObject] = []
        var skipped = false
        for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? JSONObject else {
                skipped = true
                continue
            }
            if let id = object["_au_ack"] as? String {
                events.removeAll { $0["event_id"] as? String == id }
                removals += 1
            } else if let id = object["event_id"] as? String {
                events.removeAll { $0["event_id"] as? String == id }
                events.append(object)
            }
        }
        cached = events
        // Repair a torn tail before appending, so it cannot swallow the next valid event.
        if skipped || removals >= 64 { replaceAll(events) }
        return events
    }

    // MARK: - Writing

    func append(_ json: JSONObject) {
        _ = loadAll()
        guard let id = json["event_id"] as? String else { return }
        cached?.removeAll { $0["event_id"] as? String == id }
        cached?.append(json)
        appendRecord(json)
    }

    func remove(id: String) {
        _ = loadAll()
        guard cached?.contains(where: { $0["event_id"] as? String == id }) == true else { return }
        cached?.removeAll { $0["event_id"] as? String == id }
        removals += 1
        if cached?.isEmpty == true || removals >= 64 {
            replaceAll(cached ?? [])
        } else {
            appendRecord(["_au_ack": id])
        }
    }

    private func appendRecord(_ record: JSONObject) {
        guard let line = Self.line(from: record), let handle = appendHandle() else {
            AUDiagnostics.log("analytics", "persistenceFailed")
            return
        }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([UInt8(ascii: "\n")]) + line)
        } catch {
            AUDiagnostics.log("analytics", "persistenceFailed")
            closeHandle()
        }
    }

    /// Replace the stored contents with exactly `events` (written atomically).
    ///
    /// Periodic checkpoint: only events still owed to the collector are retained.
    func replaceAll(_ events: [JSONObject]) {
        cached = events
        removals = 0
        guard let fileURL = fileURL else { return }
        closeHandle()

        if events.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        var data = Data()
        for event in events {
            if let line = Self.line(from: event) { data.append(line) }
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Atomic: a process death mid-rewrite leaves the previous file, never a truncated one.
            try data.write(to: fileURL, options: .atomic)
            excludeFromBackup()
        } catch {
            AULogEvent.logDebug("[AUAnalytics] could not rewrite store: \(error.localizedDescription)")
        }
    }

    // MARK: - Internals

    private static func line(from json: JSONObject) -> Data? {
        // `.sortedKeys` only to keep the file diffable when inspecting it by hand.
        guard var data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        else { return nil }
        data.append(UInt8(ascii: "\n"))
        return data
    }

    private func appendHandle() -> FileHandle? {
        if let handle = handle { return handle }
        guard let fileURL = fileURL else { return nil }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            excludeFromBackup()
        }
        handle = try? FileHandle(forWritingTo: fileURL)
        return handle
    }

    private func closeHandle() {
        try? handle?.close()
        handle = nil
    }

    /// A retry backlog is not the user's data; it should not travel to a new device in a backup.
    private func excludeFromBackup() {
        guard var url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private static func defaultDirectory() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Audienzz", isDirectory: true)
    }
}
