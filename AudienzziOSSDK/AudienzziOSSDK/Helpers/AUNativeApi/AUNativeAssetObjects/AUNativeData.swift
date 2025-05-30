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
public class AUNativeData: NSObject {
    /// The type of data element being submitted from the Data Asset Types table.
    /// Required for assetsurl/dcourl responses, not required for embedded asset responses.
    public var type: Int?

    /// The length of the data element being submitted.
    /// Required for assetsurl/dcourl responses, not required for embedded asset responses.
    /// Where applicable, must comply with the recommended maximum lengths in the Data Asset Types table.
    public var length: Int?

    /// The formatted string of data to be displayed.
    /// Can contain a formatted value such as “5 stars” or “$10” or “3.4 stars out of 5”.
    public var value: String?

    /// This object is a placeholder that may contain custom JSON agreed to by the parties to support
    /// flexibility beyond the standard defined in this specification
    public var ext: [String: Any]?

    init(data: NativeData) {
        self.type = data.type
        self.length = data.length
        self.value = data.value
        self.ext = data.ext
    }

    func unwrap() -> NativeData {
        let nativeData = NativeData()
        nativeData.type = self.type
        nativeData.length = self.length
        nativeData.value = self.value
        nativeData.ext = self.ext
        return nativeData
    }
}
