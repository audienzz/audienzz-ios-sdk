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

fileprivate let adTypeString = "BANNER"
fileprivate let apiTypeString = "ORIGINAL"

@objc
extension AUBannerView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest else {
            return
        }
        
        #if DEBUG
        AULogEvent.logDebug("AUBannerView --- I'm visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }
    
    override func fetchRequest(_ gamRequest: AnyObject) {
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            AULogEvent.logDebug("Audienz demand fetch for GAM \(resultCode.name())")
            self.makeWinnerEvent(resultCode.name())
            self.isInitialAutorefresh = false
            self.onLoadRequest?(gamRequest)
        }
    }
    
    private func isVisible(view: UIView) -> Bool {
        func isVisible(view: UIView, inView: UIView?) -> Bool {
            guard let inView = inView else { return true }
            let viewFrame = inView.convert(view.bounds, from: view)
            if viewFrame.intersects(inView.bounds) {
                return isVisible(view: view, inView: inView.superview)
            }
            return false
        }
        return isVisible(view: view, inView: view.superview)
    }
    
    private func makeRequestEvent() {
        guard let autorefreshM = adUnitConfiguration as? AUAdUnitConfigurationEventProtocol,
              let adUnitID = eventHandler?.adUnitID else { return }
        
        let event = AUBidRequestEvent(adViewId: configId,
                                      adUnitID: adUnitID,
                                      size: "\(adSize.width)x\(adSize.height)",
                                      isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
                                      autorefreshTime: Int(autorefreshM.autorefreshEventModel.autorefreshTime),
                                      initialRefresh: isInitialAutorefresh,
                                      adType: adTypeString,
                                      adSubType: makeAdSubType(),
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeWinnerEvent(_ resultCode: String) {
        guard let autorefreshM = adUnitConfiguration as? AUAdUnitConfigurationEventProtocol,
              let adUnitID = eventHandler?.adUnitID else { return }
        
        let event = AUBidWinnerEven(resultCode: resultCode,
                                    adUnitID: adUnitID,
                                    targetKeywords: [:],
                                    isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
                                    autorefreshTime: Int(autorefreshM.autorefreshEventModel.autorefreshTime),
                                    initialRefresh: isInitialAutorefresh,
                                    adViewId: configId,
                                    size: "\(adSize.width)x\(adSize.height)",
                                    adType: adTypeString,
                                    adSubType: makeAdSubType(),
                                    apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeAdSubType() -> String {
        if adUnit.adFormats.contains([.banner, .video]) {
            return "MULTIFORMAT"
        } else if adUnit.adFormats.contains([.banner]) && adUnit.adFormats.count == 1 {
            return "HTML"
        } else if adUnit.adFormats.contains([.video]) && adUnit.adFormats.count == 1 {
            return "VIDEO"
        }
        
        return ""
    }
    
    internal func makeCreationEvent() {
        let event = AUAdCreationEvent(adViewId: configId,
                                      adUnitID: eventHandler?.adUnitID ?? "",
                                      size: "\(adSize.width)x\(adSize.height)",
                                      adType: adTypeString,
                                      adSubType: makeAdSubType(),
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}
