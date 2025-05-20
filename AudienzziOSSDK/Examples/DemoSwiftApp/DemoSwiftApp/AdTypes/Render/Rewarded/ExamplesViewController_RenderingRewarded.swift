/*   Copyright 2018-2025 Audienzz.org, Inc.
 
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

fileprivate var activityIndicator: UIActivityIndicatorView!

extension ExamplesViewController {
    
    func createRenderingRewardLazyView() {
        let eventHandler = AUGAMRewardedAdEventHandler(adUnitID: gamAdUnitVideoRewardedRendering)
        rewardedRenderingLazyView = AURewardedRenderingView(configId: storedImpVideoRewarded,
                                                            minSizePercentage: nil,
                                                            eventHandler: eventHandler)
        rewardedRenderingLazyView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                                 size: CGSize(width: 320, height: 150))
        rewardedRenderingLazyView.backgroundColor = .gray
        rewardedRenderingLazyView.delegate = self
        
        #if DEBUG
        let nameLabel = UILabel(frame: CGRect(x: 0,
                                              y: 0,
                                              width: rewardedRenderingLazyView.frame.size.width, height: 30))
        nameLabel.text = "AURewardedRenderingView"
        rewardedRenderingLazyView.addSubview(nameLabel)
        #endif
        
        rewardedRenderingLazyView.createAd()
        lazyAdContainerView.addSubview(rewardedRenderingLazyView)
    }
}

extension ExamplesViewController: AURewardedAdUnitDelegate {
    @MainActor
    func rewardedAdDidDisplayOnScreen() {
        print("rewardedAdDidDisplayOnScreen")
        stopScroll()
        
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.frame = CGRect(x: 150, y: 30, width: 50, height: 50)
        rewardedRenderingLazyView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func rewardedAdDidReceiveAd() {
        DispatchQueue.main.async {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            rewardedRenderingLazyView.showAd(self)
        }
    }
    
    func rewardedAdDidFailToReceiveAdWithError(_ error: Error?) {
        print("Rewarded ad unit failed to receive ad with error: \(error?.localizedDescription ?? "")")
    }
    
    func rewardedAdUserDidEarnReward(_ reward: NSObject?) {
        guard let object = reward else { return }
        print("rewardedAdUserDidEarnReward: \(object)")
    }
}
