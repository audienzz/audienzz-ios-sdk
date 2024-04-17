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

@objcMembers
public class AUGAMBannerEventHandler: NSObject {
    var validGADAdSizes: [NSValue]
    let adUnitID: String
    
    public init(adUnitID: String, validGADAdSizes: [NSValue]) {
        self.validGADAdSizes = validGADAdSizes
        self.adUnitID = adUnitID
    }
}

public class AUBannerRenderingView: AUAdView {
    private var prebidBannerView: BannerView!
    
    @objc public weak var delegate: AUBannerRenderingAdDelegate?
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        prebidBannerView.loadAd()
        isLazyLoaded = true
        #if DEBUG
        print("AUBannerRenderingView --- I'm visible")
        #endif
    }
    
    public func createAd(with eventHandler: AUGAMBannerEventHandler) {
        let bannerEventHandler = GAMBannerEventHandler(adUnitID: eventHandler.adUnitID,
                                                       validGADAdSizes: eventHandler.validGADAdSizes)
        
        prebidBannerView = BannerView(frame: CGRect(origin: .zero, size: adSize),
                                      configID: configId,
                                      adSize: adSize,
                                      eventHandler: bannerEventHandler)
        prebidBannerView.delegate = self
        
        self.addSubview(prebidBannerView)
        
        if !isLazyLoad {
            prebidBannerView.loadAd()
        }
    }
    
    public func createVideoAd(with eventHandler: AnyObject) {
        guard let bannerEventHandler = eventHandler as? BannerEventHandler else { return }

        prebidBannerView = BannerView(frame: CGRect(origin: .zero, size: adSize),
                                      configID: configId,
                                      adSize: adSize,
                                      eventHandler: bannerEventHandler)

        prebidBannerView.adFormat = .video
        prebidBannerView.videoParameters.placement = .InBanner
        prebidBannerView.delegate = self
        
        self.backgroundColor = .clear
        self.addSubview(prebidBannerView)
        
        if !isLazyLoad {
            prebidBannerView.loadAd()
        }
    }
}

extension AUBannerRenderingView: BannerViewDelegate {
    public func bannerViewPresentationController() -> UIViewController? {
        delegate?.bannerViewPresentationController()
    }
    
    public func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        delegate?.bannerView?(self, didReceiveAdWithAdSize: adSize)
    }

    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        delegate?.bannerView?(self, didFailToReceiveAdWith: error)
    }

    public func bannerViewWillLeaveApplication(_ bannerView: BannerView) {
        delegate?.bannerViewWillLeaveApplication?(self)
    }

    public func bannerViewWillPresentModal(_ bannerView: BannerView) {
        delegate?.bannerViewWillPresentModal?(self)
    }

    public func bannerViewDidDismissModal(_ bannerView: BannerView) {
        delegate?.bannerViewDidDismissModal?(self)
    }
}
