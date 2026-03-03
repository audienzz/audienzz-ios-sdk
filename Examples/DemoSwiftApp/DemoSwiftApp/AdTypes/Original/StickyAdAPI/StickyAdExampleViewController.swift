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
import AudienzziOSSDK
import GoogleMobileAds

private let kConfigId = "prebid-demo-banner-300-250"
private let kAdUnitId = "ca-app-pub-3940256099942544/6300978111"
private let kAdSize = CGSize(width: 300, height: 250)
private let kMaxHeight: CGFloat = 450

/// Demonstrates ``AUStickyAdWrapperView`` behaviour.
///
/// Scroll through the article-like content — the 300×250 banner stays pinned
/// to the top of its reserved area as you scroll past it, then slides out at
/// the bottom exactly like the Flutter `AudienzzStickyAdWrapper`.
final class StickyAdExampleViewController: UIViewController {

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private var stickyWrapper: AUStickyAdWrapperView?
    private var bannerView: AUBannerView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sticky Ad"
        view.backgroundColor = .systemBackground
        setupScrollView()
        addPreAdContent()
        setupStickyBannerAd()
        addPostAdContent()
    }

    // MARK: - Layout

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    // MARK: - Content

    private func addPreAdContent() {
        contentStack.addArrangedSubview(makeTitleLabel("Sticky Ad Example"))
        contentStack.addArrangedSubview(makeBodyLabel(
            "Scroll down — the banner below stays sticky within its reserved area " +
            "as you scroll past it, then exits at the bottom. " +
            "This mirrors the Flutter AudienzzStickyAdWrapper behaviour."
        ))
        for i in 1...5 {
            contentStack.addArrangedSubview(makeParagraph(i))
        }
    }

    private func setupStickyBannerAd() {
        // GAM banner
        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: kAdSize))
        gamBanner.adUnitID = kAdUnitId
        gamBanner.rootViewController = self

        // Audienzz banner
        let banner = AUBannerView(configId: kConfigId, adSize: kAdSize, adFormats: [.banner])
        bannerView = banner

        // Full-width host view keeps the wrapper width while centering the fixed-size banner.
        let centeredBannerHost = UIView()
        centeredBannerHost.translatesAutoresizingMaskIntoConstraints = false
        banner.translatesAutoresizingMaskIntoConstraints = false
        centeredBannerHost.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: centeredBannerHost.centerXAnchor),
            banner.topAnchor.constraint(equalTo: centeredBannerHost.topAnchor),
            banner.bottomAnchor.constraint(equalTo: centeredBannerHost.bottomAnchor),
            banner.widthAnchor.constraint(equalToConstant: kAdSize.width),
            banner.heightAnchor.constraint(equalToConstant: kAdSize.height),
        ])

        // Sticky wrapper — attach scroll view after layout pass
        let wrapper = AUStickyAdWrapperView(adView: centeredBannerHost, maxHeight: kMaxHeight)
        stickyWrapper = wrapper
        contentStack.addArrangedSubview(wrapper)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            wrapper.attachToScrollView(self.scrollView)
        }

        banner.onLoadRequest = { [weak gamBanner] request in
            guard let request = request as? AdManagerRequest else { return }
            gamBanner?.load(request)
        }

        banner.createAd(with: AdManagerRequest(), gamBanner: gamBanner)
    }

    private func addPostAdContent() {
        for i in 6...14 {
            contentStack.addArrangedSubview(makeParagraph(i))
        }
    }

    // MARK: - Helpers

    private func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 22)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }

    private func makeBodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func makeParagraph(_ index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8

        let label = UILabel()
        label.text = "Paragraph \(index) — \(loremIpsum)"
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    private let loremIpsum =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor " +
        "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud " +
        "exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure " +
        "dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
}
