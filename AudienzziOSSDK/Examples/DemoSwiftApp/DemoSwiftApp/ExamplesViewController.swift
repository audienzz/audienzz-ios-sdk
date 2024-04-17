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
import GoogleInteractiveMediaAds

fileprivate let storedImpDisplayBanner = "prebid-demo-banner-320-50"
fileprivate let gamAdUnitDisplayBannerOriginal = "/21808260008/prebid_demo_app_original_api_banner"

fileprivate let storedImpVideoBanner = "prebid-demo-video-outstream-original-api"
fileprivate let gamAdUnitVideoBannerOriginal = "/21808260008/prebid-demo-original-api-video-banner"

fileprivate let storedImpsBanner = ["prebid-demo-banner-300-250", "prebid-demo-video-outstream-original-api"]
fileprivate let gamAdUnitMultiformatBannerOriginal = "/21808260008/prebid-demo-original-banner-multiformat"

class ExamplesViewController: UIViewController, GADBannerViewDelegate {
    @IBOutlet private weak var exampleScrollView: UIScrollView!
    @IBOutlet weak var adContainerView: UIView!
    @IBOutlet weak var lazyAdContainerView: LazyAdContainerView!
    var playButton: UIButton!
    
    let adSize = CGSize(width: 320, height: 50)
    let adVideoSize = CGSize(width: 320, height: 250)
    private var adLoader: GADAdLoader!
    private var adLazyLoader: GADAdLoader!
    
    private var bannerView: AUBannerView!
    private var bannerLazyView: AUBannerView!
    
    private var bannerVideoView: AUBannerVideoView!
    private var bannerMultiplatformView: AUBannerMultiplatformView!
    
    private var interstitialView: AUInterstitialView!
    private var interstitialVideoView: AUInterstitialVideoView!
    private var interstitialMultiplatformView: AUInterstitialMultiplatformView!
    
    private var nativeView: AUNativeView!
    private var nativeBannerView:AUNativeBannerView!
    private var nativeLzyView: AUNativeView!
    private var nativeLazyBannerView:AUNativeBannerView!
    
    // Rewarded
    private var rewardedView: AURewardedView!
    
    // Instream
    // IMA
    var adsLoader: IMAAdsLoader!
    var adsManager: IMAAdsManager?
    var contentPlayhead: IMAAVPlayerContentPlayhead?
    var contentPlayer: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var instreamView: AUInstreamView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        exampleScrollView.backgroundColor = .black
        
        setupAdContainer()
        setupALazydContainer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        playerLayer?.frame = instreamView.layer.bounds
        adsManager?.destroy()
        contentPlayer?.pause()
        contentPlayer = nil
    }
    
    private func setupAdContainer() {
//        createBannerView()
//        createVideoBannerView()
//        createBannerMultiplatformView()
//        
        createNativeView()
//        createNativeBannerView()
//        
//        createInstreamView()
        createRenderingBannerView()
        createRenderingBannerVideoView()
        createRenderingIntertitiaView()
        createRenderingRewardView()
    }
    
    private func setupALazydContainer() {
//        createBannerLazyView()
//
//        createInterstitialView()
//        createInterstitialVideoView()
//        createInterstitialMultiplatformView()
//        
//        createLazyNativeView()
//        createLazyNativeBannerView()
//        
//        createRewardedView()
//        createRenderingBannerLazyView()
//        createRenderingRewardLazyView()
    }
    
    // MARK: - GADBannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        guard let bannerView = bannerView as? GAMBannerView else { return }
        bannerView.resize(GADAdSizeFromCGSize(adSize))
        AUAdViewUtils.findCreativeSize(bannerView, success: { size in
            bannerView.resize(GADAdSizeFromCGSize(size))
        }, failure: { (error) in
            print("Error occuring during searching for Prebid creative size: \(error)")
        })
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        let message = "GAM did fail to receive ad with error: \(error)"
        print(message)
    }
    
    @IBAction private func refreshAdContainerDidTap() {
        var subviews = adContainerView.subviews
        subviews.remove(at: 0)
        
        guard !subviews.isEmpty else { return }
        
        for subview in subviews {
            subview.removeFromSuperview()
        }
        
        setupAdContainer()
    }
}

// MARK: - Banner API
fileprivate extension ExamplesViewController {
    func createBannerView() {
        let gamBanner = GAMBannerView(adSize: GADAdSizeFromCGSize(adSize))
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = GAMRequest()
        
        bannerView = AUBannerView(configId: storedImpDisplayBanner, adSize: adSize)
        bannerView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)), size: adSize)
        bannerView.backgroundColor = .clear
        adContainerView.addSubview(bannerView)
        
        bannerView.createAd(with: gamRequest, gamBanner: gamBanner)
        
        bannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
    
    func createBannerMultiplatformView() {
        let gamBanner = GAMBannerView(adSize: GADAdSizeFromCGSize(adSize))
        gamBanner.adUnitID = gamAdUnitMultiformatBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = GAMRequest()
        
        bannerMultiplatformView = AUBannerMultiplatformView(configId: storedImpsBanner.first!, adSize: adSize)
        bannerMultiplatformView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)), size: adVideoSize)
        bannerMultiplatformView.backgroundColor = .clear
        adContainerView.addSubview(bannerMultiplatformView)
        
        bannerMultiplatformView.createAd(with: gamRequest, gamBanner: gamBanner)
        bannerMultiplatformView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
    
    func createVideoBannerView() {
        let gamBanner = GAMBannerView(adSize: GADAdSizeFromCGSize(adVideoSize))
        gamBanner.adUnitID = gamAdUnitVideoBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = GAMRequest()
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AdVideoParameters.Protocols.VAST_2_0]
        videoParameters.playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AdVideoParameters.Placement.InBanner
        
        bannerVideoView = AUBannerVideoView(configId: storedImpVideoBanner, adSize: adVideoSize)
        bannerVideoView.parameters = videoParameters
        bannerVideoView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)),size: adVideoSize)
        bannerVideoView.backgroundColor = .clear
        adContainerView.addSubview(bannerVideoView)
        
        bannerVideoView.createAd(with: gamRequest, gamBanner: gamBanner)
        
        bannerVideoView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
}

// MARK: - Banner API Lazy Load
fileprivate extension ExamplesViewController {
    func createBannerLazyView() {
        let gamBanner = GAMBannerView(adSize: GADAdSizeFromCGSize(adSize))
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginal
        gamBanner.rootViewController = self
        gamBanner.delegate = self

        let gamRequest = GAMRequest()
        
        bannerLazyView = AUBannerView(configId: storedImpDisplayBanner, adSize: adSize, isLazyLoad: true)
        bannerLazyView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)), size: adSize)
        bannerLazyView.backgroundColor = .green
        lazyAdContainerView.addSubview(bannerLazyView)
        
        bannerLazyView.createAd(with: gamRequest, gamBanner: gamBanner)
        
        bannerLazyView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
}

fileprivate let storedImpDisplayInterstitial = "prebid-demo-display-interstitial-320-480"
fileprivate let gamAdUnitDisplayInterstitialOriginal = "/21808260008/prebid-demo-app-original-api-display-interstitial"

fileprivate let storedImpVideoInterstitial = "prebid-demo-video-interstitial-320-480-original-api"
fileprivate let gamAdUnitVideoInterstitialOriginal = "/21808260008/prebid-demo-app-original-api-video-interstitial"

fileprivate extension ExamplesViewController {
    func createInterstitialView() {
        let gamRequest = GAMRequest()
        
        interstitialView = AUInterstitialView(configId: storedImpDisplayInterstitial, adSize: CGSize(width: 320, height: 480), isLazyLoad: true)
        interstitialView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                        size: CGSize(width: 320, height: 50))
        interstitialView.backgroundColor = .systemPink
        lazyAdContainerView.addSubview(interstitialView)
        
        interstitialView.createAd(with: gamRequest)
        
        interstitialView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitDisplayInterstitialOriginal, request: request) { ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    
                    // 4. Present the interstitial ad
                    ad.present(fromRootViewController: self)
                }
            }
        }
    }
    
    func createInterstitialVideoView() {
        let gamRequest = GAMRequest()
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AdVideoParameters.Protocols.VAST_2_0]
        videoParameters.playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AdVideoParameters.Placement.InBanner
        
        let interstitialVideoView = AUInterstitialVideoView(configId: storedImpVideoInterstitial, adSize: CGSize(width: 320, height: 480), isLazyLoad: true)
        interstitialVideoView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                        size: CGSize(width: 320, height: 50))
        interstitialVideoView.backgroundColor = .yellow
        lazyAdContainerView.addSubview(interstitialVideoView)
        
        interstitialVideoView.parameters = videoParameters
        interstitialVideoView.createAd(with: gamRequest)
        
        interstitialVideoView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            GAMInterstitialAd.load(withAdManagerAdUnitID: "ca-app-pub-3940256099942544/5135589807", request: request) { ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    ad.present(fromRootViewController: self)
                }
            }
        }
    }
    
    func createInterstitialMultiplatformView() {
        let gamRequest = GAMRequest()
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AdVideoParameters.Protocols.VAST_2_0]
        videoParameters.playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AdVideoParameters.Placement.InBanner
        
        let interstitialVideoView = AUInterstitialVideoView(configId: storedImpVideoInterstitial, adSize: CGSize(width: 320, height: 480), isLazyLoad: true)
        interstitialVideoView.frame = CGRect(origin:CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                        size: CGSize(width: 320, height: 50))
        interstitialVideoView.backgroundColor = .yellow
        lazyAdContainerView.addSubview(interstitialVideoView)
        
        interstitialVideoView.parameters = videoParameters
        interstitialVideoView.createAd(with: gamRequest)
        
        interstitialVideoView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitVideoInterstitialOriginal, request: request) { ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    ad.present(fromRootViewController: self)
                }
            }
        }
    }
}

// MARK: - Native Banner API

fileprivate let storedPrebidImpression = "prebid-demo-banner-native-styles"
fileprivate let gamRenderingNativeAdUnitId = "/21808260008/apollo_custom_template_native_ad_unit"

fileprivate extension ExamplesViewController {
    func createNativeView() {
        nativeView = AUNativeView(configId: storedPrebidImpression, adSize: .zero)
        nativeView.configuration = nativeConfiguration()

        let gamRequest = GAMRequest()
        nativeView.createAd(with: gamRequest)
        
        nativeView.onLoadRequest = { [weak self] request in
            guard let self = self else { return }
            guard let request = request as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            
            self.adLoader = GADAdLoader(adUnitID: gamRenderingNativeAdUnitId, rootViewController: self,
                                        adTypes: [GADAdLoaderAdType.customNative], options: [])
            self.adLoader.delegate = self
            self.adLoader.load(request)
        }
        
        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        exampleView.frame = CGRect(x: 0, y: getPositionY(adContainerView), width: self.view.frame.width, height: 200)
        adContainerView.addSubview(exampleView)
        
        nativeView.onGetNativeAd = { [weak self] ad in
            exampleView.setupFromAd(ad: ad)
            self?.nativeView.registerView(clickableViews: [exampleView.callToActionButton])
        }
        
    }
    
    func createNativeBannerView() {
        let gamRequest = GAMRequest()
        let gamBannerView = GAMBannerView(adSize: GADAdSizeFluid)
        gamBannerView.adUnitID = "/21808260008/prebid-demo-original-native-styles"
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        
        nativeBannerView = AUNativeBannerView(configId: storedPrebidImpression, adSize: .zero)
        nativeBannerView.frame = CGRect(x: 0, y: getPositionY(adContainerView), width: self.view.frame.width, height: 200)
        adContainerView.addSubview(nativeBannerView)
        
        nativeBannerView.createAd(with: gamRequest, gamBanner: gamBannerView, configuration: nativeConfiguration())
        nativeBannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            gamBannerView.load(request)
        }
    }
    
    func nativeConfiguration() -> AUNativeRequestParameter {
        let image = AUNativeAssetImage(minimumWidth: 200, minimumHeight: 50, required: true)
        image.typeImage = AUImageAsset.Main
        
        let icon = AUNativeAssetImage(minimumWidth: 20, minimumHeight: 20, required: true)
        icon.typeImage = AUImageAsset.Icon
        
        let title = AUNativeAssetTitle(length: 90, required: true)
        let body = AUNativeAssetData(dataType: AUDataAsset.description, required: true)
        let cta = AUNativeAssetData(dataType: AUDataAsset.ctatext, required: true)
        let sponsored = AUNativeAssetData(dataType: AUDataAsset.sponsored, required: true)
        
        let asstets: [AUNativeAsset] = [title, icon, image, sponsored, body, cta]
        
        var parameters = AUNativeRequestParameter()
        
        parameters.assets = asstets
        parameters.context = AUContextType.Social
        parameters.placementType = AUPlacementType.FeedContent
        parameters.contextSubType = AUContextSubType.Social
        parameters.eventtrackers = [AUNativeEventTracker(event: EventType.Impression, methods: [EventTracking.Image, EventTracking.js])]
        
        return parameters
    }
}

// MARK: - Native API Lazy load

fileprivate extension ExamplesViewController {
    func createLazyNativeView() {
        nativeLzyView = AUNativeView(configId: storedPrebidImpression, adSize: .zero, isLazyLoad: true)
        nativeLzyView.configuration = nativeConfiguration()

        let gamRequest = GAMRequest()
        nativeLzyView.createAd(with: gamRequest)
        
        nativeLzyView.onLoadRequest = { [weak self] request in
            guard let self = self else { return }
            guard let request = request as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            
            self.adLazyLoader = GADAdLoader(adUnitID: gamRenderingNativeAdUnitId, rootViewController: self,
                                        adTypes: [GADAdLoaderAdType.customNative], options: [])
            self.adLazyLoader.delegate = self
            self.adLazyLoader.load(request)
        }
        
        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        nativeLzyView.frame = CGRect(x: 0, y: getPositionY(lazyAdContainerView), width: self.view.frame.width, height: 200)
        exampleView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200)
        nativeLzyView.addSubview(exampleView)
        lazyAdContainerView.addSubview(nativeLzyView)
        
        nativeLzyView.onGetNativeAd = { ad in
            exampleView.setupFromAd(ad: ad)
        }
    }

    func createLazyNativeBannerView() {
        let gamRequest = GAMRequest()
        let gamBannerView = GAMBannerView(adSize: GADAdSizeFluid)
        gamBannerView.adUnitID = "/21808260008/prebid-demo-original-native-styles"
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        
        nativeLazyBannerView = AUNativeBannerView(configId: storedPrebidImpression, adSize: .zero, isLazyLoad: true)
        nativeLazyBannerView.frame = CGRect(x: 0, y: getPositionY(lazyAdContainerView), width: self.view.frame.width, height: 200)
        lazyAdContainerView.addSubview(nativeLazyBannerView)
        
        nativeLazyBannerView.createAd(with: gamRequest, gamBanner: gamBannerView, configuration: nativeConfiguration())
        nativeLazyBannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            gamBannerView.load(request)
        }
    }
}

// MARK: GADCustomNativeAdLoaderDelegate
extension ExamplesViewController: GADAdLoaderDelegate, GADCustomNativeAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        print("GAM did fail to receive ad with error: \(error)")
    }
    
    func customNativeAdFormatIDs(for adLoader: GADAdLoader) -> [String] {
        ["11934135"]
    }
    
    func adLoader(_ adLoader: GADAdLoader, didReceive customNativeAd: GADCustomNativeAd) {
        if adLoader == self.adLoader {
            nativeView.findNative(adObject: customNativeAd)
        } else if adLoader == adLazyLoader {
            nativeLzyView.findNative(adObject: customNativeAd)
        }
    }
}

// MARK: - GADFullScreenContentDelegate
extension ExamplesViewController: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present interstitial ad with error: \(error.localizedDescription)")
    }
}

// MARK: - Rewarded
fileprivate let storedImpVideoRewarded = "prebid-demo-video-rewarded-320-480-original-api"
fileprivate let gamAdUnitVideoRewardedOriginal = "ca-app-pub-3940256099942544/1712485313"

fileprivate extension ExamplesViewController {
    func createRewardedView() {
        let gamRequest = GAMRequest()
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AdVideoParameters.Protocols.VAST_2_0]
        videoParameters.playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
        
        rewardedView = AURewardedView(configId: storedImpVideoRewarded, adSize: adSize)
        rewardedView.parameters = videoParameters
        rewardedView.createAd(with: gamRequest)
        rewardedView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            GADRewardedAd.load(withAdUnitID: gamAdUnitVideoRewardedOriginal, request: request) { [weak self] ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    // 5. Present the interstitial ad
                    ad.fullScreenContentDelegate = self
                    ad.present(fromRootViewController: self, userDidEarnRewardHandler: {
                        _ = ad.adReward
                    })
                }
            }
        }
    }
}

// MARK: - Helpers
extension ExamplesViewController {
    func getPositionY(_ parent: UIView) -> CGFloat {
        guard let lastView = parent.subviews.last else {
            return 0
        }
        
        return lastView.frame.origin.y + lastView.frame.height
    }
}

extension UIView {
    class func fromNib<T: UIView>() -> T {
        return Bundle(for: T.self).loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
    }
}
