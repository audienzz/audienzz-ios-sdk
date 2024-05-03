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
public class AUInterstitialView: AUAdView {
    private var adUnit: InterstitialAdUnit!
    private var gamRequest: AnyObject?
    
    /**
     VideoParameters..
     If will be nill. Automatically create default video parameters
     
     # Example #
     *   AUVideoParameters(mimes: ["video/mp4"])
     * protocols = [AdVideoParameters.Protocols.VAST_2_0]
     * playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
     * placement = AdVideoParameters.Placement.InBanner
     */
    public var parameters: AUVideoParameters?
    
    public init(configId: String, adFormats: [AUAdFormat]) {
        super.init(configId: configId, isLazyLoad: true)
        adUnit = InterstitialAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    public init(configId: String, adFormats: [AUAdFormat], isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.adUnit = InterstitialAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    public convenience init(configId: String, adFormats: [AUAdFormat], isLazyLoad: Bool, minWidthPerc: Int, minHeightPerc: Int) {
        self.init(configId: configId, adFormats: adFormats, isLazyLoad: isLazyLoad)
        self.adUnit = InterstitialAdUnit(configId: configId, minWidthPerc: minWidthPerc, minHeightPerc: minHeightPerc)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func createAd(with gamRequest: AnyObject) {
        

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
        print("AUInterstitialView --- I'm visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }
    
    internal override func fetchRequest(_ gamRequest: AnyObject) {
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienzz demand fetch for GAM \(resultCode.name())")
            guard let self = self else { return }
            self.onLoadRequest?(gamRequest)
        }
    }
}
