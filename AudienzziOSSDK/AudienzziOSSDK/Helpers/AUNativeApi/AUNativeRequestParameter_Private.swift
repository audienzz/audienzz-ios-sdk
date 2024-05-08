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

import PrebidMobile

extension AUNativeRequestParameter {
    func makeNativeParameters() -> NativeParameters {
        let nativeParam = NativeParameters()
        nativeParam.assets = assets?.compactMap { $0.unwrap() }
        nativeParam.context = context?.toContentType
        nativeParam.placementType = placementType?.toPlacementType
        nativeParam.contextSubType = contextSubType?.toContextSubType
        nativeParam.eventtrackers = eventtrackers?.compactMap { $0.unwrap() }
        
        if let placementCount = placementCount {
            nativeParam.placementCount = placementCount
        }
        if let sequence = sequence {
            nativeParam.sequence = sequence
        }
        if let asseturlsupport = asseturlsupport {
            nativeParam.asseturlsupport = asseturlsupport
        }
        if let durlsupport = durlsupport {
            nativeParam.durlsupport = durlsupport
        }
        if let privacy = privacy {
            nativeParam.privacy = privacy
        }

        nativeParam.ext = ext
        
        return nativeParam
    }
}
