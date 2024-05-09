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
public class AUNativeAdMarkupAsset: NSObject {
    
    /// Optional if asseturl/dcourl is being used; required if embeded asset is being used
    public var id: Int?
    
    /// Set to 1 if asset is required. (bidder requires it to be displayed).
    public var required: Int?
    
    /// Title object for title assets.
    /// See TitleObject definition.
    public var title: AUNativeTitle?
    
    /// Image object for image assets.
    /// See ImageObject definition.
    public var img: AUNativeImage?
    
    /// Data object for ratings, prices etc.
    public var data: AUNativeData?
    
    /// Link object for call to actions.
    /// The link object applies if the asset item is activated (clicked).
    /// If there is no link object on the asset, the parent link object on the bid response applies.
    public var link: AUNativeLink?
    
    /// This object is a placeholder that may contain custom JSON agreed to by the parties to support
    /// flexibility beyond the standard defined in this specification
    public var ext: [String: Any]?
    
    init(adMarkup: NativeAdMarkupAsset) {
        self.id = adMarkup.id
        self.required = adMarkup.required
        
        if let title = adMarkup.title {
            self.title = AUNativeTitle(title: title)
        }

        if let image = adMarkup.img {
            self.img = AUNativeImage(image: image)
        }
        
        if let data = adMarkup.data {
            self.data = AUNativeData(data: data)
        }
        
        if let link = adMarkup.link {
            self.link = AUNativeLink(link: link)
        }
        
        self.ext = adMarkup.ext
    }
    
    func unwrap() -> NativeAdMarkupAsset {
        let adMarkup = NativeAdMarkupAsset()
        
        adMarkup.id = self.id
        adMarkup.required = self.required
        
        if let title = self.title {
            adMarkup.title = title.unwrap()
        }

        if let image = self.img {
            adMarkup.img = image.unwrap()
        }
        
        if let data = self.data {
            adMarkup.data = data.unwrap()
        }
        
        if let link = self.link {
            adMarkup.link = link.unwrap()
        }
        
        adMarkup.ext = self.ext
        
        return adMarkup
    }
}

