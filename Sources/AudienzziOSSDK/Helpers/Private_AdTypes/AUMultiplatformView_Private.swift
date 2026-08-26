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
extension AUMultiplatformView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest else {
            return
        }

        #if DEBUG
            AULogEvent.logDebug("[AUMultiplatformView] became visible")
        #endif
        fetchRequest(request, prebidRequest: prebidRequest)
        isLazyLoaded = true
    }

    func fetchRequest(_ gamRequest: AnyObject, prebidRequest: PrebidRequest) {
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest, request: prebidRequest) {
            [weak self] info in
            guard let self = self else { return }
            self.makeWinnerEvent(
                AUResulrCodeConverter.convertResultCodeName(info.resultCode)
            )
            self.onLoadRequest?(gamRequest)
        }
    }

    func findingNative(adObject: AnyObject) {
        if isLazyLoad, isLazyLoaded {
            Utils.shared.delegate = subdelegate
            Utils.shared.findNative(adObject: adObject)
        } else {
            Utils.shared.delegate = subdelegate
            Utils.shared.findNative(adObject: adObject)
        }
    }

    private func makeAdSubType() -> String {
        return "MULTIFORMAT"
    }

    // Multiformat (multiplatform) is out of scope for the new analytics — event firing removed.
    func makeCreationEvent() {}

    private func makeRequestEvent() {}

    private func makeWinnerEvent(_ resultCode: String) {}
}
