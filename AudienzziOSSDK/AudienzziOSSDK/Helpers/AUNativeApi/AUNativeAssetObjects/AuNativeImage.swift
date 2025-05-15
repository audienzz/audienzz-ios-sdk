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
public class AUNativeImage: NSObject {
    /// The type of image element being submitted from the Image Asset Types table.
    /// Required for assetsurl or dcourl responses, not required for embedded asset responses.
    public var type: Int?

    /// URL of the image asset.
    public var url: String?

    /// Width of the image in pixels.
    /// Recommended for embedded asset responses.
    /// Required for assetsurl/dcourlresponses if multiple assets of same type submitted.
    public var width: Int?

    /// Height of the image in pixels.
    /// Recommended for embedded asset responses.
    /// Required for assetsurl/dcourl responses if multiple assets of same type submitted.
    public var height: Int?

    /// This object is a placeholder that may contain custom JSON agreed to by the parties to support
    /// flexibility beyond the standard defined in this specification
    public var ext: [String: Any]?

    init(image: NativeImage) {
        self.type = image.type
        self.url = image.url
        self.width = image.width
        self.height = image.height
        self.ext = image.ext
    }

    func unwrap() -> NativeImage {
        let nativeImage = NativeImage()

        nativeImage.type = self.type
        nativeImage.url = self.url
        nativeImage.width = self.width
        nativeImage.height = self.height
        nativeImage.ext = self.ext

        return nativeImage
    }
}
