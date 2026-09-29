import Foundation

/// Analytics identity is independent of the Prebid account/schain seller. Read once per event.
final class AUAnalyticsContext {
    static let shared = AUAnalyticsContext()
    private let lock = NSLock()
    private var publisherId: String?
    private var environment = "production"

    func configure(publisherId: String?, environment: String) -> Bool {
        guard ["production", "staging", "test"].contains(environment) else { return false }
        lock.lock(); defer { lock.unlock() }
        self.publisherId = publisherId?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.environment = environment
        return true
    }

    func setPublisherId(_ publisherId: String?) {
        lock.lock(); defer { lock.unlock() }
        self.publisherId = publisherId?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    func snapshot() -> (publisherId: String?, environment: String) {
        lock.lock(); defer { lock.unlock() }
        return (publisherId, environment)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// Immutable screen-visit identity captured when an ad request starts. An empty snapshot means
/// the publisher has not reported a page yet; it must never adopt a later screen's identity.
struct AUAnalyticsPageContext {
    var pageImpressionId: String? = nil
    var screenName: String? = nil
}
