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
        } else {
            if isCurrentlyVisible {
                isCurrentlyVisible = false
                onBecameHidden()
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

    public override func removeFromSuperview() {
        if isCurrentlyVisible {
            isCurrentlyVisible = false
            onBecameHidden()
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
        // We consider the ad "visible" only when its top edge is within the viewport.
        // This prevents triggering a refresh when just a pixel-sliver at the bottom of
        // the screen is in view (ad entering from below) or the ad has nearly fully
        // scrolled off the top.
        let visible = frameInWindow.minY >= window.bounds.minY && frameInWindow.minY < window.bounds.maxY

        if visible && !isCurrentlyVisible {
            isCurrentlyVisible = true
            onBecameVisible()
        } else if !visible && isCurrentlyVisible {
            isCurrentlyVisible = false
            onBecameHidden()
        }
    }
}
