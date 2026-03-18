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

// Prebid demo IDs — same across both Wrong and Correct screens so results are comparable
private let kWrongConfigId  = "prebid-demo-banner-300-250"
private let kWrongGamUnit   = "ca-app-pub-3940256099942544/6300978111"

// ─────────────────────────────────────────────────────────────────────────────
// WrongBannerViewController
//
// Intentionally reproduces the three bugs found in a real client integration.
// Run this screen alongside CorrectBannerViewController to see the visual
// difference side-by-side.
//
//  ❌ Bug 1 — NSValue(cgSize:) instead of nsValue(for: adSizeFor(cgSize:))
//             GAM receives a CGSize-typed NSValue, not a GADAdSize-typed NSValue.
//             GAM cannot decode the size list and silently ignores validAdSizes.
//             Only the primary size (320×50) is accepted — but Prebid still bids
//             300×250, so the two layers disagree.
//
//  ❌ Bug 2 — adView (AUBannerView) is NOT added to the hierarchy at setup.
//             It is added later inside willChangeAdSizeTo, which fires before the
//             real creative is ready. The container jumps to 300×250 prematurely.
//
//  ❌ Bug 3 — bannerViewDidReceiveAd removes adView from the hierarchy and places
//             gamBanner directly inside adContainer.
//             gamBanner.superview = adContainer (UIView), not adView (AUBannerView).
//             findEnclosingAUBannerView walks up: gamBanner → adContainer → … → nil.
//             AUBannerView is never found → lastPrebidCreativeSize is unreachable.
//             findCreativeSize falls back to WKWebView HTML scraping, which races
//             against WebView load completion and fails under any CPU/nav pressure.
//
// Visual result: huge blank white space above/below a small ad (matches screenshot).
// ─────────────────────────────────────────────────────────────────────────────

class WrongBannerViewController: UIViewController {

    // MARK: - Ad objects

    private var adView: AUBannerView?
    private var gamBanner: AdManagerBannerView?

    // MARK: - Layout

    private let scrollView   = UIScrollView()
    private let stackView    = UIStackView()
    private let adContainer  = UIView()
    private let statusLabel  = UILabel()
    private let sizeInfoLabel = UILabel()

    // Container height is fixed at the large size — never updated correctly
    private var containerHeightConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "❌ Wrong Setup"
        view.backgroundColor = .systemBackground
        buildLayout()
        loadAd()
    }

    // MARK: - Layout

    private func buildLayout() {
        let header = makeBugCard()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis      = .vertical
        stackView.spacing   = 12
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        // Status labels
        statusLabel.numberOfLines = 0
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .label
        statusLabel.text = "⏳ Loading…"
        stackView.addArrangedSubview(statusLabel)

        sizeInfoLabel.numberOfLines = 0
        sizeInfoLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        sizeInfoLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(sizeInfoLabel)

        // Ad container — red border so the empty space is obvious
        adContainer.layer.borderColor  = UIColor.systemRed.cgColor
        adContainer.layer.borderWidth  = 2
        adContainer.backgroundColor    = UIColor.systemRed.withAlphaComponent(0.04)
        adContainer.clipsToBounds      = true

        // ❌ Container initialized to the LARGE size — this never shrinks correctly
        containerHeightConstraint = adContainer.heightAnchor.constraint(equalToConstant: 250)
        containerHeightConstraint.isActive = true
        stackView.addArrangedSubview(adContainer)

        let note = UILabel()
        note.numberOfLines = 0
        note.font = .systemFont(ofSize: 12)
        note.textColor = .systemRed
        note.text = "⬆ Red border = ad container (fixed 250 px)\n"
                  + "The ad inside is ~50 px — the rest is blank space."
        stackView.addArrangedSubview(note)
    }

    // MARK: - Ad load (intentionally wrong)

    private func loadAd() {
        let primarySize = CGSize(width: 320, height: 50)
        let allSizes: [CGSize] = [
            CGSize(width: 320, height: 50),
            CGSize(width: 300, height: 250),
        ]

        gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: primarySize))
        gamBanner?.adUnitID       = kWrongGamUnit
        gamBanner?.rootViewController = self
        gamBanner?.adSizeDelegate = self   // ❌ Bug 2 — see willChangeAdSizeTo
        gamBanner?.delegate       = self

        // ❌ Bug 1: NSValue(cgSize:) — CGSize wrapper, NOT a GADAdSize wrapper.
        // GAM silently ignores the whole validAdSizes list.
        gamBanner?.validAdSizes = allSizes.map { NSValue(cgSize: $0) }

        let gamRequest = AdManagerRequest()

        // ❌ Bug 2: adView is created here but NOT added to the view hierarchy.
        // It will be moved into adContainer later inside willChangeAdSizeTo.
        adView = AUBannerView(
            configId: kWrongConfigId,
            adSize: primarySize,
            adFormats: [.banner],
            isLazyLoad: false
        )
        adView?.addAdditionalSize(sizes: [CGSize(width: 300, height: 250)])

        guard let adView, let gamBanner else { return }

        adView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(adUnitId: kWrongGamUnit, gamView: gamBanner)
        )
        adView.onLoadRequest = { [weak gamBanner] req in
            guard let r = req as? AdManagerRequest else { return }
            gamBanner?.load(r)
        }

        updateStatus("⏳ Prebid demand fetch started…")
    }

    // MARK: - Status helpers

    private func updateStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusLabel.text = text
            let containerH = Int(self.containerHeightConstraint.constant)
            self.sizeInfoLabel.text =
                "Container height : \(containerH) px (fixed, never resized)\n" +
                "gamBanner frame  : \(Int(self.gamBanner?.frame.height ?? 0)) px"
        }
    }

    // MARK: - Bug card

    private func makeBugCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)

        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for (tag, desc) in [
            ("Bug 1", "NSValue(cgSize:) → GAM ignores validAdSizes"),
            ("Bug 2", "adView added in willChangeAdSizeTo, not at setup"),
            ("Bug 3", "gamBanner ripped out of adView in bannerViewDidReceiveAd"),
        ] {
            let row = UIStackView()
            row.axis    = .horizontal
            row.spacing = 8

            let t = UILabel()
            t.text = "❌ \(tag)"
            t.font = .boldSystemFont(ofSize: 12)
            t.textColor = .systemRed
            t.setContentHuggingPriority(.required, for: .horizontal)

            let d = UILabel()
            d.text = desc
            d.font = .systemFont(ofSize: 12)
            d.numberOfLines = 0

            row.addArrangedSubview(t)
            row.addArrangedSubview(d)
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }
}

// MARK: - AdSizeDelegate  ❌ Bug 2 — used as "ad ready" signal (wrong semantics)

extension WrongBannerViewController: AdSizeDelegate {
    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize) {
        // willChangeAdSizeTo fires when Prebid's 1×1 creative is about to expand.
        // This is NOT the same as "the real creative is ready to display".
        // Using it here causes the container to jump to 300×250 too early and
        // notifies the publisher before the ad is actually rendered.
        DispatchQueue.main.async { [weak self] in
            guard let self, let adView = self.adView else { return }
            self.adContainer.subviews.forEach { $0.removeFromSuperview() }
            self.adContainer.addSubview(adView)
            adView.frame = CGRect(origin: .zero, size: size.size)
            self.updateStatus(
                "willChangeAdSizeTo \(Int(size.size.width))×\(Int(size.size.height)) " +
                "— container updated before creative is ready ❌"
            )
        }
    }
}

// MARK: - BannerViewDelegate  ❌ Bug 3 — breaks view hierarchy

extension WrongBannerViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // ❌ Bug 3: removes adView, puts gamBanner directly inside adContainer.
            // Hierarchy after this: adContainer → gamBanner
            // adView (AUBannerView) is no longer in the tree above gamBanner.
            // findEnclosingAUBannerView(startingAt: gamBanner) walks:
            //   gamBanner → adContainer → stackView → scrollView → self.view → nil
            // Never finds AUBannerView → lastPrebidCreativeSize is nil.
            // Falls back to WKWebView HTML scraping — race condition → failure.
            self.adContainer.subviews.forEach { $0.removeFromSuperview() }
            self.adContainer.addSubview(bannerView)
            bannerView.frame = CGRect(
                origin: .zero,
                size: CGSize(width: 320, height: 50)  // stays at primary size
            )
        }

        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { [weak self] size in
                // Rare: WebView happened to be ready — lucky, not reliable
                DispatchQueue.main.async {
                    bannerView.resize(adSizeFor(cgSize: size))
                    self?.updateStatus(
                        "⚠️ findCreativeSize got lucky (WebView was ready): " +
                        "\(Int(size.width))×\(Int(size.height))\n" +
                        "This succeeds ~50% of the time — not a fix."
                    )
                }
            },
            failure: { [weak self] error in
                // Common case: hierarchy broken + WebView not ready → no resize
                DispatchQueue.main.async {
                    self?.updateStatus(
                        "❌ findCreativeSize FAILED\n" +
                        "\(error.localizedDescription)\n" +
                        "gamBanner detached from AUBannerView → " +
                        "lastPrebidCreativeSize unreachable → blank space visible above"
                    )
                }
            }
        )
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        updateStatus("❌ Ad request failed: \(error.localizedDescription)")
    }
}
