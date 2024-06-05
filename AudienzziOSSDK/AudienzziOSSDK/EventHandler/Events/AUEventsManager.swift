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

fileprivate let batchSize = 2
fileprivate let totalObjects = 10

class AUEventsManager {
    static let shared = AUEventsManager()
    
    func configure() {
        storage = makeLocalStorage()
        networkManager = AUEventsNetworkManager()
    }
    
    // MARK: - Network
    private var networkManager: AUEventsNetworkManager!
    
    // MARK: - Local Storage
    private var storage: AULocalStorageServiceType?
    
    private func makeLocalStorage() -> AULocalStorageServiceType? {
        do {
            print("I crate local storage")
            return try AULocalStorageService()
        } catch {
            print("Can't crate local storage")
            return nil
        }
    }
    
    func addEvent(event: AUEventDB) {
        var events: [AUEventDB] = storage?.events ?? []
        events.append(event)
        
        storage?.events = events
        checkEventsForBatches()
    }
}

fileprivate extension AUEventsManager {
    func checkEventsForBatches() {
        guard let events = storage?.events else { return }
        
        print("current Network Status: \(networkManager.isConnection)")
        
        if events.count > batchSize && networkManager.isConnection {
            relifeEventsAndSend(events)
        }
    }
    
    func relifeEventsAndSend(_ event: [AUEventDB]) {
        let batchedEvents = event.batched(into: batchSize)
        guard let first = batchedEvents.first, let last = batchedEvents.last  else { return }
        sentEventsToServer(first)
        
        storage?.events = last
    }
    
    func sentEventsToServer(_ events: [AUEventDB]) {
        // TODO: implement
        let netModels = convertToNetworkModels(events)
        print(netModels)
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
                print("Error decoding JSON: \(error)")
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
