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

// Customer reproduction: 50px banner config that returns 300×600 from Prebid
private let kCorrectConfigId = "37116627"
private let kCorrectGamUnit  = "/96628199/de_audienzz.ch_v2/multi-size"

// ─────────────────────────────────────────────────────────────────────────────
// CorrectBannerViewController
//
// The three bugs from WrongBannerViewController are all fixed here.
//
//  ✅ Fix 1 — nsValue(for: adSizeFor(cgSize:))
//             GAM receives a properly typed GADAdSize NSValue.
//             validAdSizes is honoured → GAM accepts both 320×50 and 300×600.
//
//  ✅ Fix 2 — adView is added to the view hierarchy ONCE, at setup time.
//             The hierarchy self → adContainer → adView → gamBanner stays
//             intact for the entire lifetime of the ad.
//             No AdSizeDelegate / willChangeAdSizeTo needed.
//
//  ✅ Fix 3 — bannerViewDidReceiveAd never moves gamBanner.
//             findEnclosingAUBannerView walks: gamBanner → adView (AUBannerView)
//             → found. lastPrebidCreativeSize is read directly from
//             customTargeting["hb_size"] — no WKWebView, always reliable.
//
// Visual result: container auto-sizes to the exact winning creative size.
// Zero blank space. Container height = creative height every time.
// ─────────────────────────────────────────────────────────────────────────────

class CorrectBannerViewController: UIViewController {

    // MARK: - Ad objects

    private var adView: AUBannerView?
    private var gamBanner: AdManagerBannerView?

    // MARK: - Layout

    private let scrollView    = UIScrollView()
    private let stackView     = UIStackView()
    private let adContainer   = UIView()
    private let statusLabel   = UILabel()
    private let sizeInfoLabel = UILabel()

    // Container height starts at the primary size and updates after each load
    private var containerHeightConstraint: NSLayoutConstraint!
    private var adViewWidthConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "✅ Correct Setup"
        view.backgroundColor = .systemBackground
        buildLayout()
        loadAd()
    }

    // MARK: - Layout

    private func buildLayout() {
        let header = makeFixCard()
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

        // Ad container — green border to contrast with Wrong screen
        adContainer.layer.borderColor = UIColor.systemGreen.cgColor
        adContainer.layer.borderWidth = 2
        adContainer.backgroundColor   = UIColor.systemGreen.withAlphaComponent(0.04)
        adContainer.clipsToBounds     = true

        // ✅ Container starts at primary size — resizes to exact creative size on load
        containerHeightConstraint = adContainer.heightAnchor.constraint(equalToConstant: 50)
        containerHeightConstraint.isActive = true
        stackView.addArrangedSubview(adContainer)

        let note = UILabel()
        note.numberOfLines = 0
        note.font = .systemFont(ofSize: 12)
        note.textColor = .systemGreen
        note.text = "⬆ Green border = ad container (320×50 + 300×600 requested)\n"
                  + "Sized to the exact creative. No wasted space."
        stackView.addArrangedSubview(note)
    }

    // MARK: - Ad load (correct)

    private func loadAd() {
        // Multi-size: 320×50 primary + 300×600 additional
        let primarySize    = CGSize(width: 320, height: 50)
        let secondarySize  = CGSize(width: 300, height: 600)

        gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: primarySize))
        gamBanner?.adUnitID           = kCorrectGamUnit
        gamBanner?.rootViewController = self
        gamBanner?.delegate           = self
        // No adSizeDelegate — willChangeAdSizeTo is not needed

        // ✅ Fix 1: nsValue(for: adSizeFor(cgSize:)) — properly typed GADAdSize NSValues.
        // GAM can now decode the list and will accept both 320×50 and 300×600.
        gamBanner?.validAdSizes = [
            nsValue(for: adSizeFor(cgSize: primarySize)),
            nsValue(for: adSizeFor(cgSize: secondarySize))
        ]

        // ✅ Fix 2: create adView and add it to adContainer RIGHT NOW — at setup time.
        // The hierarchy (adContainer → adView → gamBanner) will never be broken.
        adView = AUBannerView(
            configId: kCorrectConfigId,
            adSize: primarySize,
            adFormats: [.banner],
            isLazyLoad: false
        )
        adView?.addAdditionalSize(sizes: [secondarySize])

        guard let adView, let gamBanner else { return }

        // Add adView once — centered horizontally, never moved in delegates
        adView.translatesAutoresizingMaskIntoConstraints = false
        adContainer.addSubview(adView)
        adViewWidthConstraint = adView.widthAnchor.constraint(equalToConstant: primarySize.width)
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: adContainer.centerXAnchor),
            adView.topAnchor.constraint(equalTo: adContainer.topAnchor),
            adViewWidthConstraint,
            adView.heightAnchor.constraint(equalTo: adContainer.heightAnchor),
        ])

        let gamRequest = AdManagerRequest()
        adView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: AUBannerEventHandler(adUnitId: kCorrectGamUnit, gamView: gamBanner)
        )
        adView.onLoadRequest = { [weak gamBanner] req in
            guard let r = req as? AdManagerRequest else { return }
            gamBanner?.load(r)
        }

        updateStatus("⏳ Prebid demand fetch started…", creativeSize: nil, source: nil)
    }

    // MARK: - Status helpers

    private func updateStatus(_ text: String, creativeSize: CGSize?, source: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusLabel.text = text
            let containerH = Int(self.containerHeightConstraint.constant)
            if let size = creativeSize {
                let matched = Int(size.height) == containerH
                self.sizeInfoLabel.text = [
                    "Creative size    : \(Int(size.width))×\(Int(size.height))",
                    "Container height : \(containerH) px",
                    "Source           : \(source ?? "—")",
                    matched
                        ? "✅ Container matches creative — zero wasted space"
                        : "⚠️ Size mismatch",
                ].joined(separator: "\n")
            } else {
                self.sizeInfoLabel.text = "Container height : \(containerH) px (waiting for ad…)"
            }
        }
    }

    // MARK: - Fix card

    private func makeFixCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)

        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for (tag, desc) in [
            ("Fix 1", "nsValue(for: adSizeFor(cgSize:)) — GAM honours validAdSizes"),
            ("Fix 2", "adView added at setup, hierarchy intact forever"),
            ("Fix 3", "No AdSizeDelegate — single bannerViewDidReceiveAd callback"),
        ] {
            let row = UIStackView()
            row.axis    = .horizontal
            row.spacing = 8

            let t = UILabel()
            t.text = "✅ \(tag)"
            t.font = .boldSystemFont(ofSize: 12)
            t.textColor = .systemGreen
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

// MARK: - BannerViewDelegate  ✅ Fix 3 — single delegate, hierarchy intact

extension CorrectBannerViewController: BannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else { return }

        // ✅ Fix 3: adView is still the superview of gamBanner.
        // Hierarchy: adContainer → adView (AUBannerView) → gamBanner
        //
        // findEnclosingAUBannerView(startingAt: gamBanner) walks:
        //   gamBanner.superview → adView  ← found (AUBannerView)
        //
        // SDK v0.1.7 fast path: lastPrebidCreativeSize is populated from
        // customTargeting["hb_size"] after fetchDemand — synchronous, no WebView.
        // findCreativeSize returns immediately with the correct size.
        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { [weak self] size in
                guard let self else { return }
                DispatchQueue.main.async {
                    // gamBanner has already been resized by AUBannerHandler (v0.1.7).
                    // Update container height and adView width to match the winning creative.
                    self.containerHeightConstraint.constant = size.height
                    self.adViewWidthConstraint.constant = size.width
                    UIView.animate(withDuration: 0.25) {
                        self.view.layoutIfNeeded()
                    }
                    self.updateStatus(
                        "✅ findCreativeSize succeeded via lastPrebidCreativeSize\n" +
                        "(fast path — no WKWebView dependency)",
                        creativeSize: size,
                        source: "lastPrebidCreativeSize (customTargeting[\"hb_size\"])"
                    )
                }
            },
            failure: { [weak self] error in
                // GAM-direct ad won (no Prebid bid) — use GAM's reported adSize as fallback
                guard let self else { return }
                let fallback = bannerView.adSize.size
                DispatchQueue.main.async {
                    self.containerHeightConstraint.constant = fallback.height
                    UIView.animate(withDuration: 0.25) {
                        self.view.layoutIfNeeded()
                    }
                    self.updateStatus(
                        "ℹ️ No Prebid bid — GAM-direct ad loaded\n" +
                        "Using gamBanner.adSize as size fallback",
                        creativeSize: fallback,
                        source: "gamBanner.adSize (GAM-direct)"
                    )
                }
            }
        )
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        updateStatus("❌ Ad request failed: \(error.localizedDescription)",
                     creativeSize: nil, source: nil)
    }
}
