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
import Foundation
import PrebidMobile

@objc public protocol AURewardedAdUnitDelegate: NSObjectProtocol {
    ///Called when ad is shoed on display and before load (used for lazy load)
    @objc optional func rewardedAdDidDisplayOnScreen()

    /// Called when an ad is loaded and ready for display
    @objc optional func rewardedAdDidReceiveAd()

    /// Called when user is able to receive a reward from the app
    @objc optional func rewardedAdUserDidEarnReward(_ reward: NSObject?)
    
    /// Called when the load process fails to produce a viable ad
    @objc optional func rewardedAdDidFailToReceiveAdWithError(_ error: Error?)

    /// Called when the interstitial view will be launched,  as a result of show() method.
    @objc optional func rewardedAdWillPresentAd()

    /// Called when the interstial is dismissed by the user
    @objc optional func rewardedAdDidDismissAd()

    /// Called when an ad causes the sdk to leave the app
    @objc optional func rewardedAdWillLeaveApplication()

    /// Called when user clicked the ad
    @objc optional func rewardedAdDidClickAd()
}
