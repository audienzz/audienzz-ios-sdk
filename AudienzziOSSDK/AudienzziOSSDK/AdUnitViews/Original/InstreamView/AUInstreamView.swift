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
    
    public override init(configId: String, adSize: CGSize) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: true)
        adUnit = InstreamVideoAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    public override init(configId: String, adSize: CGSize, isLazyLoad: Bool) {
        super.init(configId: configId, adSize: adSize, isLazyLoad: isLazyLoad)
        adUnit = InstreamVideoAdUnit(configId: configId, size: adSize)
        self.adUnitConfiguration = AUAdUnitConfiguration(adUnit: adUnit)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func createAd(size: CGSize) {
        let parameters = fillVideoParams(parameters)
        adUnit.videoParameters = parameters
        
        if !self.isLazyLoad {
            fetchRequest()
        }
    }
    
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded  else {
            return
        }

        fetchRequest()
        isLazyLoaded = true
        #if DEBUG
        print("AUInstreamView --- I'm visible")
        #endif
    }
    
    func fetchRequest() {
        adUnit.fetchDemand { [weak self] bidInfo in
            guard let self = self, let resultCode = AUResultCode(rawValue: bidInfo.resultCode.rawValue) else { return }
            if resultCode == .audienzzDemandFetchSuccess {
                self.customKeywords = bidInfo.targetingKeywords
                self.onLoadInstreamRequest?(bidInfo.targetingKeywords)
            }
        }
    }
}
