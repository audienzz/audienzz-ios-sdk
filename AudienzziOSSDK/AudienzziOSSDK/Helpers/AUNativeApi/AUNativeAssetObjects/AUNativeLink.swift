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
public class AUNativeLink: NSObject {
    
    /// Landing URL of the clickable link.
    public var url: String?
    
    /// List of third-party tracker URLs to be fired on click of the URL.
    public var clicktrackers: [String]?
    
    /// Fallback URL for deeplink.
    /// To be used if the URL given in url is not supported by the device.
    public var fallback: String?
    
    /// This object is a placeholder that may contain custom JSON agreed to by the parties to support flexibility beyond the standard defined in this specification
    public var ext: [String: Any]?
    
    init(link: NativeLink) {
        self.url = link.url
        self.clicktrackers = link.clicktrackers
        self.fallback = link.fallback
        self.ext = link.ext
    }
    
    func unwrap() -> NativeLink {
        let nativeLink = NativeLink()
        nativeLink.url = self.url
        nativeLink.clicktrackers = self.clicktrackers
        nativeLink.fallback = self.fallback
        nativeLink.ext = self.ext
        return nativeLink
    }
}

