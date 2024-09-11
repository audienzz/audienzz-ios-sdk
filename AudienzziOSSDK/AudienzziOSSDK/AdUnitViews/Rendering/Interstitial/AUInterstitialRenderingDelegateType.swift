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
import PrebidMobile

internal class AUInterstitialRenderingDelegateType: NSObject, InterstitialAdUnitDelegate {
    private weak var parent: AUInterstitialRenderingView?
    
    init(parent: AUInterstitialRenderingView) {
        super.init()
        self.parent = parent
    }
    
    public func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialDidReceiveAd?(with: interstitial.configID)
    }

    public func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        guard let parent = parent else { return }
        makeErrorEvent(parent: parent, error)
        parent.delegate?.interstitialDidFailToReceiveAdWithError?(error: error)
    }

    public func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialWillPresentAd?()
    }

    public func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        guard let parent = parent else { return }
        makeCloseEvent(parent)
        parent.delegate?.interstitialDidDismissAd?()
    }

    public func interstitialWillLeaveApplication(_ interstitial: InterstitialRenderingAdUnit) {
        parent?.delegate?.interstitialWillLeaveApplication?()
    }

    public func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        guard let parent = parent else { return }
        makeClickEvent(parent)
        parent.delegate?.interstitialDidClickAd?()
    }
    
    private func makeCloseEvent(_ parent: AUInterstitialRenderingView) {
        let event = AUCloseAdEvent(adViewId: parent.configId, adUnitID: parent.eventHandler?.adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeClickEvent(_ parent: AUInterstitialRenderingView) {
        let event = AUAdClickEvent(adViewId: parent.configId, adUnitID: parent.eventHandler?.adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeErrorEvent(parent: AUInterstitialRenderingView, _ error: Error?) {
        guard let error = error else { return }
        let event = AUFailedLoadEvent(adViewId: parent.configId,
                                      adUnitID: parent.eventHandler?.adUnitID ?? "",
                                      errorMessage: error.localizedDescription,
                                      errorCode: error.errorCode ?? -1)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}
