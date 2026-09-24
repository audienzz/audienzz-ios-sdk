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
import GoogleMobileAds
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
        guard let generation = configuredDemandRefresh?.begin({ [weak self] in self?.fetchRequest(gamRequest, prebidRequest: prebidRequest) }) else { return }
        makeRequestEvent()
        let publisherRequest = gamRequest
        let gamRequest: AnyObject = (publisherRequest as? AdManagerRequest)
            .map { AUAuctionTargeting.request(from: $0) } ?? publisherRequest
        let prebidGuard = (gamRequest as? AdManagerRequest).map { AUAuctionTargeting.PrebidGuard($0) }
        adUnit.fetchDemand(adObject: gamRequest, request: prebidRequest) {
            [weak self] info in
            guard let self = self, self.configuredDemandRefresh?.finish(generation) == true else { return }
            // Prebid removed every `hb_` key before it bid, the publisher's too.
            if let request = gamRequest as? AdManagerRequest { prebidGuard?.restore(into: request) }
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
