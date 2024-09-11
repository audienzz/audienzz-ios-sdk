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

@objc public class AUNativeEventTracker: NSObject {
    private var nativeEventTracker: NativeEventTracker!
    
    @objc
    public init(event: AUEventType, methods: [AUEventTracking]) {
        self.nativeEventTracker = NativeEventTracker(event: event.unwrap(), methods: methods.compactMap { $0.trackingType.unwrap() })
    }
    
    internal func unwrap() -> NativeEventTracker {
        nativeEventTracker
    }
}

@objc public enum AUEventType: Int {
    case Impression = 1
    case ViewableImpression50 = 2
    case ViewableImpression100 = 3
    case ViewableVideoImpression50 = 4
    case Custom = 500
    
    internal func unwrap() -> EventType {
        EventType(integerLiteral: self.rawValue)
    }
}

@objc
public class AUEventTracking: NSObject {
    @objc var trackingType: AUEventTrackingType
    
    @objc public init(trackingType: AUEventTrackingType) {
        self.trackingType = trackingType
    }
}

@objc public enum AUEventTrackingType: Int {
    case Image = 1
    case js = 2
    case Custom = 500
    
    internal func unwrap() -> EventTracking {
        EventTracking(integerLiteral: self.rawValue)
    }
}
