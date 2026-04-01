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

import Foundation
import AppTrackingTransparency
import AdSupport

fileprivate let keyVisitorId = "keyVisitorId"

class AUEventsManager: AULogEventType {
    static let shared = AUEventsManager()
    private var impressionManager = AUScreenImpressionManager()

    private var visitorId: String = "visitorId"
    private var companyId: String = "companyId"
    private var sessionId: String = AUUniqHelper.makeUniqID()
    private var deviceId: String = ""

    // MARK: - Network
    private var networkManager: AUEventsNetworkManager<AUBatchResultModel>?

    func configure(companyId: String) {
        networkManager = AUEventsNetworkManager<AUBatchResultModel>()
        visitorId = makeVisitorId()
        self.companyId = companyId
    }

    func checkImpression(_ view: AUAdView, adUnitID: String?) {
        let (shouldAdd, screenName) = impressionManager.shouldAddEvent(of: view)
        AULogEvent.logDebug("isModelExist shouldAdd: \(shouldAdd)")

        if shouldAdd, let name = screenName {
            let event = AUPageImpressionEvent(
                adViewId: view.configId,
                adUnitID: adUnitID ?? view.configId,
                screenName: name
            )
            sendEvent(event)
        }
    }

    func sendEvent<T: AUEventHandlerType>(_ event: T) {
        guard let networkManager = networkManager else {
            AULogEvent.logDebug("EventsManager not configured — event dropped")
            return
        }
        requestDeviceId()
        var mutableEvent = event
        mutableEvent.visitorId = visitorId
        mutableEvent.companyId = companyId
        mutableEvent.sessionId = sessionId
        mutableEvent.deviceId = deviceId

        let encoded = mutableEvent.encode()
        networkManager.request(.submit(encoded)) { result in
            switch result {
            case .success:
                AULogEvent.logDebug("Event sent: \(mutableEvent.type.rawValue)")
            case .failure(let error):
                AULogEvent.logDebug("Event failed: \(error.localizedDescription)")
            }
        }
    }

    private func requestDeviceId() {
        if deviceId.isEmpty || deviceId == "00000000-0000-0000-0000-000000000000" {
            deviceId = ASIdentifierManager.shared().advertisingIdentifier.uuidString.lowercased()
        }
    }

    private func makeVisitorId() -> String {
        if let visId = UserDefaults.standard.string(forKey: keyVisitorId) {
            return visId
        } else {
            let visId: String = AUUniqHelper.makeUniqID()
            UserDefaults.standard.setValue(visId, forKey: keyVisitorId)
            UserDefaults.standard.synchronize()
            return visId
        }
    }
}
