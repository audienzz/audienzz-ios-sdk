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

public class AUAdView: VisibleView {
    var isLazyLoaded: Bool = false
    private(set) var isLazyLoad: Bool
    private(set) var configId: String
    private(set) var adSize: CGSize
    
    public var onLoadRequest: ((AnyObject) -> Void)?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public init(configId: String, adSize: CGSize, isLazyLoad: Bool) {
        self.configId = configId
        self.adSize = adSize
        self.isLazyLoad = isLazyLoad
        super.init(frame: .zero)
    }
    
    public init(configId: String, adSize: CGSize) {
        self.configId = configId
        self.adSize = adSize
        self.isLazyLoad = false
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
