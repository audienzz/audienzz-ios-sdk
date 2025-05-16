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
import PrebidMobile

@objcMembers
public class AUMORTBContentData: NSObject {
    /// Exchange-specific ID for the data provider.
    public var id: String?
    /// Exchange-specific name for the data provider.
    public var name: String?
    /// Segment objects are essentially key-value pairs that convey specific units of data.
    public var segment: [AUMORTBContentSegment]?
    /// Placeholder for exchange-specific extensions to OpenRTB.
    public var ext: [String: NSObject]?
}

@objcMembers
public class AUMORTBContentSegment: NSObject {
    /// ID of the data segment specific to the data provider.
    public var id: String?
    /// Name of the data segment specific to the data provider.
    public var name: String?
    /// String representation of the data segment value.
    public var value: String?
    /// Placeholder for exchange-specific extensions to OpenRTB.
    public var ext: [String: NSObject]?
}

@objcMembers
public class AUMORTBContentProducer: NSObject {
    /// Content producer or originator ID.
    public var id: String?
    /// Content producer or originator name
    public var name: String?
    /// Array of IAB content categories that describe the content producer.
    public var cat: [String]?
    /// Highest level domain of the content producer.
    public var domain: String?
    /// Placeholder for exchange-specific extensions to OpenRTB.
    public var ext: [String: NSObject]?
}
