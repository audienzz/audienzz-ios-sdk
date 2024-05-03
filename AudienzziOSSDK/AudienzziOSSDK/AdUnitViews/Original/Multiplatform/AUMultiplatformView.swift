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
    private var prebidRequest: PrebidRequest!
    
    public var onGetNativeAd: ((NativeAd) -> Void)?
    
    public init(configId: String) {
        super.init(configId: configId, isLazyLoad: true)
        adUnit = PrebidAdUnit(configId: configId)
//        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    public override init(configId: String, isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        adUnit = PrebidAdUnit(configId: configId)
//        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func create(with gamRequest: AnyObject,
                       bannerParameters: AUBannerParameters,
                       videoParameters: AUVideoParameters,
                       nativeParameters: AUNativeRequestParameter) {
        
        let bannerParam = bannerParameters.makeBannerParameters()
        let videoParam = fillVideoParams(videoParameters)
        let nativeParam = nativeParameters.makeNativeParameters()
        
        self.gamRequest = gamRequest
        self.prebidRequest = PrebidRequest(bannerParameters: bannerParam, videoParameters: videoParam, nativeParameters: nativeParam)
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest, prebidRequest: prebidRequest)
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
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        #if DEBUG
        print("AUMultiplatformView --- I'm visible")
        #endif
        fetchRequest(request, prebidRequest: prebidRequest)
        isLazyLoaded = true
    }
    
    func fetchRequest(_ gamRequest: AnyObject, prebidRequest: PrebidRequest) {
        adUnit.fetchDemand(adObject: gamRequest, request: prebidRequest) { [weak self] _ in
            guard let self = self else { return }
            self.onLoadRequest?(gamRequest)
        }
    }
}
