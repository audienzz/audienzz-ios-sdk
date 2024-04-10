//
//  AUBannerParameters_Private.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 09.04.2024.
//

import PrebidMobile

extension AUBannerParameters {
    
    internal func makeBannerParameters() -> BannerParameters {
        let bannerParameters = BannerParameters()
        bannerParameters.api = api?.compactMap { $0.toAPI }
        
        bannerParameters.interstitialMinWidthPerc = interstitialMinWidthPerc
        bannerParameters.interstitialMinHeightPerc = interstitialMinHeightPerc
        bannerParameters.adSizes = adSizes
        
        return bannerParameters
    }
}
