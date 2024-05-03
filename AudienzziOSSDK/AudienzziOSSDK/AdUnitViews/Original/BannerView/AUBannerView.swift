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
public class AUBannerView: AUAdView {
    private var adUnit: BannerAdUnit!
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
    public var bannerParameters: AUBannerParameters?
    
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat]) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: true)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    public init(configId: String, adSize: CGSize, adFormats: [AUAdFormat], isLazyLoad: Bool) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: isLazyLoad)
        self.adUnit = BannerAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        
        self.adUnit.adFormats = Set(unwrapAdFormat(adFormats))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func createAd(with gamRequest: AnyObject, gamBanner: UIView) {
        if let parameters = bannerParameters {
            adUnit.bannerParameters = parameters.makeBannerParameters()
        } else {
            let parameters = BannerParameters()
            parameters.api = [Signals.Api.MRAID_2]
            adUnit.bannerParameters = parameters
        }
        addSubview(gamBanner)
        
        let videoParameters = fillVideoParams(self.parameters)
        adUnit.videoParameters = videoParameters

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
        print("AUBannerMultiplatformView --- I'm visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }
    
    internal override func fetchRequest(_ gamRequest: AnyObject) {
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienz demand fetch for GAM \(resultCode.name())")
            guard let self = self else { return }
            self.onLoadRequest?(gamRequest)
        }
    }
}
