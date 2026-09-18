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
    private let adViewID = UUID().uuidString
    private var analyticsAdUnitPath: String?
    private var recordedImpression = false
    /// Backstop for "at most one discard per load". The primary guarantee is that every discard
    /// site clears ``loadedAd`` immediately after reporting, so the nil check already rejects a
    /// second report; this flag keeps that true if a future release path forgets to clear it. It
    /// is deliberately not independently covered by a test — no reachable sequence currently
    /// exercises it alone.
    private var discardReported = false
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

    @nonobjc internal var configuration: (String) -> (placementID: String, adUnitPath: String)? = { id in
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: id) else { return nil }
        return (config.prebidConfig.placementId, config.gamConfig.adUnitPath)
    }
    @nonobjc internal var demand: (InterstitialAdUnit, AdManagerRequest, @escaping (ResultCode) -> Void) -> Void = {
        unit, request, completion in unit.fetchDemand(adObject: request, completion: completion)
    }
    @nonobjc internal var analytics: (AUEventDomain) -> Void = { AUEventsManager.shared.logEvent($0) }

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
        // Reaching here with inventory in hand means it aged out: the guard above already
        // established that nothing is presenting, so `isReady` can only be false because the
        // hour-long GAM lifetime elapsed. That response was filled and never seen.
        reportDiscardIfUnused("expired")
        loadedAd = nil
        loadedAt = nil
        analyticsAdUnitPath = nil
        recordedImpression = false
        discardReported = false
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
        guard let config = configuration(adConfigId) else {
            receive(.failure(AURemoteConfigInterstitialError.noRemoteConfig)); return
        }
        let unit = InterstitialAdUnit(configId: config.placementID)
        interstitialAdUnit = unit
        unit.adFormats = [.banner, .video]
        let request = AdManagerRequest()
        request.publisherProvidedID = PPIDManager.shared.getPPID()
        analyticsAdUnitPath = config.adUnitPath
        let started = now()
        recordAnalytics(.bidRequest)
        var answered = false
        demand(unit, request) { [weak self] result in
            guard let self else {
                receive(.failure(AURemoteConfigInterstitialError.deallocated)); return
            }
            guard self.loading, self.generation == token, !answered else { return }
            answered = true
            let bidder = AUBannerView.keyword("hb_bidder", in: request.customTargeting ?? [:])
            let won = result == .prebidDemandFetchSuccess && bidder?.isEmpty == false
            let code = AUResulrCodeConverter.convertResultCodeName(result)
            let elapsed = Int64(max(0, self.now() - started) * 1000)
            self.recordAnalytics(.bidResponse, resultCode: code, elapsed: elapsed, bidder: won ? bidder : nil)
            self.recordAnalytics(won ? .bidWon : .noBid,
                resultCode: won ? nil : (result == .prebidDemandFetchSuccess ? "NO_BIDS" : code),
                elapsed: elapsed, bidder: won ? bidder : nil)
            if let loadOverride = self.loadOverride { loadOverride(receive); return }
            AdManagerInterstitialAd.load(with: config.adUnitPath, request: request) { ad, error in
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
            discardReported = false
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
        reportDiscardIfUnused("presentationFailed")
        loadedAd = nil
        loadedAt = nil
        onPresentationError?(error as NSError)
    }

    /// Cancels a preload. An on-screen ad keeps its owner until its terminal delegate callback.
    @objc public func destroy() {
        destroy(reason: "disposed")
    }

    /// As ``destroy()``, but records *why* held inventory is being released.
    ///
    /// A bridge that tears an owner down in order to build its successor knows that is a
    /// replacement; from inside this class it is indistinguishable from an ordinary disposal.
    /// Only the discard reason changes — teardown is identical.
    @objc public func destroy(reason: String) {
        guard !presenting else { emit("disposeDeferred"); return }
        generation += 1
        loading = false
        let callback = completion
        completion = nil
        emit("disposed")
        reportDiscardIfUnused(reason)
        loadedAd = nil
        loadedAt = nil
        interstitialAdUnit = nil
        callback?.finish(.failure(AURemoteConfigInterstitialError.cancelled))
    }

    /// Reports, at most once per load, that inventory which loaded successfully was released
    /// without ever recording an impression.
    ///
    /// This is the event that makes the load-to-impression gap visible from inside the SDK:
    /// `loaded` without a matching `impression` is otherwise silent, and expiry in particular was
    /// only ever evaluated lazily inside `isReady`, so an ad could age out with nothing recorded
    /// anywhere.
    ///
    /// It deliberately does not fire for a load that failed (there was no inventory) or for
    /// inventory that already recorded an impression (it was used).
    ///
    /// It is a diagnostic, not a billing record. It counts what this SDK handed to, and took back
    /// from, the ad server — not Ad Manager's responses-served or render rate, which are measured
    /// server-side across demand sources this SDK cannot see. Use it to find *which* placements
    /// and *which* reasons dominate, then confirm magnitude in Ad Manager reporting.
    ///
    /// A terminal event is not guaranteed: if the process is killed while inventory is held,
    /// nothing is emitted for it, so these counts are a lower bound.
    private func reportDiscardIfUnused(_ reason: String) {
        guard loadedAd != nil, !recordedImpression, !discardReported else { return }
        discardReported = true
        emit("discardedWithoutImpression", reason: reason)
    }

    /// Use the same clickstream sink/schema as other native ad units. Auction and render are
    /// separate facts: a Prebid bid win alone cannot identify the eventual GAM render winner.
    private func recordAnalytics(_ type: AUAnalyticsEventType, resultCode: String? = nil,
                                 elapsed: Int64? = nil, bidder: String? = nil) {
        guard let analyticsAdUnitPath else { return }
        var event = AUEventDomain(type: type)
        event.adUnitId = analyticsAdUnitPath
        event.adViewId = adViewID
        event.auctionId = loadID
        event.adType = AUAdType.interstitial
        event.adSubtype = AUAdSubtype.multiformat
        event.apiType = AUEventApiType.original
        event.resultCode = resultCode
        event.timeToRespond = elapsed
        if type == .bidRequest || type == .bidResponse || type == .bidWon || type == .noBid {
            event.isAutorefresh = false
            event.autorefreshTime = 0
            event.isRefresh = false
            event.mediaTypes = AUBannerView.mediaTypesJSON(subtype: AUAdSubtype.multiformat)
            event.bidderCode = bidder
        }
        analytics(event)
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

    internal func finishPresentation(discardReason: String? = nil) {
        if let discardReason { reportDiscardIfUnused(discardReason) }
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
        guard owns(ad), !recordedImpression else { return }
        recordedImpression = true
        recordAnalytics(.adImpression)
        emit("impression")
        delegate?.adDidRecordImpression?(ad)
    }
    public func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        guard owns(ad) else { return }
        recordAnalytics(.adClick)
        emit("clicked")
        delegate?.adDidRecordClick?(ad)
    }
    public func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) { guard owns(ad) else { return }; delegate?.adWillDismissFullScreenContent?(ad) }
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard owns(ad) else { return }
        emit("dismissed")
        // Presented and dismissed with no impression callback in between: the creative was on
        // screen but Google never counted it. Distinct from a presentation that failed outright.
        finishPresentation(discardReason: "dismissedWithoutImpression")
        delegate?.adDidDismissFullScreenContent?(ad)
    }
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        guard owns(ad) else { return }
        emit("showFailed", error: error)
        finishPresentation(discardReason: "presentationFailed")
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
