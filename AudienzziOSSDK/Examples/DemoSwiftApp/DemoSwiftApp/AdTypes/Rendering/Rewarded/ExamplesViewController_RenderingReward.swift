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
import GoogleMobileAds

fileprivate let storedImpVideoRewarded = "prebid-demo-video-rewarded-320-480"
fileprivate let gamAdUnitVideoRewardedRendering = "/21808260008/prebid_oxb_rewarded_video_test"

fileprivate var rewardedRenderingView: AURewardedRenderingView!
fileprivate var rewardedRenderingLazyView: AURewardedRenderingView!

extension ExamplesViewController {
    
    func createRenderingRewardLazyView() {
        let eventHandler = AUGAMRewardedAdEventHandler(adUnitID: gamAdUnitVideoRewardedRendering)
        rewardedRenderingLazyView = AURewardedRenderingView(configId: storedImpVideoRewarded, minSizePerc: nil, eventHandler: eventHandler)
        rewardedRenderingLazyView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)), size: CGSize(width: 320, height: 50))
        rewardedRenderingLazyView.delegate = self
        rewardedRenderingLazyView.createAd()
        lazyAdContainerView.addSubview(rewardedRenderingLazyView)
    }
}

extension ExamplesViewController: AURewardedAdUnitDelegate {
    func rewardedAdDidReceiveAd() {
        rewardedRenderingLazyView.showAd(self)
    }
    
    func rewardedAdDidFailToReceiveAdWithError(_ error: Error?) {
        print("Rewarded ad unit failed to receive ad with error: \(error?.localizedDescription ?? "")")
    }
    
    func rewardedAdUserDidEarnReward(_ reward: NSObject?) {
        guard let reward = reward else { return }
        print("rewardedAdUserDidEarnReward \(reward)")
    }
}
