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

@objc public enum AURenderingInsterstitialAdFormat: Int {
    case banner
    case video
}

/**
 * AUInterstitialRenderingView.
 * Ad a view that will display the particular ad. It should be added to the UI.
 * Lazy load is true by default.
*/
@objcMembers
public class AUInterstitialRenderingView: AUAdView {
    private var adUnit: InterstitialRenderingAdUnit!
    
    public weak var delegate: AUInterstitialenderingAdDelegate?
    
    internal var subdelegate: AUInterstitialRenderingDelegateType?
    
    @objc public var skipButtonArea: Double {
        get { adUnit.skipButtonArea }
        set { adUnit.skipButtonArea = newValue }
    }
    
    @objc public var skipButtonPosition: AUAdInterstitialPosition {
        get { AUAdInterstitialPosition(rawValue: adUnit.skipButtonPosition.rawValue) ?? .undefined }
        set { adUnit.skipButtonPosition = newValue.toAdPosition }
    }
    
    @objc public var skipDelay: Double {
        get { adUnit.skipDelay }
        set { adUnit.skipDelay = newValue }
    }
    
    override public init(configId: String, isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.subdelegate = AUInterstitialRenderingDelegateType(parent: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with eventHandler: AUGAMInterstitialEventHandler, adFormat: AURenderingInsterstitialAdFormat) {
        let interstitialEventHandler = GAMInterstitialEventHandler(adUnitID: eventHandler.adUnitID)
        
        adUnit = InterstitialRenderingAdUnit(configID: configId, eventHandler: interstitialEventHandler)
        
        switch adFormat {
        case .banner:
            adUnit.adFormats = [.banner]
        case .video:
            adUnit.adFormats = [.video]
        }
        
        adUnit.delegate = subdelegate
        
        if !isLazyLoad {
            delegate?.interstitialAdDidDisplayOnScreen?()
            adUnit.loadAd()
        }
    }
    
    /// It is expected from the user to call this method on main thread
    public func showAd(_ controller: UIViewController) {
        adUnit.show(from: controller)
    }
    
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
}

internal class AUInterstitialRenderingDelegateType: NSObject, InterstitialAdUnitDelegate {
    private weak var parent: AUInterstitialRenderingView?
    
    init(parent: AUInterstitialRenderingView) {
        super.init()
        self.parent = parent
    }
    
    public func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialDidReceiveAd?(with: interstitial.configID)
    }

    public func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error:Error? ) {
        parent?.delegate?.interstitialdidFailToReceiveAdWithError?(error: error)
    }

    public func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialWillPresentAd?()
    }

    public func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialDidDismissAd?()
    }

    public func interstitialWillLeaveApplication(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialWillLeaveApplication?()
    }

    public func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialDidClickAd?()
    }
}
