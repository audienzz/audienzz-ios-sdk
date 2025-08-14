/*   Copyright 2018-2025 Audienzz.org, Inc.
 
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
import GoogleMobileAds

/**
 * AUMultiplatformView.
 * Ad view for demand combinations of ad type. It allows to run bid requests with any combination of banner, video, and native formats.
 * Lazy load is true by default.
*/
@objcMembers
public class AUMultiplatformView: AUAdView {
    internal var adUnit: PrebidAdUnit!
    internal var gamRequest: AdManagerRequest?
    internal var prebidRequest: PrebidRequest!
    internal var gadUnitID: String?
    
    public weak var delegate: AUNativeAdDelegate?
    public var onGetNativeAd: ((PrebidNativeAd) -> Void)?
    
    internal var subdelegate: AUMultiplatformDelegateType?
    
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
        let videoParam: VideoParameters? = videoParameters?.unwrap()
        let nativeParam: NativeParameters? = nativeParameters != nil ? nativeParameters!.makeNativeParameters() : nil
        
        self.prebidRequest = PrebidRequest(bannerParameters: bannerParam, videoParameters: videoParam,
                                           nativeParameters: nativeParam, isInterstitial: isInterstitial, isRewarded: isRewarded)
        self.adUnitConfiguration = AUAdUnitConfiguration(multiplatformAdUnit: adUnit, request: prebidRequest)
        self.subdelegate = AUMultiplatformDelegateType(parent: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func create(with gamRequest: AdManagerRequest, adUnitID: String) {
        self.gamRequest = AUTargeting.shared.customTargetingManager.applyToGamRequest(request: gamRequest)
        self.gadUnitID = adUnitID
        AUEventsManager.shared.checkImpression(self, adUnitID: adUnitID)
        
        makeCreationEvent()
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest, prebidRequest: prebidRequest)
        }
    }
    
    @objc
    public func findNative(adObject: AnyObject) {
        findingNative(adObject: adObject)
    }
}

internal class AUMultiplatformDelegateType: NSObject, PrebidNativeAdDelegate {
    private weak var parent: AUMultiplatformView?
    
    init(parent: AUMultiplatformView) {
        super.init()
        self.parent = parent
    }
    
    public func nativeAdLoaded(ad: PrebidNativeAd) {
        guard let parent = parent else { return }
        if parent.isLazyLoad, parent.isLazyLoaded {
            parent.onGetNativeAd?(ad)
        } else {
            parent.onGetNativeAd?(ad)
        }
    }
    
    public func nativeAdNotFound() {
        AULogEvent.logDebug("Native ad not found")
        parent?.delegate?.nativeAdNotFound()
    }

    public func nativeAdNotValid() {
        AULogEvent.logDebug("Native ad not valid")
        parent?.delegate?.nativeAdNotValid()
    }
}
