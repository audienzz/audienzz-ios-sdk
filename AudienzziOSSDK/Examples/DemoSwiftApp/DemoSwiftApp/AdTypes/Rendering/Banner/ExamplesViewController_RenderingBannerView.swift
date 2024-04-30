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

fileprivate let storedImpDisplayBanner = "prebid-demo-banner-320-50"
fileprivate let gamAdUnitDisplayBannerRendering = "/21808260008/prebid_oxb_320x50_banner"

fileprivate let storedImpVideoBanner = "prebid-demo-video-outstream"
fileprivate let gamAdUnitVideoBannerRendering = "/21808260008/prebid_oxb_300x250_banner"

fileprivate var bannerRenderingView: AUBannerRenderingView!
fileprivate var bannerRenderingLazyView: AUBannerRenderingView!

fileprivate var bannerRenderingVideoView: AUBannerRenderingView!

extension ExamplesViewController {
    func createRenderingBannerView() {
        let eventHandler = AUGAMBannerEventHandler(adUnitID: gamAdUnitDisplayBannerRendering,
                                                   validGADAdSizes: [GADAdSizeBanner].map(NSValueFromGADAdSize))
        bannerRenderingView = AUBannerRenderingView(configId: storedImpDisplayBanner, adSize: adSize, isLazyLoad: false)
        bannerRenderingView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)), size: CGSize(width: 320, height: 50))
        bannerRenderingView.delegate = self
        bannerRenderingView.createAd(with: eventHandler)
        adContainerView.addSubview(bannerRenderingView)
    }
    
    func createRenderingBannerVideoView() {
        let eventHandler = AUGAMBannerEventHandler(adUnitID: gamAdUnitVideoBannerRendering,
                                                   validGADAdSizes: [GADAdSizeMediumRectangle].map(NSValueFromGADAdSize))
        bannerRenderingVideoView = AUBannerRenderingView(configId: storedImpVideoBanner, adSize: adSize, isLazyLoad: false)
        bannerRenderingVideoView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)), size: CGSize(width: 320, height: 50))
        bannerRenderingVideoView.delegate = self
        bannerRenderingVideoView.createAd(with: eventHandler)
        adContainerView.addSubview(bannerRenderingVideoView)
    }
    
    func createRenderingBannerLazyView() {
        let eventHandler = AUGAMBannerEventHandler(adUnitID: gamAdUnitDisplayBannerRendering,
                                                   validGADAdSizes: [GADAdSizeBanner].map(NSValueFromGADAdSize))
        bannerRenderingLazyView = AUBannerRenderingView(configId: storedImpDisplayBanner, adSize: adSize, isLazyLoad: true)
        bannerRenderingLazyView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)), size: CGSize(width: 320, height: 50))
        bannerRenderingLazyView.delegate = self
        bannerRenderingLazyView.createAd(with: eventHandler)
        lazyAdContainerView.addSubview(bannerRenderingLazyView)
    }
}

extension ExamplesViewController: AUBannerRenderingAdDelegate {
    func bannerViewPresentationController() -> UIViewController? {
        self
    }
    
    func bannerView(_ bannerView: AUBannerRenderingView, didFailToReceiveAdWith error: Error) {
        print("Banner view did fail to receive ad with error: \(error)")
    }
}
