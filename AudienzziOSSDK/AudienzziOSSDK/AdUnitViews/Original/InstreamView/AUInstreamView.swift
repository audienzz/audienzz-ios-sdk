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

public typealias Keywords = [String: String]

/**
 * AUInstreamView.
 * Ad view for demand instream ad type.
 * Lazy load is true by default.
*/
@objcMembers
public class AUInstreamView: AUAdView {
    internal var adUnit: InstreamVideoAdUnit!
    internal var customKeywords: Keywords?
    
    public var parameters: AUVideoParameters?
    public var onLoadInstreamRequest: (([String: String]?) -> Void)?
    
    /**
     Initialize instream view.
     Lazy load is true by default.
     */
    public override init(configId: String, adSize: CGSize) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: true)
        adUnit = InstreamVideoAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    /**
     Initialize instream view.
     Lazy load is true by default.
     */
    public override init(configId: String, adSize: CGSize, isLazyLoad: Bool) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: isLazyLoad)
        adUnit = InstreamVideoAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(size: CGSize) {
        let parameters = parameters?.unwrap() ?? defaultVideoParameters()
        adUnit.videoParameters = parameters
        
        if !self.isLazyLoad {
            fetchRequest()
        }
    }
}
