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

fileprivate let adTypeString = "REWARDED"
fileprivate let apiTypeString = "RENDERING"

@objcMembers
public class AUGAMRewardedAdEventHandler: NSObject {
    
    let adUnitID: String
    
    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }
}

/**
 * AUInstreamView.
 * Ad view for demand instream ad type.
 * Lazy load is true by default.
*/
@objcMembers
public class AURewardedRenderingView: AUAdView {
    private var rewardedAdUnit: RewardedAdUnit!
    public weak var delegate: AURewardedAdUnitDelegate?
    internal var subdelegate: AURewardedRenderingDelegateType?
    internal var eventHandler: AUGAMRewardedAdEventHandler?
    internal var minSizePerc: NSValue?
    
    /**
     Initialize rewarded view.
     Lazy load is true by default.
     */
    @objc required public init(configId: String,
                               isLazyLoad: Bool = true,
                               minSizePercentage: NSValue? = nil,
                               eventHandler: AUGAMRewardedAdEventHandler) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.subdelegate = AURewardedRenderingDelegateType(parent: self)
        self.eventHandler = eventHandler
        self.minSizePerc = minSizePercentage
        
        let rewardedEventHandler = GAMRewardedAdEventHandler(adUnitID: eventHandler.adUnitID)
        self.rewardedAdUnit = RewardedAdUnit(configID: configId, minSizePercentage: minSizePerc?.cgSizeValue ?? .zero, eventHandler: rewardedEventHandler)
        self.adUnitConfiguration = AURewardedRenderingConfiguration(adUnit: rewardedAdUnit)
        
        makeCreationEvent(eventHandler: eventHandler)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd() {
        rewardedAdUnit.delegate = subdelegate
        
        if !isLazyLoad {
            self.delegate?.rewardedAdDidDisplayOnScreen?()
            rewardedAdUnit.loadAd()
        }
    }
    
    /// It is expected from the user to call this method on main thread
    public func showAd(_ controller: UIViewController) {
        rewardedAdUnit.show(from: controller)
    }
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        self.delegate?.rewardedAdDidDisplayOnScreen?()
        rewardedAdUnit.loadAd()
        isLazyLoaded = true
        #if DEBUG
        AULogEvent.logDebug("AURewardedRenderingView --- I'm visible")
        #endif
    }
}

fileprivate extension AURewardedRenderingView {
    func makeCreationEvent(eventHandler: AUGAMRewardedAdEventHandler) {
        let event = AUAdCreationEvent(adViewId: configId,
                                      adUnitID: eventHandler.adUnitID,
                                      size: "\(adSize.width)x\(adSize.height)",
                                      adType: adTypeString,
                                      adSubType: "VIDEO",
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}
