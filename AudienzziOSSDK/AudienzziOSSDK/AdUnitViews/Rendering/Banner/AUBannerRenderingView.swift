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
import PrebidMobileGAMEventHandlers

/**
 * AUGAMBannerEventHandler.
 * To create the GAMBannerEventHandler you should provide:
 * a GAM Ad Unit Id the list of available sizes for this ad unit.
*/
@objcMembers
public class AUGAMBannerEventHandler: NSObject {
    var validGADAdSizes: [NSValue]
    let adUnitID: String
    
    public init(adUnitID: String, validGADAdSizes: [NSValue]) {
        self.validGADAdSizes = validGADAdSizes
        self.adUnitID = adUnitID
    }
}

/**
 * AUBannerRenderingView.
 * Ad a view that will display the particular ad. It should be added to the UI.
 * Lazy load is true by default.
*/
@objcMembers
public class AUBannerRenderingView: AUAdView {
    private var bannerView: BannerView!
    
    @objc public weak var delegate: AUBannerRenderingAdDelegate?
    
    // MARK: - Public Properties
    
    @objc public var configID: String {
        bannerView.configID
    }
    
    @objc public var bannerParameters: AUBannerParameters {
        get { AUBannerParameters(with: bannerView.bannerParameters) }
    }
    
    @objc public var videoParameters: AUVideoParameters {
        get { AUVideoParameters(bannerView.videoParameters) }
    }
    
    @objc public var refreshInterval: TimeInterval {
        get { bannerView.refreshInterval }
        set { bannerView.refreshInterval = newValue }
    }
    
    @objc public var additionalSizes: [CGSize]? {
        get { bannerView.additionalSizes }
        set { bannerView.additionalSizes = newValue }
    }
    
    @objc public var adFormat: AUAdFormat {
        get { AUAdFormat(rawValue: bannerView.adFormat.rawValue) }
        set { bannerView.adFormat = AdFormat(rawValue: newValue.rawValue) }
    }
    
    @objc public var adPosition: AUAdPosition {
        get { AUAdPosition(rawValue: bannerView.adPosition.rawValue) ?? .undefined }
        set { bannerView.adPosition = newValue.toAdPosition }
    }
    
    @objc public var ortbConfig: String? {
        get { bannerView.ortbConfig }
        set { bannerView.ortbConfig = newValue }
    }

    /**
     * Initialize banner rendering view.
     * Lazy load is true by default. 
     */
    public init(configId: String, adSize: CGSize, isLazyLoad: Bool = true, eventHandler: AUGAMBannerEventHandler) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        
        let bannerEventHandler = GAMBannerEventHandler(adUnitID: eventHandler.adUnitID,
                                                       validGADAdSizes: eventHandler.validGADAdSizes)
        
        self.bannerView = BannerView(frame: CGRect(origin: .zero, size: adSize),
                                     configID: configId,
                                     adSize: adSize,
                                     eventHandler: bannerEventHandler)
        
        self.adUnitConfiguration = AUBannerRenderingConfiguration(bannerView: bannerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd() {
        bannerView.delegate = self
        
        self.addSubview(bannerView)
        
        if !isLazyLoad {
            delegate?.bannerAdDidDisplayOnScreen?()
            bannerView.loadAd()
        }
    }
    
    /**
     Function for prepare and make request for video ad type. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createVideoAd(with videoParameters: AUVideoParameters) {
        bannerView.adFormat = .video
        
        bannerView.videoParameters.protocols = videoParameters.toProtocols()
        bannerView.videoParameters.playbackMethod = videoParameters.toPlaybackMethods()
        bannerView.videoParameters.placement = videoParameters.placement?.toPlacement
        
        bannerView.videoParameters.api = videoParameters.toApi()
        bannerView.videoParameters.startDelay = videoParameters.startDelay?.toStartDelay
        bannerView.videoParameters.adSize = videoParameters.adSize
        
        bannerView.videoParameters.maxBitrate = videoParameters.toSingleContainerInt(videoParameters.maxBitrate)
        bannerView.videoParameters.minBitrate = videoParameters.toSingleContainerInt(videoParameters.minBitrate)
        bannerView.videoParameters.maxDuration = videoParameters.toSingleContainerInt(videoParameters.maxDuration)
        bannerView.videoParameters.minDuration = videoParameters.toSingleContainerInt(videoParameters.minDuration)
        bannerView.videoParameters.linearity = videoParameters.toSingleContainerInt(videoParameters.linearity)
        
        bannerView.delegate = self
        
        self.backgroundColor = .clear
        self.addSubview(bannerView)
        
        if !isLazyLoad {
            bannerView.loadAd()
        }
    }
    
    internal override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        delegate?.bannerAdDidDisplayOnScreen?()
        bannerView.loadAd()
        isLazyLoaded = true
        #if DEBUG
        print("AUBannerRenderingView --- I'm visible")
        #endif
    }
}

extension AUBannerRenderingView: BannerViewDelegate {
    public func bannerViewPresentationController() -> UIViewController? {
        delegate?.bannerViewPresentationController()
    }
    
    public func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        delegate?.bannerView?(self, didReceiveAdWithAdSize: adSize)
    }

    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        delegate?.bannerView?(self, didFailToReceiveAdWith: error)
    }

    public func bannerViewWillLeaveApplication(_ bannerView: BannerView) {
        delegate?.bannerViewWillLeaveApplication?(self)
    }

    public func bannerViewWillPresentModal(_ bannerView: BannerView) {
        delegate?.bannerViewWillPresentModal?(self)
    }

    public func bannerViewDidDismissModal(_ bannerView: BannerView) {
        delegate?.bannerViewDidDismissModal?(self)
    }
}
