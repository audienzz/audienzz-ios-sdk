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

final class RemoteConfigViewController: UIViewController {
    private enum Constants {
        static let fixedBannerConfigId = "192"

        static let inlineAdaptiveConfigId = "118"

        static let interstitialConfigId = "267"

        static let horizontalInset: CGFloat = 16
    }

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!

    private let stackView = UIStackView()

    private let fixedBannerContainer = UIView()
    private let adaptiveBannerContainer = UIView()

    private var interstitial: AURemoteConfigInterstitial?

    private let loremLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.text = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
        Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
        
                Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
                Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
        
                Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
                Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
        
        """
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupUI()
        loadBanners()
    }

    // MARK: - Layout

    private func setupLayout() {
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalInset),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalInset)
        ])
    }

    // MARK: - UI

    private func setupUI() {
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        stackView.distribution = .fill

        fixedBannerContainer.translatesAutoresizingMaskIntoConstraints = false
        adaptiveBannerContainer.translatesAutoresizingMaskIntoConstraints = false

        fixedBannerContainer.backgroundColor = .clear
        adaptiveBannerContainer.backgroundColor = .clear

        stackView.addArrangedSubview(fixedBannerContainer)
        stackView.addArrangedSubview(loremLabel)
        stackView.addArrangedSubview(adaptiveBannerContainer)

        setupInterstitialButton()
    }

    private func setupInterstitialButton() {
        let interstitialButton = UIButton(type: .system)

        interstitialButton.setTitle("Load Interstitial", for: .normal)
        interstitialButton.setTitleColor(.white, for: .normal)
        interstitialButton.setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)

        interstitialButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)

        interstitialButton.backgroundColor = .systemGray
        interstitialButton.layer.cornerRadius = 12

        interstitialButton.addTarget(
            self,
            action: #selector(loadInterstitialTapped),
            for: .touchUpInside
        )
        stackView.addArrangedSubview(interstitialButton)
    }

    // MARK: - Ads

    private func loadBanners() {
        loadFixedBanner()
        loadAdaptiveBanner()
    }

    private func loadFixedBanner() {
        let banner = AURemoteConfigBannerView(
            adConfigId: Constants.fixedBannerConfigId
        )

        banner.load(
            in: fixedBannerContainer,
            size: CGSize(width: 300, height: 600),
            rootViewController: self
        )
    }

    private func loadAdaptiveBanner() {
        let banner = AURemoteConfigBannerView(
            adConfigId: Constants.inlineAdaptiveConfigId
        )

        banner.load(
            in: adaptiveBannerContainer,
            rootViewController: self,
            delegate: self
        )
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

// MARK: - FullScreenContentDelegate

extension RemoteConfigViewController: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial failed to present: \(error)")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial dismissed")
    }
}

// MARK: - BannerViewDelegate

extension RemoteConfigViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("bannerViewDidReceiveAd \(bannerView.frame.size)")
        adaptiveBannerContainer.heightAnchor.constraint(
            equalToConstant: bannerView.frame.height
        ).isActive = true
    }
}
