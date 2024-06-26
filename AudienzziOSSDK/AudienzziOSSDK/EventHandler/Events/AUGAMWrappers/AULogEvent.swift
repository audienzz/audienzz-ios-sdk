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

protocol AULogEventType {
    func LogEvent(_ message: String)
    func logEvent(className: AnyObject, message: String)
}

final class AULogEvent {
    
    static let shared = AULogEvent()
    
    static func logEvent(className: AnyObject, message: String) {
        let selfName = String(describing: self)
        let unwrapClassName = String(describing: className)
        
        AULogEvent.logDebug("\(selfName) - \(unwrapClassName) - \(message)")
    }
    
    static func logDebug(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}

extension AULogEventType {
    
    func LogEvent(_ message: String) {
        guard let mySelf = Self.self as? AnyClass else { return }
        AULogEvent.logEvent(className: mySelf, message: message)
    }
    
    
    func logEvent(className: AnyObject, message: String) {
        AULogEvent.logEvent(className: className, message: message)
    }
}



extension Error {
    var errorCode:Int? {
        return (self as NSError).code
    }
}
