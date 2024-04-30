//
//  AUBannerParameters.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 09.04.2024.
//

import PrebidMobile

@objcMembers
public class AUBannerParameters: NSObject {
    /// List of supported API frameworks for this impression. If an API is not explicitly listed, it is assumed not to be supported.
    public var api: [AUApi]?
    
    public var interstitialMinWidthPerc: Int?
    public var interstitialMinHeightPerc: Int?
    
    public var adSizes: [CGSize]?
}
