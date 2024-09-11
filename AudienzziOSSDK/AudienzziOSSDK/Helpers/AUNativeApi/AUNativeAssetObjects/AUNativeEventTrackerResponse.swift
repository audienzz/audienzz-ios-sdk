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
import PrebidMobile

@objcMembers
public class AUNativeEventTrackerResponse: NSObject {
    
    /// Type of event to track.
    /// See Event Types table.
    public var event: Int?
    
    /// Type of tracking requested.
    /// See Event Tracking Methods table.
    public var method: Int?
    
    /// The URL of the image or js.
    /// Required for image or js, optional for custom.
    public var url: String?
    
    /// To be agreed individually with the exchange, an array of key:value objects for custom tracking,
    /// for example the account number of the DSP with a tracking company. IE {“accountnumber”:”123”}.
    public var customdata: [String: Any]?
    
    /// This object is a placeholder that may contain custom JSON agreed to by the parties to support flexibility beyond the standard defined in this specification
    public var ext: [String: Any]?
    
    init(eventTracker: NativeEventTrackerResponse) {
        self.event = eventTracker.event
        self.method = eventTracker.method
        self.url = eventTracker.url
        self.customdata = eventTracker.customdata
        self.ext = eventTracker.ext
    }
    
    func unwrap() -> NativeEventTrackerResponse {
        let eventTracker = NativeEventTrackerResponse()
        eventTracker.event = self.event
        eventTracker.method = self.method
        eventTracker.url = self.url
        eventTracker.customdata = self.customdata
        eventTracker.ext = self.ext
        return eventTracker
    }
}

