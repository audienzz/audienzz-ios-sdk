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
public class AURewardedEventHandler: NSObject {
    let adUnit: GADRewardedAd
    
    public init(adUnit: GADRewardedAd) {
        self.adUnit = adUnit
    }
}

class AURewardedHandler: NSObject,
                             GADFullScreenContentDelegate,
                             GADAppEventDelegate {

    let handler: AURewardedEventHandler
    let adView: AURewardedView
    weak var fullScreentDelegate: GADFullScreenContentDelegate?
    
    init(handler: AURewardedEventHandler, adView: AURewardedView) {
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
        print("AURewardedHandler")
    }
    
    
    func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
        print("AURewardedHandler -- adDidRecordImpression")
        fullScreentDelegate?.adDidRecordImpression?(ad)
    }
    
    func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
        print("AURewardedHandler -- adDidRecordClick")
        fullScreentDelegate?.adDidRecordClick?(ad)
    }
    
    func ad(_ ad: any GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        print("AURewardedHandler -- didFailToPresentFullScreenContentWithError")
        fullScreentDelegate?.ad?(ad, didFailToPresentFullScreenContentWithError: error)
    }
    
    func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("AURewardedHandler -- adWillPresentFullScreenContent")
        fullScreentDelegate?.adWillPresentFullScreenContent?(ad)
    }
    
    func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("AURewardedHandler -- adWillDismissFullScreenContent")
        fullScreentDelegate?.adWillDismissFullScreenContent?(ad)
    }
    
    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        print("AURewardedHandler -- adDidDismissFullScreenContent")
        fullScreentDelegate?.adDidDismissFullScreenContent?(ad)
    }
}
