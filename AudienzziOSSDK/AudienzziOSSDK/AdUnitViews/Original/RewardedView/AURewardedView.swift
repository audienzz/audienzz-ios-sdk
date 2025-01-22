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

/**
 * AURewardedView.
 * Ad view for demand  Rewarded ad type.
 * Lazy load is true by default.
*/
@objcMembers
public class AURewardedView: AUAdView {
    internal var adUnit: RewardedVideoAdUnit!
    internal var gamRequest: AnyObject?
    internal var eventHandler: AURewardedHandler?
    internal var gadUnitID: String?
    public var parameters: AUVideoParameters?
    
    /**
     Initialize rewarded view.
     Lazy load is true by default.
     */
    public init(configId: String) {
        super.init(configId: configId, isLazyLoad: true)
        adUnit = RewardedVideoAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    /**
     Initialize rewarded view.
     Lazy load is true by default.
     */
    public override init(configId: String, isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        adUnit = RewardedVideoAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func removeFromSuperview() {
        super.removeFromSuperview()
        adUnit?.stopAutoRefresh()
        adUnit = nil
        self.eventHandler = nil
    }
    
    deinit {
        self.eventHandler = nil
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AnyObject, adUnitID: String) {
        AUEventsManager.shared.checkImpression(self, adUnitID: adUnitID)
        self.gadUnitID = adUnitID
        let parameters = parameters?.unwrap() ?? defaultVideoParameters()
        adUnit.videoParameters = parameters
        self.gamRequest = gamRequest
        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
    
    public func connectHandler(_ eventHandler: AURewardedEventHandler) {
        self.eventHandler = AURewardedHandler(handler: eventHandler, adView: self)
        makeCreationEvent()
    }
}
