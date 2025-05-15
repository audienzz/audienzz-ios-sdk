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

import SQLite

// create database structure
// used for debug purposes and for modifing db structure
protocol AULocalStorageCreator {
    func createLocalStorage()
}

final class AUSQLiteDataBaseCreator: AULocalStorageCreator {
    func createLocalStorage() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let db = try Connection("\(path)/\(SQLiteConstants.dbPathComponent)")
            
            try createEventsTable(on: db)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func createLocalStorageTest() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let db = try Connection("\(path)/\(SQLiteConstants.dbPathComponentTest)")
            
            try createEventsTable(on: db)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
}

fileprivate extension AUSQLiteDataBaseCreator {
    func createEventsTable(on dataBase: Connection) throws {
        let events = Table(SQLiteConstants.DataBaseTables.events)
        
        let id = SQLite.Expression<String>("id")
        let payload = SQLite.Expression<String>("payload")
        
        try dataBase.run(events.create { t in
            t.column(id, primaryKey: true)
            t.column(payload, primaryKey: false)
        })
    }
}

