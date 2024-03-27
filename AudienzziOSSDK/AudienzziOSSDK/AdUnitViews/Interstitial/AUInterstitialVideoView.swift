//
//  AUInterstitialVideoView.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 25.03.2024.
//

import UIKit
import PrebidMobile

public class AUInterstitialVideoView: AUAdView {
    private var adUnit: InterstitialAdUnit!
    private var gamRequest: AnyObject?
    
    /**
     VideoParameters..
     If will be nill. Automatically create default video parameters
     
     # Example #
     *   AUVideoParameters(mimes: ["video/mp4"])
     * protocols = [AdVideoParameters.Protocols.VAST_2_0]
     * playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
     * placement = AdVideoParameters.Placement.InBanner
     */
    public var parameters: AUVideoParameters?
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }

        onLoadRequest?(request)
        isLazyLoaded = true
    }
    
    public func createAd(with gamRequest: AnyObject) {
        adUnit = InterstitialAdUnit(configId: configId)
        adUnit.adFormats = [.video]

        let parameters = fillVideoParams(parameters)
        adUnit.videoParameters = parameters

        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienz demand fetch for GAM \(resultCode.name())")
            
            guard let self = self else { return }
            self.gamRequest = gamRequest
            if !self.isLazyLoad {
                self.onLoadRequest?(gamRequest)
            }
        }
    }
}
