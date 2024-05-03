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

fileprivate let storedImpDisplayInterstitial = "prebid-demo-display-interstitial-320-480"
fileprivate let gamAdUnitDisplayInterstitialOriginal = "/21808260008/prebid-demo-app-original-api-display-interstitial"

fileprivate let storedImpVideoInterstitial = "prebid-demo-video-interstitial-320-480-original-api"
fileprivate let gamAdUnitVideoInterstitialOriginal = "/21808260008/prebid-demo-app-original-api-video-interstitial"

fileprivate var interstitialView: AUInterstitialView!
fileprivate var interstitialVideoView: AUInterstitialView!
fileprivate var interstitialMultiplatformView: AUInterstitialView!

extension ExamplesViewController {
    func createInterstitialView() {
        let gamRequest = GAMRequest()
        
        interstitialView = AUInterstitialView(configId: storedImpDisplayInterstitial, adFormats: [.banner])
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
        videoParameters.protocols = [AUVideoProtocols.VAST_2_0]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AUPlacement.InBanner
        
        let interstitialVideoView = AUInterstitialView(configId: storedImpVideoInterstitial, adFormats: [.video])
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
        videoParameters.protocols = [AUVideoProtocols.VAST_2_0]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AUPlacement.InBanner
        
        let interstitialVideoView = AUInterstitialView(configId: storedImpVideoInterstitial,
                                                       adFormats: [.banner, .video],
                                                       isLazyLoad: true,
                                                       minWidthPerc: 60,
                                                       minHeightPerc: 70)
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

// MARK: - GADFullScreenContentDelegate
extension ExamplesViewController: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present interstitial ad with error: \(error.localizedDescription)")
    }
}
