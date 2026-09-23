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

/// Disk backing for `AUEventQueue` — a durable outbox so events survive process death.
///
/// Events are stored as JSON Lines: one serialized event per line, appended as it is enqueued and
/// rewritten only when a batch is confirmed delivered. Appending (rather than rewriting the whole
/// buffer per event) keeps the cost of an enqueue constant regardless of how much is backed up.
///
/// Writing on *enqueue* is the whole point. The queue already flushes when the app backgrounds, so
/// the tidy path was never the lossy one; what was lost was a foreground crash or force-quit, and
/// only a write that has already happened by then can survive it.
///
/// A line that fails to parse is skipped rather than failing the load: the last line can be a
/// partial write if the process died mid-append, and one torn event is not a reason to drop the
/// hundreds of intact ones in front of it.
///
/// Not thread-safe by itself — every call is made from `AUEventQueue`'s serial queue.
final class AUEventStore {

    private let fileURL: URL?
    private var handle: FileHandle?

    /// - Parameter directory: override for tests. Default is Application Support, which is meant
    ///   for data the app recreates as needed but should not lose casually — Caches would let the
    ///   system evict a backlog we are in the middle of retrying.
    init(directory: URL? = nil, fileName: String = "events.jsonl") {
        guard let base = directory ?? Self.defaultDirectory() else {
            self.fileURL = nil
            AULogEvent.logDebug("[AUAnalytics] no writable directory — events will not be persisted")
            return
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent(fileName)
        excludeFromBackup()
    }

    deinit {
        try? handle?.close()
    }

    // MARK: - Reading

    /// Every event still on disk, oldest first. Unparseable lines are skipped.
    func loadAll() -> [JSONObject] {
        guard let fileURL = fileURL,
              let data = try? Data(contentsOf: fileURL),
              !data.isEmpty
        else { return [] }

        var events: [JSONObject] = []
        var skipped = 0
        for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            if let object = try? JSONSerialization.jsonObject(with: Data(line)) as? JSONObject {
                events.append(object)
            } else {
                skipped += 1
            }
        }
        if skipped > 0 {
            AULogEvent.logDebug("[AUAnalytics] skipped \(skipped) unreadable line(s) while restoring")
        }
        if !events.isEmpty {
            AULogEvent.logDebug("[AUAnalytics] restored \(events.count) event(s) from disk")
        }
        return events
    }

    // MARK: - Writing

    /// Append one event. Constant cost — no rewrite of what is already stored.
    func append(_ json: JSONObject) {
        guard let line = Self.line(from: json) else { return }
        guard let handle = appendHandle() else { return }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {
            AULogEvent.logDebug("[AUAnalytics] could not persist event: \(error.localizedDescription)")
            closeHandle()
        }
    }

    /// Replace the stored contents with exactly `events` (written atomically).
    ///
    /// Called after a batch settles, so what is on disk is what is still owed to the collector.
    func replaceAll(_ events: [JSONObject]) {
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
