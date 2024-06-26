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
import AppTrackingTransparency
import AdSupport

fileprivate let timerInterval = 3.0

class AUEventsManager: AULogEventType {
    static let shared = AUEventsManager()
    private var impressionManager = AUScreenImpressionManager()
    
    //  batches time implementation
    fileprivate var timer: Timer?
    
    func configure() {
        storage = makeLocalStorage()
        networkManager = AUEventsNetworkManager<AUBatchResultModel>()
        requestIDFApermission()
    }
    
    // MARK: - Network
    private var networkManager: AUEventsNetworkManager<AUBatchResultModel>!
    
    // MARK: - Local Storage
    private var storage: AULocalStorageServiceType?
    
    private func makeLocalStorage() -> AULocalStorageServiceType? {
        do {
            AULogEvent.logDebug("I crate local storage")
            return try AULocalStorageService()
        } catch {
            AULogEvent.logDebug("Can't crate local storage")
            return nil
        }
    }
    
    func checkImpression(_ view: AUAdView) {
        let shoudAdd = impressionManager.shouldAddEvent(of: view)
        AULogEvent.logDebug("isModelExist shoudAdd: \(shoudAdd)")
        
        if shoudAdd {
            guard let payload = PayloadModel(adViewId: view.configId,
                                             adUnitID: view.configId,
                                             type: .SCREEN_IMPRESSION).makePayload()
            else { return }
            
            addEvent(event: AUEventDB(payload))
        }
    }
    
    func addEvent(event: AUEventDB) {
        var events: [AUEventDB] = storage?.events ?? []
        events.append(event)
        
        storage?.events = events
        updateTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    private func requestIDFApermission() {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                AULogEvent.logDebug("enable tracking")
            case .denied:
                AULogEvent.logDebug("disable tracking")
            default:
                AULogEvent.logDebug("disable tracking")
            }
            
            AULogEvent.logDebug(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
        }
    }
}

fileprivate extension AUEventsManager {
    func updateTimer() {
        stopTimer()
        startTimer()
    }
    
    func checkEventsForBatches() {
        guard let events = storage?.events else { return }
        
        AULogEvent.logDebug("current Network Status: \(networkManager.isConnection)")
        
        if events.isEmpty.not() && networkManager.isConnection {
            sentEventsToServer(events)
        }
    }
    
    func sentEventsToServer(_ events: [AUEventDB]) {
        // TODO: implement
        let netModels = convertToNetworkModels(events)
        AULogEvent.logDebug("\(type(of: self)) If I got API I will send events")
        return
        let model = BatchRequestModel(batch: BatchModel(visitorId: 24343), netModels: netModels)
        
        networkManager.request(.batchEvents(model)) { [weak self] result in
            switch result {
            case .success(let success):
                AULogEvent.logDebug("networkManager success")
            case .failure(let error):
                AULogEvent.logDebug(error.localizedDescription)
            }
        }
    }
    
    func convertToNetworkModels(_ events: [AUEventDB]) -> [AUEventHandlerType] {
        var netModels: [AUEventHandlerType] = []
        
        for event in events {
            do {
                let jsonData = Data(event.payload.utf8)
                let decoder = JSONDecoder()
                let model = try decoder.decode(PayloadModel.self, from: jsonData)
                guard let netModel: AUEventHandlerType = convert(fromType: model.type, of: model) else {
                    continue
                }
                netModels.append(netModel)
            } catch {
                AULogEvent.logDebug("Error decoding JSON: \(error)")
            }
        }
        
        return netModels
    }
    
    func convert(fromType: AUAdEventType, of payload: PayloadModel) -> AUEventHandlerType? {
        switch fromType {
        case .BID_WINNER:
            return AUBidWinnerEven(payload)
        case .AD_CLICK:
            return AUAdClickEvent(payload)
        case .VIEWABILITY:
            return AUViewabilityEvent(payload)
        case .BID_REQUEST:
            return AUBidRequestEvent(payload)
        case .AD_CREATION:
            return AUAdCreationEvent(payload)
        case .CLOSE_AD:
            return AUCloseAdEvent(payload)
        case .AD_FAILED_TO_LOAD:
            return AUFailedLoadEvent(payload)
        case .SCREEN_IMPRESSION:
            return AUScreenImpression(payload)
        }
    }
}

extension Array {
    func batched(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        return stride(from: 0, to: self.count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, self.count)])
        }
    }
}

fileprivate extension AUEventsManager {
    func startTimer() {
         timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: false) { [weak self] timer in
             self?.timerFired()
         }
     }
     
     func timerFired() {
         checkEventsForBatches()
     }
     
     func stopTimer() {
         timer?.invalidate()
         timer = nil
     }
}
