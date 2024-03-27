//
//  AUInterstitialView.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 25.03.2024.
//

import UIKit
import PrebidMobile

public class AUInterstitialView: AUAdView {
    private var adUnit: InterstitialAdUnit!
    private var gamRequest: AnyObject?
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        print("AUBannerView --- I'm visible")
        onLoadRequest?(request)
        isLazyLoaded = true
    }
    
    public func createAd(with gamRequest: AnyObject) {
        adUnit = InterstitialAdUnit(configId: configId)

        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienzz demand fetch for GAM \(resultCode.name())")
            guard let self = self else { return }
            self.gamRequest = gamRequest
            if !self.isLazyLoad {
                self.onLoadRequest?(gamRequest)
            }
        }
    }
}
