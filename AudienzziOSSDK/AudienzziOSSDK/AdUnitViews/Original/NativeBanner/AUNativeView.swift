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

@objc
public enum AUNativeType: Int {
    case origin
    case rendering
}

@objc public protocol AUNativeAdDelegate : AnyObject{
    /**
     * Native was not found in the server returned response,
     * Please display the ad as regular ways
     */
    func nativeAdNotFound()
    /**
     * Native ad was returned, however, the bid is not valid for displaying
     * Should be treated as on ad load failed
     */
    func nativeAdNotValid()
}

/**
 * AUNativeView.
 * Ad view for demand  Native ad type.
 * Lazy load is true by default.
*/
@objcMembers
public class AUNativeView: AUAdView {
    internal var nativeUnit: NativeRequest!
    internal var nativeAd: AUNativeAd!
    internal var gamRequest: AnyObject?
    
    public var onNativeLoadRequest: ((AnyObject, [String:String]) -> Void)?
    public var onGetNativeAd: ((AUNativeAd) -> Void)?
    public var nativeParameter: AUNativeRequestParameter!
    public weak var delegate: AUNativeAdDelegate?
    
    internal var subdelegate: NativeAdDelegateType?
    public var adType: AUNativeType!
    
    /**
     Initialize native style view.
     Lazy load is true by default.
     */
    public init(configId: String, adType: AUNativeType = .origin) {
        super.init(configId: configId, isLazyLoad: true)
        nativeUnit = NativeRequest(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: nativeUnit)
        self.subdelegate = NativeAdDelegateType(parent: self)
        self.adType = adType
    }
    
    /**
     Initialize native style view.
     Lazy load is true by default.
     */
    public init(configId: String, isLazyLoad: Bool, adType: AUNativeType = .origin) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        nativeUnit = NativeRequest(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: nativeUnit)
        self.subdelegate = NativeAdDelegateType(parent: self)
        self.adType = adType
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AnyObject) {
        nativeUnit.context = nativeParameter.context?.toContentType
        nativeUnit.assets = nativeParameter.assets?.compactMap { $0.unwrap() }
        nativeUnit.placementType = nativeParameter.placementType?.toPlacementType
        nativeUnit.contextSubType = nativeParameter.contextSubType?.toContextSubType
        nativeUnit.eventtrackers = nativeParameter.eventtrackers?.compactMap { $0.unwrap() }

        if let placementCount = nativeParameter.placementCount {
            nativeUnit.placementCount = placementCount
        }
        if let sequence = nativeParameter.sequence {
            nativeUnit.sequence = sequence
        }
        if let asseturlsupport = nativeParameter.asseturlsupport {
            nativeUnit.asseturlsupport = asseturlsupport
        }
        if let durlsupport = nativeParameter.durlsupport {
            nativeUnit.durlsupport = durlsupport
        }
        if let privacy = nativeParameter.privacy {
            nativeUnit.privacy = privacy
        }
        
        nativeUnit.ext = nativeParameter.ext
        self.gamRequest = gamRequest
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        }
    }
    
    @objc
    public func findNative(adObject: AnyObject) {
        findingNative(adObject)
    }
    
    @discardableResult
    public func registerView(clickableViews: [UIView]? ) -> Bool {
        nativeAd.registerView(view: self, clickableViews: clickableViews)
    }
    
    @objc public func findRenderingAd(_ ad: AUNativeAd?) {
        guard let customAd = ad else {
            return
        }
        
        self.nativeAd = customAd
        onGetNativeAd?(nativeAd)
    }
}

internal class NativeAdDelegateType: NSObject, NativeAdDelegate {
    private weak var parent: AUNativeView?

    init(parent: AUNativeView) {
        super.init()
        self.parent = parent
    }
    
    public func nativeAdLoaded(ad: NativeAd) {
        guard let parent = parent else { return }
        parent.nativeAd = AUNativeAd(ad)
        if parent.isLazyLoad, parent.isLazyLoaded {
            parent.onGetNativeAd?(parent.nativeAd)
        } else {
            parent.onGetNativeAd?(parent.nativeAd)
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
