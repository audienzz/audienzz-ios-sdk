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

// MARK: - Multiplatform
fileprivate let storedPrebidImpressions = ["prebid-demo-banner-300-250", "prebid-demo-banner-native-styles"]
fileprivate let gamRenderingMultiformatAdUnitId = "/21808260008/prebid-demo-multiformat-native-styles"

extension ExamplesViewController {
    func createMultiplatformView() {
        let configId = storedPrebidImpressions[1]
        
        let bannerParameters = AUBannerParameters()
        bannerParameters.api = [AUApi(apiType: .MRAID_2)]
        bannerParameters.adSizes = [adSize]
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols.VAST_2_0]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AUPlacement.InBanner
        videoParameters.adSize = adSize
        
        let nativeParameters = nativeParameters()
        
        multiformatView = AUMultiplatformView(configId: configId, isLazyLoad: false,
                                              bannerParameters: bannerParameters, videoParameters: videoParameters, nativeParameters: nativeParameters)
        multiformatView.frame = CGRect(x: 0, y: getPositionY(adContainerView), width: 320, height: 250)
        multiformatView.backgroundColor = .clear
        
        adContainerView.addSubview(multiformatView)
        
        let gamRequest = GAMRequest()
        multiformatView.create(with: gamRequest)
        
        multiformatView.onLoadRequest = { [weak self] request in
            guard let self = self, let updateRequest = request as? GADRequest else { return }
            
            // 5. Configure and make a GAM ad request
            self.adMultiLoader = GADAdLoader(adUnitID: gamRenderingMultiformatAdUnitId, rootViewController: self,
                                        adTypes: [GADAdLoaderAdType.customNative, GADAdLoaderAdType.gamBanner], options: [])
            self.adMultiLoader.delegate = self
            self.adMultiLoader.load(updateRequest)
        }
    }
    
    func createMultiplatformLazyView() {
        let configId = storedPrebidImpressions[0]
        
        let bannerParameters = AUBannerParameters()
        bannerParameters.api = [AUApi(apiType: .MRAID_2)]
        bannerParameters.adSizes = [adSize]
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols.VAST_2_0]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = AUPlacement.InBanner
        videoParameters.adSize = adSize
        
        let nativeParameters = nativeParameters()
        
        multiformatLazyView = AUMultiplatformView(configId: configId,
                                                  bannerParameters: bannerParameters,
                                                  videoParameters: videoParameters, nativeParameters: nativeParameters)
        multiformatLazyView.frame = CGRect(x: 0, y: getPositionY(lazyAdContainerView), width: 320, height: 250)
        multiformatLazyView.backgroundColor = .clear
        
        lazyAdContainerView.addSubview(multiformatLazyView)
        
        let gamRequest = GAMRequest()
        multiformatLazyView.create(with: gamRequest)
        
        multiformatLazyView.onLoadRequest = { [weak self] request in
            guard let self = self, let updateRequest = request as? GADRequest else { return }
            
            // 5. Configure and make a GAM ad request
            self.adLazyMultiLoader = GADAdLoader(adUnitID: gamRenderingMultiformatAdUnitId, rootViewController: self,
                                                 adTypes: [GADAdLoaderAdType.customNative, GADAdLoaderAdType.gamBanner], options: [])
            self.adLazyMultiLoader.delegate = self
            self.adLazyMultiLoader.load(updateRequest)
        }
    }
    
    fileprivate func nativeParameters() -> AUNativeRequestParameter {
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

extension ExamplesViewController: GAMBannerAdLoaderDelegate {
    func validBannerSizes(for adLoader: GADAdLoader) -> [NSValue] {
        return [NSValueFromGADAdSize(GADAdSizeFromCGSize(adSize))]
    }
    
    func adLoader(_ adLoader: GADAdLoader, didReceive bannerView: GAMBannerView) {
        if adLoader == adMultiLoader {
            self.multiformatView.addSubview(bannerView)
            
            AUAdViewUtils.findCreativeSize(bannerView, success: { [weak self] size in
                bannerView.resize(GADAdSizeFromCGSize(size))
                guard let self = self else { return }
//                self.updatesize(fromView: self.multiformatView, parent: self.adContainerView, size: size)
            }, failure: { (error) in
                print("Error occuring during searching for Prebid creative size: \(error)")
            })
        } else if adLoader == adLazyMultiLoader {
            self.multiformatLazyView.addSubview(bannerView)
            
            AUAdViewUtils.findCreativeSize(bannerView, success: { [weak self] size in
                bannerView.resize(GADAdSizeFromCGSize(size))
                guard let self = self else { return }
//                self.updatesize(fromView: self.multiformatLazyView, parent: self.lazyAdContainerView, size: size)
            }, failure: { (error) in
                print("Error occuring during searching for Prebid creative size: \(error)")
            })
        }
    }
    
    private func updatesize(fromView: UIView, parent: UIView, size: CGSize) {
        fromView.frame = CGRect(x: fromView.frame.origin.x, y: fromView.frame.origin.y, width: size.width, height: size.height)
        
        //update y positions
        
        let parentSubviews = parent.subviews
        var maxYPostion: CGFloat = 0
        
        for subview in parentSubviews {
            subview.frame = CGRect(x: fromView.frame.origin.x, y: maxYPostion, width: subview.frame.size.width, height: subview.frame.size.height)
            maxYPostion = subview.frame.origin.y + subview.frame.height
        }
    }
}
