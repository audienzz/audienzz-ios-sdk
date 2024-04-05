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

@objc public class AUNativeEventTracker: NativeEventTracker {}

public protocol AUNativeAsset {}
extension AUNativeAsset where Self: NativeAsset {}

public class AUNativeAssetTitle: NativeAssetTitle, AUNativeAsset {}
public class AUNativeAssetData: NativeAssetData, AUNativeAsset {
    public required init(dataType: AUDataAsset, required: Bool) {
        super.init(type: dataType.toDataAsset, required: required)
    }
    
    required init(type: DataAsset, required: Bool) {
        fatalError("init(type:required:) has not been implemented")
    }
}
public class AUNativeAssetImage: NativeAssetImage, AUNativeAsset {
    public var typeImage: AUImageAsset? {
        get {
            AUImageAsset(rawValue: super.type?.value ?? 1)
        }
        set {
            super.type = ImageAsset(integerLiteral: newValue?.rawValue ?? 1)
        }
    }
}

public struct AUNativeRequestParameter {
    public var context: AUContextType?
    public var contextSubType: AUContextSubType?
    public var placementType: AUPlacementType?
    public var placementCount: Int?
    public var sequence: Int?
    public var assets: [AUNativeAsset]?
    public var asseturlsupport: Int?
    public var durlsupport: Int?
    public var eventtrackers: [AUNativeEventTracker]?
    public var privacy: Int?
    public var ext: [String: Any]?
    
    public init() {
        
    }
}
