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
import GoogleMobileAds
import PrebidMobile
import UIKit

private let customPrebidServerURL = "https://ib.adnxs.com/openrtb2/prebid"
private let prebidServerAccountId = "3927"
private let customStatusEndpoint = "https://ib.adnxs.com/status"

internal let AUSDKVersion = "0.3.2"

@objcMembers
public class Audienzz: NSObject {
    var audienzzSchainObjectConfig: String?

    // MARK: - Properties (SDK)

    public var timeoutUpdated: Bool {
        get { Prebid.shared.timeoutUpdated }
        set { Prebid.shared.timeoutUpdated = newValue }
    }

    public var audienzServerAccountId: String {
        get { Prebid.shared.prebidServerAccountId }
        set { Prebid.shared.prebidServerAccountId = newValue }
    }

    public var pbsDebug: Bool {
        get { Prebid.shared.pbsDebug }
        set { Prebid.shared.pbsDebug = newValue }
    }

    public var customHeaders: [String: String] {
        get { Prebid.shared.customHeaders }
        set { Prebid.shared.customHeaders = newValue }
    }

    public var storedBidResponses: [String: String] {
        get { Prebid.shared.storedBidResponses }
        set { Prebid.shared.storedBidResponses = newValue }
    }

    public static let shared = Audienzz()

    public func configureSDK(companyId: String, appVolume: Float = 0) {
        setupPrebid(companyId, appVolume: appVolume)

        do {
            try Prebid.initializeSDK(serverURL: customPrebidServerURL) {
                status,
                    error in
                self.handleInitializationResultStatus(status: status)


                if let error = error {
                    AULogEvent.logDebug("Initialization Error: \(error)")
                }
            }
        } catch {
            AULogEvent.logDebug(
                "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
            )
        }
    }

    public func configureSDK(
        companyId: String,
        gadMobileAdsVersion: String? = nil,
        appVolume: Float = 0
    ) {
        setupPrebid(companyId, appVolume: appVolume)

        do {
            try Prebid.initializeSDK(
                serverURL: customPrebidServerURL,
                gadMobileAdsVersion: gadMobileAdsVersion
            ) { status, error in
                if let error = error {
                    AULogEvent.logDebug(
                        "Initialization Error: \(error.localizedDescription)"
                    )
                    return
                }

                self.handleInitializationResultStatus(status: status)
            }
        } catch {
            AULogEvent.logDebug(
                "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
            )
        }
    }

    public func configureWithRemoteSDK(
        gadMobileAdsVersion: String? = nil
    ) async throws {
        // Apply muted default immediately so ads are always muted even if remote
        // config is unavailable (network error, backend not ready, nil response).
        // The value will be overridden below once the remote config is fetched.
        applyGamAppVolume(0)

        do {
            try await AudienzzRemoteConfig.shared.fetchPublisherConfig()
        } catch {
            // Don't abort init on fetch failure — fall through to the fallback
            // below so a first-launch user on a flaky network can still monetize.
            AULogEvent.logDebug(
                "Audienzz Remote Config fetch failed: \(error). Falling back to default Prebid host/account."
            )
        }

        guard let publisherConfig = AudienzzRemoteConfig.shared.publisherConfig else {
            // Cold start with no cache and no network: initialize Prebid with the
            // hardcoded default host/account instead of leaving the SDK dead.
            AULogEvent.logDebug(
                "Audienzz Remote Config unavailable — initializing with default Prebid host/account"
            )
            setupRemotePrebid(
                AudienzzRemoteConfig.shared.publisherId ?? "1",
                prebidServerAccountId: prebidServerAccountId,
                prebidStatusUrl: customStatusEndpoint,
                appVolume: 0
            )
            initializePrebid(
                serverURL: customPrebidServerURL,
                gadMobileAdsVersion: gadMobileAdsVersion,
            )
            return
        }

        setupRemotePrebid(
            AudienzzRemoteConfig.shared.publisherId ?? "1",
            prebidServerAccountId: publisherConfig.prebidServer.accountId,
            prebidStatusUrl: publisherConfig.prebidServer.statusUrl,
            appVolume: publisherConfig.gamConfig?.appVolume ?? 0
        )

        if let schain = publisherConfig.ortb?.schain {
            // Build via JSONSerialization instead of string interpolation so a
            // quote/backslash in the backend-provided asi/sid can't produce
            // malformed JSON (which silently drops the schain).
            let schainDict: [String: Any] = [
                "source": [
                    "ext": [
                        "schain": [
                            "complete": 1,
                            "nodes": [[
                                "asi": schain.advertisingSystemDomain,
                                "sid": schain.sellerId,
                                "hp": 1
                            ]],
                            "ver": "1.0"
                        ]
                    ]
                ]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: schainDict),
               let schainJson = String(data: data, encoding: .utf8) {
                setSchainObject(schain: schainJson)
            }
        }

        if let ortb = publisherConfig.ortb {
            AUTargeting.shared.publisherName = ortb.publisherName
            AUTargeting.shared.domain = ortb.domain
        }

        if let iosOrtb = publisherConfig.ios?.ortb {
            AUTargeting.shared.storeURL = iosOrtb.storeUrl
            AUTargeting.shared.sourceapp = iosOrtb.sourceApp
            AUTargeting.shared.itunesID = iosOrtb.bundleId
        }

        initializePrebid(
            serverURL: publisherConfig.prebidServer.url,
            gadMobileAdsVersion: gadMobileAdsVersion,
        )
    }

    /// Shared Prebid initialization used by the remote-config flow (both the
    /// happy path and the default-host fallback).
    private func initializePrebid(
        serverURL: String,
        gadMobileAdsVersion: String?
    ) {
        do {
            try Prebid.initializeSDK(
                serverURL: serverURL,
                gadMobileAdsVersion: gadMobileAdsVersion
            ) { status, error in
                if let error = error {
                    AULogEvent.logDebug(
                        "Initialization Error: \(error.localizedDescription)"
                    )
                    return
                }

                self.handleInitializationResultStatus(status: status)
            }
        } catch {
            AULogEvent.logDebug(
                "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Public Init For RN Bridg (Audienzz)

    /// Stable Obj-C selector for RN bridge: `configureSDK_RNWithCompanyId:completion:`
    @objc(configureSDK_RNWithCompanyId:completion:)
    public func configureSDK_RN(
        companyId: String,
        completion: (() -> Void)?
    ) {
        configureSDK_RN(companyId: companyId, appVolume: 0, completion)
    }

    /// Special method used for RN bridging initialization
    public func configureSDK_RN(
        companyId: String,
        appVolume: Float = 0,
        _ completion: (() -> Void)? = nil
    ) {
        Task {
            setupPrebid(companyId, appVolume: appVolume)

            do {
                try Prebid.initializeSDK(serverURL: customPrebidServerURL) {
                    status,
                        error in
                    self.handleInitializationResultStatus(status: status)

                    if let error = error {
                        AULogEvent.logDebug("Initialization Error: \(error)")
                    }

                    completion?()
                }
            } catch {
                AULogEvent.logDebug(
                    "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
                )
                // You may want to call completion here as well depending on your error handling strategy
                completion?()
            }
        }
    }

    /// Special method used for RN bridging initialization
    public func configureSDK_RN(
        companyId: String,
        gadMobileAdsVersion: String?,
        appVolume: Float = 0,
        _ completion: (() -> Void)? = nil
    ) {
        Task {
            setupPrebid(companyId, appVolume: appVolume)

            do {
                try Prebid.initializeSDK(
                    serverURL: customPrebidServerURL,
                    gadMobileAdsVersion: gadMobileAdsVersion
                ) { status, error in
                    if let error = error {
                        AULogEvent.logDebug(
                            "Initialization Error: \(error.localizedDescription)"
                        )
                        // Must still resolve the bridge promise, otherwise the
                        // RN/JS caller hangs forever on init failure.
                        completion?()
                        return
                    }

                    self.handleInitializationResultStatus(status: status)
                    completion?()
                }
            } catch {
                AULogEvent.logDebug(
                    "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
                )
                // You may want to call completion here as well depending on your error handling strategy
                completion?()
            }
        }
    }

    // MARK: - Public Properties (Audienzz)

    /// Sets the global GMA ad audio volume.
    ///
    /// Can be called at any time after initialization to update the volume mid-session.
    /// The value set here takes precedence over the backend `gamConfig.setAppVolume` for the
    /// remainder of the session.
    ///
    /// - Parameter volume: Audio level in range [0.0, 1.0]. 0.0 = muted, 1.0 = full device volume.
    ///                     Values outside the range are clamped automatically.
    public func setAppVolume(_ volume: Float) {
        let clamped = min(max(volume, 0), 1)
        if clamped != volume {
            AULogEvent.logDebug("setAppVolume: \(volume) is out of [0.0, 1.0], clamped to \(clamped)")
        }
        MobileAds.shared.applicationVolume = clamped
        MobileAds.shared.isApplicationMuted = (clamped == 0)
        AULogEvent.logDebug("GMA app volume updated to \(clamped), muted=\(clamped == 0)")
    }

    // MARK: - Smart refresh v2 (screen-aware) feature flag

    /// Local override for the screen-aware smart-refresh model (directional viewport gate +
    /// screen-navigation pause/reload). Takes precedence over the backend
    /// `publisherConfig.smartRefreshV2` for the remainder of the session. `nil` (default) = defer
    /// to the backend value; `false`/`true` = force off/on regardless of the backend.
    public var smartRefreshV2Override: Bool?

    /// Objective-C entry point for the override above.
    ///
    /// A Swift `Bool?` is not representable in Objective-C, so `smartRefreshV2Override` is absent
    /// from the generated header and the React Native bridge — which is Objective-C — could not
    /// build against it at all. Setting the tri-state from ObjC needs an explicit method.
    @objc public func setSmartRefreshV2Override(_ enabled: Bool) {
        smartRefreshV2Override = enabled
    }

    /// Clears the local override, deferring to the backend `smartRefreshV2` value again.
    @objc public func clearSmartRefreshV2Override() {
        smartRefreshV2Override = nil
    }

    /// Resolved smart-refresh-v2 flag: local override wins, else the backend publisher config, else
    /// `false` (legacy smart refresh). Read at use-time so it picks up the async remote config once
    /// it loads.
    /// Whether any PPID may be sent. Backend-controlled; absent → enabled.
    ///
    /// There is deliberately no public setter. A PPID is always sent unless the backend turns it
    /// off for that publisher, and the only thing an app decides is *which* identifier to use, via
    /// `PPIDManager.setPublisherPPID`.
    internal var isPpidEnabled: Bool {
        backendPpidEnabled ?? AudienzzRemoteConfig.shared.publisherConfig?.ppidEnabled ?? true
    }

    /// Whether the SDK may mint its own PPID. Backend-controlled; absent → enabled.
    internal var isAutomaticPpidEnabled: Bool {
        backendAutomaticPpidEnabled
            ?? AudienzzRemoteConfig.shared.publisherConfig?.automaticPpidEnabled
            ?? true
    }

    private var backendPpidEnabled: Bool?
    private var backendAutomaticPpidEnabled: Bool?

    /// Applies the publisher config's PPID switches.
    ///
    /// The SDK reads them from its own remote config when it fetched that itself. The Flutter
    /// bridge fetches the publisher config in Dart, so `publisherConfig` is nil there and the
    /// resolved values have to be handed down instead. Not part of the documented app-facing API.
    public func applyBackendPpidConfig(ppidEnabled: Bool?, automaticPpidEnabled: Bool?) {
        backendPpidEnabled = ppidEnabled
        backendAutomaticPpidEnabled = automaticPpidEnabled
    }

    internal var isSmartRefreshV2Enabled: Bool {
        smartRefreshV2Override
            ?? AudienzzRemoteConfig.shared.publisherConfig?.smartRefreshV2
            ?? false
    }

    /// When `true`, a screen-change reload (smart refresh v2, on returning to a screen) briefly
    /// blanks the current banner — keeping the slot's size — until the fresh ad renders, making the
    /// refresh visually obvious. Default `false`. Only affects screen-change reloads, not periodic
    /// refresh.
    public var blankOnScreenReload: Bool = false

    public var timeoutMillis: Int {
        // Assigning Prebid's `timeoutMillis` also updates `timeoutMillisDynamic`
        // (via its didSet), so the auction picks up the value AND the getter
        // reflects what was set. Writing only Dynamic left the getter stale.
        get { Prebid.shared.timeoutMillis }
        set { Prebid.shared.timeoutMillis = newValue }
    }

    public var timeoutMillisDynamic: NSNumber? {
        get { Prebid.shared.timeoutMillisDynamic }
        set { Prebid.shared.timeoutMillisDynamic = newValue }
    }

    public var storedAuctionResponse: String? {
        // Previously a dead stored property — setting it never reached Prebid,
        // so the stored-auction-response feature silently did nothing.
        get { Prebid.shared.storedAuctionResponse }
        set { Prebid.shared.storedAuctionResponse = newValue }
    }

    // MARK: - Stored Bid Response

    public func addStoredBidResponse(bidder: String, responseId: String) {
        Prebid.shared.storedBidResponses[bidder] = responseId
    }

    public func clearStoredBidResponses() {
        storedBidResponses.removeAll()
    }

    public func getStoredBidResponses() -> [[String: String]]? {
        var storedBidResponses: [[String: String]] = []

        for (bidder, responseId) in Prebid.shared.storedBidResponses {
            var storedBidResponse: [String: String] = [:]
            storedBidResponse["bidder"] = bidder
            storedBidResponse["id"] = responseId
            storedBidResponses.append(storedBidResponse)
        }
        return storedBidResponses.isEmpty ? nil : storedBidResponses
    }

    // MARK: - Custom Headers

    public func addCustomHeader(name: String, value: String) {
        customHeaders[name] = value
    }

    public func clearCustomHeaders() {
        customHeaders.removeAll()
    }

    /// Set publisher schain object to use with ad requests
    public func setSchainObject(schain: String) {
        audienzzSchainObjectConfig = schain
        AUTargeting.shared.setGlobalOrtbConfig(ortbConfig: schain)
    }

    /// Report an ad-bearing screen, dialog, or popup by its view controller — call from `viewDidAppear`
    /// (or when a dialog/overlay appears). The screen name is derived from the controller's type unless
    /// `name` is provided. Fires a `pageImpression` and a fresh page-impression id that ties all
    /// subsequent ad events on this visit together. Screens without ads don't need to call it.
    public func pageImpression(_ viewController: UIViewController, name: String? = nil) {
        let screenName = name ?? String(describing: type(of: viewController))
        AULogEvent.logDebug(
            "[Audienzz][pageImpression] viewController=\(type(of: viewController)) → \"\(screenName)\" (\(name == nil ? "derived" : "override"))")
        notifyScreenResumed(viewController, name: screenName)
    }

    /// Report an ad-bearing screen, dialog, or popup by an explicit name (e.g. a SwiftUI or route
    /// name). Fires the page impression and drives screen-aware smart refresh (v2) for banners tagged
    /// with the same name via `AUBannerView.setScreen(_:)` — matched by value.
    @objc(pageImpressionWithName:)
    public func pageImpression(_ name: String) {
        AULogEvent.logDebug("[Audienzz][pageImpression] name=\"\(name)\"")
        notifyScreenResumed(name as AnyObject, name: name)
    }

    /// Report a screen whose identity and analytics name are different things.
    ///
    /// `pageId` identifies the *page instance* and is matched by value against a banner's
    /// `setScreen(_:)`; `name` is what analytics records. They are separated because a name legit-
    /// imately repeats — two article screens are both "article" — while ownership must not. Passing
    /// the name as both, which ``pageImpression(_:)-(String)`` does, makes the second article's page
    /// impression recreate the first article's banners instead of releasing them.
    ///
    /// Host bridges mint the id per route instance. A native app with distinct view controllers
    /// should keep using ``pageImpression(_:name:)`` and let identity be the controller.
    @objc(pageImpressionWithPageId:name:)
    public func pageImpression(pageId: String, name: String) {
        AULogEvent.logDebug("[Audienzz][pageImpression] pageId=\"\(pageId)\" name=\"\(name)\"")
        notifyScreenResumed(pageId as NSString, name: name)
    }

    /// Single sink for the manual page-impression API: page impression + the page-scoped ad
    /// coordinator. Takes any screen token (a `UIViewController` or a name).
    ///
    /// Ads are page-scoped unconditionally — this is NOT gated on `isSmartRefreshV2Enabled`, which
    /// now only selects the viewport gate used for scroll pause/resume. Every page impression
    /// releases the previous page's banners and reloads the incoming page's, so a banner can never
    /// keep auctioning for a screen the user has left.
    internal func notifyScreenResumed(_ screen: AnyObject, name: String) {
        AULogEvent.logDebug("[Audienzz][pageImpression] firing → \"\(name)\"")
        // An explicit report always wins over a pending automatic foreground one, and claims this
        // foreground visit so an activation arriving afterwards doesn't schedule a duplicate.
        reportedInThisForegroundVisit = true
        cancelPendingForegroundReimpression()
        // Armed on the first page impression, so there is always an active screen to re-fire for.
        observeForegroundReimpression()
        AUEventsManager.shared.onScreenResumed(screenName: name)
        AUScreenAdCoordinator.shared.onScreenResumed(screen, name: name)
        // Emitted only once the transition is complete. An observer is free to report another page
        // — the bridges hand this to app code — and running it mid-transition let that nested
        // report finish first, after which this call's sweep overwrote it with the older page.
        pageImpressionObserver?(name)
    }

    // MARK: - Foreground re-impression

    /// Returning from the background is a new page impression for the screen the user comes back to:
    /// its banners reload so the creative is fresh at the moment it's looked at, and any banner left
    /// over from an earlier screen is released.
    ///
    /// Suppressed when the app itself reported a page impression within
    /// `foregroundReimpressionDebounce` of the activation (the common case where a view controller's
    /// `viewDidAppear` also fires on return), so a restore never double-auctions.
    internal func observeForegroundReimpression() {
        guard foregroundObserver == nil else { return }
        // Only a real background → foreground round trip counts. `didBecomeActive` alone also fires
        // after Control Centre, a system permission prompt or an incoming call — none of which are a
        // new page view, and all of which would otherwise burn an auction.
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.didEnterBackground = true
            self?.isAppBackgrounded = true
            // A new foreground visit starts when we come back, and nothing has been reported for it
            // yet. Whether the app reports one itself is a property of THAT visit, not of how long
            // ago the last report happened.
            self?.reportedInThisForegroundVisit = false
            // Drop any pending automatic re-impression: backgrounding again inside the scheduling
            // window would otherwise recreate the whole active page while backgrounded.
            self?.cancelPendingForegroundReimpression()
            // Hold every banner's refresh for the duration of the background, and retire whatever
            // auction was in flight. A `DispatchWorkItem` scheduled on the main queue would fire on
            // return regardless, and a response landing meanwhile buys a creative nobody sees.
            AUScreenAdCoordinator.shared.blockForBackground()
        }
        // Clear the auction gate at willEnterForeground, not didBecomeActive. An app that reports
        // its page from `willEnterForeground` runs BEFORE activation: with the gate still closed its
        // recreation was rejected, and the activation that followed then suppressed the automatic
        // re-impression as a duplicate — so the visit got no fresh auction at all and a blanked slot
        // could stay blank.
        willForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Only the gate opens here. Deferred retries deliberately do NOT run yet: whether an
            // automatic page impression is going to own this recovery is not known until
            // didBecomeActive, and the gap between the two notifications is not bounded. Retrying
            // here meant a long gap let the retry auction first and the impression auction again.
            self?.isAppBackgrounded = false
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isAppBackgrounded = false
            // Exactly one owner recovers each banner. A page impression — scheduled here, or already
            // reported by the app during this visit — recreates every banner on the active page and
            // clears their background block itself. Only when no impression is going to happen does
            // the coordinator resume them directly; doing both is how one return used to produce two
            // auctions per banner.
            var impressionOwnsRecovery = false
            if self.didEnterBackground {
                self.didEnterBackground = false
                impressionOwnsRecovery = self.scheduleForegroundReimpression()
            }
            if !impressionOwnsRecovery {
                AUScreenAdCoordinator.shared.resumeAfterForeground()
            }
        }
    }

    /// Schedules the automatic re-impression instead of firing it immediately, so an app that
    /// reports its own page impression on resume cancels it. That makes the outcome the same in
    /// both callback orders — exactly one page impression, not two.
    /// - Returns: `true` when a page impression owns this visit's recovery — either one is now
    ///   scheduled, or the app already reported one itself. `false` means nothing else will recreate
    ///   the banners, so the caller must resume them directly.
    @discardableResult
    private func scheduleForegroundReimpression() -> Bool {
        guard let (screen, name) = AUScreenAdCoordinator.shared.activeScreenAndName else {
            AULogEvent.logDebug("[Audienzz][pageImpression] foreground — no active screen yet, skipping")
            return false
        }
        // Cancelling on an explicit report only covers the order "activation first". An app that
        // reports from `willEnterForeground` reports BEFORE activation, so also check whether this
        // visit has already been reported.
        //
        // Deliberately not an elapsed-time test. Age and ownership are different questions, and
        // conflating them failed both ways: a slow willEnterForeground → didBecomeActive gap made a
        // report from this visit look old enough to ignore (two impressions), and a quick
        // background/return made a report from the PREVIOUS visit look recent enough to suppress
        // this one (no impression at all).
        guard !reportedInThisForegroundVisit else {
            AULogEvent.logDebug(
                "[Audienzz][pageImpression] foreground — app already reported \"\(name)\" this visit, skipping")
            // The report may have run before our foreground observer opened the auction gate.
            // No impression is pending; unblock and recover any load that report could not start.
            return false
        }
        pendingForegroundReimpression?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingForegroundReimpression = nil
            AULogEvent.logDebug("[Audienzz][pageImpression] foreground → re-firing \"\(name)\"")
            self?.notifyScreenResumed(screen, name: name)
        }
        pendingForegroundReimpression = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.foregroundReimpressionDelay, execute: work)
        return true
    }

    /// True while an automatic foreground page impression is scheduled. A banner whose auction the
    /// gate deferred consults this: the impression recreates every banner on the active page, so it
    /// owns the recovery and a deferred retry must stand down rather than auction as well.
    internal var hasPendingForegroundReimpression: Bool { pendingForegroundReimpression != nil }

    internal func cancelPendingForegroundReimpression() {
        pendingForegroundReimpression?.cancel()
        pendingForegroundReimpression = nil
    }

    #if DEBUG
    /// Test isolation only: no page report is synthesized, so pre-page behavior remains testable.
    @nonobjc internal func resetLifecycleForTesting() {
        cancelPendingForegroundReimpression()
        let center = NotificationCenter.default
        [foregroundObserver, backgroundObserver, willForegroundObserver].compactMap { $0 }
            .forEach { center.removeObserver($0) }
        foregroundObserver = nil
        backgroundObserver = nil
        willForegroundObserver = nil
        didEnterBackground = false
        isAppBackgrounded = false
        reportedInThisForegroundVisit = false
        pageImpressionObserver = nil
        AUScreenAdCoordinator.shared.resetForTesting()
        observeForegroundReimpression()
    }
    #endif

    /// Delay before an automatic foreground re-impression fires, giving the app's own report a
    /// chance to cancel it.
    private static let foregroundReimpressionDelay: TimeInterval = 0.4

    /// True between `didEnterBackground` and the next activation. Read by the ad views' auction
    /// gate, so nothing auctions while the app is backgrounded.
    internal private(set) var isAppBackgrounded = false

    private var didEnterBackground = false
    /// Notified after every page impression, including the automatic one fired on returning to the
    /// foreground.
    ///
    /// The Flutter and React Native bridges need to know a page transition happened so they can
    /// remount platform views and page-scope the ad types the native coordinator doesn't track. They
    /// used to observe their own app lifecycle and report a page impression themselves, which meant
    /// two independent owners each scheduling and de-duplicating — no ordering of the two ever came
    /// out right. Native owns foreground reporting; the bridges just listen.
    public var pageImpressionObserver: ((String) -> Void)?

    /// Whether the app reported a page impression itself during the current foreground visit.
    /// Reset when the app backgrounds, so each visit is judged on its own.
    private var reportedInThisForegroundVisit = false
    private var pendingForegroundReimpression: DispatchWorkItem?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var willForegroundObserver: NSObjectProtocol?

    private func setupPrebid(_ companyId: String, appVolume: Float = 0) {
        AUEventsManager.shared.configure(companyId: companyId)
        Prebid.shared.prebidServerAccountId = prebidServerAccountId
        Prebid.shared.customStatusEndpoint = customStatusEndpoint
        Targeting.shared.omidPartnerName = "Google"
        let v = MobileAds.shared.versionNumber
        Targeting.shared.omidPartnerVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        applyGamAppVolume(appVolume)
    }

    private func setupRemotePrebid(
        _ companyId: String,
        prebidServerAccountId: String,
        prebidStatusUrl: String,
        appVolume: Float = 0
    ) {
        AUEventsManager.shared.configure(companyId: companyId)
        Prebid.shared.prebidServerAccountId = prebidServerAccountId
        Prebid.shared.customStatusEndpoint = prebidStatusUrl
        Targeting.shared.omidPartnerName = "Google"
        let v = MobileAds.shared.versionNumber
        Targeting.shared.omidPartnerVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        applyGamAppVolume(appVolume)
    }

    private func applyGamAppVolume(_ volume: Float) {
        let clamped = min(max(volume, 0), 1)
        MobileAds.shared.applicationVolume = clamped
        MobileAds.shared.isApplicationMuted = (clamped == 0)
        AULogEvent.logDebug("GMA app volume set to \(clamped), muted=\(clamped == 0)")
    }

    private func handleInitializationResultStatus(
        status: PrebidInitializationStatus
    ) {
        switch status {
        case .succeeded:
            AULogEvent.logDebug("Audienzz SDK initialized")
        case .failed:
            AULogEvent.logDebug("Audienzz SDK initialization failed")
        case .serverStatusWarning:
            AULogEvent.logDebug("Audienzz SDK server status warning")
        default:
            AULogEvent.logDebug("Audienzz SDK encountered unexpected error")
        }
    }
}
