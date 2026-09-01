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

/// Screen-aware smart refresh (v2). Matches banner ads to the screen (`UIViewController`) they live
/// on and, on every `onScreenResumed` transition, pauses the previous screen's banners and force-
/// reloads the incoming screen's banners. Wired only under the smart-refresh-v2 feature flag —
/// `Audienzz.onScreenResumed` gates the call — so the legacy model is untouched. Main-thread affine.
internal final class AUScreenAdCoordinator {
    static let shared = AUScreenAdCoordinator()
    private init() {}

    /// Live smart-refresh banners. Weak so views deallocate freely and entries auto-prune.
    private let ads = NSHashTable<AUBannerView>.weakObjects()

    /// The most recent `onScreenResumed` screen. A `UIViewController` host is held weakly (so it
    /// deallocates freely); a value token (e.g. a route-key `String`) is held strongly, since the
    /// caller may not otherwise retain it. Exactly one is non-nil at a time.
    private weak var activeScreenVC: UIViewController?
    private var activeScreenToken: AnyObject?

    /// The current active screen (token preferred), or nil before the first resume.
    private var activeScreen: AnyObject? { activeScreenToken ?? activeScreenVC }

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
        assertMain()
        ads.add(ad)
    }

    func deregister(_ ad: AUBannerView) {
        assertMain()
        ads.remove(ad)
    }

    /// True when `ad` lives on the active screen, or when no screen has resumed yet (so a freshly-
    /// created banner starts active rather than paused). Used to initialize a banner's `screenActive`.
    func isActiveScreen(for ad: AUBannerView) -> Bool {
        guard let activeScreen else { return true }
        return ad.isHostedBy(activeScreen)
    }

    /// Hard screen transition. The screen is any token — a host `UIViewController` (matched by object
    /// identity) or a route key (matched by value against a banner's `setScreen`). So two screens of
    /// the same class, and the same screen re-resuming (app foreground), both behave as distinct
    /// transitions — releasing the previous screen's banners and reloading the incoming screen's
    /// already-loaded banners (a never-loaded banner is left for its normal lazy load).
    func onScreenResumed(_ screen: AnyObject) {
        assertMain()
        setActiveScreen(screen)
        let live = ads.allObjects
        AULogEvent.logDebug(
            "[AUScreenCoordinator] onScreenResumed screen=\(type(of: screen)) — \(live.count) banner(s) registered")
        for ad in live {
            guard ad.smartRefresh else { continue }
            let active = ad.isHostedBy(screen)
            ad.screenActive = active
            let hostName = ad.resolveHostViewController().map { String(describing: type(of: $0)) }
                ?? (ad.hostScreenOverride.map { "\($0)" } ?? "none")
            if active {
                AULogEvent.logDebug("[AUScreenCoordinator]   \(ad.configId) host=\(hostName) — ACTIVE, reloading")
                ad.forceScreenReload()
            } else {
                AULogEvent.logDebug("[AUScreenCoordinator]   \(ad.configId) host=\(hostName) — INACTIVE, pausing")
                ad.pauseSmartRefresh()
            }
        }
    }

    private func assertMain() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }
}
