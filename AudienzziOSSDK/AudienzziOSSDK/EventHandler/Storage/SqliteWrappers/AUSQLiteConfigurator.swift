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

protocol AULocalStorageConfigurator {
    func configureStorage() throws
    func configureStorageTest() throws
}

final class AUSQLiteConfigurator: AULocalStorageConfigurator {
    
    func configureStorage() throws {
        let destination = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let newDBPath = destination.appendingPathComponent(SQLiteConstants.dbPathComponent)
        
        if FileManager.default.fileExists(atPath: newDBPath.path) {
            return
        } else {
            AUSQLiteDataBaseCreator().createLocalStorage()
        }
    }
    
    func configureStorageTest() throws {
        let destination = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let newDBPath = destination.appendingPathComponent(SQLiteConstants.dbPathComponentTest)
        
        if FileManager.default.fileExists(atPath: newDBPath.path) {
            return
        } else {
            AUSQLiteDataBaseCreator().createLocalStorageTest()
        }
    }
}
