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


import UIKit
import PrebidMobile

/**
 Defines the User Id Object from an External Thrid Party Source
 */
@objcMembers
public class AUExternalUserId: NSObject {
    public static var supportsSecureCoding: Bool {
        true
    }
    
    
    // MARK: - Properties
    public var source: String
    public var identifier: String
    public var atype: NSNumber?
    public var ext: [String: Any]?

    // MARK: - Initialization
    /**
     Initialize ExternalUserId Class
    - Parameter source: Source of the External User Id String.
    - Parameter identifier: String of the External User Id.
    - Parameter atype: (Optional) Int of the External User Id.
    - Parameter ext: (Optional) Dictionary of the External User Id.
    */
    public init(source: String, identifier: String, atype: NSNumber? = nil, ext:[String: Any]? = nil) {
        self.source = source
        self.identifier = identifier
        self.atype = atype
        self.ext = ext
        super.init()
    }
}

internal extension AUExternalUserId {
    func unwrap() -> ExternalUserId {
        return ExternalUserId(source: self.source, identifier: self.identifier, atype: self.atype, ext: self.ext)
    }
    
    convenience init(with exIds: ExternalUserId) {
        self.init(source: exIds.source, identifier: exIds.identifier)
        self.atype = exIds.atype
        self.ext = exIds.ext
    }
}
