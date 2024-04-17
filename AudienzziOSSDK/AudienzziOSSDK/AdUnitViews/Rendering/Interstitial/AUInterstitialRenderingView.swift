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

public enum RenderingInsterstitialAdFormat: Int {
    case banner
    case video
}

public class AUInterstitialRenderingView: AUAdView {
    private var renderingInterstitial: InterstitialRenderingAdUnit!
    
    public weak var delegate: AUInterstitialenderingAdDelegate?
    
    public func createAd(with eventHandler: AUGAMInterstitialEventHandler, adFormat: RenderingInsterstitialAdFormat) {
        let interstitialEventHandler = GAMInterstitialEventHandler(adUnitID: eventHandler.adUnitID)
        
        renderingInterstitial = InterstitialRenderingAdUnit(configID: configId, eventHandler: interstitialEventHandler)
        
        switch adFormat {
        case .banner:
            renderingInterstitial.adFormats = [.banner]
        case .video:
            renderingInterstitial.adFormats = [.video]
        }
        
        renderingInterstitial.delegate = self
        
        renderingInterstitial.loadAd()
    }
    
    public func showAd(_ controller: UIViewController) {
        renderingInterstitial.show(from: controller)
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
