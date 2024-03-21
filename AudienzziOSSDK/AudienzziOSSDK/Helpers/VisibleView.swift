/*   Copyright 2018-2024 Audienzz.org, Inc.
 
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

open class VisibleView: UIView {
    
    open override class func awakeFromNib() {
        super.awakeFromNib()
    }
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window != nil {
            observeSuperviewsOnOffsetChange()
        } else {
            removeAsSuperviewObserver()
        }
    }
    
    open func detectVisible() {
    }
    
    private func observeSuperviewsOnOffsetChange() {
        guard let superviews = self.getAllSuperviews() else { return }
        for superview in superviews {
            if superview.responds(to: #selector(getter: UIScrollView.contentOffset)) {
                superview.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
            }
        }
    }
    
    private func removeAsSuperviewObserver() {
        guard let superviews = self.getAllSuperviews() else { return }
        for superview in superviews {
            superview.removeObserver(self, forKeyPath: "contentOffset")
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            checkIfFrameIsVisible()
        }
    }
    
    private func checkIfFrameIsVisible() {
        guard let myWindow = self.window else { return }
        let myFrameToWindow = myWindow.convert(self.frame, from: self)
        let myPointToWindow = myWindow.convert(self.frame.origin, from: self.superview)
        
        if myFrameToWindow.size.width == 0 && myFrameToWindow.size.height == 0 {
            return
        }
    
        if CGRectContainsPoint(myWindow.frame, myPointToWindow) {
            detectVisible()
        }
    }
}
