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

fileprivate let adTypeString = "BANNER"
fileprivate let apiTypeString = "RENDERING"

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
    internal var bannerView: BannerView!
    
    @objc public weak var delegate: AUBannerRenderingAdDelegate?
    
    internal var subdelegate: AUBannerRenderingDelegateType?
    internal var eventHandler: AUGAMBannerEventHandler?
    
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
    
    @objc public func setVideoParameters(_ videoParameters: AUVideoParameters) {
        setupVideoParameters(videoParameters)
    }

    /**
     * Initialize banner rendering view.
     * Lazy load is true by default. Format is HTML-banner as default
     */
    public init(configId: String,
                adSize: CGSize,
                format: AUAdFormat = .banner,
                isLazyLoad: Bool = true,
                eventHandler: AUGAMBannerEventHandler) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.eventHandler = eventHandler
        let bannerEventHandler = GAMBannerEventHandler(adUnitID: eventHandler.adUnitID,
                                                       validGADAdSizes: eventHandler.validGADAdSizes)
        
        self.bannerView = BannerView(frame: CGRect(origin: .zero, size: adSize),
                                     configID: configId,
                                     adSize: adSize,
                                     eventHandler: bannerEventHandler)
        
        self.adUnitConfiguration = AUBannerRenderingConfiguration(bannerView: bannerView)
        self.subdelegate = AUBannerRenderingDelegateType(parent: self)
        
        bannerView.adFormat = format == .video ? .video : .banner
        
        self.makeCreationEvent(format, eventHandler: eventHandler)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen. 
     If you use VIDEO please use 'setVideoParameters' method befrore.
     */
    public func createAd() {
        bannerView.delegate = subdelegate
        
        self.addSubview(bannerView)
        
        if !isLazyLoad {
            delegate?.bannerAdDidDisplayOnScreen?()
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

internal class AUBannerRenderingDelegateType: NSObject, BannerViewDelegate {
    private weak var parent: AUBannerRenderingView?
    
    init(parent: AUBannerRenderingView) {
        super.init()
        self.parent = parent
    }
    
    public func bannerViewPresentationController() -> UIViewController? {
        parent?.delegate?.bannerViewPresentationController()
    }
    
    public func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        guard let parent = parent else { return } // LOAD
        parent.delegate?.bannerView?(parent, didReceiveAdWithAdSize: adSize)
    }

    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        guard let parent = parent else { return }
        makeErrorEvent(parent: parent, error)
        parent.delegate?.bannerView?(parent, didFailToReceiveAdWith: error)
    }

    public func bannerViewWillLeaveApplication(_ bannerView: BannerView) {
        guard let parent = parent else { return }
        //open safery - leave app
        parent.delegate?.bannerViewWillLeaveApplication?(parent)
    }

    public func bannerViewWillPresentModal(_ bannerView: BannerView) {
        guard let parent = parent else { return }
        makeClickEvent(parent)
        parent.delegate?.bannerViewWillPresentModal?(parent)
    }

    public func bannerViewDidDismissModal(_ bannerView: BannerView) {
        guard let parent = parent else { return }
        makeCloseEvent(parent)
        parent.delegate?.bannerViewDidDismissModal?(parent)
    }
    
    private func makeCloseEvent(_ parent: AUBannerRenderingView) {
        let event = AUCloseAdEvent(adViewId: parent.configId, adUnitID: parent.eventHandler?.adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeClickEvent(_ parent: AUBannerRenderingView) {
        let event = AUAdClickEvent(adViewId: parent.configId, adUnitID: parent.eventHandler?.adUnitID ?? "")
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    private func makeErrorEvent(parent: AUBannerRenderingView, _ error: Error) {
        let event = AUFailedLoadEvent(adViewId: parent.configId,
                                      adUnitID: parent.eventHandler?.adUnitID ?? "",
                                      errorMessage: error.localizedDescription,
                                      errorCode: error.errorCode ?? -1)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}

fileprivate extension AUBannerRenderingView {
    func makeCreationEvent(_ format: AUAdFormat, eventHandler: AUGAMBannerEventHandler) {
        let event = AUAdCreationEvent(adViewId: configId,
                                      adUnitID: eventHandler.adUnitID,
                                      size: "\(adSize.width)x\(adSize.height)",
                                      adType: adTypeString,
                                      adSubType: format == .banner ? "HTML" : "VIDEO",
                                      apiType: apiTypeString)
        
        guard let payload = event.convertToJSONString() else { return }
        
        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
    
    func setupVideoParameters(_ videoParameters: AUVideoParameters) {
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
    }
}
