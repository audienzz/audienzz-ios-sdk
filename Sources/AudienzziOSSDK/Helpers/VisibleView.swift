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
}

@objcMembers
public class VisibleView: UIView {

    private var contentOffsetObservations = [NSKeyValueObservation]()
    private var isCurrentlyVisible: Bool = false

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window != nil {
            observeSuperviewsOnOffsetChange()
        } else {
            if isCurrentlyVisible {
                isCurrentlyVisible = false
                onBecameHidden()
            }
            removeAsSuperviewObserver()
        }
    }

    internal dynamic func detectVisible() {
        // Implement your visibility detection logic here
    }

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

    private func observeSuperviewsOnOffsetChange() {
        guard let superviews = self.getAllSuperviews() else { return }

        // Observe contentOffset of UIScrollView superviews
        for superview in superviews {
            if let scrollView = superview as? UIScrollView {
                let observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                    self?.checkIfFrameIsVisible()
                }
                contentOffsetObservations.append(observation)
            }
        }
    }

    private func removeAsSuperviewObserver() {
        // Invalidate all observations
        contentOffsetObservations.forEach { $0.invalidate() }
        contentOffsetObservations.removeAll()
    }

    private func checkIfFrameIsVisible() {
        guard let window = self.window else { return }

        let frameInWindow = window.convert(self.frame, from: self.superview)

        if frameInWindow.size.width == 0 && frameInWindow.size.height == 0 {
            return
        }

        let visible = frameInWindow.intersects(window.bounds)

        if visible && !isCurrentlyVisible {
            isCurrentlyVisible = true
            onBecameVisible()
        } else if !visible && isCurrentlyVisible {
            isCurrentlyVisible = false
            onBecameHidden()
        }
    }
}
