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

import PrebidMobile
import UIKit

@objc
extension AUInstreamView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded else {
            return
        }

        fetchRequest()
        isLazyLoaded = true
        #if DEBUG
            AULogEvent.logDebug("[AUInstreamView] became visible")
        #endif
    }

    func fetchRequest() {
        adUnit.fetchDemand { [weak self] bidInfo in
            guard let self = self else { return }
            let resultCode = AUResultCode(rawValue: bidInfo.resultCode.rawValue)
            if resultCode == .audienzzDemandFetchSuccess {
                self.customKeywords = bidInfo.targetingKeywords
                self.onLoadInstreamRequest?(bidInfo.targetingKeywords)
            } else {
                // On no-bid/timeout/error still request the IMA/GAM tag so
                // GAM-direct and house demand can fill. Dropping the callback
                // here forfeits the entire instream impression opportunity.
                self.customKeywords = nil
                self.onLoadInstreamRequest?(nil)
            }
        }
    }
}
