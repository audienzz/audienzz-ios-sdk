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

import AudienzziOSSDK
import GoogleMobileAds
import UIKit

// MARK: - Rewarded
private let storedImpVideoRewarded =
    "prebid-demo-video-rewarded-320-480-original-api"
private let gamAdUnitVideoRewardedOriginal =
    "ca-app-pub-3940256099942544/1712485313"

extension ExamplesViewController {
    func createRewardedView() {
        let gamRequest = AdManagerRequest()

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [
            AUVideoPlaybackMethod(type: .AutoPlaySoundOff)
        ]

        rewardedView = AURewardedView(configId: storedImpVideoRewarded)
        rewardedView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: CGSize(width: view.frame.size.width, height: 300)
        )
        rewardedView.backgroundColor = .magenta
        rewardedView.parameters = videoParameters

        lazyAdContainerView.addSubview(rewardedView)
        rewardedView.createAd(
            with: gamRequest,
            adUnitID: gamAdUnitVideoRewardedOriginal
        )
        rewardedView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? AdManagerRequest else {
                print("Faild request unwrap")
                return
            }
            self?.stopScroll()
            RewardedAd.load(
                with: gamAdUnitVideoRewardedOriginal,
                request: request
            ) { [weak self] ad, error in
                guard let self = self else { return }
                if let error = error {
                    print(
                        "Failed to load rewarded ad with error: \(error.localizedDescription)"
                    )
                } else if let ad = ad {
                    // 5. Present the interstitial ad
                    ad.fullScreenContentDelegate = self
                    self.rewardedView.connectHandler(
                        AURewardedEventHandler(adUnit: ad)
                    )
                    ad.present(
                        from: self,
                        userDidEarnRewardHandler: {
                            _ = ad.adReward
                        }
                    )
                }
            }
        }
    }
}
