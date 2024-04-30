//
//  AUInstreamView.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 08.04.2024.
//

import UIKit
import PrebidMobile

public typealias Keywords = [String: String]

@objcMembers
public class AUInstreamView: AUAdView {
    // Prebid
    private var adUnit: InstreamVideoAdUnit!
    private var customKeywords: Keywords?
    /**
     VideoParameters..
     If will be nill. Automatically create default video parameters
     
     # Example #
     *   AUVideoParameters(mimes: ["video/mp4"])
     * protocols = [AdVideoParameters.Protocols.VAST_2_0]
     * playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
     * placement = AdVideoParameters.Placement.InBanner
     */
    public var parameters: AUVideoParameters?
    public var onLoadInstreamRequest: (([String: String]?) -> Void)?
    
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        onLoadInstreamRequest?(customKeywords)
        isLazyLoaded = true
        #if DEBUG
        print("AUInstreamView --- I'm visible")
        #endif
    }
    
    public func createAd(size: CGSize) {
        adUnit = InstreamVideoAdUnit(configId: configId, size: size)
        
        let parameters = fillVideoParams(parameters)
        adUnit.videoParameters = parameters
        
        adUnit.fetchDemand { [weak self] bidInfo in
            guard let self = self else { return }
            if bidInfo.resultCode == .prebidDemandFetchSuccess {
                if !self.isLazyLoad {
                    self.customKeywords = bidInfo.targetingKeywords
                    self.onLoadInstreamRequest?(bidInfo.targetingKeywords)
                }
            }
        }
    }
}
