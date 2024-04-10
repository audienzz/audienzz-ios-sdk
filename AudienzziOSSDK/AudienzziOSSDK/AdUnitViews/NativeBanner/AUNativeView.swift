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

public class AUNativeView: AUAdView, NativeAdDelegate {
    private var nativeUnit: NativeRequest!
    private var nativeAd: NativeAd!
    private var gamRequest: AnyObject?
    
    public var onGetNativeAd: ((NativeAd) -> Void)?
    public var configuration: AUNativeRequestParameter!
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest  else {
            return
        }
        
        #if DEBUG
        print("AUNativeView --- I'm visible")
        #endif
        onLoadRequest?(request)
        isLazyLoaded = true
    }
    
    public func createAd(with gamRequest: AnyObject) {
        nativeUnit = NativeRequest(configId: configId)
        
        nativeUnit.context = configuration.context?.toContentType
        nativeUnit.assets = configuration.assets?.compactMap { $0 as? NativeAsset }
        nativeUnit.placementType = configuration.placementType?.toPlacementType
        nativeUnit.contextSubType = configuration.contextSubType?.toContextSubType
        nativeUnit.eventtrackers = configuration.eventtrackers

        if let placementCount = configuration.placementCount {
            nativeUnit.placementCount = placementCount
        }
        if let sequence = configuration.sequence {
            nativeUnit.sequence = sequence
        }
        if let asseturlsupport = configuration.asseturlsupport {
            nativeUnit.asseturlsupport = asseturlsupport
        }
        if let durlsupport = configuration.durlsupport {
            nativeUnit.durlsupport = durlsupport
        }
        if let privacy = configuration.privacy {
            nativeUnit.privacy = privacy
        }
        
        nativeUnit.ext = configuration.ext

        nativeUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            print("Audienz demand fetch for GAM \(resultCode.name())")
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

