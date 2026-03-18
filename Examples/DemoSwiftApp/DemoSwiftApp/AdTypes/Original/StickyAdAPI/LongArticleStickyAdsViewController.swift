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

private let kBannerAdConfigId = "46"
private let kMaxHeight: CGFloat = 450

private func parseAdSize(_ s: String) -> CGSize? {
    let p = s.split(separator: "x")
    guard p.count == 2, let w = Double(p[0]), let h = Double(p[1]) else { return nil }
    return CGSize(width: w, height: h)
}

/// Demonstrates five ``AUStickyAdWrapperView`` instances embedded inside a
/// long article-style scroll view. Each 300×250 banner stays pinned to the
/// top of its reserved area while the user scrolls past it, then slides out
/// at the bottom — exactly like the Flutter `AudienzzStickyAdWrapper`.
final class LongArticleStickyAdsViewController: UIViewController {

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private var stickyWrappers: [AUStickyAdWrapperView] = []
    private var bannerViews:    [AUBannerView]           = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Long Article – 5 Sticky Ads"
        view.backgroundColor = .systemBackground
        setupScrollView()
        buildArticle()
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
                equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
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

    // MARK: - Article Construction

    private func buildArticle() {
        // Title block
        contentStack.addArrangedSubview(makeTitleLabel(Article.title))
        contentStack.addArrangedSubview(makeBylineLabel("By Jane Smith  •  March 3, 2026  •  12 min read"))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeBodyLabel(Article.intro))

        // Section 1 → Ad 1
        contentStack.addArrangedSubview(makeSectionHeader(Article.sectionTitles[0]))
        contentStack.addArrangedSubview(makeBodyLabel(Article.sectionBodies[0]))
        addStickyAd(number: 1)

        // Section 2 → Ad 2
        contentStack.addArrangedSubview(makeSectionHeader(Article.sectionTitles[1]))
        contentStack.addArrangedSubview(makeBodyLabel(Article.sectionBodies[1]))
        addStickyAd(number: 2)

        // Section 3 → Ad 3
        contentStack.addArrangedSubview(makeSectionHeader(Article.sectionTitles[2]))
        contentStack.addArrangedSubview(makeBodyLabel(Article.sectionBodies[2]))
        addStickyAd(number: 3)

        // Section 4 → Ad 4
        contentStack.addArrangedSubview(makeSectionHeader(Article.sectionTitles[3]))
        contentStack.addArrangedSubview(makeBodyLabel(Article.sectionBodies[3]))
        addStickyAd(number: 4)

        // Section 5 → Ad 5
        contentStack.addArrangedSubview(makeSectionHeader(Article.sectionTitles[4]))
        contentStack.addArrangedSubview(makeBodyLabel(Article.sectionBodies[4]))
        addStickyAd(number: 5)

        // Conclusion
        contentStack.addArrangedSubview(makeSectionHeader("Conclusion"))
        contentStack.addArrangedSubview(makeBodyLabel(Article.conclusion))
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeBylineLabel("© 2026 Audienzz AG. All rights reserved."))

        // Attach all wrappers to the scroll view after the first layout pass.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stickyWrappers.forEach { $0.attachToScrollView(self.scrollView) }
        }
    }

    // MARK: - Sticky Ad Factory

    private func addStickyAd(number: Int) {
        guard let rc = AudienzzRemoteConfig.shared.remoteConfig(for: kBannerAdConfigId) else {
            print("[LongArticleStickyAdsViewController] Remote ad config '\(kBannerAdConfigId)' not yet available.")
            return
        }
        let configId = rc.prebidConfig.placementId
        let gamUnitId = rc.gamConfig.adUnitPath
        let adSize = rc.gamConfig.adSizes
            .compactMap { parseAdSize($0) }
            .sorted { $0.width * $0.height > $1.width * $1.height }
            .first ?? CGSize(width: 300, height: 250)

        // GAM banner
        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: adSize))
        gamBanner.adUnitID = gamUnitId
        gamBanner.rootViewController = self

        // Audienzz banner
        let banner = AUBannerView(configId: configId, adSize: adSize, adFormats: [.banner])
        bannerViews.append(banner)

        // Center the fixed-size banner inside a full-width host view so the
        // wrapper stays full-width while the ad itself is centred.
        let host = UIView()
        host.translatesAutoresizingMaskIntoConstraints = false
        banner.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            banner.topAnchor.constraint(equalTo: host.topAnchor),
            banner.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            banner.widthAnchor.constraint(equalToConstant: adSize.width),
            banner.heightAnchor.constraint(equalToConstant: adSize.height),
        ])

        // Wrap in a sticky container
        let wrapper = AUStickyAdWrapperView(adView: host, maxHeight: kMaxHeight)
        stickyWrappers.append(wrapper)
        contentStack.addArrangedSubview(wrapper)

        banner.onLoadRequest = { [weak gamBanner] request in
            guard let request = request as? AdManagerRequest else { return }
            gamBanner?.load(request)
        }

        banner.createAd(with: AdManagerRequest(), gamBanner: gamBanner)
    }

    // MARK: - Label Factories

    private func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 24)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }

    private func makeBylineLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .italicSystemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func makeSectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 18)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }

    private func makeBodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1),
        ])
        return view
    }
}

// MARK: - Article Content

private enum Article {

    static let title = "The Future of Mobile Advertising: Trends, Challenges, and Opportunities"

    static let intro = """
        The mobile advertising landscape is undergoing a profound transformation. With billions of smartphones in active use worldwide, marketers have unprecedented access to consumers at every moment of their day. Yet the industry faces mounting pressure to deliver relevant, respectful, and effective ads in an era defined by privacy regulations, ad-blocking technology, and an increasingly discerning audience.

        This in-depth analysis explores the major forces shaping mobile advertising in 2026 and what they mean for publishers, advertisers, and the SDKs — like Audienzz — that power the ecosystem.
        """

    static let sectionTitles = [
        "1. The Rise of Programmatic Advertising",
        "2. Privacy-First Advertising in a Post-Cookie World",
        "3. Creative Innovation and Rich Media",
        "4. Measurement, Attribution, and Analytics",
        "5. Emerging Channels: CTV, Audio, and Beyond",
    ]

    static let sectionBodies = [
        """
        Programmatic advertising has become the dominant model for buying and selling mobile ad inventory. Real-time bidding (RTB) platforms enable advertisers to purchase impressions on a per-auction basis, targeting specific users based on demographic data, contextual signals, and behavioural patterns. In 2025, programmatic accounted for over 88 % of all digital display ad spend — a figure that continues to climb.

        Header bidding, once the preserve of desktop web publishers, has firmly taken root on mobile. SDKs like Audienzz enable app developers to monetise their audiences more efficiently than ever, exposing their inventory to multiple demand sources simultaneously. Supply-side and demand-side platforms have grown increasingly sophisticated, incorporating machine-learning models that optimise bids in real time based on predicted conversion probabilities.

        The shift towards unified auctions has levelled the playing field for smaller publishers, who can now compete alongside premium inventory holders. For developers integrating a modern SDK, this means even a modest app can attract competitive CPMs provided the targeting signals it surfaces are rich and reliable.
        """,
        """
        The deprecation of third-party cookies and the restriction of device identifiers such as Apple's IDFA have forced advertisers to rethink how they target and track users. Contextual targeting — serving ads based on the content a user is currently viewing rather than their historical browsing behaviour — has enjoyed a renaissance. Semantic analysis technologies can now classify in-app content with remarkable accuracy, enabling brands to appear alongside relevant editorial without relying on cross-site tracking.

        Privacy-preserving measurement frameworks have also emerged as a critical area of innovation. Apple's SKAdNetwork and Google's Privacy Sandbox for Android attempt to deliver campaign attribution data to advertisers while keeping individual user data on-device. These frameworks are still maturing, and advertisers must invest in modelling techniques that can extrapolate insights from aggregated, privacy-safe data.

        For publishers, the challenge is to collect first-party data — with genuine user consent — in ways that enrich the targeting pool available to their advertising partners. Consent management platforms (CMPs) integrated directly into the SDK layer simplify compliance with GDPR, CCPA, and the growing roster of regional privacy laws.
        """,
        """
        In a crowded market, creative quality has become a decisive competitive advantage. Static banner ads continue to command a substantial share of impressions, but rich media formats — expandable banners, playable ads, rewarded video, and interactive interstitials — routinely deliver engagement rates several times higher than their traditional counterparts. High-frame-rate displays and more powerful mobile chipsets now make it technically feasible to run complex, GPU-accelerated ad experiences that were unimaginable just a few years ago.

        Sticky banner formats, such as those provided by the Audienzz SDK's AUStickyAdWrapperView, represent a compelling middle ground: they offer extended exposure without the intrusive nature of full-screen interstitials. By keeping the ad visible as the user scrolls through content, sticky placements significantly increase the time-in-view metric — one of the most important proxies for ad effectiveness in a viewability-conscious ecosystem.

        When combined with programmatic demand, sticky formats can materially improve eCPMs for publishers. The ability to define a maximum reservation height (maxHeight) and a custom sticky offset gives developers fine-grained control over the user experience, ensuring ads enhance rather than disrupt editorial content.
        """,
        """
        Attribution — the process of determining which ad touchpoint caused a conversion — has long been both the holy grail and the bane of mobile marketers. Multi-touch attribution models attempt to distribute credit across multiple interactions in a user's journey, providing a more nuanced picture than the blunt instrument of last-click attribution. Machine learning is now being applied to attribution at scale, with probabilistic models that can infer conversions even in the absence of deterministic identifiers.

        Incrementality testing, in which a holdout group is deliberately not shown an ad so that its causal effect can be measured, is gaining traction as a gold-standard methodology. Combined with media mix modelling (MMM) — which analyses aggregate spend and outcome data over time — these approaches provide a robust evidence base for media investment decisions.

        For app developers, integrating robust analytics from day one is essential. Detailed session data, in-app events, and revenue metrics are the raw material that sophisticated advertisers require when evaluating a publisher's inventory. SDKs that expose clean, well-documented event hooks make this instrumentation straightforward to implement.
        """,
        """
        Connected TV (CTV) and streaming audio have emerged as high-growth frontiers for performance advertisers previously confined to mobile web and in-app channels. As living-room and kitchen devices join the programmatic ecosystem, advertisers can extend audience segments built on mobile data across screens and listening contexts. Cross-device measurement, once a significant technical challenge, is becoming more tractable as household-level identity graphs mature.

        Podcasts and music-streaming platforms have demonstrated that audio advertising, done well, can achieve recall and brand-lift metrics that rival premium video. Interactive audio ads — where a listener can speak a keyword to trigger a follow-up action — are beginning to move from experiment to mainstream format.

        For the mobile SDK ecosystem, the implication is that ad formats and measurement capabilities must evolve to encompass audio triggers, second-screen companion experiences, and QR-code integrations that bridge the physical and digital worlds. Publishers who invest in these capabilities today will be well positioned to capture the premium demand that flows into these channels over the next three to five years.
        """,
    ]

    static let conclusion = """
        Mobile advertising in 2026 is characterised by tension between performance and privacy, scale and relevance, automation and creativity. The publishers and advertisers who will thrive are those who invest in first-party data strategies, embrace privacy-preserving technology, and champion creative formats that respect the user experience.

        SDKs that abstract away the complexity of header bidding, sticky ad placement, and consent management — while exposing clean, well-documented APIs — will be indispensable partners in this journey. The road ahead is challenging, but for those willing to adapt, the opportunity is immense.
        """
}
