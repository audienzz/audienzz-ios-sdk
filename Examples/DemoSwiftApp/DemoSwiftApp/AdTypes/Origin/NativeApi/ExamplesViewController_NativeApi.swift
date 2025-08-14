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
import AudienzziOSSDK
import GoogleMobileAds

fileprivate let storedPrebidImpression = "prebid-demo-banner-native-styles"
fileprivate let gamNativeAdUnitId = "/21808260008/apollo_custom_template_native_ad_unit"
internal let gamNativeBannerAdUnitId = "/21808260008/prebid-demo-original-native-styles"

fileprivate let nativeRenderingStoredImpression = "prebid-demo-banner-native-styles"
fileprivate let gamRenderingNativeAdUnitId = "/21808260008/apollo_custom_template_native_ad_unit"

fileprivate var nativeBannerView:AUNativeBannerView!
fileprivate var nativeLzyView: AUNativeView!
fileprivate var nativeLazyBannerView:AUNativeBannerView!
fileprivate var nativeRenderingView: AUNativeView!

// MARK: - Native Banner API
extension ExamplesViewController {
    func createNativeView() {
        nativeView = AUNativeView(configId: storedPrebidImpression, isLazyLoad: false)
        nativeView.nativeParameter = nativeConfiguration()

        let gamRequest = GAMRequest()
        nativeView.createAd(with: gamRequest)
        
        nativeView.onLoadRequest = { [weak self] request in
            guard let self = self else { return }
            guard let request = request as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            
            self.adLoader = GADAdLoader(adUnitID: "ca-app-pub-6632294249825318/1327733692", rootViewController: self,
                                        adTypes: [GADAdLoaderAdType.native], options: [])
            self.adLoader.delegate = self
            self.adLoader.load(request)
        }
        
        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        exampleView.frame = CGRect(x: 0, y: getPositionY(adContainerView), width: self.view.frame.width, height: 200)
        adContainerView.addSubview(exampleView)
        
        nativeView.onGetNativeAd = { ad in
            exampleView.setupFromAd(ad: ad)
        }
    }
    
    func createRenderingNativeView() {
        nativeRenderingView = AUNativeView(configId: storedPrebidImpression, adType: .rendering)
        nativeRenderingView.nativeParameter = nativeConfiguration()

        let gamRequest = GAMRequest()
        nativeRenderingView.createAd(with: gamRequest)
        
        nativeRenderingView.onNativeLoadRequest = { [weak self] request, keywords in
            guard let self = self else { return }
            guard let request = request as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            
            AudienzzGAMUtils.shared.prepareRequest(request, bidTargeting: keywords)
            
            self.adRenderingLoader = GADAdLoader(adUnitID: gamRenderingNativeAdUnitId, rootViewController: self,
                                        adTypes: [GADAdLoaderAdType.customNative], options: [])
            self.adRenderingLoader.delegate = self
            self.adRenderingLoader.load(request)
        }
        
        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        nativeRenderingView.frame = CGRect(x: 0, y: getPositionY(lazyAdContainerView), width: self.view.frame.width, height: 200)
        exampleView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200)
        nativeRenderingView.addSubview(exampleView)
        lazyAdContainerView.addSubview(nativeRenderingView)
        
        nativeRenderingView.onGetNativeAd = { ad in
            exampleView.setupFromAd(ad: ad)
        }
    }
    
    func createNativeBannerView() {
        let gamRequest = GAMRequest()
        let gamBannerView = GAMBannerView(adSize: GADAdSizeFluid)
        gamBannerView.adUnitID = gamNativeBannerAdUnitId
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        
        let configuration = nativeConfiguration()
        
        nativeBannerView = AUNativeBannerView(configId: storedPrebidImpression, configuration: configuration, isLazyLoad: false)
        nativeBannerView.frame = CGRect(x: 0, y: getPositionY(adContainerView), width: self.view.frame.width, height: 250)
        nativeBannerView.backgroundColor = .lightGray
        adContainerView.addSubview(nativeBannerView)
        
        addConstrains(subView: nativeBannerView, container: adContainerView, height: 250)
        
        nativeBannerView.createAd(with: gamRequest, gamBanner: gamBannerView, configuration: configuration)
        nativeBannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            gamBannerView.load(request)
        }
    }
    
    func nativeConfiguration() -> AUNativeRequestParameter {
        let image = AUNativeAssetImage(minimumWidth: 200, minimumHeight: 50, required: true)
        image.type = AUImageAsset.Main
        
        let icon = AUNativeAssetImage(minimumWidth: 20, minimumHeight: 20, required: true)
        icon.type = AUImageAsset.Icon
        
        let title = AUNativeAssetTitle(length: 90, required: true)
        let body = AUNativeAssetData(type: AUDataAsset.description, required: true)
        let cta = AUNativeAssetData(type: AUDataAsset.ctatext, required: true)
        let sponsored = AUNativeAssetData(type: AUDataAsset.sponsored, required: true)
        
        let asstets: [AUNativeAsset] = [title, icon, image, sponsored, body, cta]
        
        var parameters = AUNativeRequestParameter()
        
        parameters.assets = asstets
        parameters.context = AUContextType.Social
        parameters.placementType = AUPlacementType.FeedContent
        parameters.contextSubType = AUContextSubType.Social
        parameters.eventtrackers = [AUNativeEventTracker(event: AUEventType.Impression,
                                                         methods: [AUEventTracking(trackingType: .Image), AUEventTracking(trackingType: .js)])]
        
        return parameters
    }
}

// MARK: - Native API Lazy load
extension ExamplesViewController {
    func createLazyNativeView() {
        nativeLzyView = AUNativeView(configId: storedPrebidImpression)
        nativeLzyView.nativeParameter = nativeConfiguration()

        let gamRequest = GAMRequest()
        nativeLzyView.createAd(with: gamRequest)
        
        nativeLzyView.onLoadRequest = { [weak self] request in
            guard let self = self else { return }
            guard let request = request as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            
            self.adLazyLoader = GADAdLoader(adUnitID: gamRenderingNativeAdUnitId, rootViewController: self,
                                        adTypes: [GADAdLoaderAdType.customNative], options: [])
            self.adLazyLoader.delegate = self
            self.adLazyLoader.load(request)
        }
        
        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        nativeLzyView.frame = CGRect(x: 0, y: getPositionY(lazyAdContainerView), width: self.view.frame.width, height: 200)
        exampleView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200)
        nativeLzyView.addSubview(exampleView)
        lazyAdContainerView.addSubview(nativeLzyView)
        
        nativeLzyView.onGetNativeAd = { ad in
            exampleView.setupFromAd(ad: ad)
        }
    }

    func createLazyNativeBannerView() {
        let gamRequest = GAMRequest()
        let gamBannerView = GAMBannerView(adSize: GADAdSizeFluid)
        gamBannerView.adUnitID = "/21808260008/prebid-demo-original-native-styles"
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        
        let configuration = nativeConfiguration()
        
        nativeLazyBannerView = AUNativeBannerView(configId: storedPrebidImpression, configuration: configuration)
        nativeLazyBannerView.frame = CGRect(x: 0, y: getPositionY(lazyAdContainerView), width: self.view.frame.width, height: 200)
        lazyAdContainerView.addSubview(nativeLazyBannerView)
        
        nativeLazyBannerView.createAd(with: gamRequest, gamBanner: gamBannerView, configuration: configuration)
        nativeLazyBannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GAMRequest else {
                print("Faild request unwrap")
                return
            }
            gamBannerView.load(request)
        }
    }
}

// MARK: GADCustomNativeAdLoaderDelegate
extension ExamplesViewController: GADAdLoaderDelegate, GADCustomNativeAdLoaderDelegate, GADNativeAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        print("GAM did fail to receive ad with error: \(nativeAd)")
        if adLoader == self.adLoader {
            nativeView.findNative(adObject: nativeAd)
        } else if adLoader == adLazyLoader {
            nativeLzyView.findNative(adObject: nativeAd)
        }  else if adLoader == self.adRenderingLoader {
            
        }
    }
    
    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        print("GAM did fail to receive ad with error: \(error)")
    }
    
    func customNativeAdFormatIDs(for adLoader: GADAdLoader) -> [String] {
        ["11934135"]
    }
    
    func adLoader(_ adLoader: GADAdLoader, didReceive customNativeAd: GADCustomNativeAd) {
        if adLoader == self.adLoader {
            nativeView.findNative(adObject: customNativeAd)
        } else if adLoader == adLazyLoader {
            nativeLzyView.findNative(adObject: customNativeAd)
        }  else if adLoader == self.adRenderingLoader {
            AudienzzGAMUtils.shared.findCustomNativeAd(for: customNativeAd, completion: { ad, error in
                nativeRenderingView.findRenderingAd(ad)
            })
        }
    }
}
