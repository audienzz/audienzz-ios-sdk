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

internal class AURewardedRenderingDelegateType: NSObject, RewardedAdUnitDelegate {
    private weak var parent: AURewardedRenderingView?
    
    init(parent: AURewardedRenderingView) {
        super.init()
        self.parent = parent
    }
    
    public func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        parent?.delegate?.rewardedAdDidReceiveAd?()
    }
    
    public func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        guard let parent = parent else { return }
        makeErrorEvent(parent: parent, error)
        parent.delegate?.rewardedAdDidFailToReceiveAdWithError?(error)
    }
    
    public func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        parent?.delegate?.rewardedAdWillPresentAd?()
    }

    /// Called when the interstial is dismissed by the user
    public func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        guard let parent = parent else { return }
        makeCloseEvent(parent)
        parent.delegate?.rewardedAdDidDismissAd?()
    }

    /// Called when an ad causes the sdk to leave the app
    public func rewardedAdWillLeaveApplication(_ rewardedAd: RewardedAdUnit) {
        parent?.delegate?.rewardedAdWillLeaveApplication?()
    }

    /// Called when user clicked the ad
    public func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        guard let parent = parent else { return }
        makeClickEvent(parent)
        parent.delegate?.rewardedAdDidClickAd?()
    }
    
    /// Called when user is able to receive a reward from the app
    public func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit) {
        parent?.delegate?.rewardedAdUserDidEarnReward?(rewardedAd.reward)
    }
    
    private func makeCloseEvent(_ parent: AURewardedRenderingView) {
        let event = AUCloseAdEvent(adViewId: parent.configId, adUnitID: parent.eventHandler?.adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeClickEvent(_ parent: AURewardedRenderingView) {
        let event = AUAdClickEvent(adViewId: parent.configId, adUnitID: parent.eventHandler?.adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeErrorEvent(parent: AURewardedRenderingView, _ error: Error?) {
        guard let error = error else { return }
        let event = AUFailedLoadEvent(adViewId: parent.configId,
                                      adUnitID: parent.eventHandler?.adUnitID ?? "",
                                      errorMessage: error.localizedDescription,
                                      errorCode: error.errorCode ?? -1)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}

