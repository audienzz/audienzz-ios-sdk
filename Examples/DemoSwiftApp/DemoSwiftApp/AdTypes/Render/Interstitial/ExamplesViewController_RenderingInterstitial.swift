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

private var interstitialRenderingBannerView: AUInterstitialRenderingView!
private var interstitialRenderingVideoView: AUInterstitialRenderingView!

extension ExamplesViewController {
    func createRenderingIntertitiaBannerView() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "47") else {
            print("Warning: Remote config '47' not available for createRenderingIntertitiaBannerView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let eventHandler = AUGAMInterstitialEventHandler(
            adUnitID: gamAdUnitPath
        )

        interstitialRenderingBannerView = AUInterstitialRenderingView(
            configId: placementId,
            isLazyLoad: true,
            adFormat: .banner,
            minSizePercentage: nil,
            eventHandler: eventHandler
        )
        interstitialRenderingBannerView.delegate = self
        interstitialRenderingBannerView.frame = CGRect(
            x: 0,
            y: getPositionY(lazyAdContainerView),
            width: 320,
            height: 250
        )
        interstitialRenderingBannerView.backgroundColor = .blue

        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: interstitialRenderingBannerView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = "AUInterstitialRenderingView"
            interstitialRenderingBannerView.addSubview(nameLabel)
        #endif

        interstitialRenderingBannerView.createAd()

        lazyAdContainerView.addSubview(interstitialRenderingBannerView)

    }

    func createRenderingIntertitiaVideoView() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "47") else {
            print("Warning: Remote config '47' not available for createRenderingIntertitiaVideoView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let eventHandler = AUGAMInterstitialEventHandler(
            adUnitID: gamAdUnitPath
        )

        interstitialRenderingVideoView = AUInterstitialRenderingView(
            configId: placementId,
            isLazyLoad: true,
            adFormat: .video,
            minSizePercentage: nil,
            eventHandler: eventHandler
        )
        interstitialRenderingVideoView.delegate = self
        interstitialRenderingVideoView.frame = CGRect(
            x: 0,
            y: getPositionY(lazyAdContainerView),
            width: 320,
            height: 250
        )
        interstitialRenderingVideoView.backgroundColor = .darkGray

        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: interstitialRenderingVideoView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = "AUInterstitialRenderingViewVideo"
            interstitialRenderingVideoView.addSubview(nameLabel)
        #endif

        interstitialRenderingVideoView.createAd()

        lazyAdContainerView.addSubview(interstitialRenderingVideoView)

    }
}

extension ExamplesViewController: AUInterstitialenderingAdDelegate {
    @MainActor
    func interstitialAdDidDisplayOnScreen() {
        stopScroll()
        print("interstitialAdDidDisplayOnScreen")
    }

    func interstitialDidReceiveAd(with configId: String) {
        let interstitialPlacementId = AudienzzRemoteConfig.shared.remoteConfig(for: "47")?.prebidConfig.placementId
        if interstitialPlacementId == configId {
            if interstitialRenderingBannerView != nil {
                interstitialRenderingBannerView.showAd(self)
            } else if interstitialRenderingVideoView != nil {
                interstitialRenderingVideoView.showAd(self)
            }
        }
    }

    func interstitialDidFailToReceiveAdWithError(error: Error?) {
        guard let error = error else { return }
        print("Banner view did fail to receive ad with error: \(error)")
    }
}
