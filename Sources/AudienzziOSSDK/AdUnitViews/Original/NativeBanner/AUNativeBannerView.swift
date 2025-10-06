/*   Copyright 2018-2025 Audienzz.org, Inc.
 
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
import GoogleMobileAds

/**
 * AUNativeBannerView.
 * Ad view for demand native banner.
 * Lazy load is true by default.
*/
@objcMembers
public class AUNativeBannerView: AUAdView {
    internal var gamRequest: AdManagerRequest?
    internal var nativeUnit: NativeRequest!
    
    /**
     Initialize native banner view.
     Lazy load is true by default.
     */
    public init(configId: String, configuration: AUNativeRequestParameter) {
        super.init(configId: configId, isLazyLoad: true)
        let assetes = configuration.assets?.compactMap { $0.unwrap() }
        nativeUnit = NativeRequest(configId: configId, assets: assetes)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: nativeUnit)
    }
    
    /**
     Initialize native banner view.
     Lazy load is true by default.
     */
    public init(configId: String, configuration: AUNativeRequestParameter, isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        let assetes = configuration.assets?.compactMap { $0.unwrap() }
        nativeUnit = NativeRequest(configId: configId, assets: assetes)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: nativeUnit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AdManagerRequest, gamBanner: UIView, configuration: AUNativeRequestParameter) {
        nativeUnit.context = configuration.context?.toContentType
        nativeUnit.placementType = configuration.placementType?.toPlacementType
        nativeUnit.contextSubType = configuration.contextSubType?.toContextSubType
        nativeUnit.eventtrackers = configuration.eventtrackers?.compactMap { $0.unwrap() }
        
        if let placementCount = configuration.placementCount {
            nativeUnit.placementCount = placementCount
        }
        if let sequence = configuration.sequence {
            nativeUnit.sequence = sequence
        }
        if let asseturlsupport = configuration.asseturlsupport {
            nativeUnit.asseturlsupport = asseturlsupport
        }
        if let durlsupport = configuration.durlsupport {
            nativeUnit.durlsupport = durlsupport
        }
        if let privacy = configuration.privacy {
            nativeUnit.privacy = privacy
        }

        nativeUnit.ext = configuration.ext
        
        addSubview(gamBanner)
        
        let ppid = PPIDManager.shared.getPPID()
        
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }
        
        self.gamRequest = AUTargeting.shared.customTargetingManager.applyToGamRequest(request: gamRequest)
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
}
