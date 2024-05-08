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
import UIKit
import PrebidMobile

/**
 * AUMultiplatformView.
 * Ad view for demand combinations of ad type. It allows to run bid requests with any combination of banner, video, and native formats.
 * Lazy load is true by default.
*/
@objcMembers
public class AUMultiplatformView: AUAdView {
    internal var adUnit: PrebidAdUnit!
    internal var gamRequest: AnyObject?
    internal var prebidRequest: PrebidRequest!
    
    public weak var delegate: AUNativeAdDelegate?
    public var onGetNativeAd: ((NativeAd) -> Void)?
    
    /**
     * Initialize multiformat view.
     * Lazy load is true by default. Banner parametrs is nil by default. Video parameters is nill by default. Native parameters is nill by default.
     * isInterstitial is false by default. isRewarded is false by default.
     */
    public init(configId: String,
                isLazyLoad: Bool = true,
                bannerParameters: AUBannerParameters? = nil,
                videoParameters: AUVideoParameters? = nil,
                nativeParameters: AUNativeRequestParameter? = nil,
                isInterstitial: Bool = false,
                isRewarded: Bool = false) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        adUnit = PrebidAdUnit(configId: configId)
        let bannerParam: BannerParameters? = bannerParameters != nil ? bannerParameters!.makeBannerParameters() : nil
        let videoParam: VideoParameters? = videoParameters != nil ? fillVideoParams(videoParameters) : nil
        let nativeParam: NativeParameters? = nativeParameters != nil ? nativeParameters!.makeNativeParameters() : nil
        
        self.prebidRequest = PrebidRequest(bannerParameters: bannerParam, videoParameters: videoParam,
                                           nativeParameters: nativeParam, isInterstitial: isInterstitial, isRewarded: isRewarded)
        self.adUnitConfiguration = AUAdUnitConfiguration(multiplatformAdUnit: adUnit, request: prebidRequest)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func create(with gamRequest: AnyObject) {
        self.gamRequest = gamRequest
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest, prebidRequest: prebidRequest)
        }
    }
    
    @objc
    public func findNative(adObject: AnyObject) {
        findingNative(adObject: adObject)
    }
}

@objc
extension AUMultiplatformView: NativeAdDelegate {
    public func nativeAdLoaded(ad: NativeAd) {
        if isLazyLoad, isLazyLoaded {
            self.onGetNativeAd?(ad)
        } else {
            self.onGetNativeAd?(ad)
        }
    }
    
    public func nativeAdNotFound() {
        print("Native ad not found")
        delegate?.nativeAdNotFound()
    }

    public func nativeAdNotValid() {
        print("Native ad not valid")
        delegate?.nativeAdNotValid()
    }
}
