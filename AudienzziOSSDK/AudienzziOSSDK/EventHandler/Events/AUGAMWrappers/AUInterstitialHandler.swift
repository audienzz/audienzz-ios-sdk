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

import Foundation
import GoogleMobileAds

@objcMembers
public class AUInterstitialEventHandler: NSObject {
    let adUnit: GADInterstitialAd
    
    public init(adUnit: GADInterstitialAd) {
        self.adUnit = adUnit
    }
}

class AUInterstitialHandler: NSObject,
                             GADFullScreenContentDelegate,
                             GADAppEventDelegate {
    
    let handler: AUInterstitialEventHandler
    let adView: AUInterstitialView
    weak var fullScreentDelegate: GADFullScreenContentDelegate?
    
    init(handler: AUInterstitialEventHandler, adView: AUInterstitialView) {
        self.handler = handler
        self.fullScreentDelegate = handler.adUnit.fullScreenContentDelegate
        self.adView = adView
        super.init()
        addListener()
    }
    
    
    func addListener() {
        handler.adUnit.fullScreenContentDelegate = self
    }
    
    deinit {
        print("AUInterstitialHandler")
    }
    
    
    func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
        print("AUInterstitialHandler -- adDidRecordImpression")
        fullScreentDelegate?.adDidRecordImpression?(ad)
    }
    
    func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
        print("AUInterstitialHandler -- adDidRecordClick")
        fullScreentDelegate?.adDidRecordClick?(ad)
    }
    
    func ad(_ ad: any GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        print("AUInterstitialHandler -- didFailToPresentFullScreenContentWithError")
        fullScreentDelegate?.ad?(ad, didFailToPresentFullScreenContentWithError: error)
    }
    
    func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("AUInterstitialHandler -- adWillPresentFullScreenContent")
        fullScreentDelegate?.adWillPresentFullScreenContent?(ad)
    }
    
    func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("AUInterstitialHandler -- adWillDismissFullScreenContent")
        fullScreentDelegate?.adWillDismissFullScreenContent?(ad)
    }
    
    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("AUInterstitialHandler -- adDidDismissFullScreenContent")
        fullScreentDelegate?.adDidDismissFullScreenContent?(ad)
    }
}
