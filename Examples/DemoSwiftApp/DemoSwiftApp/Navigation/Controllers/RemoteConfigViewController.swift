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
        DemoPageReporting.report(self)
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
        DemoPageReporting.report(self)
        banner.load(in: bannerContainer, rootViewController: self)
    }

    deinit {
        banner.destroy()
    }
}

/// Demo navigation state. Every destination (including the ad-free menu) reports here;
/// reappearing beneath a dismissed interstitial is still the same visit.
enum DemoPageReporting {
    private static weak var current: UIViewController?
    static func report(_ screen: UIViewController) {
        guard current !== screen else { return }
        current = screen
        Audienzz.shared.pageImpression(screen)
    }
    static func rewardedOpened() { current = nil }
}

// MARK: - ePaper (gallery ads)

/// An ePaper: one page per printed page, swiped horizontally, with ad pages 5 and 13.
/// `AUGalleryAds` requests each ad when the reader is within the ad config's
/// `config.preloadDistancePages` (2 by default) of it — not when the screen opens, not when the
/// page's cell is built. Tap a printed page to open its article, then go back: the ad is kept,
/// not reloaded. Follow it with diagnostics: `AUDZ gallery preload …`.
final class GalleryAdsViewController: UIViewController, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout, AUGalleryAdsDelegate {

    private static let pageCount = 16
    private let slots = [
        AUGalleryAdSlot(slotKey: "epaper-1", adConfigId: "46", pageIndex: 4),
        AUGalleryAdSlot(slotKey: "epaper-2", adConfigId: "46", pageIndex: 12),
    ]
    private lazy var galleryAds = AUGalleryAds(slots: slots, rootViewController: self)
    private var slotStatus: [String: String] = [:]
    private let statusLabel = UILabel()
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.isPagingEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .systemBackground
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "page")
        view.dataSource = self
        view.delegate = self
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ePaper (gallery ads)"
        view.backgroundColor = .systemBackground
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 13)
        let stack = UIStackView(arrangedSubviews: [statusLabel, collectionView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        galleryAds.delegate = self
        renderStatus(page: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DemoPageReporting.report(self)
        galleryAds.updatePosition(currentPage)
    }

    deinit {
        MainActor.assumeIsolated { galleryAds.destroy() }
    }

    private var currentPage: CGFloat {
        let width = collectionView.bounds.width
        return width > 0 ? collectionView.contentOffset.x / width : 0
    }

    private func renderStatus(page: Int) {
        statusLabel.text = "  Page \(page + 1)/\(Self.pageCount) · ads on pages 5 and 13 · "
            + slots.map { "\($0.slotKey): \(slotStatus[$0.slotKey] ?? "not requested")" }.joined(separator: " · ")
    }

    private func setStatus(_ slotKey: String, _ value: String) {
        slotStatus[slotKey] = value
        renderStatus(page: Int(currentPage.rounded()))
    }

    // MARK: AUGalleryAdsDelegate

    func galleryAds(_ galleryAds: AUGalleryAds, didCreateAdViewFor slotKey: String) {
        setStatus(slotKey, "requested")
        if let slot = slots.first(where: { $0.slotKey == slotKey }) {
            collectionView.reloadItems(at: [IndexPath(item: slot.pageIndex, section: 0)])
        }
    }

    func galleryAds(_ galleryAds: AUGalleryAds, didLoadAdFor slotKey: String) { setStatus(slotKey, "loaded") }

    func galleryAds(_ galleryAds: AUGalleryAds, didFailToLoadAdFor slotKey: String, error: Error?) {
        setStatus(slotKey, error == nil ? "no config" : "failed")
    }

    // MARK: Paging

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        galleryAds.updatePosition(currentPage)
        renderStatus(page: Int(currentPage.rounded()))
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Self.pageCount
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "page", for: indexPath)
        // A reused cell may hold another page's content or a gallery ad's host view; the gallery
        // takes its host back on the next embed, so only our own labels are cleared here.
        cell.contentView.subviews.filter { $0 is UILabel }.forEach { $0.removeFromSuperview() }
        if let slot = slots.first(where: { $0.pageIndex == indexPath.item }) {
            cell.contentView.backgroundColor = .systemBackground
            if !galleryAds.embed(slot.slotKey, in: cell.contentView) {
                addLabel("Ad not loaded yet", to: cell)
            }
        } else {
            // A page cell must not keep a gallery host it was reused from.
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.contentView.backgroundColor = UIColor(white: 0.93, alpha: 1)
            addLabel("Printed page \(indexPath.item + 1)\n(tap for the article)", to: cell)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !slots.contains(where: { $0.pageIndex == indexPath.item }) else { return }
        navigationController?.pushViewController(GalleryArticleViewController(page: indexPath.item + 1), animated: true)
    }

    private func addLabel(_ text: String, to cell: UICollectionViewCell) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 22)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        ])
    }
}

/// The mobile article view opened from a printed page: its own page, ad-free.
final class GalleryArticleViewController: UIViewController {
    private let page: Int

    init(page: Int) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Article from page \(page)"
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.numberOfLines = 0
        label.text = "Go back: the ePaper ad you saw is still there, no new request."
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DemoPageReporting.report(self)
    }
}
