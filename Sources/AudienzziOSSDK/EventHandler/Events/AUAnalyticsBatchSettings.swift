import Foundation

/// Publisher-wide delivery policy. The queue reads it before constructing each new HTTP request.
final class AUAnalyticsBatchSettings {
    static let shared = AUAnalyticsBatchSettings()
    static let defaultSize = 10
    static let maxSize = 15
    private let lock = NSLock()
    private var size = defaultSize

    static func resolve(_ value: Int?) -> Int {
        guard let value, value > 0 else { return defaultSize }
        return min(maxSize, value)
    }
    func applyBackendConfig(_ value: Int?) {
        lock.lock(); defer { lock.unlock() }
        size = Self.resolve(value)
    }
    var current: Int { lock.lock(); defer { lock.unlock() }; return size }
}
