import Foundation

/// Fullscreen demand is explicitly requested by its owner, never by page or viewport refresh.
/// A generation prevents a disposed request from delivering a late ad-server handoff.
internal final class AUFullscreenDemand {
    private var generation = 0
    private var inFlight = false
    private var destroyed = false

    func begin() -> Int? {
        guard !destroyed, !inFlight else { return nil }
        generation += 1
        inFlight = true
        return generation
    }

    func finish(_ token: Int) -> Bool {
        guard !destroyed, inFlight, token == generation else { return false }
        inFlight = false
        return true
    }

    func destroy() {
        destroyed = true
        inFlight = false
        generation += 1
    }
}
