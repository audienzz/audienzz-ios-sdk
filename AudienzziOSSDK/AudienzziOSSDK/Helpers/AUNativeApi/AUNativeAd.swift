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

import Foundation
import UIKit
import PrebidMobile

@objcMembers
public class AUNativeAd: NSObject {
    
    // MARK: - Public properties
    
    public var nativeAdMarkup: AUNativeAdMarkup? {
        get { AUNativeAdMarkup(nativeAdMarkup: nativeAd.nativeAdMarkup) }
    }
    public weak var delegate: AUNativeAdEventDelegate?
    
    // MARK: - Internal properties
    private var nativeAd: NativeAd!
    internal var subdelegate: AUNativeAdDelegateType?
    
    // MARK: - Array getters
    
    @objc public var titles: [AUNativeTitle] {
        nativeAdMarkup?.assets?.compactMap { return $0.title } ?? []
    }
    
    @objc public var dataObjects: [AUNativeData] {
        nativeAdMarkup?.assets?.compactMap { return $0.data } ?? []
    }
    
    @objc public var images: [AUNativeImage] {
        nativeAdMarkup?.assets?.compactMap { return $0.img } ?? []
    }
    
    @objc public var eventTrackers: [AUNativeEventTrackerResponse]? {
        return nativeAdMarkup?.eventtrackers
    }
    
    // MARK: - Filtered array getters
    
    @objc public func dataObjects(of dataType: AUNativeDataAssetType) -> [AUNativeData] {
        dataObjects.filter { $0.type == dataType.rawValue }
    }

    @objc public func images(of imageType: AUNativeImageAssetType) -> [AUNativeImage] {
        images.filter { $0.type == imageType.rawValue }
    }
    
    // MARK: - Property getters
    
    @objc public var title: String? {
        return nativeAd.title
    }
    
    @objc public var imageUrl: String? {
        return nativeAd.imageUrl
    }
    
    @objc public var iconUrl: String? {
        return nativeAd.iconUrl
    }
    
    @objc public var sponsoredBy: String? {
        return nativeAd.sponsoredBy
    }
    
    @objc public var text: String? {
        return nativeAd.text
    }
    
    @objc public var callToAction: String? {
        return nativeAd.callToAction
    }
    
    internal init(_ nativeAd: NativeAd) {
        super.init()
        self.nativeAd = nativeAd
        self.subdelegate = AUNativeAdDelegateType(parent: self)
    }
    
    //MARK: registerView function
    @discardableResult
    public func registerView(view: UIView?, clickableViews: [UIView]? ) -> Bool {
        nativeAd.registerView(view: view, clickableViews: clickableViews)
    }
}

internal class AUNativeAdDelegateType: NSObject, NativeAdEventDelegate {
    private weak var parent: AUNativeAd?

    init(parent: AUNativeAd) {
        super.init()
        self.parent = parent
    }
    
    @objc public func adDidExpire(ad:NativeAd) {
        guard let parent = parent else { return }
        parent.delegate?.adDidExpire?(ad: parent)
    }

    @objc public func adWasClicked(ad:NativeAd) {
        guard let parent = parent else { return }
        parent.delegate?.adWasClicked?(ad: parent)
    }

    @objc public func adDidLogImpression(ad:NativeAd) {
        guard let parent = parent else { return }
        parent.delegate?.adDidLogImpression?(ad: parent)
    }
}
