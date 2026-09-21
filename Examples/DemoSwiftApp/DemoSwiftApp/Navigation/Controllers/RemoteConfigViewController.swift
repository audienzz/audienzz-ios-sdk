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
        static let fixedBannerConfigId = "46"

        static let inlineAdaptiveConfigId = "46"

        static let interstitialConfigId = "47"

        static let horizontalInset: CGFloat = 16
    }

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!

    private let stackView = UIStackView()

    private let fixedBannerContainer = UIView()
    private let adaptiveBannerContainer = UIView()

    // load(in:) mounts the inner ad, not its remote-config owner. Keep each owner for the
    // screen's lifetime so its asynchronous Google-load and sizing callbacks remain valid.
    private let fixedBanner = AURemoteConfigBannerView(adConfigId: Constants.fixedBannerConfigId)
    private let adaptiveBanner = AURemoteConfigBannerView(adConfigId: Constants.inlineAdaptiveConfigId)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Track the screen visit for analytics (fires `pageImpression` and a fresh page-impression
        // id that ties this screen's ad events together). Call it before ads load.
        Audienzz.shared.pageImpression(self)
        // Identical loads coalesce. On a return visit pageImpression reactivates the existing ads.
        loadBanners()
    }

    deinit {
        fixedBanner.destroy()
        adaptiveBanner.destroy()
        interstitial?.destroy()
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

        interstitialButton.setTitle("Preload / show interstitial", for: .normal)
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

        let openScreenButton = UIButton(type: .system)
        openScreenButton.setTitle("Open ad screen (test screen nav)", for: .normal)
        openScreenButton.setTitleColor(.white, for: .normal)
        openScreenButton.setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
        openScreenButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        openScreenButton.backgroundColor = .systemBlue
        openScreenButton.layer.cornerRadius = 12
        openScreenButton.addTarget(self, action: #selector(openAdScreenTapped), for: .touchUpInside)
        stackView.addArrangedSubview(openScreenButton)
    }

    @objc private func openAdScreenTapped() {
        navigationController?.pushViewController(
            RemoteConfigAdScreenViewController(), animated: true)
    }

    // MARK: - Ads

    private func loadBanners() {
        loadFixedBanner()
        loadAdaptiveBanner()
    }

    private func loadFixedBanner() {
        fixedBanner.load(
            in: fixedBannerContainer,
            rootViewController: self,
            delegate: self
        )
    }

    private func loadAdaptiveBanner() {
        adaptiveBanner.load(
            in: adaptiveBannerContainer,
            rootViewController: self,
            delegate: self
        )
    }

    @objc private func loadInterstitialTapped() {
        if let interstitial, interstitial.isReady {
            _ = interstitial.show(from: self, eligible: true)
            return
        }
        if interstitial == nil {
            interstitial = AURemoteConfigInterstitial(adConfigId: Constants.interstitialConfigId)
        }
        interstitial?.delegate = self
        interstitial?.presentationViewController = self
        interstitial?.onPresentationError = { print("Interstitial presentation failed: \($0)") }

        print("Loading interstitial...")
        interstitial?.prefetch { result in
            switch result {
            case .success:
                print("Interstitial ready. Tap again at the intended transition to show.")
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
        // The remote banner owns its container's height and updates it when Google changes size.
    }
}

/// A separate screen with a remote-config banner, pushed from the Remote Config screen. Navigating
/// here and back exercises screen-navigation pause/resume/reload and ad↔screen matching. Each
/// screen reports its own page before loading ads; screen tracking is explicit.
final class RemoteConfigAdScreenViewController: UIViewController {
    private let banner = AURemoteConfigBannerView(adConfigId: "46")
    private let bannerContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Remote Config Ad Screen"
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.text = "Navigate back to verify the Remote Config screen's banners reload, and that "
            + "this screen's banner pauses/reloads on screen changes."
        label.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerContainer)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            bannerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            bannerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bannerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bannerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            label.topAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Audienzz.shared.pageImpression(self)
        banner.load(in: bannerContainer, rootViewController: self)
    }

    deinit {
        banner.destroy()
    }
}
