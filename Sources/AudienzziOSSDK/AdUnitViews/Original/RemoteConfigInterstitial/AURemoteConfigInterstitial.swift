import UIKit
import PrebidMobile
import GoogleMobileAds

public enum AURemoteConfigInterstitialError: Error {
    case noRemoteConfig, deallocated, busy, cancelled, notReady, expired, inactive
}

/// Remote fullscreen inventory. By default a successful load immediately presents once,
/// matching Android. Set automaticallyShowOnLoad=false to explicitly preload instead.
@objcMembers
public class AURemoteConfigInterstitial: NSObject, FullScreenContentDelegate {
    private static weak var activePresentation: AURemoteConfigInterstitial?
    private var pendingPreloads: [AUInterstitialLoadCompletion] = []
    private var isPreloading = false
    private let adConfigId: String
    private var interstitialAdUnit: InterstitialAdUnit?
    private var loadedAd: AUInterstitialPresenting?
    private var loading = false
    private var presenting = false
    private var generation = 0
    private var loadedAt: TimeInterval?
    private var completion: AUInterstitialLoadCompletion?
    private var loadID = UUID().uuidString
    // Google keeps its delegate weak. Keep the owner until the presentation terminates.
    private var presentationOwner: AURemoteConfigInterstitial?

    public weak var delegate: FullScreenContentDelegate?
    public weak var presentationViewController: UIViewController?
    public var automaticallyShowOnLoad = true
    /// Includes preflight errors (inactive app, expired or absent ad) that have no Google ad callback.
    public var onPresentationError: ((NSError) -> Void)?
    /// Per-load diagnostics; forward to publisher analytics as needed.
    public var onLifecycleEvent: (([String: Any]) -> Void)?

    @nonobjc internal var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    @nonobjc internal var isForeground: () -> Bool = { UIApplication.shared.applicationState == .active }
    @nonobjc internal var loadOverride: ((@escaping (Result<AUInterstitialPresenting, Error>) -> Void) -> Void)?

    public init(adConfigId: String) {
        self.adConfigId = adConfigId
        super.init()
    }

    deinit {
        pendingPreloads.forEach { $0.finish(.failure(AURemoteConfigInterstitialError.deallocated)) }
    }

    public var isReady: Bool {
        loadedAd != nil && !presenting && loadedAt.map { now() - $0 < 3600 } == true
    }

    /// Completion reports loading, not presentation. Display failures go to onPresentationError
    /// and Google's delegate. Concurrent/redundant loads are rejected rather than replacing inventory.
    public func load(completion: @escaping (Result<Void, Error>) -> Void) {
        startLoad(automaticallyShow: true, completion: completion)
    }

    /// Retain one preload. Concurrent calls share its result; no completion schedules a show.
    public func preload(completion: @escaping (Result<Void, Error>) -> Void) {
        if isReady { completion(.success(())); return }
        if isPreloading {
            pendingPreloads.append(AUInterstitialLoadCompletion(completion)); return
        }
        guard !loading, !presenting else { completion(.failure(AURemoteConfigInterstitialError.busy)); return }
        isPreloading = true
        pendingPreloads.append(AUInterstitialLoadCompletion(completion))
        startLoad(automaticallyShow: false) { [weak self] result in
            guard let self else { return }
            let callbacks = self.pendingPreloads
            self.pendingPreloads = []
            self.isPreloading = false
            callbacks.forEach { $0.finish(result) }
        }
    }

    public func preloadWithCompletion(_ completion: @escaping (Error?) -> Void) {
        preload { result in
            switch result {
            case .success: completion(nil)
            case .failure(let error): completion(error)
            }
        }
    }

    /// Call on the main thread at an eligible transition, after checking publisher frequency caps.
    /// An unavailable ad skips this opportunity. It never queues a show for load completion.
    /// True means presentation was submitted; delegate/error callbacks report Google's outcome.
    @discardableResult
    public func showAtOpportunity(from controller: UIViewController, eligible: Bool) -> Bool {
        let reason: String?
        if !eligible { reason = "ineligible" }
        else if !isReady { reason = "notReady" }
        else if !isForeground() { reason = "inactive" }
        else if Self.activePresentation != nil { reason = "anotherInterstitialPresenting" }
        else { reason = nil }
        if let reason { emit("opportunitySkipped", reason: reason); return false }
        return present(from: controller)
    }

    private func startLoad(automaticallyShow: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !loading, !presenting, !isReady else {
            completion(.failure(AURemoteConfigInterstitialError.busy)); return
        }
        loadedAd = nil
        loadedAt = nil
        generation += 1
        let token = generation
        loading = true
        let pending = AUInterstitialLoadCompletion(completion)
        self.completion = pending
        loadID = UUID().uuidString
        emit("loadRequested")
        let receive: (Result<AUInterstitialPresenting, Error>) -> Void = { [weak self] result in
            guard let self else { pending.finish(.failure(AURemoteConfigInterstitialError.deallocated)); return }
            self.didLoad(result, generation: token, automaticallyShow: automaticallyShow)
        }
        if let loadOverride { loadOverride(receive); return }
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: adConfigId) else {
            receive(.failure(AURemoteConfigInterstitialError.noRemoteConfig)); return
        }
        let unit = InterstitialAdUnit(configId: config.prebidConfig.placementId)
        interstitialAdUnit = unit
        unit.adFormats = [.banner, .video]
        let request = AdManagerRequest()
        request.publisherProvidedID = PPIDManager.shared.getPPID()
        unit.fetchDemand(adObject: request) { [weak self] _ in
            guard let self else {
                receive(.failure(AURemoteConfigInterstitialError.deallocated)); return
            }
            guard self.loading, self.generation == token else { return }
            AdManagerInterstitialAd.load(with: config.gamConfig.adUnitPath, request: request) { ad, error in
                if let ad { receive(.success(AUGoogleInterstitial(ad))) }
                else { receive(.failure(error ?? AURemoteConfigInterstitialError.notReady)) }
            }
        }
    }

    private func didLoad(_ result: Result<AUInterstitialPresenting, Error>, generation token: Int, automaticallyShow: Bool) {
        guard loading, token == generation else { return }
        loading = false
        let callback = completion
        completion = nil
        switch result {
        case .failure(let error):
            emit("loadFailed", error: error)
            callback?.finish(.failure(error))
        case .success(let ad):
            loadedAd = ad
            loadedAt = now()
            ad.delegate = self
            emit("loaded")
            callback?.finish(.success(()))
            // A legacy caller may show/destroy in its load callback. Do not show twice.
            if automaticallyShow, automaticallyShowOnLoad, token == generation, loadedAd != nil, !presenting {
                present(from: presentationViewController)
            }
        }
    }

    public func loadWithCompletion(_ completion: @escaping (Error?) -> Void) {
        load { result in
            switch result {
            case .success: completion(nil)
            case .failure(let error): completion(error)
            }
        }
    }

    public func show(from rootViewController: UIViewController) { present(from: rootViewController) }

    @discardableResult
    private func present(from rootViewController: UIViewController?) -> Bool {
        guard !presenting, Self.activePresentation == nil else { return false } // Single-use, including reentrant publisher callbacks.
        guard let ad = loadedAd else { reportPresentationError(AURemoteConfigInterstitialError.notReady); return false }
        emit("showAttempted")
        guard isReady else { reportPresentationError(AURemoteConfigInterstitialError.expired); return false }
        guard isForeground() else { reportPresentationError(AURemoteConfigInterstitialError.inactive); return false }
        do { try ad.canPresent(from: rootViewController) }
        catch { reportPresentationError(error); return false }
        presenting = true
        Self.activePresentation = self
        presentationOwner = self
        ad.present(from: rootViewController)
        return true
    }

    private func reportPresentationError(_ error: Error) {
        emit("showFailed", error: error)
        loadedAd = nil
        loadedAt = nil
        onPresentationError?(error as NSError)
    }

    /// Cancels a preload. An on-screen ad keeps its owner until its terminal delegate callback.
    public func destroy() {
        guard !presenting else { emit("disposeDeferred"); return }
        generation += 1
        loading = false
        let callback = completion
        completion = nil
        emit("disposed")
        loadedAd = nil
        loadedAt = nil
        interstitialAdUnit = nil
        callback?.finish(.failure(AURemoteConfigInterstitialError.cancelled))
    }

    private func emit(_ event: String, error: Error? = nil, reason: String? = nil) {
        var values: [String: Any] = ["event": event, "loadId": loadID, "configId": adConfigId,
            "timestampMillis": Int(Date().timeIntervalSince1970 * 1000)]
        if let loadedAt { values["loadAgeMillis"] = Int((now() - loadedAt) * 1000) }
        values["responseId"] = loadedAd?.responseID
        if let reason { values["reason"] = reason }
        if let error = error as NSError? {
            values["errorCode"] = error.code; values["errorDomain"] = error.domain
            values["errorMessage"] = error.localizedDescription
        }
        onLifecycleEvent?(values)
    }

    internal func finishPresentation() {
        presenting = false
        if Self.activePresentation === self { Self.activePresentation = nil }
        loadedAd = nil
        loadedAt = nil
        presentationOwner = nil
    }

    private func owns(_ ad: FullScreenPresentingAd) -> Bool {
        presenting && (loadedAd?.googleAd as AnyObject?) === (ad as AnyObject)
    }

    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard owns(ad) else { return }
        emit("presented")
        delegate?.adWillPresentFullScreenContent?(ad)
    }
    public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        guard owns(ad) else { return }
        emit("impression")
        delegate?.adDidRecordImpression?(ad)
    }
    public func adDidRecordClick(_ ad: FullScreenPresentingAd) { guard owns(ad) else { return }; delegate?.adDidRecordClick?(ad) }
    public func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) { guard owns(ad) else { return }; delegate?.adWillDismissFullScreenContent?(ad) }
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard owns(ad) else { return }
        emit("dismissed")
        finishPresentation()
        delegate?.adDidDismissFullScreenContent?(ad)
    }
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        guard owns(ad) else { return }
        emit("showFailed", error: error)
        finishPresentation()
        onPresentationError?(error as NSError)
        delegate?.ad?(ad, didFailToPresentFullScreenContentWithError: error)
    }
}

internal protocol AUInterstitialPresenting: AnyObject {
    var delegate: FullScreenContentDelegate? { get set }
    var responseID: String? { get }
    var googleAd: FullScreenPresentingAd? { get }
    func canPresent(from controller: UIViewController?) throws
    func present(from controller: UIViewController?)
}
private final class AUGoogleInterstitial: AUInterstitialPresenting {
    let ad: AdManagerInterstitialAd
    init(_ ad: AdManagerInterstitialAd) { self.ad = ad }
    var delegate: FullScreenContentDelegate? {
        get { ad.fullScreenContentDelegate }
        set { ad.fullScreenContentDelegate = newValue }
    }
    var responseID: String? { ad.responseInfo.responseIdentifier }
    var googleAd: FullScreenPresentingAd? { ad }
    func canPresent(from controller: UIViewController?) throws { try ad.canPresent(from: controller) }
    func present(from controller: UIViewController?) { ad.present(from: controller) }
}


private final class AUInterstitialLoadCompletion {
    private var callback: ((Result<Void, Error>) -> Void)?
    init(_ callback: @escaping (Result<Void, Error>) -> Void) { self.callback = callback }
    func finish(_ result: Result<Void, Error>) {
        let run = callback
        callback = nil
        run?(result)
    }
}
