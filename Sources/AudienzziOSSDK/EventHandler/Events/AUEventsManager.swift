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
import UIKit
import AppTrackingTransparency
import AdSupport

fileprivate let keyVisitorId = "keyVisitorId"

class AUEventsManager: AULogEventType {
    static let shared = AUEventsManager()
    private var impressionManager = AUScreenImpressionManager()

    private var visitorId: String = "visitorId"
    private var companyId: String = "companyId"
    private var sessionId: String = AUUniqHelper.makeUniqID()
    private var sessionStartTimestamp: Int = Int(Date().timeIntervalSince1970 * 1000)
    private var deviceId: String = ""
    private var currentPageImpressionId: String? = nil

    // Device / locale info — computed once on configure() (main thread)
    private var screenWidth: Int = 0
    private var screenHeight: Int = 0
    private var locale: String = ""
    private var zoneOffsetSeconds: Int = 0

    // MARK: - Network
    private var networkManager: AUEventsNetworkManager<AUBatchResultModel>?

    func configure(companyId: String) {
        networkManager = AUEventsNetworkManager<AUBatchResultModel>()
        visitorId = makeVisitorId()
        self.companyId = companyId

        let bounds = UIScreen.main.bounds
        screenWidth = Int(bounds.width)
        screenHeight = Int(bounds.height)
        locale = Locale.current.identifier
        zoneOffsetSeconds = TimeZone.current.secondsFromGMT()
    }

    func onScreenResumed(screenName: String) {
        currentPageImpressionId = AUUniqHelper.makeUniqID()
        let event = AUPageImpressionEvent(
            adViewId: "",
            adUnitID: "",
            screenName: screenName
        )
        sendEvent(event)
    }

    func checkImpression(_ view: AUAdView, adUnitID: String?) {
        let (shouldAdd, screenName) = impressionManager.shouldAddEvent(of: view)
        AULogEvent.logDebug("isModelExist shouldAdd: \(shouldAdd)")

        if shouldAdd, let name = screenName {
            onScreenResumed(screenName: name)
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
        mutableEvent.sessionStartTimestamp = sessionStartTimestamp
        mutableEvent.deviceId = deviceId
        mutableEvent.pageImpressionId = currentPageImpressionId
        mutableEvent.screenWidth = screenWidth
        mutableEvent.screenHeight = screenHeight
        mutableEvent.locale = locale
        mutableEvent.zoneOffsetSeconds = zoneOffsetSeconds

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
