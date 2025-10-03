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
 AUInterstitialView.
 Ad view for demand Interstitial and/or video.
 Lazy load is true by default.
*/
@objcMembers
public class AUInterstitialView: AUAdView {
    internal var adUnit: InterstitialAdUnit!
    internal var gamRequest: AnyObject?
    internal var eventHandler: AUInterstitialHandler?
    internal var gadUnitID: String?
    
    public var videoParameters: AUVideoParameters?
    public var bannerParameters = AUBannerParameters()
    
    /**
     Initialize Interstitial view
     Lazy load is true by default.
     */
    public init(configId: String, adFormats: [AUAdFormat]) {
        super.init(configId: configId, isLazyLoad: true)
        adUnit = InterstitialAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    /**
     Initialize Interstitial view
     Lazy load is true by default.
     */
    public init(configId: String, adFormats: [AUAdFormat], isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.adUnit = InterstitialAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    /**
     Initialize Interstitial view. Convenience variant
     Lazy load is true by default.
     */
    public convenience init(configId: String, adFormats: [AUAdFormat], isLazyLoad: Bool, minWidthPerc: Int, minHeightPerc: Int) {
        self.init(configId: configId, adFormats: adFormats, isLazyLoad: isLazyLoad)
        self.adUnit = InterstitialAdUnit(configId: configId, minWidthPerc: minWidthPerc, minHeightPerc: minHeightPerc)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func removeFromSuperview() {
        super.removeFromSuperview()
        adUnit?.stopAutoRefresh()
        adUnit = nil
        self.eventHandler = nil
    }
    
    deinit {
        self.eventHandler = nil
    }
    
    public func setImpOrtbConfig(ortbConfig: String){
        adUnit.setImpORTBConfig(ortbConfig)
    }
    
    public func getImpOrtbConfig() -> String? {
        return adUnit.getImpORTBConfig()
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AdManagerRequest, adUnitID: String) {
        adUnit.bannerParameters = bannerParameters.makeBannerParameters()
        
        adUnit.videoParameters = self.videoParameters?.unwrap() ?? defaultVideoParameters()
        
        AUEventsManager.shared.checkImpression(self, adUnitID: adUnitID)
        self.gadUnitID = adUnitID
        
        let ppid = PPIDManager.shared.getPPID()
        
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }
        
        self.gamRequest = AUTargeting.shared.customTargetingManager.applyToGamRequest(request: gamRequest)
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
    
    public func connectHandler(_ eventHandler: AUInterstitialEventHandler) {
        self.eventHandler = AUInterstitialHandler(handler: eventHandler, adView: self)
        makeCreationEvent()
    }
    
 }
