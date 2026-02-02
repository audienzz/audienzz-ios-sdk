//
//  AURemoteConfigInterstitial.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 20.11.2025.
//

import UIKit
import PrebidMobile
import GoogleMobileAds

public enum AURemoteConfigInterstitialError: Error {
    case noRemoteConfig
}
/**
 AURemoteConfigInterstitial.
 Interstitial ad controller based on the remote configuration.
 */
@objcMembers
public class AURemoteConfigInterstitial: NSObject {
    private let adConfigId: String
    private var interstitialAdUnit: InterstitialAdUnit?
    private var gamInterstitialAd: AdManagerInterstitialAd?
    
    /// Delegate for handling ad presentation events (show, dismiss, fail to show).
    public weak var delegate: FullScreenContentDelegate?

    public init(adConfigId: String) {
        self.adConfigId = adConfigId
        super.init()
    }
    
    /// Returns true if the ad is loaded and ready to be shown.
    public var isReady: Bool {
        return gamInterstitialAd != nil
    }
    
    /// Starts loading the interstitial ad.
    /// - Parameter completion: A closure to be executed when the ad loading completes. Returns success or failure error.
    public func load(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let remoteConfig = AudienzzRemoteConfig.shared.remoteConfig(for: adConfigId) else {
            AULogEvent.logDebug("[AURemoteConfigInterstitial] Remote config is nil for id: \(adConfigId)")
            completion(.failure(AURemoteConfigInterstitialError.noRemoteConfig))
            return
        }

        interstitialAdUnit = InterstitialAdUnit(configId: remoteConfig.prebidConfig.placementId)
        interstitialAdUnit?.adFormats = [.banner, .video]

        let gamRequest = AdManagerRequest()
        let ppid = PPIDManager.shared.getPPID()
        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }

        interstitialAdUnit?.fetchDemand(adObject: gamRequest) { [weak self] result in
            guard let self = self else { return }

            AdManagerInterstitialAd.load(
                with: remoteConfig.gamConfig.adUnitPath,
                request: gamRequest
            ) { [weak self] ad, error in
                guard let self = self else { return }
                
                if let error = error {
                    AULogEvent.logDebug("[AURemoteConfigInterstitial] Failed to load interstitial: \(error)")
                    completion(.failure(error))
                    return
                }
                
                self.gamInterstitialAd = ad
                completion(.success(()))
            }
        }
    }
    
    @objc public func loadWithCompletion(_ completion: @escaping (Error?) -> Void) {
        load { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    /// Presents the interstitial ad from the specified view controller.
    /// - Parameter rootViewController: The view controller to present the ad from.
    public func show(from rootViewController: UIViewController) {
        guard let ad = gamInterstitialAd else {
            AULogEvent.logDebug("[AURemoteConfigInterstitial] Ad not ready to show")
            return
        }

        ad.fullScreenContentDelegate = delegate
        ad.present(from: rootViewController)
    }
}
