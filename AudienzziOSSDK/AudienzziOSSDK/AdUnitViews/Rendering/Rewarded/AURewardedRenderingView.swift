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

/**
 * AUInstreamView.
 * Ad view for demand instream ad type.
 * Lazy load is true by default.
*/
@objcMembers
public class AURewardedRenderingView: AUAdView {
    private var rewardedAdUnit: RewardedAdUnit!
    public weak var delegate: AURewardedAdUnitDelegate?
    
    /**
     Initialize rewarded view.
     Lazy load is true by default.
     */
    public override init(configId: String, isLazyLoad: Bool = true) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with eventHandler: AUGAMRewardedAdEventHandler, minSizePerc: NSValue? = nil) {
        let rewardedEventHandler = GAMRewardedAdEventHandler(adUnitID: eventHandler.adUnitID)
        rewardedAdUnit = RewardedAdUnit(configID: configId, eventHandler: rewardedEventHandler)
        rewardedAdUnit.delegate = self
        
        if !isLazyLoad {
            self.delegate?.rewardedAdDidDisplayOnScreen?()
            rewardedAdUnit.loadAd()
        }
    }
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        self.delegate?.rewardedAdDidDisplayOnScreen?()
        rewardedAdUnit.loadAd()
        isLazyLoaded = true
        #if DEBUG
        print("AURewardedRenderingView --- I'm visible")
        #endif
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

