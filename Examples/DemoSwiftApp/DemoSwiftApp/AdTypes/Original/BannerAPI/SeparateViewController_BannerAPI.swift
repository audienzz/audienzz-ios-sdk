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

// Unfilled (intentional test IDs, not replaced by remote config)
private let storedImpUnfilled = "2"
private let gamAdUnitUnfilled = "/96628199/de_audienzz.ch_v2/multi-size"

// MARK: - Banner API
extension SeparateViewController {
    func createBannerView_320x50() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createBannerView_320x50")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: adSize))
        gamBanner.adUnitID = gamAdUnitPath
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerView_320x50 = AUBannerView(
            configId: placementId,
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

        bannerView_320x50.adUnitConfiguration.setAutoRefreshMillis(
            time: Double((config.config.refreshTimeSeconds ?? 30) * 1000)
        )
        bannerView_320x50.smartRefresh = true
        bannerView_320x50.addAdditionalSize(sizes: [
            CGSize(width: 500, height: 600)
        ])

        let handler = AUBannerEventHandler(
            adUnitId: gamAdUnitPath,
            gamView: gamBanner
        )
        bannerView_320x50.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: handler
        )

        bannerView_320x50.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }

    func createBannerView_300x250() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createBannerView_300x250")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adVideoSize)
        )
        gamBanner.adUnitID = gamAdUnitPath
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerView_300x250 = AUBannerView(
            configId: placementId,
            adSize: adSizeMult,
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

        let handler = AUBannerEventHandler(
            adUnitId: gamAdUnitPath,
            gamView: gamBanner
        )

        bannerView_300x250.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: handler
        )

        bannerView_300x250.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
    
    func createBannerUnfilledView() {
        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adVideoSize)
        )
        gamBanner.adUnitID = gamAdUnitUnfilled
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        
        let gamRequest = AdManagerRequest()
        
        bannerUnfilledView = AUBannerView(
            configId: storedImpUnfilled,
            adSize: adVideoSize,
            adFormats: [.banner],
            isLazyLoad: false
        )
      
        bannerUnfilledView.frame = CGRect(
            origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
            size: CGSize(width: self.view.frame.width, height: 250)
        )
        bannerUnfilledView.backgroundColor = .clear
        adContainerView.addSubview(bannerUnfilledView)

        let handler = AUBannerEventHandler(
            adUnitId: gamAdUnitUnfilled,
            gamView: gamBanner
        )

        addDebugLabel(toView: bannerUnfilledView, name: "Banner unfilled view")
        
        bannerUnfilledView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: handler
        )

        bannerUnfilledView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("Failed request unwrap")
                return
            }
            gamBanner.load(request)
        }
       
    
    }

    func createVideoBannerView() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createVideoBannerView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitPath
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
            configId: placementId,
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
                adUnitId: gamAdUnitPath,
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createBannerMultiplatformView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitPath
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
            configId: placementId,
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
                adUnitId: gamAdUnitPath,
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
extension SeparateViewController {
    func createBannerLazyView_320x50() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createBannerLazyView_320x50")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: adSize))
        gamBanner.adUnitID = gamAdUnitPath
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = AdManagerRequest()

        bannerLazyView_320x50 = AUBannerView(
            configId: placementId,
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

        bannerLazyView_320x50.adUnitConfiguration.setAutoRefreshMillis(
            time: Double((config.config.refreshTimeSeconds ?? 30) * 1000)
        )
        bannerLazyView_320x50.smartRefresh = true

        addDebugLabel(
            toView: bannerLazyView_320x50,
            name: "bannerLazyView_320x50"
        )

        bannerLazyView_320x50.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(
                adUnitId: gamAdUnitPath,
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createBannerLazyView_320x250")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adVideoSize)
        )
        gamBanner.adUnitID = gamAdUnitPath
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = AdManagerRequest()

        bannerLazyView_300x250 = AUBannerView(
            configId: placementId,
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
                adUnitId: gamAdUnitPath,
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createMultisizeBannerLazyView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let viewWidth = view.frame.inset(by: view.safeAreaInsets).width
        adaptiveSize = currentOrientationAnchoredAdaptiveBanner(
            width: viewWidth
        )
        let gamBanner = AdManagerBannerView(adSize: adaptiveSize)
        gamBanner.adUnitID = gamAdUnitPath
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = AdManagerRequest()

        bannerLazyMultisizeView = AUBannerView(
            configId: placementId,
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
                adUnitId: gamAdUnitPath,
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createVideoLazyBannerView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitPath
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
            configId: placementId,
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
                adUnitId: gamAdUnitPath,
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "46") else {
            print("Warning: Remote config '46' not available for createBannerMultiplatformLazyView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamBanner = AdManagerBannerView(
            adSize: adSizeFor(cgSize: adSizeMult)
        )
        gamBanner.adUnitID = gamAdUnitPath
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
            configId: placementId,
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
                adUnitId: gamAdUnitPath,
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
extension SeparateViewController: BannerViewDelegate {
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
        
        if (bannerView.adUnitID == gamAdUnitUnfilled){
            bannerView.removeFromSuperview()
        } else {
            errorHandling(forView: bannerView, error: error)
        }
    }
}
