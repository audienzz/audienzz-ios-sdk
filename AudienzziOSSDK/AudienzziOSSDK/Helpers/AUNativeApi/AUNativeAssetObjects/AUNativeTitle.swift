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
public class AUNativeTitle: NSObject {
    /// The text associated with the text element.
    public var text: String?

    /// The length of the title being provided.
    /// Required if using assetsurl/dcourl representation, optional if using embedded asset representation.
    public var length: Int?

    /// This object is a placeholder that may contain custom JSON agreed to by the parties to support
    /// flexibility beyond the standard defined in this specification
    public var ext: [String: Any]?

    required init(title: NativeTitle) {
        super.init()
        self.text = title.text
        self.length = title.length
        self.ext = title.ext
    }

    public override init() {
        super.init()
    }

    internal func unwrap() -> NativeTitle {
        let title = NativeTitle()
        title.text = self.text
        title.length = self.length
        title.ext = self.ext

        return title
    }
}
