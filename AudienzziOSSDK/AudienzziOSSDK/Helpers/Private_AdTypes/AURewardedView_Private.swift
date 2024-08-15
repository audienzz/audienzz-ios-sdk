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

fileprivate let adTypeString = "REWARDED"
fileprivate let apiTypeString = "ORIGINAL"

@objc
internal extension AURewardedView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }

        fetchRequest(request)
        isLazyLoaded = true
        #if DEBUG
        AULogEvent.logDebug("AURewardedView --- I'm visible")
        #endif
    }
    
    override func fetchRequest(_ gamRequest: AnyObject) {
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            AULogEvent.logDebug("Audienz demand fetch for GAM \(resultCode.name())")
            guard let self = self else { return }
            self.makeWinnerEvent(AUResulrCodeConverter.convertResultCodeName(resultCode))
            self.onLoadRequest?(gamRequest)
        }
    }
    
    private func makeRequestEvent() {
        guard let adUnitID = gadUnitID else { return }

        let event = AUBidRequestEvent(adViewId: configId,
                                      adUnitID: adUnitID,
                                      size: AUUniqHelper.sizeMaker(adSize),
                                      isAutorefresh: false,
                                      autorefreshTime: Int(0),
                                      initialRefresh: false,
                                      adType: adTypeString,
                                      adSubType: "VIDEO",
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeWinnerEvent(_ resultCode: String) {
        guard let adUnitID = gadUnitID else { return }
        
        let event = AUBidWinnerEvent(resultCode: resultCode,
                                     adUnitID: adUnitID,
                                     targetKeywords: [:],
                                     isAutorefresh: false,
                                     autorefreshTime: Int(0),
                                     initialRefresh: false,
                                     adViewId: configId,
                                     size: AUUniqHelper.sizeMaker(adSize),
                                     adType: adTypeString,
                                     adSubType: "VIDEO",
                                     apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    func makeCreationEvent() {
        let event = AUAdCreationEvent(adViewId: configId,
                                      adUnitID: eventHandler?.adUnitID ?? "",
                                      size: AUUniqHelper.sizeMaker(adSize),
                                      adType: adTypeString,
                                      adSubType: "VIDEO",
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}
