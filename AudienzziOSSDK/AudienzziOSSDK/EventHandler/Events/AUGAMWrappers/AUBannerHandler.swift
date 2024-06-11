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

import Foundation
import GoogleMobileAds

@objcMembers
public class AUBannerEventHandler: NSObject {
    let adUnitId: String
    let gamView: GAMBannerView
    
    public init(adUnitId: String, gamView: GAMBannerView) {
        self.adUnitId = adUnitId
        self.gamView = gamView
    }
}

class AUBannerHandler: NSObject,
                       GADBannerViewDelegate,
                       GADAppEventDelegate,
                       GADAdSizeDelegate {
    
    
    let auBannerView: AUBannerView
    let gamView: GAMBannerView!
    weak var bannerDelegate: GADBannerViewDelegate?
    weak var eventDelegate: GADAppEventDelegate?
    weak var sizeDelegate: GADAdSizeDelegate?

    init(auBannerView: AUBannerView, gamView: GAMBannerView) {
        self.auBannerView = auBannerView
        self.gamView = gamView
        self.bannerDelegate = gamView.delegate
        self.eventDelegate = gamView.appEventDelegate
        self.sizeDelegate = gamView.adSizeDelegate
        super.init()
        addListener()
    }
    
    
    func addListener() {
        self.gamView.delegate = self
        self.gamView.appEventDelegate = self
        self.gamView.adSizeDelegate = self
    }
    
    deinit {
        print("AUBannerHandler")
    }
    
    // MARK: - GADBannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("AUBannerHandler -- bannerViewDidReceiveAd")
        bannerDelegate?.bannerViewDidReceiveAd?(bannerView)
    }
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: any Error) {
        print("AUBannerHandler -- didFailToReceiveAdWithError")
        bannerDelegate?.bannerView?(bannerView, didFailToReceiveAdWithError: error)
    }
    
    /// Tells the delegate that an impression has been recorded for an ad.
    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        print("AUBannerHandler -- bannerViewDidRecordImpression")
        bannerDelegate?.bannerViewDidRecordImpression?(bannerView)
    }
    
    /// Tells the delegate that a click has been recorded for the ad.
    func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        print("AUBannerHandler -- bannerViewDidRecordClick")
        bannerDelegate?.bannerViewDidRecordClick?(bannerView)
    }
    
    // MARK: - Click-Time
    
    func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
        print("AUBannerHandler -- bannerViewWillPresentScreen")
        bannerDelegate?.bannerViewWillPresentScreen?(bannerView)
    }
    
    func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
        print("AUBannerHandler -- bannerViewWillDismissScreen")
        bannerDelegate?.bannerViewWillDismissScreen?(bannerView)
    }
    
    func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
        print("AUBannerHandler -- bannerViewDidDismissScreen")
        bannerDelegate?.bannerViewDidDismissScreen?(bannerView)
    }
    
    
    // MARK: - GADAppEventDelegate
    func adView(_ banner: GADBannerView, didReceiveAppEvent name: String, withInfo info: String?) {
        print("AUBannerHandler -- didReceiveAppEvent")
        eventDelegate?.adView?(banner, didReceiveAppEvent: name, withInfo: info)
    }
    
    // MARK: - GADAdSizeDelegate
    func adView(_ bannerView: GADBannerView, willChangeAdSizeTo size: GADAdSize) {
        print("AUBannerHandler -- willChangeAdSizeTo")
        sizeDelegate?.adView(bannerView, willChangeAdSizeTo: size)
    }
}
