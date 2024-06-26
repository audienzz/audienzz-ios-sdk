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

class AULocalServiceTests: XCTestCase {
    
    func testCreateLoacalDB() {
        do {
            let localDB = try AULocalStorageService()
            try localDB.prepareForTest()
            
            
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.appending("/\(SQLiteConstants.dbPathComponentTest)")
            
            XCTAssertNotNil(localDB.dataBaseTest, "Must be exist DB")
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Must be exist")
            
            
            try localDB.finishTesting()
            XCTAssertFalse(FileManager.default.fileExists(atPath: path), "Must be removed")
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
            XCTAssertThrowsError(error)
        }
    }
    
    func testDBEventsManage() {
        var localDB: AULocalStorageService!
        
        do {
            localDB = try AULocalStorageService()
            try localDB.prepareForTest()
        } catch let error {
            XCTAssertThrowsError(error)
        }
        
        let payloadModel = PayloadModel(adViewId: .random,
                                        adUnitID: .random,
                                        type: .random,
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
        
        guard let payload = payloadModel.makePayload() else {
            fatalError("payload must converted to string")
        }
        
        let dbModel = AUEventDB(payload)
        let testEvents = [dbModel]
        localDB.saveEventsTest(testEvents)
        
        let eventsTest: [AUEventDB] = localDB.getEventsTest()!
        
        XCTAssertTrue(eventsTest.count == 1, "Must be not empty")
        XCTAssertEqual(testEvents, eventsTest, "Not equal")
        XCTAssertEqual(testEvents, localDB.eventsTest, "Not equal")
        
        localDB.removeEventsTest()
        
        XCTAssertTrue(localDB.eventsTest!.isEmpty, "Must be empty")
        
        do {
            try localDB.finishTesting()
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.appending("/\(SQLiteConstants.dbPathComponentTest)")
            XCTAssertFalse(FileManager.default.fileExists(atPath: path), "Must be removed")
        } catch {
            XCTAssertThrowsError(error)
        }
    }
}
