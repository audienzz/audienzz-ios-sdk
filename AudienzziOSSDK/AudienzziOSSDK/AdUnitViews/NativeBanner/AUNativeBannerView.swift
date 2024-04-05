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

public class AUNativeBannerView: AUAdView {
    private var gamRequest: AnyObject?
    private var nativeUnit: NativeRequest!
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        print("AUBannerView --- I'm visible")
        onLoadRequest?(request)
        isLazyLoaded = true
    }
    
    public func createAd(with gamRequest: AnyObject, gamBanner: UIView, configuration: AUNativeRequestParameter) {
        let assetes = configuration.assets?.compactMap { $0 as? NativeAsset }
        nativeUnit = NativeRequest(configId: configId, assets: assetes)
        nativeUnit.context = configuration.context?.toContentType
        nativeUnit.placementType = configuration.placementType?.toPlacementType
        nativeUnit.contextSubType = configuration.contextSubType?.toContextSubType
        nativeUnit.eventtrackers = configuration.eventtrackers
        addSubview(gamBanner)

        nativeUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienz demand fetch for GAM \(resultCode.name())")
            guard let self = self else { return }
            self.gamRequest = gamRequest
            if !self.isLazyLoad {
                self.onLoadRequest?(gamRequest)
            }
        }
    }
}
