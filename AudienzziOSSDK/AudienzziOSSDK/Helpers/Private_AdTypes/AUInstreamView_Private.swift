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
internal extension AUInstreamView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        fetchRequest()
        isLazyLoaded = true
        #if DEBUG
        AULogEvent.logDebug("AUInstreamView --- I'm visible")
        #endif
    }
    
    func fetchRequest() {
        adUnit.fetchDemand { [weak self] bidInfo in
            guard let self = self, let resultCode = AUResultCode(rawValue: bidInfo.resultCode.rawValue) else { return }
            if resultCode == .audienzzDemandFetchSuccess {
                self.customKeywords = bidInfo.targetingKeywords
                self.onLoadInstreamRequest?(bidInfo.targetingKeywords)
            }
        }
    }
}
