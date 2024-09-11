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
                       GADAdSizeDelegate,
                       AULogEventType {
    
    
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
    
    var adUnitID: String? {
        self.gamView.adUnitID
    }
    
    private func addListener() {
        self.gamView.delegate = self
        self.gamView.appEventDelegate = self
        self.gamView.adSizeDelegate = self
    }
    
    deinit {
        AULogEvent.logDebug("AUBannerHandler")
    }
    
    // MARK: - GADBannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        LogEvent("bannerViewDidReceiveAd")
        bannerDelegate?.bannerViewDidReceiveAd?(bannerView)
    }
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: any Error) {
        LogEvent("didFailToReceiveAdWithError")
        
        let event = AUFailedLoadEvent(adViewId: auBannerView.configId,
                                      adUnitID: adUnitID ?? "",
                                      errorMessage: error.localizedDescription,
                                      errorCode: error.errorCode ?? -1)
        
        guard let payload = event.convertToJSONString() else {
            bannerDelegate?.bannerView?(bannerView, didFailToReceiveAdWithError: error)
            return
        }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
        bannerDelegate?.bannerView?(bannerView, didFailToReceiveAdWithError: error)
    }
    
    /// Tells the delegate that an impression has been recorded for an ad.
    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        LogEvent("bannerViewDidRecordImpression")
        bannerDelegate?.bannerViewDidRecordImpression?(bannerView)
    }
    
    /// Tells the delegate that a click has been recorded for the ad.
    func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        LogEvent("bannerViewDidRecordClick")
        
        let event = AUAdClickEvent(adViewId: auBannerView.configId, adUnitID: adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else {
            bannerDelegate?.bannerViewDidRecordClick?(bannerView)
            return
        }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
        
        bannerDelegate?.bannerViewDidRecordClick?(bannerView)
    }
    
    // MARK: - Click-Time
    
    func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
        LogEvent("bannerViewWillPresentScreen")
        bannerDelegate?.bannerViewWillPresentScreen?(bannerView)
    }
    
    func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
        LogEvent("bannerViewWillDismissScreen")
        bannerDelegate?.bannerViewWillDismissScreen?(bannerView)
    }
    
    func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
        LogEvent("bannerViewDidDismissScreen")
        bannerDelegate?.bannerViewDidDismissScreen?(bannerView)
    }
    
    
    // MARK: - GADAppEventDelegate
    func adView(_ banner: GADBannerView, didReceiveAppEvent name: String, withInfo info: String?) {
        LogEvent("didReceiveAppEvent")
        eventDelegate?.adView?(banner, didReceiveAppEvent: name, withInfo: info)
    }
    
    // MARK: - GADAdSizeDelegate
    func adView(_ bannerView: GADBannerView, willChangeAdSizeTo size: GADAdSize) {
        LogEvent("willChangeAdSizeTo")
        sizeDelegate?.adView(bannerView, willChangeAdSizeTo: size)
    }
}
