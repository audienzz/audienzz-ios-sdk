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

fileprivate let timerInterval = 3.0
fileprivate let keyVisitorId = "keyVisitorId"

class AUEventsManager: AULogEventType {
	static let shared = AUEventsManager()
	private var impressionManager = AUScreenImpressionManager()
	
	private var visitorId: String = "visitorId"
	private var companyId: String = "companyId"
	private var sessionId: String = AUUniqHelper.makeUniqID()
	private var deviceId: String = ""
	
	//  batches time implementation
	fileprivate var timer: Timer?
	
	func configure(companyId: String) {
		storage = makeLocalStorage()
		networkManager = AUEventsNetworkManager<AUBatchResultModel>()
		visitorId = makeVisitorId()
		self.companyId = companyId
	}
	
	// MARK: - Network
	private var networkManager: AUEventsNetworkManager<AUBatchResultModel>!
	
	// MARK: - Local Storage
	private var storage: AULocalStorageService?
	
	private func makeLocalStorage() -> AULocalStorageService? {
		do {
			AULogEvent.logDebug("I crate local storage")
			return try AULocalStorageService()
		} catch {
			AULogEvent.logDebug("Can't crate local storage")
			return nil
		}
	}
	
	func checkImpression(_ view: AUAdView, adUnitID: String?) {
		let (shoudAdd, screenName) = impressionManager.shouldAddEvent(of: view)
		AULogEvent.logDebug("isModelExist shoudAdd: \(shoudAdd)")
		
		if shoudAdd, let name = screenName {
			guard let payload = PayloadModel(adViewId: view.configId,
											 adUnitID: adUnitID ?? view.configId,
											 type: .SCREEN_IMPRESSION,
											 visitorId: visitorId,
											 companyId: companyId,
											 sessionId: sessionId,
											 deviceId: deviceId,
											 screenName: name).makePayload()
			else { return }
			
			addEvent(event: AUEventDB(payload))
		}
	}
	
	func addEvent(event: AUEventDB) {
		
		Task {
			var events = await storage?.getEvents() ?? []
			events.append(event)
			
			await storage?.setEvents(newValue: events)
			updateTimer()
		}
	}
	
	deinit {
		stopTimer()
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

fileprivate extension AUEventsManager {
	func updateTimer() {
		stopTimer()
		startTimer()
	}
	
	func checkEventsForBatches() async {
		guard let events = await storage?.getEvents() else { return }
		
		AULogEvent.logDebug("current Network Status: \(networkManager.isConnection)")
		
		if !events.isEmpty && networkManager.isConnection {
			sentEventsToServer(events)
		}
	}
	
	func sentEventsToServer(_ events: [AUEventDB]) {
		let netModels = convertToNetworkModels(events)
		let models = netModels.compactMap { $0.encode() }
		
		networkManager.request(.batchEvents(models)) { [weak self] result in
			switch result {
			case .success:
				AULogEvent.logDebug("networkManager success")
				self?.updateEvents(by: events)
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
		requestDeviceId()
		switch fromType {
		case .BID_WINNER:
			var model = AUBidWinnerEvent(payload)
			model?.visitorId = visitorId
			model?.companyId = companyId
			model?.sessionId = sessionId
			model?.deviceId = deviceId
			return model
		case .AD_CLICK:
			var model = AUAdClickEvent(payload)
			model?.visitorId = visitorId
			model?.companyId = companyId
			model?.sessionId = sessionId
			model?.deviceId = deviceId
			return model
		case .BID_REQUEST:
			var model = AUBidRequestEvent(payload)
			model?.visitorId = visitorId
			model?.companyId = companyId
			model?.sessionId = sessionId
			model?.deviceId = deviceId
			return model
		case .AD_CREATION:
			var model = AUAdCreationEvent(payload)
			model?.visitorId = visitorId
			model?.companyId = companyId
			model?.sessionId = sessionId
			model?.deviceId = deviceId
			return model
		case .CLOSE_AD:
			var model = AUCloseAdEvent(payload)
			model?.visitorId = visitorId
			model?.companyId = companyId
			model?.sessionId = sessionId
			model?.deviceId = deviceId
			return model
		case .AD_FAILED_TO_LOAD:
			var model = AUFailedLoadEvent(payload)
			model?.visitorId = visitorId
			model?.companyId = companyId
			model?.sessionId = sessionId
			model?.deviceId = deviceId
			return model
		case .SCREEN_IMPRESSION:
			var model = AUScreenImpression(payload)
			model?.deviceId = deviceId
			return model
		}
	}
	
	func updateEvents(by oldEvents: [AUEventDB]) {
		Task {
			await storage?.removeEvents()
			AULogEvent.logDebug("networkManager events.cont= \(await storage?.getEvents()?.count ?? 0)")
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
		Task {
			await checkEventsForBatches()
		}
	}
	
	func stopTimer() {
		timer?.invalidate()
		timer = nil
	}
}
