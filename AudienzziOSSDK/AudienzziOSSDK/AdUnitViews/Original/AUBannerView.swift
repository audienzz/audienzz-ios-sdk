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

/**
 AUBannerView.
 Ad view for demand  banner and/or video.
 Lazy load is true by default.
*/
@objcMembers
public class AUBannerView: AUAdView {
    internal var adUnit: BannerAdUnit!
    internal var gamRequest: AnyObject?
    private var eventHandler: AUBannerHandler!

    public var parameters: AUVideoParameters?
    public var bannerParameters: AUBannerParameters?
    
    /**
     Initialize banner view
     Lazy load is true by default.
     */
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat]) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: true)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    /**
     Initialize banner view
     Lazy load is optional to set if needed.
     */
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat], isLazyLoad: Bool) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: isLazyLoad)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("AUBannerView")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AnyObject, gamBanner: UIView, eventHandler: AUBannerEventHandler? = nil) {
        AUEventsManager.shared.checkImpression(self)
        if let parameters = bannerParameters {
            adUnit.bannerParameters = parameters.makeBannerParameters()
        } else {
            let parameters = BannerParameters()
            parameters.api = [Signals.Api.MRAID_2]
            adUnit.bannerParameters = parameters
        }
        addSubview(gamBanner)
        
        adUnit.videoParameters = self.parameters?.unwrap() ?? defaultVideoParameters()

        self.gamRequest = gamRequest
        
        if let bannerEventHandler = eventHandler {
            self.eventHandler = AUBannerHandler(auBannerView: self, gamView: bannerEventHandler.gamView)
        }
        
        let model = AUAdClickEvent(adViewId: "adViewId", adUnitID: "adUnitID")
        if let jsonString = model.convertToJSONString() {
            Audienzz.shared.addEvent(JSONString: jsonString)
            Audienzz.shared.addEvent(JSONString: jsonString)
            Audienzz.shared.addEvent(JSONString: jsonString)
        }

        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
}
