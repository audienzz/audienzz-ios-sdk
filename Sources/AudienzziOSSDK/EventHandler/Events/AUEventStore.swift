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

/// Durable JSONL outbox; old event-only and per-ID acknowledgement journals remain readable.
/// One analytics worker owns this store. No unacknowledged event is evicted to admit another.
final class AUEventStore {
    enum Admission { case stored, full, ioError, invalid }
    private let fileURL: URL?
    private let maxBytes: Int
    private var cached: [JSONObject]?
    private var storedIDs = Set<String>()
    private(set) var quarantinedIDs = Set<String>()
    private(set) var readFailed = false
    private var payloadBytes = 0
    private var removals = 0

    init(directory: URL? = nil, fileName: String = "events.jsonl", maxBytes: Int = 20 * 1024 * 1024) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Audienzz", isDirectory: true)
        fileURL = base?.appendingPathComponent(fileName)
        self.maxBytes = maxBytes
    }

    func loadAll() -> [JSONObject] {
        if let cached { return cached.filter { !quarantinedIDs.contains($0["event_id"] as? String ?? "") } }
        var records: [String: JSONObject] = [:]
        var order: [String] = []
        var seen = Set<String>()
        var rejected = Set<String>()
        var damaged = false
        do {
            if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
                    guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? JSONObject else {
                        damaged = true; continue
                    }
                    if let id = object["_au_ack"] as? String {
                        records.removeValue(forKey: id); removals += 1
                    } else if let ids = object["_au_ack_ids"] as? [String] {
                        let set = Set(ids)
                        ids.forEach { records.removeValue(forKey: $0) }
                        rejected.subtract(set); removals += ids.count
                    } else if let id = object["_au_quarantine"] as? String {
                        rejected.insert(id)
                    } else if let id = object["event_id"] as? String {
                        if seen.insert(id).inserted { order.append(id) }
                        records[id] = object
                    } else { damaged = true }
                }
            }
        } catch {
            readFailed = true
            persistenceFailed()
            return [] // Do NOT cache this or overwrite the unreadable journal.
        }
        let events = order.compactMap { records[$0] }
        readFailed = false
        storedIDs = Set(records.keys)
        cached = events; quarantinedIDs = rejected
        payloadBytes = events.reduce(0) { $0 + (Self.encode($1)?.count ?? 0) }
        if damaged || removals >= max(64, events.count / 4) { compact() }
        return events.filter { !rejected.contains($0["event_id"] as? String ?? "") }
    }

    @discardableResult func append(_ event: JSONObject) -> Admission {
        if cached == nil { _ = loadAll() }
        guard !readFailed else { return .ioError }
        guard let id = event["event_id"] as? String, let data = Self.encode(event) else { return .invalid }
        if storedIDs.contains(id) { return .stored }
        guard payloadBytes + data.count <= maxBytes else { return .full }
        guard appendRecord(event) else { return .ioError }
        cached?.append(event); storedIDs.insert(id); payloadBytes += data.count
        checkpointIfNeeded()
        return .stored
    }

    @discardableResult func acknowledge(ids: [String]) -> Bool {
        if cached == nil { _ = loadAll() }
        guard !readFailed else { return false }
        let set = Set(ids)
        let removed = (cached ?? []).filter { set.contains($0["event_id"] as? String ?? "") }
        if removed.isEmpty { return true }
        guard appendRecord(["_au_ack_ids": ids]) else { return false }
        cached?.removeAll { set.contains($0["event_id"] as? String ?? "") }
        quarantinedIDs.subtract(set); storedIDs.subtract(set)
        payloadBytes -= removed.reduce(0) { $0 + (Self.encode($1)?.count ?? 0) }
        removals += removed.count
        checkpointIfNeeded()
        return true
    }

    @discardableResult func quarantine(id: String) -> Bool {
        if quarantinedIDs.contains(id) { return true }
        guard appendRecord(["_au_quarantine": id]) else { return false }
        quarantinedIDs.insert(id)
        checkpointIfNeeded()
        return true
    }

    func remove(id: String) { acknowledge(ids: [id]) }

    // Maintenance/testing only. Network acknowledgements always name their exact IDs.
    @discardableResult func replaceAll(_ events: [JSONObject]) -> Bool {
        guard writeSnapshot(events, rejected: []) else { return false }
        cached = events; storedIDs = Set(events.compactMap { $0["event_id"] as? String }); quarantinedIDs = []; removals = 0
        payloadBytes = events.reduce(0) { $0 + (Self.encode($1)?.count ?? 0) }
        return true
    }

    private func appendRecord(_ record: JSONObject) -> Bool {
        guard let fileURL, let data = Self.encode(record) else { persistenceFailed(); return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else { persistenceFailed(); return false }
                excludeFromBackup()
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([10]) + data + Data([10]))
            try handle.synchronize()
            return true
        } catch { persistenceFailed(); return false }
    }

    private func checkpointIfNeeded() {
        let bytes = fileURL.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } ?? 0
        if cached?.isEmpty == true || removals >= max(64, (cached?.count ?? 0) / 4) || bytes > maxBytes + 1024 * 1024 { compact() }
    }
    private func compact() {
        if writeSnapshot(cached ?? [], rejected: quarantinedIDs) { removals = 0 }
    }
    private func writeSnapshot(_ events: [JSONObject], rejected: Set<String>) -> Bool {
        guard let fileURL else { persistenceFailed(); return false }
        do {
            if events.isEmpty {
                if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            } else {
                var data = Data()
                for event in events {
                    guard let encoded = Self.encode(event) else { return false }
                    data.append(encoded); data.append(10)
                }
                for id in rejected {
                    data.append(try JSONSerialization.data(withJSONObject: ["_au_quarantine": id])); data.append(10)
                }
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: fileURL, options: .atomic)
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.synchronize()
                excludeFromBackup()
            }
            return true
        } catch { persistenceFailed(); return false }
    }
    static func encode(_ event: JSONObject) -> Data? {
        guard JSONSerialization.isValidJSONObject(event) else { return nil }
        return try? JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
    }
    private func persistenceFailed() { AUDiagnostics.log("analytics", "persistenceFailed") }
    private func excludeFromBackup() {
        guard var url = fileURL else { return }
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
