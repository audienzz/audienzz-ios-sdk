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
import SQLite

protocol AULocalStorageServiceTypeTestable {
    var eventsTest: [AUEventDB]? { get set }
    
    func prepareForTest() throws
    func getEventsTest() -> [AUEventDB]?
    func saveEventsTest(_ events: [AUEventDB])
    func removeEventsTest()
    func finishTesting() throws
}

extension AULocalStorageService: AULocalStorageServiceTypeTestable {
    
    var eventsTest: [AUEventDB]? {
        get { getEventsTest() }
        set {
            guard let events = newValue, !events.isEmpty else {
                return
            }
            saveEventsTest(events)
        }
    }
    
    
    func prepareForTest() throws {
        try AUSQLiteConfigurator().configureStorageTest()
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        self.dataBaseTest = try Connection("\(path)/\(SQLiteConstants.dbPathComponentTest)")
    }
    
    
    func getEventsTest() -> [AUEventDB]? {
        let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
        
        let id = Expression<String>("id")
        let payload = Expression<String>("payload")
        
        do {
            let events = Array(try dataBaseTest!.prepare(eventsTable))
            return events.compactMap {
                do {
                    return AUEventDB(id: try $0.get(id),
                                     payload: try $0.get(payload))
                } catch let error {
                    AULogEvent.logDebug(error.localizedDescription)
                    return nil
                }
                
            }
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
            return []
        }
    }
    
    func saveEventsTest(_ events: [AUEventDB]) {
        let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
        
        let id = Expression<String>("id")
        let payload = Expression<String>("payload")
        
        do {
            removeEventsTest()
            try events.forEach { event in
                _ = try dataBaseTest!.run(eventsTable.insert(or: .replace,
                                                        id <- event.id,
                                                        payload <- event.payload))
            }
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
        }
    }
    
    func removeEventsTest() {
        do {
            let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
            try dataBaseTest!.run(eventsTable.delete())
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
        }
    }
    
    func finishTesting() throws {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.appending("/\(SQLiteConstants.dbPathComponentTest)")
        try FileManager.default.removeItem(atPath: path)
    }
}
