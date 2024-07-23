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

// MARK: - Interstitial API

fileprivate let storedImpDisplayInterstitial = "prebid-demo-display-interstitial-320-480"
fileprivate let gamAdUnitDisplayInterstitialOriginal = "ca-app-pub-3940256099942544/4411468910"
fileprivate let storedImpVideoInterstitial = "prebid-demo-video-interstitial-320-480-original-api"
fileprivate let gamAdUnitVideoInterstitialOriginal = "ca-app-pub-3940256099942544/5135589807"

fileprivate let storedImpsInterstitial = ["prebid-demo-display-interstitial-320-480", "prebid-demo-video-interstitial-320-480-original-api"]
fileprivate let gamAdUnitMultiformatInterstitialOriginal = "/21808260008/prebid-demo-intestitial-multiformat"

extension SeparateViewController {
    func createInterstitialView() {
        let gamRequest = GAMRequest()

        interstitialView = AUInterstitialView(configId: storedImpDisplayInterstitial, adFormats: [.banner], isLazyLoad: true)
        interstitialView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                        size: CGSize(width: 320, height: 300))
        interstitialView.backgroundColor = .systemPink
        lazyAdContainerView.addSubview(interstitialView)
        
        addDebugLabel(toView: interstitialView, name: "interstitialView")
        
        interstitialView.createAd(with: gamRequest, adUnitID: gamAdUnitDisplayInterstitialOriginal)
        
        interstitialView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            self?.stopScroll()
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitDisplayInterstitialOriginal, request: request) { ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    self.interstitialView.connectHandler(AUInterstitialEventHandler(adUnit: ad))
                    ad.present(fromRootViewController: self)
                }
            }
        }
    }
    
    func createInterstitialVideoView() {
        let gamRequest = GAMRequest()
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod(type: .AutoPlaySoundOff)]
        videoParameters.placement = AUPlacement.InBanner
        
        interstitialVideoView = AUInterstitialView(configId: storedImpVideoInterstitial,
                                                   adFormats: [.video],
                                                   isLazyLoad: true,
                                                   minWidthPerc: 60,
                                                   minHeightPerc: 70)
        interstitialVideoView.frame = CGRect(origin:CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                        size: CGSize(width: 320, height: 250))
        interstitialVideoView.backgroundColor = .darkGray
        lazyAdContainerView.addSubview(interstitialVideoView)
        
        addDebugLabel(toView: interstitialVideoView, name: "interstitialVideoView")
        
        interstitialVideoView.parameters = videoParameters
        interstitialVideoView.createAd(with: gamRequest, adUnitID: gamAdUnitVideoInterstitialOriginal)
        
        interstitialVideoView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            self?.stopScroll()
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitVideoInterstitialOriginal, request: request) { ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    self.interstitialVideoView.connectHandler(AUInterstitialEventHandler(adUnit: ad))
                    ad.present(fromRootViewController: self)
                }
            }
        }
    }
    
    func createInterstitialMultiplatformView() {
        let gamRequest = GAMRequest()
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod(type: .AutoPlaySoundOff)]
        
        interstitialMultiplatformView = AUInterstitialView(configId: storedImpsInterstitial.randomElement()!,
                                                           adFormats: [.banner, .video],
                                                           isLazyLoad: true,
                                                           minWidthPerc: 60,
                                                           minHeightPerc: 70)
        interstitialMultiplatformView.frame = CGRect(origin:CGPoint(x: 0, y: getPositionY(lazyAdContainerView)),
                                        size: CGSize(width: 320, height: 250))
        interstitialMultiplatformView.backgroundColor = .systemPink
        lazyAdContainerView.addSubview(interstitialMultiplatformView)
        
        addDebugLabel(toView: interstitialMultiplatformView, name: "interstitialMultiplatformView")
        
        interstitialMultiplatformView.parameters = videoParameters
        interstitialMultiplatformView.createAd(with: gamRequest, adUnitID: gamAdUnitMultiformatInterstitialOriginal)
        
        interstitialMultiplatformView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            self?.stopScroll()
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitMultiformatInterstitialOriginal, request: request) { ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                    self.errorHandling(adView: self.interstitialMultiplatformView, error: error)
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    self.interstitialMultiplatformView.connectHandler(AUInterstitialEventHandler(adUnit: ad))
                    ad.present(fromRootViewController: self)
                }
            }
        }
    }
}

extension SeparateViewController: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if let adv = ad as? GAMInterstitialAd {
            print("GADFullScreenPresentingAd: \(adv.adUnitID)")
        }
        print("Failed to present interstitial ad with error: \(error.localizedDescription)")
    }

    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        
    }
}

