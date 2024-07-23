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
import XCTest

class ModelsMapperTests: XCTestCase {
    func testPayloadModel() {
        let payloadModel = makePayloadModel()
        XCTAssertNotNil(payloadModel.makePayload(), "Payload musn't be a nil")
    }
    
    func testNetworkModels() {
        let allCases = AUAdEventType.allCases
        
        for type in allCases {
            testNetworkConvertingModel(by: type)
        }
    }
    
    func testNetworkConvertingModel(by type: AUAdEventType) {
        let payloadModel = makePayloadModel(type)
        let stringPayload = payloadModel.makePayload()
        XCTAssertNotNil(stringPayload, "Payload musn't be a nil")
        
        var eventModel: AUEventHandlerType?
        
        switch type {
        case .BID_WINNER:
            eventModel = AUBidWinnerEven(payloadModel)
        case .AD_CLICK:
            eventModel = AUAdClickEvent(payloadModel)
        case .BID_REQUEST:
            eventModel = AUBidRequestEvent(payloadModel)
        case .AD_CREATION:
            eventModel = AUAdCreationEvent(payloadModel)
        case .CLOSE_AD:
            eventModel = AUCloseAdEvent(payloadModel)
        case .AD_FAILED_TO_LOAD:
            eventModel = AUFailedLoadEvent(payloadModel)
        case .SCREEN_IMPRESSION:
            eventModel = AUScreenImpression(payloadModel)
        }
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
    }
    
    func testConvertNetworkModelToDBModel() {
        let allCases = AUAdEventType.allCases
        guard let type = allCases.randomElement() else {
            XCTAssertTrue(false, "Incorrect All_Cases")
            return
        }
        
        var eventModel: AUEventHandlerType?
        let payloadModel = makePayloadModel(type)
        
        switch type {
        case .BID_WINNER:
            eventModel = AUBidWinnerEven(payloadModel)
        case .AD_CLICK:
            eventModel = AUAdClickEvent(payloadModel)
        case .BID_REQUEST:
            eventModel = AUBidRequestEvent(payloadModel)
        case .AD_CREATION:
            eventModel = AUAdCreationEvent(payloadModel)
        case .CLOSE_AD:
            eventModel = AUCloseAdEvent(payloadModel)
        case .AD_FAILED_TO_LOAD:
            eventModel = AUFailedLoadEvent(payloadModel)
        case .SCREEN_IMPRESSION:
            eventModel = AUScreenImpression(payloadModel)
        }
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        
        let convertedToNetModel = convertToNetworkModel(dbModel)
        
        XCTAssertEqual(eventModel?.type, convertedToNetModel.type, "Not Equal models")
    }
    
    func testConvertNetworkBidWinner() {
        let type: AUAdEventType = .BID_WINNER
        let payloadModel = makePayloadModel(.BID_WINNER)
        let eventModel = AUBidWinnerEven(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUBidWinnerEven
        
        XCTAssertEqual(convertedToNetModel.resultCode, eventModel?.resultCode, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.targetKeywords, eventModel?.targetKeywords, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.isAutorefresh, eventModel?.isAutorefresh, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.autorefreshTime, eventModel?.autorefreshTime, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.size, eventModel?.size, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adType, eventModel?.adType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adSubType, eventModel?.adSubType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.apiType, eventModel?.apiType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.initialRefresh, eventModel?.initialRefresh, "Not Equal models")
    }
    
    func testConvertNetworkAdClick() {
        let type: AUAdEventType = .AD_CLICK
        let payloadModel = makePayloadModel(type)
        let eventModel = AUAdClickEvent(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUAdClickEvent
        
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
    }
    
    func testConvertNetworkBidRequest() {
        let type: AUAdEventType = .BID_REQUEST
        let payloadModel = makePayloadModel(type)
        let eventModel = AUBidRequestEvent(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUBidRequestEvent
        
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.isAutorefresh, eventModel?.isAutorefresh, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.autorefreshTime, eventModel?.autorefreshTime, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.size, eventModel?.size, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adType, eventModel?.adType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adSubType, eventModel?.adSubType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.apiType, eventModel?.apiType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.initialRefresh, eventModel?.initialRefresh, "Not Equal models")
    }
    
    func testConvertNerworkAdCreation() {
        let type: AUAdEventType = .AD_CREATION
        let payloadModel = makePayloadModel(type)
        let eventModel = AUAdCreationEvent(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUAdCreationEvent
        
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.size, eventModel?.size, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adType, eventModel?.adType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adSubType, eventModel?.adSubType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.apiType, eventModel?.apiType, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
    }
    
    func testConvertNerworkAdClose() {
        let type: AUAdEventType = .CLOSE_AD
        let payloadModel = makePayloadModel(type)
        let eventModel = AUCloseAdEvent(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUCloseAdEvent
        
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
    }
    
    func testConvertNerworkFailedLoad() {
        let type: AUAdEventType = .AD_FAILED_TO_LOAD
        let payloadModel = makePayloadModel(type)
        let eventModel = AUFailedLoadEvent(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUFailedLoadEvent
        
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.errorCode, eventModel?.errorCode, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.errorMessage, eventModel?.errorMessage, "Not Equal models")
    }
    
    func testConvertNetworkScreenImpression() {
        let type: AUAdEventType = .SCREEN_IMPRESSION
        let payloadModel = makePayloadModel(type)
        let eventModel = AUScreenImpression(payloadModel)
        
        XCTAssertNotNil(eventModel, "EnetModel \(type.rawValue) musn't be a nil")
        XCTAssertTrue(eventModel?.type == type, "\(type.rawValue) model has incorrect type")
        
        guard let payload = payloadModel.makePayload() else {
            XCTAssertTrue(false, "Incorrect cast Payload")
            return
        }
            
        let dbModel = AUEventDB(payload)
        let convertedToNetModel = convertToNetworkModel(dbModel) as! AUScreenImpression
        
        XCTAssertEqual(convertedToNetModel.adUnitID, eventModel?.adUnitID, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.adViewId, eventModel?.adViewId, "Not Equal models")
        XCTAssertEqual(convertedToNetModel.type, eventModel?.type, "Not Equal models")
    }
    
    private func convertToNetworkModel(_ event: AUEventDB) -> AUEventHandlerType {
        var model: PayloadModel!
        
        do {
            let jsonData = Data(event.payload.utf8)
            let decoder = JSONDecoder()
            model = try decoder.decode(PayloadModel.self, from: jsonData)
        } catch {
            AULogEvent.logDebug("Error decoding JSON: \(error)")
        }
        
        guard let netModel: AUEventHandlerType = convert(fromType: model.type, of: model) else {
            fatalError("Cannot corectly convert")
        }
        return netModel
    }
    
    private func convert(fromType: AUAdEventType, of payload: PayloadModel) -> AUEventHandlerType? {
        switch fromType {
        case .BID_WINNER:
            return AUBidWinnerEven(payload)
        case .AD_CLICK:
            return AUAdClickEvent(payload)
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
    
    private func makePayloadModel(_ type: AUAdEventType? = nil) -> PayloadModel {
        PayloadModel(adViewId: .random,
                     adUnitID: .random,
                     type: type ?? .random,
                     visitorId: .random,
                     companyId: .random,
                     sessionId: .random,
                     deviceId: .random,
                     resultCode: .random,
                     targetKeywords: [.random: .random],
                     isAutorefresh: .random,
                     autorefreshTime: .random,
                     initialRefresh: .random,
                     size: .random,
                     adType: .random,
                     adSubType: .random,
                     apiType: .random,
                     errorMessage: .random,
                     errorCode: .random)
    }
}
