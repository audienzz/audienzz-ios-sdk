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

/// Automatic screen tracking (iOS). Swizzles `UIViewController.viewDidAppear(_:)` once so every
/// content screen fires a page impression and drives screen-aware smart refresh with no per-screen
/// code. Container controllers (navigation / tab / split / page) and alerts are filtered out, and
/// the callbacks that fire together in one run-loop turn are coalesced to the deepest content
/// controller. Everything is gated on `Audienzz.shared.autoScreenTracking`, so opting out (before
/// init) means the swizzle is never installed.
final class AUScreenTracker {
    static let shared = AUScreenTracker()
    private init() {}

    private static var installed = false
    private var pendingVC: UIViewController?
    private var scheduled = false

    /// One-shot: the next `viewDidAppear` for this controller is ignored. Set when a banner has
    /// already resumed its host screen proactively (its prefetch fires during layout, before
    /// `viewDidAppear`), so the swizzle's later callback for the same appearance doesn't fire a
    /// duplicate page impression / coordinator transition. Weak so a controller that never re-appears
    /// can't be leaked or wrongly matched after it deallocates.
    private weak var suppressNextVC: UIViewController?

    /// Installs the `viewDidAppear` swizzle once. Safe to call from every init entry point.
    static func installIfNeeded() {
        guard !installed else { return }
        installed = true
        UIViewController.au_installScreenTrackingSwizzle()
    }

    /// Skip the next automatic `viewDidAppear` for `viewController` (one-shot). Called right before a
    /// banner proactively resumes its host screen so the appearance isn't counted twice.
    func suppressNextAppearance(for viewController: UIViewController) {
        suppressNextVC = viewController
    }

    /// Called from the swizzled `viewDidAppear`. Filters, then coalesces to the deepest content
    /// controller appearing in this run-loop turn (child `viewDidAppear` fires after its parent).
    func viewControllerDidAppear(_ viewController: UIViewController) {
        guard Audienzz.shared.autoScreenTracking, Self.isTrackable(viewController) else { return }
        // A banner already resumed this screen ahead of its first fetch — swallow the one duplicate.
        if suppressNextVC === viewController {
            suppressNextVC = nil
            return
        }
        pendingVC = viewController
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            guard let vc = self.pendingVC else { return }
            self.pendingVC = nil
            Audienzz.shared.notifyScreenResumed(vc)
        }
    }

    /// Container controllers host the real screen (their child) — skip them. Alerts aren't screens.
    private static func isTrackable(_ viewController: UIViewController) -> Bool {
        if viewController is UINavigationController { return false }
        if viewController is UITabBarController { return false }
        if viewController is UISplitViewController { return false }
        if viewController is UIPageViewController { return false }
        if viewController is UIAlertController { return false }
        return true
    }
}

private extension UIViewController {
    static func au_installScreenTrackingSwizzle() {
        let original = #selector(viewDidAppear(_:))
        let swizzled = #selector(au_screenTracking_viewDidAppear(_:))
        guard
            let originalMethod = class_getInstanceMethod(UIViewController.self, original),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func au_screenTracking_viewDidAppear(_ animated: Bool) {
        // Implementations were exchanged, so this call runs the ORIGINAL viewDidAppear.
        au_screenTracking_viewDidAppear(animated)
        AUScreenTracker.shared.viewControllerDidAppear(self)
    }
}
