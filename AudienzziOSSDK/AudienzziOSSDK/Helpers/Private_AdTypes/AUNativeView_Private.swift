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

@objc
internal extension AUNativeView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        #if DEBUG
        AULogEvent.logDebug("AUNativeView --- I'm visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }
    
    override func fetchRequest(_ gamRequest: AnyObject) {
        switch adType {
        case .origin:
            nativeUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
                AULogEvent.logDebug("Audienz demand fetch for GAM \(resultCode.name())")
                guard let self = self else { return }
                self.onLoadRequest?(gamRequest)
            }
        case .rendering:
            nativeUnit.fetchDemand { [weak self] bidInfo in
                AULogEvent.logDebug("Audienz demand fetch for GAM \(bidInfo.resultCode.name())")
                guard let self = self else { return }
                self.onNativeLoadRequest?(gamRequest, bidInfo.targetingKeywords ?? [:])
            }
        case .none:
            break
        }
    }
    
    func findingNative(_ adObject: AnyObject) {
        if isLazyLoad, isLazyLoaded {
            Utils.shared.delegate = subdelegate
            Utils.shared.findNative(adObject: adObject)
        } else {
            Utils.shared.delegate = subdelegate
            Utils.shared.findNative(adObject: adObject)
        }
    }
}