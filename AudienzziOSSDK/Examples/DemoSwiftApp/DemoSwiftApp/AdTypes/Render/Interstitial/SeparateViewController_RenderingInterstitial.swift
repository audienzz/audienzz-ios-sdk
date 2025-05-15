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

private let storedImpDisplayInterstitial =
    "prebid-demo-display-interstitial-320-480"
private let gamAdUnitDisplayInterstitialRendering =
    "/21808260008/prebid_oxb_html_interstitial"

private let storedImpVideoInterstitial =
    "prebid-demo-video-interstitial-320-480"
private let gamAdUnitVideoInterstitialRendering =
    "/21808260008/prebid_oxb_interstitial_video"

private var interstitialRenderingBannerView: AUInterstitialRenderingView!
private var interstitialRenderingVideoView: AUInterstitialRenderingView!

extension SeparateViewController {

    func createRenderingIntertitiaBannerView() {
        let eventHandler = AUGAMInterstitialEventHandler(
            adUnitID: gamAdUnitDisplayInterstitialRendering
        )

        interstitialRenderingBannerView = AUInterstitialRenderingView(
            configId: storedImpDisplayInterstitial,
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

        lazyAdContainerView.addSubview(interstitialRenderingBannerView)
        interstitialRenderingBannerView.createAd()
    }

    func createRenderingIntertitiaVideoView() {
        let eventHandler = AUGAMInterstitialEventHandler(
            adUnitID: gamAdUnitVideoInterstitialRendering
        )

        interstitialRenderingVideoView = AUInterstitialRenderingView(
            configId: storedImpVideoInterstitial,
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

        lazyAdContainerView.addSubview(interstitialRenderingVideoView)
        interstitialRenderingVideoView.createAd()
    }
}

extension SeparateViewController: AUInterstitialenderingAdDelegate {
    @MainActor
    func interstitialAdDidDisplayOnScreen() {
        stopScroll()
        print("interstitialAdDidDisplayOnScreen")
    }

    func interstitialDidReceiveAd(with configId: String) {
        if storedImpDisplayInterstitial == configId {
            interstitialRenderingBannerView.showAd(self)
        } else if configId == storedImpVideoInterstitial {
            interstitialRenderingVideoView.showAd(self)
        }
    }

    func interstitialDidFailToReceiveAdWithError(error: Error?) {
        guard let error = error else { return }
        print("Banner view did fail to receive ad with error: \(error)")
    }
}
