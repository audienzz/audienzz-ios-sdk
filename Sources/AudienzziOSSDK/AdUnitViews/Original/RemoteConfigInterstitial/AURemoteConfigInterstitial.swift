import UIKit
import PrebidMobile
import GoogleMobileAds

public enum AURemoteConfigInterstitialError: Error {
    case noRemoteConfig, deallocated, busy, cancelled, notReady, expired, inactive
}

/// Remote fullscreen inventory.
///
/// Three verbs, and each says exactly what it does:
///
///  * ``prefetch(completion:)`` obtains and retains one ad. It never presents.
///  * ``show(from:eligible:)`` presents ready inventory at the publisher's current opportunity.
///    If nothing is ready, the app is not active, or the publisher says this opportunity is not
///    eligible, that outcome is reported and NOTHING is scheduled — the reader will not be shown
///    an interstitial later, out of context.
///  * ``prefetchAndShow(from:completion:)`` asks for presentation when the load completes, or
///    presents inventory that is already in hand. This is the only entry point that presents
///    something the publisher did not explicitly time, and it is opted into by name.
///
/// Repeated prefetches for the same owner coalesce onto the load in flight and reuse valid ready
/// inventory; repeated presentation calls cannot show twice or start a parallel request.
///
/// **Migration.** `load(completion:)` is gone because its meaning changed under publishers: it
/// used to load and wait for an explicit show, and later presented on completion by default.
/// Rather than leave a method whose behaviour depends on which version you compiled against, both
/// behaviours now have their own name.
///
/// | Before | Now |
/// | --- | --- |
/// | `load { … }` used only to prepare inventory | `prefetch { … }`, then `show(from:)` at your opportunity |
/// | `load { … }` relied on for immediate display | `prefetchAndShow(from:) { … }` |
/// | `automaticallyShowOnLoad = false` + `load` | `prefetch` |
/// | `preload { … }` | `prefetch { … }` |
/// | `showAtOpportunity(from:eligible:)` | `show(from:eligible:)` |
/// | `show(from:)` | `show(from:)` — unchanged, now reports a skipped opportunity |
///
/// Deciding *when* an interstitial is appropriate stays with the publisher: pass your frequency
/// cap / placement decision as `eligible`.
@objcMembers
public class AURemoteConfigInterstitial: NSObject, FullScreenContentDelegate {
    private static weak var activePresentation: AURemoteConfigInterstitial?
    private var pendingPreloads: [AUInterstitialLoadCompletion] = []
    private var isPreloading = false
    /// Set by ``prefetchAndShow(from:completion:)`` only. An ordinary prefetch can never set it,
    /// which is what guarantees a prefetch cannot surprise the reader with a presentation.
    private var showWhenLoaded = false
    private let adConfigId: String
    private var interstitialAdUnit: InterstitialAdUnit?
    private var loadedAd: AUInterstitialPresenting?
    private var loading = false
    private var presenting = false
    private var generation = 0
    private var loadedAt: TimeInterval?
    private var completion: AUInterstitialLoadCompletion?
    /// Auction identity for this load, shared by every event of the load.
    ///
    /// Lower-cased through the same helper the banner path uses: the two were producing different
    /// casings for the same kind of identifier, so a single run's `auction_id` column mixed
    /// `CE4A378A-…` with `a58d608a-…` and could not be joined case-sensitively.
    private var loadID = AUUniqHelper.makeUniqID()
    private let adViewID = AUUniqHelper.makeUniqID()
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

    /// Obtain and retain one ad, without displaying it.
    ///
    /// Concurrent calls share the load in flight; a call made while valid inventory is already in
    /// hand succeeds immediately without spending another request. No completion here can lead to
    /// a presentation.
    public func prefetch(completion: @escaping (Result<Void, Error>) -> Void) {
        requestLoad(showWhenLoaded: false, from: nil, completion: completion)
    }

    public func prefetchWithCompletion(_ completion: @escaping (Error?) -> Void) {
        prefetch { completion($0.errorOrNil) }
    }

    /// Ask for presentation as soon as the load completes, or present inventory already in hand.
    ///
    /// Subject to the same guards as ``show(from:eligible:)``: a backgrounded app, expired
    /// inventory or another interstitial already on screen still cancel the presentation. Like
    /// ``prefetch(completion:)``, repeated calls coalesce rather than starting a second request.
    public func prefetchAndShow(from controller: UIViewController,
                                completion: @escaping (Result<Void, Error>) -> Void) {
        requestLoad(showWhenLoaded: true, from: controller, completion: completion)
    }

    /// Objective-C form; named apart from ``prefetchAndShow(from:completion:)`` so a bare closure
    /// is never ambiguous between the two.
    public func prefetchAndShowWithCompletion(from controller: UIViewController,
                                              completion: @escaping (Error?) -> Void) {
        prefetchAndShow(from: controller) { completion($0.errorOrNil) }
    }

    /// Present ready inventory at this opportunity. Never schedules a later presentation.
    @discardableResult
    public func show(from controller: UIViewController) -> Bool {
        show(from: controller, eligible: true)
    }

    /// Call on the main thread at an eligible transition, after checking publisher frequency caps.
    /// An unavailable ad skips this opportunity rather than queueing a show for load completion —
    /// that is what ``prefetchAndShow(from:completion:)`` is for, and it has to be asked for.
    /// True means presentation was submitted; delegate/error callbacks report Google's outcome.
    @discardableResult
    public func show(from controller: UIViewController, eligible: Bool) -> Bool {
        if let reason = skipReason(eligible: eligible) {
            emit("opportunitySkipped", reason: reason)
            return false
        }
        return present(from: controller)
    }

    /// Why this opportunity cannot be taken, or nil when it can.
    private func skipReason(eligible: Bool) -> String? {
        if !eligible { return "ineligible" }
        if !isReady { return "notReady" }
        if !isForeground() { return "inactive" }
        if Self.activePresentation != nil { return "anotherInterstitialPresenting" }
        return nil
    }

    /// The single loading path behind both ``prefetch(completion:)`` and
    /// ``prefetchAndShow(from:completion:)``. Whether a presentation follows is a property of the
    /// request, not a second loading system.
    private func requestLoad(showWhenLoaded: Bool,
                             from controller: UIViewController?,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        // The presentation intent is recorded ONLY on a path that accepts the request. Recording
        // it up front meant a call rejected because something was already on screen left the
        // intent behind, and the next ordinary `prefetch` presented on its back — the one thing a
        // prefetch promises never to do.
        if isReady {
            if let controller { presentationViewController = controller }
            completion(.success(()))
            // Already in hand: this is the same request, answered instantly. Presenting here is
            // what makes a second prefetchAndShow reuse inventory instead of buying more.
            if showWhenLoaded { presentWhenLoaded() }
            return
        }
        if isPreloading {
            // Joins the load in flight, and may add a presentation to it.
            if let controller { presentationViewController = controller }
            if showWhenLoaded { self.showWhenLoaded = true }
            pendingPreloads.append(AUInterstitialLoadCompletion(completion)); return
        }
        guard !loading, !presenting else { completion(.failure(AURemoteConfigInterstitialError.busy)); return }
        if let controller { presentationViewController = controller }
        if showWhenLoaded { self.showWhenLoaded = true }
        isPreloading = true
        pendingPreloads.append(AUInterstitialLoadCompletion(completion))
        startLoad { [weak self] result in
            guard let self else { return }
            let callbacks = self.pendingPreloads
            self.pendingPreloads = []
            self.isPreloading = false
            callbacks.forEach { $0.finish(result) }
        }
    }

    /// Present what was just loaded, under the same guards an explicit show would apply.
    ///
    /// Unlike ``show(from:eligible:)`` there is no return value for the caller to inspect, so a
    /// guard that cancels the presentation is also reported on ``onPresentationError`` — this is
    /// the presentation the publisher asked for when they called ``prefetchAndShow(from:completion:)``.
    private func presentWhenLoaded() {
        showWhenLoaded = false
        // The completion of a prefetchAndShow is allowed to present the ad itself. It then already
        // is on screen: nothing to do, and emphatically not a failed presentation — reporting one
        // clears `loadedAd`, which is what `owns(_:)` matches Google's callbacks against, so the
        // dismissal of the ad the reader is looking at would never be seen.
        guard !presenting else { return }
        if let reason = skipReason(eligible: true) {
            emit("opportunitySkipped", reason: reason)
            reportPresentationError(Self.presentationError(for: reason, holdingInventory: loadedAd != nil))
            return
        }
        present(from: presentationViewController)
    }

    private static func presentationError(for reason: String,
                                          holdingInventory: Bool) -> AURemoteConfigInterstitialError {
        switch reason {
        case "notReady": return holdingInventory ? .expired : .notReady
        case "inactive": return .inactive
        case "anotherInterstitialPresenting": return .busy
        default: return .notReady
        }
    }

    private func startLoad(completion: @escaping (Result<Void, Error>) -> Void) {
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
        loadID = AUUniqHelper.makeUniqID()
        emit("loadRequested")
        let receive: (Result<AUInterstitialPresenting, Error>) -> Void = { [weak self] result in
            guard let self else { pending.finish(.failure(AURemoteConfigInterstitialError.deallocated)); return }
            self.didLoad(result, generation: token)
        }
        guard let config = configuration(adConfigId) else {
            receive(.failure(AURemoteConfigInterstitialError.noRemoteConfig)); return
        }
        let unit = InterstitialAdUnit(configId: config.placementID)
        interstitialAdUnit = unit
        unit.adFormats = [.banner, .video]
        // The same request policy as every other original GAM path here: global targeting from the
        // shared manager (which also carries the SDK's own au_sdk / au_v keys), then the PPID.
        // Constructing a bare request meant a publisher's configured targeting never reached remote
        // interstitials at all, so targeted line items could not be selected for them.
        let request = AUTargeting.shared.customTargetingManager
            .applyToGamRequest(request: AdManagerRequest())
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

    private func didLoad(_ result: Result<AUInterstitialPresenting, Error>, generation token: Int) {
        guard loading, token == generation else { return }
        loading = false
        let callback = completion
        completion = nil
        switch result {
        case .failure(let error):
            // Nothing to present, and the request is over: a later prefetch must not inherit a
            // presentation that was asked for on behalf of a load that failed.
            showWhenLoaded = false
            emit("loadFailed", error: error)
            callback?.finish(.failure(error))
        case .success(let ad):
            loadedAd = ad
            loadedAt = now()
            discardReported = false
            ad.delegate = self
            emit("loaded")
            // Consumed here rather than inside the presentation, so that a completion which
            // presents or destroys cannot leave the request standing and have an unrelated later
            // prefetch inherit it.
            let presentOnCompletion = showWhenLoaded
            showWhenLoaded = false
            callback?.finish(.success(()))
            // A caller may show/destroy inside its own completion. Do not show twice.
            if presentOnCompletion, token == generation, loadedAd != nil, !presenting {
                presentWhenLoaded()
            }
        }
    }

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
        // Never take the owner away from an ad that is on screen. `owns(_:)` matches Google's
        // delegate callbacks against `loadedAd`, so clearing it mid-presentation makes every
        // terminal callback — dismissal included — unrecognisable, and this owner stays
        // "presenting" forever. Release on the terminal callback instead.
        //
        // A backstop, like ``discardReported``: the callers that could reach here while
        // presenting are already guarded (``presentWhenLoaded()`` returns early, ``present(from:)``
        // rejects a reentrant call), so no reachable sequence exercises this branch alone and no
        // test discriminates it. It is kept because the invariant it protects — an on-screen ad
        // keeps its owner — is what every Google callback is matched against.
        guard !presenting else {
            onPresentationError?(error as NSError)
            return
        }
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
        showWhenLoaded = false
        isPreloading = false
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
        // The interstitial funnel already names every step; diagnostics just mirrors it into the
        // same greppable stream as banners, so one capture shows both.
        AUDiagnostics.log("interstitial", event, [
            ("config", adConfigId), ("loadId", loadID), ("reason", reason),
            ("error", (error as NSError?).map { "\($0.domain)/\($0.code)" }),
        ])
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


private extension Result where Success == Void {
    /// ObjC convenience: the completions exposed to Objective-C report an optional error.
    var errorOrNil: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
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
