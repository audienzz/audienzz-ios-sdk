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
import PrebidMobile
import PrebidMobileGAMEventHandlers

@objcMembers
public class AUGAMInterstitialEventHandler: NSObject {
    let adUnitID: String
    
    // MARK: - Public Methods
    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }
}

public enum AURenderingInsterstitialAdFormat: Int {
    case banner
    case video
}

@objcMembers
public class AUInterstitialRenderingView: AUAdView {
    private var adUnit: InterstitialRenderingAdUnit!
    
    public weak var delegate: AUInterstitialenderingAdDelegate?
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        delegate?.interstitialAdDidDisplayOnScreen?()
        adUnit.loadAd()
        isLazyLoaded = true
        #if DEBUG
        print("AUInterstitialRenderingView --- I'm visible")
        #endif
    }
    
    public func createAd(with eventHandler: AUGAMInterstitialEventHandler, adFormat: AURenderingInsterstitialAdFormat) {
        let interstitialEventHandler = GAMInterstitialEventHandler(adUnitID: eventHandler.adUnitID)
        
        adUnit = InterstitialRenderingAdUnit(configID: configId, eventHandler: interstitialEventHandler)
        
        switch adFormat {
        case .banner:
            adUnit.adFormats = [.banner]
        case .video:
            adUnit.adFormats = [.video]
        }
        
        adUnit.delegate = self
        
        if !isLazyLoad {
            delegate?.interstitialAdDidDisplayOnScreen?()
            adUnit.loadAd()
        }
    }
    
    public func showAd(_ controller: UIViewController) {
        adUnit.show(from: controller)
    }
}

extension AUInterstitialRenderingView: InterstitialAdUnitDelegate {
    public func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        delegate?.interstitialDidReceiveAd?(with: interstitial.configID)
    }

    public func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error:Error? ) {
        delegate?.interstitialdidFailToReceiveAdWithError?(error: error)
    }

    public func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        delegate?.interstitialWillPresentAd?()
    }

    public func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        delegate?.interstitialDidDismissAd?()
    }

    public func interstitialWillLeaveApplication(_ interstitial: InterstitialRenderingAdUnit) {
        delegate?.interstitialWillLeaveApplication?()
    }

    public func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        delegate?.interstitialDidClickAd?()
    }
}