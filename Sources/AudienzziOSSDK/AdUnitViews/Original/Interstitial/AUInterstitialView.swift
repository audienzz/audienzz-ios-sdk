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
 AUInterstitialView.
 Ad view for demand Interstitial and/or video.
 Lazy load is true by default.
*/
@objcMembers
public class AUInterstitialView: AUAdView {
    internal var adUnit: InterstitialAdUnit!

    /// Asks Prebid for demand. A seam so a test can stand in for Prebid, including the way it
    /// rewrites the request's custom targeting.
    @nonobjc internal var demand: (InterstitialAdUnit, AdManagerRequest, @escaping (ResultCode) -> Void) -> Void = {
        unit, request, completion in unit.fetchDemand(adObject: request, completion: completion)
    }
    internal var gamRequest: AnyObject?
    internal var eventHandler: AUInterstitialHandler?
    internal var gadUnitID: String?

    /// Prebid auction winner (hb_bidder), captured on bid success and reported on adImpression.
    internal var prebidWinningBidder: String?
    /// Winning-bid economics from the last auction, reused on adImpression/adClick/viewability.
    internal var lastRenderEconomics: AURenderEconomics?
    /// SDK-generated auction id, minted at auction start and reused across every event of that
    /// auction (bidRequest → bidResponse/bidWon/noBid → adImpression/adClick/viewability).
    internal var currentAuctionId: String?
    /// Currency + value captured from the GMA paid event (`AdValue`); backfills currency (and cpm)
    /// on the render events, since exact economics aren't on the original API without the fork.
    internal var lastPaidCurrency: String?
    internal var lastPaidCpm: Double?
    /// Full-screen viewability driver (start on present, success after 1s, cancel on dismiss).
    internal var fullScreenViewabilityTimer: AUFullScreenViewabilityTimer?

    /// Video settings for the request: duration, bitrate, protocols, playback and so on.
    /// Its `api` list is ignored — the API frameworks an interstitial advertises are
    /// backend-controlled (see `AUInterstitialCapabilities`).
    public var videoParameters: AUVideoParameters?
    /// Banner settings for the request: sizes and minimum size percentages. Its `api` list is
    /// ignored, like ``videoParameters``'s.
    public var bannerParameters = AUBannerParameters()

    /// Formats and API frameworks this interstitial's requests advertise. A hand-built
    /// interstitial has no ad config, so this is the default unless a bridge that read the ad
    /// config itself hands the backend values over (``setBackendCapabilities(format:apis:)``).
    /// There is no publisher setting for it.
    internal var capabilities = AUInterstitialCapabilities.default

    /**
     Initialize Interstitial view.
     The ad formats and API frameworks it requests are not arguments: they are
     backend-controlled, and a hand-built interstitial asks for banner and video with
     MRAID 1/2/3 + OMID 1.
     */
    public override init(configId: String, isLazyLoad: Bool) {
        super.init(configId: configId, isLazyLoad: isLazyLoad)
        self.adUnit = InterstitialAdUnit(configId: configId)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        capabilities.apply(to: adUnit)
    }

    /**
     Initialize Interstitial view.
     Lazy load is true by default.
     */
    public convenience init(configId: String) {
        self.init(configId: configId, isLazyLoad: true)
    }

    /**
     Initialize Interstitial view with minimum size percentages.
     */
    public convenience init(configId: String, isLazyLoad: Bool, minWidthPerc: Int, minHeightPerc: Int) {
        self.init(configId: configId, isLazyLoad: isLazyLoad)
        self.adUnit = InterstitialAdUnit(configId: configId, minWidthPerc: minWidthPerc, minHeightPerc: minHeightPerc)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
        capabilities.apply(to: adUnit)
    }

    /// Bridge-only: the ad config's raw `prebidConfig.format` / `prebidConfig.apis`, for a bridge
    /// whose remote interstitials read the ad config themselves (Flutter). They are validated
    /// exactly as the native remote interstitial validates them, and take effect on the next
    /// accepted request. Not a publisher setting.
    @_spi(AudienzzBridge)
    public func setBackendCapabilities(format: String?, apis: [Int]?) {
        capabilities = AUInterstitialCapabilities.resolve(format: format, apis: apis)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func removeFromSuperview() {
        super.removeFromSuperview()
        adUnit?.stopAutoRefresh()
        adUnit = nil
        self.eventHandler = nil
    }

    /// Explicitly tears down the ad: stops auto-refresh and releases the Prebid
    /// ad unit and event handler. Prefer this over relying on
    /// `removeFromSuperview` as a destructor. Safe to call more than once.
    public func destroy() {
        fullscreenDemand.destroy()
        adUnit?.stopAutoRefresh()
        adUnit = nil
        self.gamRequest = nil
        self.eventHandler = nil
    }

    deinit {
        self.eventHandler = nil
    }
    
    public func setImpOrtbConfig(ortbConfig: String){
        adUnit.setImpORTBConfig(ortbConfig)
    }
    
    public func getImpOrtbConfig() -> String? {
        return adUnit.getImpORTBConfig()
    }
    
    /**
     Function for prepare and make request for ad. If Lazy load enabled request will be send only when view will appear on screen.
     */
    public func createAd(with gamRequest: AdManagerRequest, adUnitID: String) {
        adUnit.bannerParameters = bannerParameters.makeBannerParameters()
        
        adUnit.videoParameters = self.videoParameters?.unwrap() ?? defaultVideoParameters(placement: .Interstitial, plcmnt: .Interstitial)


        self.gadUnitID = adUnitID
        
        let ppid = PPIDManager.shared.getPPID()
        
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }
        
        self.gamRequest = AUTargeting.shared.customTargetingManager.applyToGamRequest(request: gamRequest)
        
        if !self.isLazyLoad {
            fetchRequest(gamRequest)
        } else {
            #if DEBUG
            // M7: a fullscreen interstitial placeholder has a zero frame, so the
            // visibility-based lazy trigger can only fire if the view is actually
            // added to the hierarchy and scrolled on screen. If it isn't, set
            // isLazyLoad = false so createAd fetches immediately.
            AULogEvent.logDebug("[AUInterstitialView] lazy load enabled — the ad fetches only once this view reaches the viewport. For a standalone interstitial, use isLazyLoad = false.")
            #endif
            loadIfAlreadyVisible()
        }
    }

    public func connectHandler(_ eventHandler: AUInterstitialEventHandler) {
        self.eventHandler = AUInterstitialHandler(handler: eventHandler, adView: self)
    }
    
 }
