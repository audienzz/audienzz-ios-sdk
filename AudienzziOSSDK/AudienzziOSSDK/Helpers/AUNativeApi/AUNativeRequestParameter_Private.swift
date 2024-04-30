//
//  AUNativeRequestParameter_Private.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 09.04.2024.
//

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
