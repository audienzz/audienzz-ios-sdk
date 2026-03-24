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

// MARK: - Rewarded
extension ExamplesViewController {
    func createRewardedView() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "47") else {
            print("Warning: Remote config '47' not available for createRewardedView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamRequest = GAMRequest()

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod(type: .AutoPlaySoundOff)]

        rewardedView = AURewardedView(configId: placementId)
        rewardedView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                    size: CGSize(width: view.frame.size.width, height: 300))
        rewardedView.backgroundColor = .magenta
        rewardedView.parameters = videoParameters
        lazyAdContainerView.addSubview(rewardedView)
        
        rewardedView.createAd(with: gamRequest)
        rewardedView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            GADRewardedAd.load(withAdUnitID: gamAdUnitPath, request: request) { [weak self] ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    // 5. Present the interstitial ad
                    ad.fullScreenContentDelegate = self
                    self.rewardedView.connectHandler(AURewardedEventHandler(adUnit: ad))
                    ad.present(fromRootViewController: self, userDidEarnRewardHandler: {
                        _ = ad.adReward
                    })
                }
            }
        }
    }
}
