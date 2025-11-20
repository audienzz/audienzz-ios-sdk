//
//  RemoteConfigViewController.swift
//  DemoSwiftApp
//
//  Created by Maksym Ovcharuk on 27.10.2025.
//

import AudienzziOSSDK
import GoogleInteractiveMediaAds
import GoogleMobileAds
import UIKit

class RemoteConfigViewController: UIViewController {
    private enum Constants {
        static let inlineAdaptiveConfigId = 118
    }

    // MARK: - IBOutlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var stackView: UIStackView!

    // Ad display
    @IBOutlet private weak var adContainerView: UIView!

    private var interstitial: AURemoteConfigInterstitial?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requestAd()
        requestInterstitial()
    }

    func requestAd() {
        adContainerView.subviews.forEach { $0.removeFromSuperview() }

        let bannerView = AURemoteConfigBannerView(adConfigId: Constants.inlineAdaptiveConfigId)
        bannerView.load(in: adContainerView,
                        rootViewController: self)
    }
    
    func requestInterstitial() {
        // Example config ID for interstitial, assuming one exists or using a placeholder
        // Since I don't have a specific ID for interstitial in the prompt, I'll use a placeholder or reuse one if appropriate.
        // However, to be safe and follow the "Prebid settings without knowing implementation details"
        // I will assume there is an ID for it.
        // Let's use a hypothetical ID 123 for now, or better, add a button to trigger it.
        
        let button = UIButton(type: .system)
        button.setTitle("Load Interstitial", for: .normal)
        button.addTarget(self, action: #selector(loadInterstitialTapped), for: .touchUpInside)
        stackView.addArrangedSubview(button)
    }
    
    @objc private func loadInterstitialTapped() {
        // Using a hypothetical config ID for interstitial.
        // In a real scenario, this would be a valid ID from the backend.
        let interstitialConfigId = 1337
        interstitial = AURemoteConfigInterstitial(adConfigId: interstitialConfigId)
        interstitial?.delegate = self
        
        print("Loading interstitial...")
        interstitial?.load { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                print("Interstitial loaded, showing...")
                self.interstitial?.show(from: self)
            case .failure(let error):
                print("Failed to load interstitial: \(error)")
            }
        }
    }
}

extension RemoteConfigViewController: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial failed to present: \(error)")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial dismissed")
    }
}
