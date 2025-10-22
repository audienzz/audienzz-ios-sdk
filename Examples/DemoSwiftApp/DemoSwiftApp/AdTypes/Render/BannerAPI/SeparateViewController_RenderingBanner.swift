import AudienzziOSSDK
import GoogleMobileAds
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

private var bannerRenderingView: AUBannerRenderingView!
private var bannerRenderingVideoView: AUBannerRenderingView!

private var bannerRenderingLazyView: AUBannerRenderingView!
private var bannerRenderingVideoLazyView: AUBannerRenderingView!

extension SeparateViewController {
    private enum Constants {
        static let storedImpDisplayBanner = "prebid-demo-banner-320-50"
        static let gamAdUnitDisplayBannerRendering = "/21808260008/prebid_oxb_320x50_banner"

        static let storedImpVideoBanner = "prebid-demo-video-outstream"
        static let gamAdUnitVideoBannerRendering = "/21808260008/prebid_oxb_300x250_banner"
    }

    func createRenderingBannerView() {
        let eventHandler = AUGAMBannerEventHandler(
            adUnitID: Constants.gamAdUnitDisplayBannerRendering,
            validGADAdSizes: [AdSizeBanner].map(nsValue)
        )
        bannerRenderingView = AUBannerRenderingView(
            configId: Constants.storedImpDisplayBanner,
            adSize: adSize,
            isLazyLoad: false,
            eventHandler: eventHandler
        )
        bannerRenderingView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: CGSize(width: 320, height: 50)
        )
        bannerRenderingView.delegate = self

        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: bannerRenderingView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = "AUBannerRenderingView"
            bannerRenderingView.addSubview(nameLabel)
        #endif
        adContainerView.addSubview(bannerRenderingView)
        bannerRenderingView.createAd()
    }

    func createRenderingBannerVideoView() {
        let eventHandler = AUGAMBannerEventHandler(
            adUnitID: Constants.gamAdUnitVideoBannerRendering,
            validGADAdSizes: [AdSizeMediumRectangle].map(nsValue)
        )
        bannerRenderingVideoView = AUBannerRenderingView(
            configId: Constants.storedImpVideoBanner,
            adSize: CGSize(width: 300, height: 250),
            format: .video,
            isLazyLoad: false,
            eventHandler: eventHandler
        )
        bannerRenderingVideoView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: CGSize(width: 300, height: 250)
        )
        bannerRenderingVideoView.delegate = self

        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 0,
                    y: 50,
                    width: bannerRenderingVideoView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = "AUBannerRenderingViewVideo"
            bannerRenderingVideoView.addSubview(nameLabel)
        #endif

        let videoParams = AUVideoParameters(mimes: ["video/mp4"])
        videoParams.placement = .InBanner
        bannerRenderingVideoView.setVideoParameters(videoParams)
        adContainerView.addSubview(bannerRenderingVideoView)
        bannerRenderingVideoView.createAd()
    }
}

// MARK: - Lazy
extension SeparateViewController {
    func createRenderingBannerLazyView() {
        let eventHandler = AUGAMBannerEventHandler(
            adUnitID: Constants.gamAdUnitDisplayBannerRendering,
            validGADAdSizes: [AdSizeBanner].map(nsValue)
        )
        bannerRenderingLazyView = AUBannerRenderingView(
            configId: Constants.storedImpDisplayBanner,
            adSize: adSize,
            eventHandler: eventHandler
        )
        bannerRenderingLazyView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: CGSize(width: 320, height: 50)
        )
        bannerRenderingLazyView.backgroundColor = .cyan
        bannerRenderingLazyView.delegate = self

        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: bannerRenderingLazyView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = "AUBannerRenderingView - Lazy"
            bannerRenderingLazyView.addSubview(nameLabel)
        #endif
        lazyAdContainerView.addSubview(bannerRenderingLazyView)
        bannerRenderingLazyView.createAd()
    }

    func createRenderingBannerVideoLazyView() {
        let eventHandler = AUGAMBannerEventHandler(
            adUnitID: Constants.gamAdUnitVideoBannerRendering,
            validGADAdSizes: [AdSizeMediumRectangle].map(nsValue)
        )
        bannerRenderingVideoLazyView = AUBannerRenderingView(
            configId: Constants.storedImpVideoBanner,
            adSize: CGSize(width: 300, height: 250),
            format: .video,
            eventHandler: eventHandler
        )
        bannerRenderingVideoLazyView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: CGSize(width: 300, height: 250)
        )
        bannerRenderingVideoLazyView.backgroundColor = .systemPink
        bannerRenderingVideoLazyView.delegate = self

        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 0,
                    y: 50,
                    width: bannerRenderingVideoLazyView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = "AUBannerRenderingViewVideo - Lazy"
            bannerRenderingVideoLazyView.addSubview(nameLabel)
        #endif

        let videoParams = AUVideoParameters(mimes: ["video/mp4"])
        videoParams.placement = .InBanner
        bannerRenderingVideoLazyView.setVideoParameters(videoParams)
        lazyAdContainerView.addSubview(bannerRenderingVideoLazyView)
        bannerRenderingVideoLazyView.createAd()
    }
}

extension SeparateViewController: AUBannerRenderingAdDelegate {
    func bannerViewPresentationController() -> UIViewController? {
        self
    }

    func bannerView(
        _ bannerView: AUBannerRenderingView,
        didFailToReceiveAdWith error: Error
    ) {
        print("Banner view did fail to receive ad with error: \(error)")
    }
}
