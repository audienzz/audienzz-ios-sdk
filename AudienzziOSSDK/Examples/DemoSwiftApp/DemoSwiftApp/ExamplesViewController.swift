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
fileprivate let gamAdUnitDisplayBannerOriginal = "/21808260008/prebid_demo_app_original_api_banner"

fileprivate let storedImpVideoBanner = "prebid-demo-video-outstream-original-api"
fileprivate let gamAdUnitVideoBannerOriginal = "/21808260008/prebid-demo-original-api-video-banner"

fileprivate let storedImpsBanner = ["prebid-demo-banner-300-250", "prebid-demo-video-outstream-original-api"]
fileprivate let gamAdUnitMultiformatBannerOriginal = "/21808260008/prebid-demo-original-banner-multiformat"

class ExamplesViewController: UIViewController, GADBannerViewDelegate {
    @IBOutlet private weak var exampleScrollView: UIScrollView!
    @IBOutlet private weak var adContainerView: UIView!
    @IBOutlet private weak var lazyAdContainerView: LazyAdContainerView!
    
    private let adSize = CGSize(width: 320, height: 50)
    private let adVideoSize = CGSize(width: 320, height: 250)
    
    private var bannerView: AUBannerView!
    private var bannerLazyView: AUBannerView!
    
    private var bannerVideoView: AUBannerVideoView!
    private var bannerMultiplatformView: AUBannerMultiplatformView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        exampleScrollView.backgroundColor = .black
        
        createBannerView()
        createVideoBannerView()
        createBannerMultiplatformView()
        createBannerLazyView()
    }
    
    // MARK: - GADBannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        guard let bannerView = bannerView as? GAMBannerView else { return }
        bannerView.resize(GADAdSizeFromCGSize(adSize))
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        let message = "GAM did fail to receive ad with error: \(error)"
        print(message)
    }
}

extension ExamplesViewController: UIScrollViewDelegate {
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
        bannerLazyView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: adSize)
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

// MARK: - Helpers
private extension ExamplesViewController {
    func getPositionY(_ parent: UIView) -> CGFloat {
        guard let lastView = parent.subviews.last else {
            return 0
        }
        
        return lastView.frame.origin.y + lastView.frame.height
    }
}
