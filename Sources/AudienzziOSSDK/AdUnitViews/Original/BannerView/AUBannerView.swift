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
 AUBannerView.
 Ad view for demand  banner and/or video.
 Lazy load is true by default.
 */
@objcMembers
public class AUBannerView: AUAdView {
    internal var adUnit: BannerAdUnit!
    internal var gamRequest: AnyObject?
    internal var eventHandler: AUBannerHandler?

    public var videoParameters: AUVideoParameters?
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

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        adUnit?.stopAutoRefresh()
        self.adUnit = nil
        self.gamRequest = nil
        self.eventHandler = nil
    }
    
    public func addAdditionalSize(sizes: [CGSize]) {
        adUnit.addAdditionalSize(sizes: sizes)
    }
    
    public func setImpOrtbConfig(ortbConfig: String){
        adUnit.setImpORTBConfig(ortbConfig)
    }
    
    public func getImpOrtbConfig() -> String? {
        return adUnit.getImpORTBConfig()
    }

    deinit {
        self.eventHandler = nil
    }

    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AdManagerRequest, gamBanner: UIView, eventHandler: AUBannerEventHandler? = nil) {
        if let parameters = bannerParameters {
            adUnit.bannerParameters = parameters.makeBannerParameters()
        } else {
            let parameters = BannerParameters()
            parameters.api = [Signals.Api.MRAID_2, Signals.Api.MRAID_3, Signals.Api.OMID_1]
            adUnit.bannerParameters = parameters
        }
        addSubview(gamBanner)

        adUnit.videoParameters = self.videoParameters?.unwrap() ?? defaultVideoParameters()
        
        let ppid = PPIDManager.shared.getPPID()
        
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }

        self.gamRequest = AUTargeting.shared.customTargetingManager.applyToGamRequest(request: gamRequest)

        if let bannerEventHandler = eventHandler {
            self.eventHandler = AUBannerHandler(auBannerView: self, gamView: bannerEventHandler.gamView)
        }

        AUEventsManager.shared.checkImpression(self, adUnitID: self.eventHandler?.adUnitID)

        makeCreationEvent()

        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
}
