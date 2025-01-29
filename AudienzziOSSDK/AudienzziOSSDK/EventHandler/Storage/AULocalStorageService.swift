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

protocol AULocalStorageServiceType {
    var events: [AUEventDB]? { get set }
    
    func removeEvents()
}

final class AULocalStorageService: AULocalStorageServiceType {
    
    fileprivate let dataBase: Connection
    internal var dataBaseTest: Connection?
    
    var events: [AUEventDB]? {
        get { return getEvents() }
        set {
            guard let events = newValue, !events.isEmpty else {
                return
            }
            saveEvents(events)
        }
    }
    
    init() throws {
        try AUSQLiteConfigurator().configureStorage()
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        self.dataBase = try Connection("\(path)/\(SQLiteConstants.dbPathComponent)")
        try dataBase.execute("PRAGMA journal_mode = WAL;")
    }
    
    func removeEvents() {
        removeAllEvents()
    }
}

fileprivate extension AULocalStorageService {
    func getEvents() -> [AUEventDB] {
        let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
        
        let id = SQLite.Expression<String>("id")
        let payload = SQLite.Expression<String>("payload")
        
        do {
            let events = Array(try dataBase.prepare(eventsTable))
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
    
    func saveEvents(_ events: [AUEventDB]) {
        let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
        
        let id = SQLite.Expression<String>("id")
        let payload = SQLite.Expression<String>("payload")
        
        do {
            removeAllEvents()
            try events.forEach { event in
                let query = eventsTable.insert(or: .replace,
                                               id <- event.id,
                                               payload <- event.payload)
                _ = try dataBase.run(query)
            }
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
        }
    }
    
    func removeAllEvents() {
        do {
            let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
            try dataBase.run(eventsTable.delete())
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
        }
    }
    
    
    //MARK: - Migration if needed
    func insertEvents(_ events: [AUEventDB]) {
        let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
        
        let id = Expression<String>(value: "id")
        let payload = Expression<String>(value: "payload")
        
        do {
            try events.forEach { event in
                _ = try dataBase.run(eventsTable.insert(or: .replace, id <- event.id,
                                                        payload <- event.payload))
            }
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
        }
    }
    
    func modifyEvents() {
        // Simple data will be replace on actual when time has come
        let dictToModyfy: [String: String] = ["Kia": "KIA", "Ram": "RAM", "FIAT": "Fiat", "MINI": "Mini"]
        
        let eventsTable = Table(SQLiteConstants.DataBaseTables.events)
        let payload = Expression<String>(value: "payload")
        
        do {
            for (oldV, newV) in dictToModyfy {
                let selectedRows = eventsTable.filter(payload == oldV)
                try dataBase.run(selectedRows.update(payload <- newV))
            }
        } catch let error {
            AULogEvent.logDebug(error.localizedDescription)
        }
    }
}

