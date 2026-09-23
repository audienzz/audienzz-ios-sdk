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

import UIKit

/// Page-scoped ad ownership. Matches banner ads to the screen (`UIViewController` or route key)
/// they live on and, on every `pageImpression`, **releases** the previous page's banners — stopping
/// their auction and refresh entirely — and **recreates** the incoming page's, so returning to a
/// screen shows a fresh creative.
///
/// This runs for every banner on every page impression; it is not gated on the smart-refresh-v2
/// flag, which now only selects the viewport gate used for scroll pause/resume. Main-thread affine.
///
/// **Ordering contract:** call `pageImpression` *before* creating the screen's ads. A banner
/// registered under an older page epoch is released and logged as an integration error; on iOS it
/// self-adopts if it later moves into a window under the active screen (see `AUBannerView`).
internal final class AUScreenAdCoordinator {
    static let shared = AUScreenAdCoordinator()
    internal init() {}

    /// Live banners. Weak so views deallocate freely and entries auto-prune.
    private let ads = NSHashTable<AUBannerView>.weakObjects()
    private let configuredAds = NSHashTable<AUConfiguredDemandRefresh>.weakObjects()
    func registerConfigured(_ ad: AUConfiguredDemandRefresh) { configuredAds.add(ad) }
    func deregisterConfigured(_ ad: AUConfiguredDemandRefresh) { configuredAds.remove(ad) }

    /// The most recent `pageImpression` screen. A `UIViewController` host is held weakly (so it
    /// deallocates freely); a value token (e.g. a route-key `String`) is held strongly, since the
    /// caller may not otherwise retain it. Exactly one is non-nil at a time.
    private weak var activeScreenVC: UIViewController?
    private var activeScreenToken: AnyObject?
    private var activeScreenName: String?

    /// The current active screen (token preferred), or nil before the first page impression.
    private var activeScreen: AnyObject? { activeScreenToken ?? activeScreenVC }

    /// The active screen plus its reported name, for the foreground re-impression.
    var activeScreenAndName: (AnyObject, String)? {
        guard let activeScreen, let activeScreenName else { return nil }
        return (activeScreen, activeScreenName)
    }

    /// Monotonic page counter. A banner stamps it at `createAd`; a banner whose stamp is older than
    /// the current epoch belongs to a page the user has left.
    private(set) var epoch: Int = 0
    let requestLedger = AUAdRequestLedger()

    private func setActiveScreen(_ screen: AnyObject) {
        if let vc = screen as? UIViewController {
            activeScreenVC = vc
            activeScreenToken = nil
        } else {
            activeScreenToken = screen
            activeScreenVC = nil
        }
    }

    func register(_ ad: AUBannerView) {
        // The ownership question, answered at birth: which page was current when this slot was
        // created. A slot whose page is not the active one — reported here as owner=… active=… —
        // is the shape of every "my banner never loads" report.
        AUDiagnostics.log("slot", "create", [
            ("config", ad.configId),
            ("owner", ad.hostScreenOverride.map { "\($0)" } ?? "hostViewController"),
            ("activePage", activeScreenName ?? "none"),
            ("epoch", epoch),
        ])
        assertMain()
        ads.add(ad)
        if isActiveScreen(for: ad) { ad.requestContext.register() }
    }

    func deregister(_ ad: AUBannerView) {
        assertMain()
        ads.remove(ad)
    }

    /// Prebid is configured — let every live banner take the first load it deferred.
    ///
    /// Driven from the registry rather than per-banner closures, so a banner deallocated while
    /// waiting is simply no longer here.
    func resumeAllAfterPrebidConfigured() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.resumeAllAfterPrebidConfigured() }
            return
        }
        ads.allObjects.forEach { $0.resumeEligibleWork() }
    }

    /// True when `ad` lives on the active screen, or when no screen has resumed yet (so a freshly-
    /// created banner starts active rather than paused). Used to initialize a banner's `screenActive`.
    func isActiveScreen(for ad: AUBannerView) -> Bool {
        guard let activeScreen else { return true }
        return ad.isHostedBy(activeScreen)
    }

    /// Hard page transition. The screen is any token — a host `UIViewController` (matched by object
    /// identity) or a route key (matched by value against a banner's `setScreen`). Two screens of the
    /// same class, and the same screen resuming again (app foreground, back navigation), all count as
    /// distinct transitions.
    ///
    /// Every registered banner is swept: the incoming page's banners are recreated (fresh auction),
    /// everything else is released (auction and refresh stopped, slot left dormant until its page
    /// comes back). A banner created *before* this page impression carries a stale epoch and is
    /// reported as an integration error rather than silently kept alive.
    /// How a screen token is named in an `AUDZ` line.
    ///
    /// A route key is its own string; a view controller has none, so its object identity stands in.
    /// The point is only that two visits to the same screen, and two screens of the same class,
    /// are distinguishable when reading a captured log back.
    static func diagnosticToken(for screen: AnyObject) -> String {
        if let key = screen as? NSString { return key as String }
        return "\(type(of: screen))#\(UInt(bitPattern: ObjectIdentifier(screen).hashValue) % 100000)"
    }

    func onScreenResumed(_ screen: AnyObject, name: String) {
        assertMain()
        epoch += 1
        setActiveScreen(screen)
        activeScreenName = name
        let live = ads.allObjects
        requestLedger.beginPage(epoch, retained: live.filter { $0.isHostedBy(screen) }.map { $0.requestContext })
        for ad in configuredAds.allObjects { ad.pageChanged(screen) }
        AULogEvent.logDebug(
            "[AUScreenCoordinator] pageImpression \"\(name)\" epoch=\(epoch) — \(live.count) banner(s) registered")
        AUDiagnostics.log("page", "transition", [
            ("id", Self.diagnosticToken(for: screen)),
            ("name", name),
            ("epoch", epoch),
            ("slots", live.count),
        ])
        for ad in live {
            let hostName = ad.resolveHostViewController().map { String(describing: type(of: $0)) }
                ?? (ad.hostScreenOverride.map { "\($0)" } ?? "none")
            if ad.isHostedBy(screen) {
                ad.screenActive = true
                ad.pageEpoch = epoch
                AULogEvent.logDebug("[AUScreenCoordinator]   \(ad.configId) host=\(hostName) — ACTIVE, recreating")
                AUDiagnostics.log("slot", "recreate", [
                    ("config", ad.configId), ("host", hostName), ("page", name), ("epoch", epoch),
                ])
                ad.recreateForPage()
            } else {
                ad.screenActive = false
                AULogEvent.logDebug("[AUScreenCoordinator]   \(ad.configId) host=\(hostName) — INACTIVE, releasing")
                AUDiagnostics.log("slot", "release", [
                    ("config", ad.configId), ("host", hostName),
                    ("reason", "otherPage"), ("page", name),
                ])
                ad.releaseForPage()
            }
        }
    }

    /// Restore refresh after the app returns to the foreground, for apps that never call
    /// `pageImpression`.
    ///
    /// A page-scoped app gets a foreground page impression instead, and that impression recreates
    /// every banner on the active page — doing both is how a single return used to produce two
    /// auctions for one banner. The caller decides which of the two owns the recovery.
    func resumeAfterForeground() {
        assertMain()
        for ad in configuredAds.allObjects { ad.foreground() }
        for ad in ads.allObjects {
            ad.resumeAfterForeground()
        }
    }

    /// Hold refresh for every banner while the app is backgrounded, and retire whatever auction was
    /// in flight: a response landing while backgrounded produces a creative nobody can see.
    func blockForBackground() {
        assertMain()
        for ad in configuredAds.allObjects { ad.background() }
        for ad in ads.allObjects {
            ad.blockForBackground()
        }
    }

    /// Repairs the one case the sweep genuinely gets wrong: a banner created *before* its screen's
    /// `pageImpression` that was not yet in a window when the sweep ran. Its responder chain could
    /// not resolve a host, so `isHostedBy` said no and it was released — a dead slot.
    ///
    /// Called from `AUBannerView.didMoveToWindow`, once the host *can* be resolved. If that host is
    /// the active screen the banner joins the current page and loads. Event-driven rather than a
    /// timing grace window, so it can never resurrect a previous page's ad.
    func adoptIfOnActiveScreen(_ ad: AUBannerView) {
        assertMain()
        guard let activeScreen, !ad.screenActive, ad.isHostedBy(activeScreen) else { return }
        AULogEvent.logWarn(
            """
            [AUScreenCoordinator] \(ad.configId) was created before pageImpression for \
            "\(activeScreenName ?? "?")" and wasn't on screen when the page swept — adopted on \
            attach. Call Audienzz.shared.pageImpression(_:) BEFORE creating this screen's ads.
            """)
        ad.screenActive = true
        ad.pageEpoch = epoch
        ad.recreateForPage()
    }

    #if DEBUG
    func resetForTesting() {
        assertMain()
        // Destroy before clearing registration: this also retires work retained by a scheduler.
        for ad in ads.allObjects { ad.destroy() }
        for ad in configuredAds.allObjects { ad.destroy() }
        ads.removeAllObjects()
        configuredAds.removeAllObjects()
        activeScreenVC = nil
        activeScreenToken = nil
        activeScreenName = nil
        epoch = 0
        requestLedger.beginPage(0, retained: [])
    }
    #endif

    private func assertMain() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }
}
