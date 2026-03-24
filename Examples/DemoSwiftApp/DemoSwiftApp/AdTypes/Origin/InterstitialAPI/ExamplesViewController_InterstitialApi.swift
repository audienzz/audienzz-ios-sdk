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

//fileprivate var interstitialView: AUInterstitialView!
fileprivate var interstitialVideoView: AUInterstitialView!
fileprivate var interstitialMultiplatformView: AUInterstitialView!

extension ExamplesViewController {
    func createInterstitialView() {
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "47") else {
            print("Warning: Remote config '47' not available for createInterstitialView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamRequest = GAMRequest()

        interstitialView = AUInterstitialView(configId: placementId, adFormats: [.banner])
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
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitPath, request: request) { [weak self] ad, error in
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "47") else {
            print("Warning: Remote config '47' not available for createInterstitialVideoView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamRequest = GAMRequest()

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod(type: .AutoPlaySoundOff)]
        videoParameters.placement = AUPlacement.InBanner

        let interstitialVideoView = AUInterstitialView(configId: placementId, adFormats: [.video])
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
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitPath, request: request) { ad, error in
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
        guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: "47") else {
            print("Warning: Remote config '47' not available for createInterstitialMultiplatformView")
            return
        }
        let placementId = config.prebidConfig.placementId
        let gamAdUnitPath = config.gamConfig.adUnitPath

        let gamRequest = GAMRequest()

        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod(type: .AutoPlaySoundOff)]
        videoParameters.placement = AUPlacement.InBanner

        let interstitialVideoView = AUInterstitialView(configId: placementId,
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
            GAMInterstitialAd.load(withAdManagerAdUnitID: gamAdUnitPath, request: request) { ad, error in
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
    
    func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
        print("ExamplesViewController -- adDidRecordImpression")
    }
    
    func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
        print("ExamplesViewController -- adDidRecordClick")
    }
    
    func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("ExamplesViewController -- adWillPresentFullScreenContent")
    }
    
    func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("ExamplesViewController -- adWillDismissFullScreenContent")
    }
    
    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("ExamplesViewController -- adDidDismissFullScreenContent")
    }
}
