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
public class AUNativeAsset: NSObject {
    private var nativeAsset: NativeAsset!
    
    public var required: Bool {
        get { nativeAsset.required }
        set { nativeAsset.required = newValue }
    }
    
    public init(isRequired: Bool) {
        super.init()
        self.nativeAsset = NativeAsset(isRequired: isRequired)
    }
    
    func unwrap() -> NativeAsset {
        nativeAsset
    }
}

@objcMembers
public class AUNativeAssetTitle: AUNativeAsset {
    private var nativeAssetTitle: NativeAssetTitle!
    
    public var ext: AnyObject? {
        get { nativeAssetTitle.ext }
        set { nativeAssetTitle.ext = newValue }
    }
    
    public required init(length: NSInteger, required: Bool) {
        super.init(isRequired: required)
        self.nativeAssetTitle = NativeAssetTitle(length: length, required: required)
    }
    
    override func unwrap() -> NativeAsset {
        nativeAssetTitle
    }
}

@objcMembers
public class AUNativeAssetImage: AUNativeAsset {
    private var nativeAssetImage: NativeAssetImage!
    
    public var type: AUImageAsset? {
        get { AUImageAsset(rawValue: nativeAssetImage.type?.value ?? 500) }
        set { nativeAssetImage.type = ImageAsset(integerLiteral: newValue?.rawValue ?? 1) }
    }
    public var width: Int? {
        get { nativeAssetImage.width }
        set { nativeAssetImage.width = newValue }
    }
    public var widthMin: Int? {
        get { nativeAssetImage.widthMin }
        set { nativeAssetImage.widthMin = newValue }
    }
    public var height: Int? {
        get { nativeAssetImage.height }
        set { nativeAssetImage.height = newValue }
    }
    public var heightMin: Int? {
        get { nativeAssetImage.heightMin }
        set { nativeAssetImage.heightMin = newValue }
    }
    public var mimes: Array<String>? {
        get { nativeAssetImage.mimes }
        set { nativeAssetImage.mimes = newValue }
    }
    public var ext: AnyObject? {
        get { nativeAssetImage.ext }
        set { nativeAssetImage.ext = newValue }
    }
    
    public convenience init(minimumWidth: Int, minimumHeight: Int, required: Bool) {
        self.init(isRequired: required)
        self.nativeAssetImage = NativeAssetImage(minimumWidth: minimumWidth, minimumHeight: minimumHeight, required: required)
    }
    
    public override init(isRequired: Bool) {
        super.init(isRequired: isRequired)
        self.nativeAssetImage = NativeAssetImage(isRequired: isRequired)
    }
    
    override func unwrap() -> NativeAsset {
        nativeAssetImage
    }
}

@objcMembers
public class AUNativeAssetData: AUNativeAsset {
    private var nativeAssetData: NativeAssetData!

    public var length: Int? {
        get { nativeAssetData.length }
        set { nativeAssetData.length = newValue }
    }
    public var ext: AnyObject? {
        get { nativeAssetData.ext }
        set { nativeAssetData.ext = newValue }
    }
    
    public required init(type: AUDataAsset, required: Bool) {
        super.init(isRequired: required)
        self.nativeAssetData = NativeAssetData(type: type.toDataAsset, required: required)
    }
    
    override func unwrap() -> NativeAsset {
        nativeAssetData
    }
}
