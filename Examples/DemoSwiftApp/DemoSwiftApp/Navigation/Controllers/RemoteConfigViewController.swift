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
        static let fixedBannerConfigId = 192

        static let inlineAdaptiveConfigId = 118

        static let interstitialConfigId = 267
    }

    // MARK: - IBOutlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var stackView: UIStackView!

    // Ad display
    @IBOutlet private weak var adContainerView: UIView!

    private var interstitial: AURemoteConfigInterstitial?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func setupLayout() {
        stackView.removeFromSuperview()
        adContainerView.removeFromSuperview()

        scrollView.isHidden = true
        
        view.addSubview(stackView)
        view.addSubview(adContainerView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        adContainerView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 10

        stackView.setContentHuggingPriority(.required, for: .vertical)
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)

        adContainerView.setContentHuggingPriority(.defaultLow, for: .vertical)
        adContainerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        adContainerView.backgroundColor = .secondarySystemBackground
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            adContainerView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            adContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            adContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            adContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupUI() {
        let fixedBannerButton = UIButton(type: .system)
        fixedBannerButton.setTitle("Load Fixed Banner", for: .normal)
        fixedBannerButton.addTarget(self, action: #selector(loadFixedBannerTapped), for: .touchUpInside)
        stackView.addArrangedSubview(fixedBannerButton)
        
        let adaptiveBannerButton = UIButton(type: .system)
        adaptiveBannerButton.setTitle("Load Adaptive Banner", for: .normal)
        adaptiveBannerButton.addTarget(self, action: #selector(loadAdaptiveBannerTapped), for: .touchUpInside)
        stackView.addArrangedSubview(adaptiveBannerButton)
        
        let interstitialButton = UIButton(type: .system)
        interstitialButton.setTitle("Load Interstitial", for: .normal)
        interstitialButton.addTarget(self, action: #selector(loadInterstitialTapped), for: .touchUpInside)
        stackView.addArrangedSubview(interstitialButton)
    }

    private func loadBanner(configId: Int) {
        adContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        let bannerView = AURemoteConfigBannerView(adConfigId: configId)
        bannerView.load(in: adContainerView,
                        rootViewController: self)
    }
    
    @objc private func loadFixedBannerTapped() {
        loadBanner(configId: Constants.fixedBannerConfigId)
    }
    
    @objc private func loadAdaptiveBannerTapped() {
        loadBanner(configId: Constants.inlineAdaptiveConfigId)
    }
    
    @objc private func loadInterstitialTapped() {
        interstitial = AURemoteConfigInterstitial(adConfigId: Constants.interstitialConfigId)
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
