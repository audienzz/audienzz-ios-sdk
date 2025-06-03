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

// 320x50
private let storedImpDisplayBanner = "prebid-demo-banner-320-50"
private let gamAdUnitDisplayBannerOriginal =
    "ca-app-pub-3940256099942544/2934735716"
// 320x250
private let storedImpDisplayBanner_320x250 = "prebid-demo-banner-300-250"
private let gamAdUnitDisplayBannerOriginal_320x250 =
    "ca-app-pub-3940256099942544/6300978111"

// adaptive
private let gamAdUnitDisplayAdaptiveBanner =
    "ca-app-pub-3940256099942544/2435281174"

// Video outstream
private let storedImpVideoBanner = "prebid-demo-video-outstream-original-api"
private let gamAdUnitVideoBannerOriginal =
    "/21808260008/prebid-demo-original-api-video-banner"

//  Multiformat video + HTML banner
private let storedImpsBanner = [
    "prebid-demo-banner-300-250", "prebid-demo-video-outstream-original-api",
]
private let gamAdUnitMultiformatBannerOriginal =
    "/21808260008/prebid-demo-original-banner-multiformat"

//  ========== Lazy ==========
// 320x50
private let storedImpDisplayBannerLazy = "prebid-demo-banner-320-50"
private let gamAdUnitDisplayBannerOriginalLazy =
    "ca-app-pub-3940256099942544/2934735716"

//320x250
private let storedImpDisplayBanner_300x250_Lazy = "prebid-demo-banner-300-250"
private let gamAdUnitDisplayBannerOriginal_300x250_Lazy =
    "ca-app-pub-6632294249825318/7709196874"

// multisize
private let gamAdUnitDisplayAdaptiveBannerLazy =
    "ca-app-pub-3940256099942544/2435281174"

// Video outstream
private let storedImpVideoBannerLazy =
    "prebid-demo-video-outstream-original-api"
private let gamAdUnitVideoBannerOriginalLazy =
    "/21808260008/prebid-demo-original-api-video-banner"

//  Multiformat video + HTML banner
private let storedImpsBannerLazy = [
    "prebid-demo-banner-300-250", "prebid-demo-video-outstream-original-api",
]
private let gamAdUnitMultiformatBannerOriginalLazy =
    "/21808260008/prebid-demo-original-banner-multiformat"

// MARK: - Banner API
extension ExamplesViewController {
    func createBannerView_320x50() {
        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: adSize))
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerView_320x50 = AUBannerView(
            configId: storedImpDisplayBanner,
            adSize: adSize,
            adFormats: [.banner],
            isLazyLoad: false
        )
        bannerView_320x50.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: CGSize(width: self.view.frame.width, height: 50)
        )
        bannerView_320x50.backgroundColor = .clear
        adContainerView.addSubview(bannerView_320x50)

        addDebugLabel(toView: bannerView_320x50, name: "bannerView_320x50")

        bannerView_320x50.adUnitConfiguration.setAutoRefreshMillis(time: 30000)
        bannerView_320x50.addAdditionalSize(sizes: [
            CGSize(width: 500, height: 600)
        ])

        bannerView_320x50.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitDisplayBannerOriginal,
                gamView: gamBanner
            )
        )

        bannerView_320x50.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createbannerView_300x250() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adVideoSize)
        )
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginal_320x250
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerView_300x250 = AUBannerView(
            configId: storedImpDisplayBanner_320x250,
            adSize: adVideoSize,
            adFormats: [.banner],
            isLazyLoad: false
        )
        bannerView_300x250.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: CGSize(width: self.view.frame.width, height: 250)
        )
        bannerView_300x250.backgroundColor = .clear
        adContainerView.addSubview(bannerView_300x250)

        addDebugLabel(toView: bannerView_300x250, name: "bannerView_300x250")

        bannerView_300x250.createAd(with: gamRequest, gamBanner: gamBanner)

        bannerView_300x250.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createMultisizeBanner() {
        let viewWidth = view.frame.inset(by: view.safeAreaInsets).width
        adaptiveSize = currentOrientationAnchoredAdaptiveBanner(
            width: viewWidth
        )
        let gamBanner = AdManagerBannerView(adSize: adaptiveSize)
        gamBanner.adUnitID = gamAdUnitDisplayAdaptiveBanner
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerMultisizeView = AUBannerView(
            configId: storedImpDisplayBanner,
            adSize: adaptiveSize.size,
            adFormats: [.banner],
            isLazyLoad: false
        )
        bannerMultisizeView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: adaptiveSize.size
        )
        adContainerView.addSubview(bannerMultisizeView)

        addDebugLabel(toView: bannerMultisizeView, name: "bannerMultisizeView")

        bannerMultisizeView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitDisplayAdaptiveBanner,
                gamView: gamBanner
            )
        )

        bannerMultisizeView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createVideoBannerView() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitVideoBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [
            AUVideoPlaybackMethod(type: .AutoPlaySoundOff)
        ]
        videoParameters.placement = AUPlacement.InBanner

        bannerVideoView = AUBannerView(
            configId: storedImpVideoBanner,
            adSize: adSizeMult,
            adFormats: [.video],
            isLazyLoad: false
        )
        bannerVideoView.videoParameters = videoParameters
        bannerVideoView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: adVideoSize
        )
        bannerVideoView.backgroundColor = .clear
        adContainerView.addSubview(bannerVideoView)

        addDebugLabel(toView: bannerVideoView, name: "bannerVideoView")

        bannerVideoView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitVideoBannerOriginal,
                gamView: gamBanner
            )
        )

        bannerVideoView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createBannerMultiplatformView() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitMultiformatBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = AdManagerRequest()

        let bannerParameters = AUBannerParameters()
        bannerParameters.api = [AUApi(apiType: .MRAID_2)]

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [
            AUVideoPlaybackMethod(type: .AutoPlaySoundOff)
        ]
        videoParameters.placement = AUPlacement.InBanner

        bannerMultiplatformView = AUBannerView(
            configId: storedImpsBanner.randomElement()!,
            adSize: adSizeMult,
            adFormats: [.banner, .video],
            isLazyLoad: false
        )
        bannerMultiplatformView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: adSizeMult
        )
        bannerMultiplatformView.bannerParameters = bannerParameters
        bannerMultiplatformView.videoParameters = videoParameters
        bannerMultiplatformView.backgroundColor = .clear
        adContainerView.addSubview(bannerMultiplatformView)

        bannerMultiplatformView.layer.borderWidth = 1
        bannerMultiplatformView.layer.borderColor = UIColor.black.cgColor

        addDebugLabel(
            toView: bannerMultiplatformView,
            name: "bannerMultiplatformView"
        )

        bannerMultiplatformView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitMultiformatBannerOriginal,
                gamView: gamBanner
            )
        )
        bannerMultiplatformView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
}

// MARK: - Banner API Lazy Load
extension ExamplesViewController {
    func createBannerLazyView_320x50() {
        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: adSize))
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginalLazy
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = AdManagerRequest()

        bannerLazyView_320x50 = AUBannerView(
            configId: storedImpDisplayBannerLazy,
            adSize: adSize,
            adFormats: [.banner],
            isLazyLoad: true
        )
        bannerLazyView_320x50.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: CGSize(width: self.view.frame.width, height: 50)
        )
        bannerLazyView_320x50.backgroundColor = .clear
        lazyAdContainerView.addSubview(bannerLazyView_320x50)

        addDebugLabel(
            toView: bannerLazyView_320x50,
            name: "bannerLazyView_320x50"
        )

        bannerLazyView_320x50.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitDisplayBannerOriginalLazy,
                gamView: gamBanner
            )
        )

        bannerLazyView_320x50.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createBannerLazyView_320x250() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adVideoSize)
        )
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginal_320x250
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = AdManagerRequest()

        bannerLazyView_300x250 = AUBannerView(
            configId: storedImpDisplayBanner_300x250_Lazy,
            adSize: adSize,
            adFormats: [.banner],
            isLazyLoad: true
        )
        bannerLazyView_300x250.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: CGSize(width: self.view.frame.width, height: 250)
        )
        bannerLazyView_300x250.backgroundColor = .clear
        lazyAdContainerView.addSubview(bannerLazyView_300x250)

        addDebugLabel(
            toView: bannerLazyView_300x250,
            name: "bannerLazyView_300x250"
        )

        bannerLazyView_300x250.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitDisplayBannerOriginal_320x250,
                gamView: gamBanner
            )
        )

        bannerLazyView_300x250.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createMultisizeBannerLazyView() {
        let viewWidth = view.frame.inset(by: view.safeAreaInsets).width
        adaptiveSize = currentOrientationAnchoredAdaptiveBanner(
            width: viewWidth
        )
        let gamBanner = AdManagerBannerView(adSize: adaptiveSize)
        gamBanner.adUnitID = gamAdUnitDisplayAdaptiveBannerLazy
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerLazyMultisizeView = AUBannerView(
            configId: storedImpDisplayBannerLazy,
            adSize: adaptiveSize.size,
            adFormats: [.banner],
            isLazyLoad: true
        )
        bannerLazyMultisizeView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: adaptiveSize.size
        )
        bannerLazyMultisizeView.backgroundColor = .clear
        lazyAdContainerView.addSubview(bannerLazyMultisizeView)

        addDebugLabel(
            toView: bannerLazyMultisizeView,
            name: "bannerLazyMultisizeView"
        )

        bannerLazyMultisizeView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitDisplayAdaptiveBannerLazy,
                gamView: gamBanner
            )
        )

        bannerLazyMultisizeView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createVideoLazyBannerView() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitVideoBannerOriginalLazy
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [
            AUVideoPlaybackMethod(type: .AutoPlaySoundOff)
        ]
        videoParameters.placement = AUPlacement.InBanner

        bannerLazyVideoView = AUBannerView(
            configId: storedImpVideoBannerLazy,
            adSize: adSizeMult,
            adFormats: [.video],
            isLazyLoad: true
        )
        bannerLazyVideoView.videoParameters = videoParameters
        bannerLazyVideoView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: adVideoSize
        )
        bannerLazyVideoView.backgroundColor = .clear
        lazyAdContainerView.addSubview(bannerLazyVideoView)

        addDebugLabel(toView: bannerLazyVideoView, name: "bannerLazyVideoView")

        bannerLazyVideoView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitVideoBannerOriginalLazy,
                gamView: gamBanner
            )
        )

        bannerLazyVideoView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createBannerMultiplatformLazyView() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitMultiformatBannerOriginalLazy
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = AdManagerRequest()

        let bannerParameters = AUBannerParameters()
        bannerParameters.api = [AUApi(apiType: .MRAID_2)]

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [
            AUVideoPlaybackMethod(type: .AutoPlaySoundOff)
        ]
        videoParameters.placement = AUPlacement.InBanner

        bannerLazyMultiplatformView = AUBannerView(
            configId: storedImpsBannerLazy.randomElement()!,
            adSize: adSizeMult,
            adFormats: [.banner, .video],
            isLazyLoad: true
        )
        bannerLazyMultiplatformView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
            size: adSizeMult
        )
        bannerLazyMultiplatformView.bannerParameters = bannerParameters
        bannerLazyMultiplatformView.videoParameters = videoParameters
        bannerLazyMultiplatformView.backgroundColor = .clear
        lazyAdContainerView.addSubview(bannerLazyMultiplatformView)

        addDebugLabel(
            toView: bannerLazyMultiplatformView,
            name: "bannerLazyMultiplatformView"
        )

        bannerLazyMultiplatformView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitMultiformatBannerOriginalLazy,
                gamView: gamBanner
            )
        )
        bannerLazyMultiplatformView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
}

// MARK: - GADBannerViewDelegate
extension ExamplesViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else {
            return
        }
        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { size in
                bannerView.resize(adSizeFor(cgSize: size))
            },
            failure: { [weak self] (error) in
                self?.showSizeError(forView: bannerView, error: error)
            }
        )
    }

    func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: Error
    ) {
        print("GAM did fail to receive ad with error: \(error)")
        errorHandling(forView: bannerView, error: error)
    }
}
