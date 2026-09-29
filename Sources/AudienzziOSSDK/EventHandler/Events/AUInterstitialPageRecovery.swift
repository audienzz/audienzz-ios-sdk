import Foundation

/// Captures the displayed page at presentation, independently of the prefetched ad's analytics.
internal final class AUInterstitialPageRecovery {
    private var token: UUID?
    private var revision = 0
    func onShown() {
        guard token == nil else { return }
        let token = UUID()
        self.token = token
        revision = AUScreenAdCoordinator.shared.beginInterstitial(token)
    }
    func finish(dismissed: Bool) {
        guard let token else { return }
        self.token = nil
        AUScreenAdCoordinator.shared.endInterstitial(token, revision: revision, dismissed: dismissed)
    }
    deinit { finish(dismissed: false) }
}
