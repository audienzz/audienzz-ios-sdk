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

fileprivate let storedImpVideoInterstitial = "prebid-demo-video-interstitial-320-480"
fileprivate let gamAdUnitVideoInterstitialRendering = "/21808260008/prebid_oxb_interstitial_video"

fileprivate var interstitialRenderingView: AUInterstitialRenderingView!

extension ExamplesViewController {
    func createRenderingIntertitiaView() {
        let eventHandler = AUGAMInterstitialEventHandler(adUnitID: gamAdUnitVideoInterstitialRendering)
        
        interstitialRenderingView = AUInterstitialRenderingView(configId: storedImpVideoInterstitial, isLazyLoad: true)
        interstitialRenderingView.delegate = self
        interstitialRenderingView.frame = CGRect(x: 0, y: getPositionY(adContainerView), width: 320, height: 50)
        
        interstitialRenderingView.createAd(with: eventHandler, adFormat: .video)
        
        adContainerView.addSubview(interstitialRenderingView)
    }
}

extension ExamplesViewController: AUInterstitialenderingAdDelegate {
    
    func interstitialDidReceiveAd(with configId: String) {
        interstitialRenderingView.showAd(self)
    }
    
    func interstitialdidFailToReceiveAdWithError( error:Error? ) {
        print("Banner view did fail to receive ad with error: \(error)")
    }
    
    func interstitialWillPresentAd() {}

    /// Called when the interstitial is dismissed by the user
    func interstitialDidDismissAd() {}

    /// Called when an ad causes the sdk to leave the app
    func interstitialWillLeaveApplication() {}

    /// Called when user clicked the ad
    func interstitialDidClickAd() {}
}
