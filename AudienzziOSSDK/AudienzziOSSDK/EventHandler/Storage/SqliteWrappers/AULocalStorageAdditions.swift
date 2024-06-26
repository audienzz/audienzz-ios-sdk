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

enum SQLiteError: Error {
    case emptyComponent(message: String)
    case fileSystemError(error: Error)
}

struct SQLiteConstants {
    
    static var dbPathComponent: String {
        return SQLiteConstants.dbName + "." + SQLiteConstants.dbExtension
    }
    
    static let dbName: String = "eventsStorage"
    static let dbExtension: String = "sqlite3"
    
    struct DataBaseTables {
        static let events: String = "events" // events
    }
    
    // test Part
    
    static var dbPathComponentTest: String {
        return SQLiteConstants.dbNameTest + "." + SQLiteConstants.dbExtensionTest
    }
    
    static let dbNameTest: String = "eventsStorageTest"
    static let dbExtensionTest: String = "sqlite3"
}
