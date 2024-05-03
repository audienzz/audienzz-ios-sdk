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

@objcMembers
public class AUNativeBannerView: AUAdView {
    private var gamRequest: AnyObject?
    private var nativeUnit: NativeRequest!
    
    public init(configId: String, configuration: AUNativeRequestParameter) {
        super.init(configId: configId, isLazyLoad: true)
        let assetes = configuration.assets?.compactMap { $0.unwrap() }
        nativeUnit = NativeRequest(configId: configId, assets: assetes)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: nativeUnit)
    }
    
    public init(configId: String, configuration: AUNativeRequestParameter, isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        let assetes = configuration.assets?.compactMap { $0.unwrap() }
        nativeUnit = NativeRequest(configId: configId, assets: assetes)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: nativeUnit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func createAd(with gamRequest: AnyObject, gamBanner: UIView, configuration: AUNativeRequestParameter) {
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
        
        self.gamRequest = gamRequest
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        #if DEBUG
        print("AUNativeBannerView --- I'm visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }
    
    internal override func fetchRequest(_ gamRequest: AnyObject) {
        nativeUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienz demand fetch for GAM \(resultCode.name())")
            guard let self = self else { return }
            self.onLoadRequest?(gamRequest)
        }
    }
}
