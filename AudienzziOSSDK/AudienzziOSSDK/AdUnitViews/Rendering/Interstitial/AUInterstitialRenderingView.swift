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

fileprivate let adTypeString = "INTERSTITIAL"
fileprivate let apiTypeString = "RENDERING"

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
    internal var eventHandler: AUGAMInterstitialEventHandler?
    internal var adFormat: AURenderingInsterstitialAdFormat!
    internal var minSizePerc: CGSize?
    
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
    
    @objc required public init(configId: String,
                               isLazyLoad: Bool = true,
                               adFormat: AURenderingInsterstitialAdFormat,
                               minSizePercentage: NSValue? = nil,
                               eventHandler: AUGAMInterstitialEventHandler) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.subdelegate = AUInterstitialRenderingDelegateType(parent: self)
        self.eventHandler = eventHandler
        self.adFormat = adFormat
        self.minSizePerc = minSizePercentage?.cgSizeValue
        
        let interstitialEventHandler = GAMInterstitialEventHandler(adUnitID: eventHandler.adUnitID)
        
        self.adUnit = InterstitialRenderingAdUnit(configID: configId,
                                                  minSizePercentage: minSizePerc ?? .zero,
                                                  eventHandler: interstitialEventHandler)
        
        makeCreationEvent(adFormat, eventHandler: eventHandler)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd() {
        
        switch adFormat {
        case .banner:
            adUnit.adFormats = [.banner]
        case .video:
            adUnit.adFormats = [.video]
        case .none:
            break
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

fileprivate extension AUInterstitialRenderingView {
    func makeCreationEvent(_ format: AURenderingInsterstitialAdFormat, eventHandler: AUGAMInterstitialEventHandler) {
        let event = AUAdCreationEvent(adViewId: configId,
                                      adUnitID: eventHandler.adUnitID,
                                      size: "\(adSize.width)x\(adSize.height)",
                                      adType: adTypeString,
                                      adSubType: format == .banner ? "HTML" : "VIDEO",
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}
