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

    /// Host `UIViewController` of the most recent `onScreenResumed` — the currently-active screen.
    private weak var activeScreen: UIViewController?

    func register(_ ad: AUBannerView) {
        assertMain()
        ads.add(ad)
    }

    func deregister(_ ad: AUBannerView) {
        assertMain()
        ads.remove(ad)
    }

    /// True when `vc` is the active screen, or when no screen has resumed yet (so a freshly-created
    /// banner starts active rather than paused). Used to initialize a banner's `screenActive`.
    func isActiveScreen(_ vc: UIViewController?) -> Bool {
        guard let activeScreen else { return true }
        return vc != nil && vc === activeScreen
    }

    /// Hard screen transition. Matching is by host-VC object identity (not class name), so two
    /// screens of the same class, and the same screen re-resuming (app foreground), both behave as
    /// distinct transitions — releasing the previous screen's banners and reloading the incoming
    /// screen's already-loaded banners (a never-loaded banner is left for its normal lazy load).
    func onScreenResumed(_ viewController: UIViewController) {
        assertMain()
        activeScreen = viewController
        for ad in ads.allObjects {
            guard ad.smartRefresh else { continue }
            let host = ad.resolveHostViewController()
            let active = (host != nil && host === viewController)
            ad.screenActive = active
            if active {
                ad.forceScreenReload()
            } else {
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
