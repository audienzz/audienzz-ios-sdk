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
    private let interstitialStatusLabel = UILabel()

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
        // A nav button under EVERY ad slot, matching the Android example: the screen-navigation
        // test is about what happens to THAT banner when you leave and come back, so the button has
        // to be reachable while the slot it concerns is on screen.
        stackView.insertArrangedSubview(
            makeButton("Open ad screen (from fixed banner)", color: .systemBlue,
                       action: #selector(openAdScreenTapped)),
            at: stackView.arrangedSubviews.firstIndex(of: loremLabel) ?? 1
        )
        stackView.addArrangedSubview(
            makeButton("Open ad screen (from adaptive banner)", color: .systemBlue,
                       action: #selector(openAdScreenTapped))
        )

        // One button per verb, so each can be exercised on its own. A single button that both
        // fetched and showed could not tell you which half misbehaved, and hid the fact that
        // `prefetch` must never present by itself — which the status line now makes visible.
        let header = UILabel()
        header.text = "Interstitial"
        header.font = .systemFont(ofSize: 13, weight: .bold)
        stackView.addArrangedSubview(header)

        interstitialStatusLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        interstitialStatusLabel.textColor = .secondaryLabel
        interstitialStatusLabel.numberOfLines = 0
        interstitialStatusLabel.text = "not loaded"
        stackView.addArrangedSubview(interstitialStatusLabel)

        stackView.addArrangedSubview(
            makeButton("Prefetch", color: .systemGray, action: #selector(prefetchTapped)))
        stackView.addArrangedSubview(
            makeButton("Show", color: .systemGray, action: #selector(showTapped)))
        stackView.addArrangedSubview(
            makeButton("Prefetch and show", color: .systemGray,
                       action: #selector(prefetchAndShowTapped)))
    }

    private func makeButton(_ title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setInterstitialStatus(_ text: String) {
        interstitialStatusLabel.text = text
        print("[Interstitial] \(text)")
    }

    /// Built once and kept, so `prefetch` then `show` act on the same ad — rebuilding between the
    /// two would throw away the inventory the prefetch just paid for.
    private func ensureInterstitial() -> AURemoteConfigInterstitial {
        if let interstitial { return interstitial }
        let ad = AURemoteConfigInterstitial(adConfigId: Constants.interstitialConfigId)
        ad.delegate = self
        ad.presentationViewController = self
        ad.onPresentationError = { [weak self] error in
            self?.setInterstitialStatus("error: \(error)")
        }
        interstitial = ad
        return ad
    }

    @objc private func prefetchTapped() {
        setInterstitialStatus("loading…")
        ensureInterstitial().prefetch { [weak self] result in
            switch result {
            case .success:
                // Deliberately does NOT present: a prefetch never surprises the reader with an ad.
                self?.setInterstitialStatus("ready to show")
            case .failure(let error):
                self?.setInterstitialStatus("load failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func showTapped() {
        let ad = ensureInterstitial()
        guard ad.isReady else {
            // Reported rather than silently queued: `show` takes an opportunity or skips it.
            setInterstitialStatus("not ready — nothing to show (prefetch first)")
            return
        }
        if !ad.show(from: self, eligible: true) {
            setInterstitialStatus("opportunity skipped")
        }
    }

    @objc private func prefetchAndShowTapped() {
        setInterstitialStatus("loading… (will show when ready)")
        ensureInterstitial().prefetchAndShow(from: self) { [weak self] result in
            if case .failure(let error) = result {
                self?.setInterstitialStatus("failed: \(error.localizedDescription)")
            }
        }
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

}

// MARK: - FullScreenContentDelegate

extension RemoteConfigViewController: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        setInterstitialStatus("showing")
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        setInterstitialStatus("failed to show: \(error.localizedDescription)")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Inventory is spent on presentation, so the slot really is empty again.
        setInterstitialStatus("closed — not loaded")
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

        // Directly under the ad, matching the Android example: leaving is half of the test, and a
        // tester should not have to hunt for the back gesture to perform it.
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close (back to Remote Config)", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.backgroundColor = .systemBlue
        closeButton.layer.cornerRadius = 12
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        view.addSubview(bannerContainer)
        view.addSubview(closeButton)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            bannerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            bannerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bannerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bannerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            closeButton.topAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            label.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

    }

    @objc private func closeTapped() {
        // The same transition as the back gesture, just discoverable. Popping is what makes the
        // Remote Config screen current again, which is the half of this test that matters.
        navigationController?.popViewController(animated: true)
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
