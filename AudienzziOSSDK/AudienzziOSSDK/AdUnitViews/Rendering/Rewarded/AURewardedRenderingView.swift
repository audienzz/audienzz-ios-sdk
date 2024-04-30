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
import PrebidMobileGAMEventHandlers

@objcMembers
public class AUGAMRewardedAdEventHandler: NSObject {
    
    let adUnitID: String
    
    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }
}

@objcMembers
public class AURewardedRenderingView: AUAdView {
    private var rewardedAdUnit: RewardedAdUnit!
    public weak var delegate: AURewardedAdUnitDelegate?
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        rewardedAdUnit.loadAd()
        isLazyLoaded = true
        #if DEBUG
        print("AURewardedRenderingView --- I'm visible")
        #endif
    }
    
    public func createAd(with eventHandler: AUGAMRewardedAdEventHandler) {
        let rewardedEventHandler = GAMRewardedAdEventHandler(adUnitID: eventHandler.adUnitID)
        rewardedAdUnit = RewardedAdUnit(configID: configId, eventHandler: rewardedEventHandler)
        rewardedAdUnit.delegate = self
        
        if !isLazyLoad {
            rewardedAdUnit.loadAd()
        }
    }
}

extension AURewardedRenderingView: RewardedAdUnitDelegate {
    public func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        delegate?.rewardedAdDidReceiveAd?(rewardedAd)
    }
    
    public func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        delegate?.rewardedAd?(rewardedAd, didFailToReceiveAdWithError: error)
    }
    
    public func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        delegate?.rewardedAdWillPresentAd?(rewardedAd)
    }

    /// Called when the interstial is dismissed by the user
    public func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        delegate?.rewardedAdDidDismissAd?(rewardedAd)
    }

    /// Called when an ad causes the sdk to leave the app
    public func rewardedAdWillLeaveApplication(_ rewardedAd: RewardedAdUnit) {
        delegate?.rewardedAdWillLeaveApplication?(rewardedAd)
    }

    /// Called when user clicked the ad
    public func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        delegate?.rewardedAdDidClickAd?(rewardedAd)
    }
}

