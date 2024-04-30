//
//  AUMultiplatformView.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 09.04.2024.
//

import UIKit
import PrebidMobile

@objcMembers
public class AUMultiplatformView: AUAdView, NativeAdDelegate {
    private var adUnit: PrebidAdUnit!
    private var gamRequest: AnyObject?
    
    public var onGetNativeAd: ((NativeAd) -> Void)?
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        #if DEBUG
        print("AUMultiplatformView --- I'm visible")
        #endif
        onLoadRequest?(request)
        isLazyLoaded = true
    }
    
    public func create(with gamRequest: AnyObject,
                       bannerParameters: AUBannerParameters,
                       videoParameters: AUVideoParameters,
                       nativeParameters: AUNativeRequestParameter) {
        adUnit = PrebidAdUnit(configId: configId)
        adUnit.setAutoRefreshMillis(time: 30_000)
        
        let bannerParam = bannerParameters.makeBannerParameters()
        let videoParam = fillVideoParams(videoParameters)
        let nativeParam = nativeParameters.makeNativeParameters()
        
        let prebidRequest = PrebidRequest(bannerParameters: bannerParam, videoParameters: videoParam, nativeParameters: nativeParam)
        
        adUnit.fetchDemand(adObject: gamRequest, request: prebidRequest) { [weak self] _ in
            guard let self = self else { return }
            self.gamRequest = gamRequest
            if !self.isLazyLoad {
                self.onLoadRequest?(gamRequest)
            }
        }
    }
    
    @objc
    public func findNative(adObject: AnyObject) {
        if isLazyLoad, isLazyLoaded {
            Utils.shared.delegate = self
            Utils.shared.findNative(adObject: adObject)
        } else {
            Utils.shared.delegate = self
            Utils.shared.findNative(adObject: adObject)
        }
    }
    
    public func nativeAdLoaded(ad: NativeAd) {
        if isLazyLoad, isLazyLoaded {
            self.onGetNativeAd?(ad)
        } else {
            self.onGetNativeAd?(ad)
        }
    }
    
    public func nativeAdNotFound() {
        print("Native ad not found")
    }

    public func nativeAdNotValid() {
        print("Native ad not valid")
    }
}
