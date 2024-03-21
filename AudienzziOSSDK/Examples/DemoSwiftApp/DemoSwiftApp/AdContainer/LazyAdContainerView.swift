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
import AudienzziOSSDK

// just test if view will display in view port
class LazyAdContainerView: VisibleView {
    private var isLazyLoadApear: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func detectVisible() {
        guard !isLazyLoadApear else { return }
        print("I AM VISIBLE: \(isVisible(view: self))")
        isLazyLoadApear = true
    }
    
}

private extension LazyAdContainerView {
    func isVisible(view: UIView) -> Bool {
        func isVisible(view: UIView, inView: UIView?) -> Bool {
            guard let inView = inView else { return true }
            let viewFrame = inView.convert(view.bounds, from: view)
            if viewFrame.intersects(inView.bounds) {
                return isVisible(view: view, inView: inView.superview)
            }
            return false
        }
        return isVisible(view: view, inView: view.superview)
    }
}
