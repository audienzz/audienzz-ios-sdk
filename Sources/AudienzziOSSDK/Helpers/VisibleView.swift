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
import PrebidMobile

extension UIView {
    func getAllSuperviews() -> [UIView]? {
        var superviews: [UIView] = []

        guard let superView = self.superview else {
            return nil
        }

        superviews.append(superView)

        guard let subViews = superView.getAllSuperviews() else {
            return superviews
        }

        superviews.append(contentsOf: subViews)
        return superviews
    }

    /// Returns the nearest `UITableView` or `UICollectionView` ancestor, or `nil` if none.
    func findTableOrCollectionViewAncestor() -> UIScrollView? {
        var view: UIView? = superview
        while let current = view {
            if current is UITableView || current is UICollectionView {
                return current as? UIScrollView
            }
            view = current.superview
        }
        return nil
    }
}

@objcMembers
public class VisibleView: UIView {

    private var contentOffsetObservations = [NSKeyValueObservation]()
    private var isCurrentlyVisible: Bool = false
    private var isRefreshEligible: Bool = false

    /// Whether the view currently meets the visibility threshold (≥20% on screen).
    /// Exposed so subclasses can tell a prefetch-zone (not-yet-visible) load apart
    /// from a genuinely visible one. Drives the lazy-load / prefetch path only.
    internal var isViewCurrentlyVisible: Bool { isCurrentlyVisible }

    /// Whether the view currently qualifies for smart **refresh** (a stricter, directional
    /// rule than ``isViewCurrentlyVisible``): the ad's top edge must be fully on screen and no
    /// more than 50% of its height may be off the bottom of the viewport. See
    /// ``computeRefreshEligible(frameInWindow:viewport:)``. Used to gate refreshes only —
    /// the initial load still uses the prefetch / ≥20% path.
    internal var isViewRefreshEligible: Bool { isRefreshEligible }

    // MARK: - Prefetch margin

    /// Distance in points before the view enters the viewport that triggers
    /// ``onEnteredPrefetchZone()``, which starts the Prebid demand fetch early so the ad is
    /// ready the moment the view scrolls into view.
    ///
    /// Defaults to **200 pt**. Set to `0` to load only when the view is exactly on screen.
    ///
    /// - Note: Has no practical effect inside `UITableView` or `UICollectionView`. Those
    ///   containers dequeue cells just before they appear, so the view is already within the
    ///   margin by the time it is added to the hierarchy. For table/collection views, set
    ///   `isLazyLoad = false` and rely on the table/collection prefetch mechanism instead
    ///   (`UITableView.prefetchDataSource` / `UICollectionView.isPrefetchingEnabled`).
    public var prefetchMarginPoints: CGFloat = 200

    /// Tracks whether `onEnteredPrefetchZone()` has already fired. One-shot per view lifetime.
    private var hasFiredPrefetchZone: Bool = false

    // MARK: - Lifecycle

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window != nil {
            #if DEBUG
            if prefetchMarginPoints > 0, findTableOrCollectionViewAncestor() != nil {
                AULogEvent.logDebug(
                    "[VisibleView] ⚠️ prefetchMarginPoints=\(Int(prefetchMarginPoints)) has no effect " +
                    "inside a UITableView/UICollectionView. Cells are dequeued just before they appear, " +
                    "so the view is already within the margin when added to the hierarchy. " +
                    "Use isLazyLoad = false and rely on the table/collection prefetch APIs instead."
                )
            }
            #endif
            observeSuperviewsOnOffsetChange()
            // Perform an immediate visibility check on the next run loop tick so that ads
            // already in the viewport when the screen opens are detected without requiring
            // a scroll event to trigger the KVO-based contentOffset observation.
            DispatchQueue.main.async { [weak self] in
                self?.checkIfFrameIsVisible()
            }
        } else {
            if isCurrentlyVisible {
                isCurrentlyVisible = false
                onBecameHidden()
            }
            if isRefreshEligible {
                isRefreshEligible = false
                onRefreshBecameIneligible()
            }
            removeAsSuperviewObserver()
        }
    }

    // MARK: - Overridable hooks

    internal dynamic func detectVisible() {
        // Implement your visibility detection logic here
    }

    /// Called once when the view enters the prefetch zone — i.e. when it comes within
    /// `prefetchMarginPoints` pt of the visible viewport. Fires before `onBecameVisible()`.
    /// Override to start demand fetch early. One-shot per view lifetime.
    internal dynamic func onEnteredPrefetchZone() {}

    internal dynamic func onBecameVisible() {
        detectVisible()
    }

    internal dynamic func onBecameHidden() {}

    /// Called when the view crosses into the smart-refresh eligible zone (top edge fully on
    /// screen AND ≤50% of its height off the bottom). Override to resume auto-refresh.
    internal dynamic func onRefreshBecameEligible() {}

    /// Called when the view leaves the smart-refresh eligible zone (top edge clipped by ≥1pt,
    /// or >50% of its height off the bottom). Override to pause auto-refresh.
    internal dynamic func onRefreshBecameIneligible() {}

    public override func removeFromSuperview() {
        if isCurrentlyVisible {
            isCurrentlyVisible = false
            onBecameHidden()
        }
        if isRefreshEligible {
            isRefreshEligible = false
            onRefreshBecameIneligible()
        }
        removeAsSuperviewObserver()
        super.removeFromSuperview()
    }

    deinit {
        removeAsSuperviewObserver()
    }

    // MARK: - Scroll observation

    private func observeSuperviewsOnOffsetChange() {
        guard let superviews = self.getAllSuperviews() else { return }

        for superview in superviews {
            if let scrollView = superview as? UIScrollView {
                let observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                    self?.checkIfFrameIsVisible()
                }
                contentOffsetObservations.append(observation)
            }
        }
    }

    private func removeAsSuperviewObserver() {
        contentOffsetObservations.forEach { $0.invalidate() }
        contentOffsetObservations.removeAll()
    }

    // MARK: - Visibility check

    private func checkIfFrameIsVisible() {
        guard let window = self.window else { return }

        let frameInWindow = window.convert(self.frame, from: self.superview)

        if frameInWindow.size.width == 0 && frameInWindow.size.height == 0 {
            return
        }

        // Prefetch zone — fires once when the view is within prefetchMarginPoints of the viewport.
        if !hasFiredPrefetchZone {
            let expandedBounds = window.bounds.insetBy(
                dx: -prefetchMarginPoints,
                dy: -prefetchMarginPoints
            )
            let withinPrefetchZone = prefetchMarginPoints > 0
                ? frameInWindow.intersects(expandedBounds)
                : frameInWindow.intersects(window.bounds)
            if withinPrefetchZone {
                hasFiredPrefetchZone = true
                #if DEBUG
                AULogEvent.logDebug("[VisibleView] entered prefetch zone (margin=\(Int(prefetchMarginPoints))pt)")
                #endif
                onEnteredPrefetchZone()
            }
        }

        // Actual visibility — drives smart refresh and the legacy detectVisible() path.
        // We consider the ad "visible" only when at least 20% of its height intersects
        // the viewport, matching the Android implementation (visibleHeightFraction >= 0.2).
        let intersection = frameInWindow.intersection(window.bounds)
        let visibleFraction = frameInWindow.height > 0 ? intersection.height / frameInWindow.height : 0
        let visible = visibleFraction >= 0.2

        if visible && !isCurrentlyVisible {
            isCurrentlyVisible = true
            onBecameVisible()
        } else if !visible && isCurrentlyVisible {
            isCurrentlyVisible = false
            onBecameHidden()
        }

        // Smart-refresh eligibility — a stricter, directional rule than the ≥20% check above.
        // Drives pause/resume of the refresh cycle only; the initial load uses the paths above.
        let refreshEligible = computeRefreshEligible(frameInWindow: frameInWindow, viewport: window.bounds)
        if refreshEligible && !isRefreshEligible {
            isRefreshEligible = true
            onRefreshBecameEligible()
        } else if !refreshEligible && isRefreshEligible {
            isRefreshEligible = false
            onRefreshBecameIneligible()
        }
    }

    /// Smart-refresh eligibility rule (asymmetric, directional):
    /// - **Top edge** must be fully on screen — if ≥1pt of the top is clipped above the
    ///   viewport, the ad is ineligible (pause).
    /// - **Bottom edge** may be clipped by up to 50% of the ad's height — if more than 50%
    ///   is off the bottom of the viewport, the ad is ineligible (pause on start).
    ///
    /// A fully-visible ad, or one entering from the bottom with ≥50% on screen, is eligible.
    /// Kept separate from `currentVisibleHeightFraction()` so the viewability tracker's math
    /// is untouched. Geometry is in window coordinates.
    private func computeRefreshEligible(frameInWindow: CGRect, viewport: CGRect) -> Bool {
        guard frameInWindow.height > 0 else { return false }
        // >0 when the top edge is above the viewport top; >0 when the bottom edge is below it.
        let topOffscreen = viewport.minY - frameInWindow.minY
        let bottomOffscreen = frameInWindow.maxY - viewport.maxY
        let topFullyOnScreen = topOffscreen < 1.0
        let bottomWithinHalf = bottomOffscreen <= frameInWindow.height * 0.5
        return topFullyOnScreen && bottomWithinHalf
    }

    /// Fraction (0...1) of the view's height currently intersecting the window — used by the
    /// viewability tracker for the MRC-style ≥50% check. Returns 0 when off-screen / not in a window.
    internal func currentVisibleHeightFraction() -> CGFloat {
        guard let window = self.window else { return 0 }
        let frameInWindow = window.convert(self.frame, from: self.superview)
        guard frameInWindow.height > 0 else { return 0 }
        let intersection = frameInWindow.intersection(window.bounds)
        return max(0, intersection.height / frameInWindow.height)
    }
}
