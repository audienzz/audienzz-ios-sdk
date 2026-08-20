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

// =============================================================================
// LegacyBannerViewController_v0_1_8
//
// This screen is an exact copy of the banner ad integration as it existed in
// iOS SDK tag 0.1.8. Used to verify backward compatibility — code written
// against 0.1.8 must continue to work unchanged after a SDK upgrade.
//
// Differences from the current ExamplesViewController_BannerAPI.swift:
//   • refresh time is hardcoded to 30 000 ms (not read from remote config)
//   • smartRefresh is NOT set (defaults to false)
//   • prefetchMarginPoints is NOT set (defaults to 0 / no prefetch distance)
// =============================================================================

import UIKit
import AudienzziOSSDK
import GoogleMobileAds

// Remote config ID — same as used throughout the demo app.
private let kLegacyBannerConfigId = "46"

private func parseLegacyAdSize(_ s: String) -> CGSize? {
    let p = s.split(separator: "x")
    guard p.count == 2, let w = Double(p[0]), let h = Double(p[1]) else { return nil }
    return CGSize(width: w, height: h)
}


// MARK: - LegacyBannerViewController_v0_1_8

class LegacyBannerViewController_v0_1_8: UIViewController {

    // ── AUBannerView instances ─────────────────────────────────────────────────
    private var banner_320x50:  AUBannerView!
    private var banner_300x250: AUBannerView!

    // ── GAM banner views ───────────────────────────────────────────────────────
    private var gamBanner_320x50:  AdManagerBannerView!
    private var gamBanner_300x250: AdManagerBannerView!

    // ── Layout ─────────────────────────────────────────────────────────────────
    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()


    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Legacy Banner (v0.1.8)"
        view.backgroundColor = .systemBackground
        buildLayout()
        setupBanner_320x50()
        setupBanner_300x250()
    }


    // MARK: - Layout helpers

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        stackView.axis      = .vertical
        stackView.spacing   = 32
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    private func makeContainer(label: String, height: CGFloat) -> UIView {
        let header = UILabel()
        header.text = label
        header.font = .systemFont(ofSize: 12, weight: .medium)
        header.textColor = .secondaryLabel
        stackView.addArrangedSubview(header)

        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: height).isActive = true
        stackView.addArrangedSubview(container)
        return container
    }


    // MARK: ── Banner 320×50 ───────────────────────────────────────────────────
    //
    // v0.1.8 integration style:
    //   • refresh time hardcoded to 30 000 ms
    //   • no smartRefresh
    //   • no prefetchMarginPoints

    private func setupBanner_320x50() {
        guard let rc = AudienzzRemoteConfig.shared.remoteConfig(for: kLegacyBannerConfigId) else {
            print("[LegacyBannerViewController] Remote config not available for 320×50.")
            return
        }

        let size = rc.gamConfig.adSizes
            .compactMap { parseLegacyAdSize($0) }
            .sorted { $0.width * $0.height < $1.width * $1.height }
            .first ?? CGSize(width: 320, height: 50)

        let container = makeContainer(label: "320×50 (v0.1.8 — no smartRefresh, hardcoded 30s)", height: size.height)

        gamBanner_320x50 = AdManagerBannerView(adSize: adSizeFor(cgSize: size))
        gamBanner_320x50.adUnitID = rc.gamConfig.adUnitPath
        gamBanner_320x50.rootViewController = self
        gamBanner_320x50.delegate = self

        banner_320x50 = AUBannerView(
            configId: rc.prebidConfig.placementId,
            adSize: size,
            adFormats: [.banner],
            isLazyLoad: false
        )
        banner_320x50.frame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: size.height))
        banner_320x50.backgroundColor = .clear
        container.addSubview(banner_320x50)

        // v0.1.8: refresh time is hardcoded, not read from remote config
        banner_320x50.adUnitConfiguration.setAutoRefreshMillis(time: 30000)
        // v0.1.8: smartRefresh is NOT set (defaults to false)
        // v0.1.8: prefetchMarginPoints is NOT set

        let gamRequest = AdManagerRequest()
        banner_320x50.createAd(
            with: gamRequest,
            gamBanner: gamBanner_320x50,
            eventHandler: AUBannerEventHandler(
                adUnitId: rc.gamConfig.adUnitPath,
                gamView: gamBanner_320x50
            )
        )

        banner_320x50.onLoadRequest = { [weak self] request in
            guard let request = request as? AdManagerRequest else { return }
            self?.gamBanner_320x50?.load(request)
        }
    }


    // MARK: ── Banner 300×250 ──────────────────────────────────────────────────

    private func setupBanner_300x250() {
        guard let rc = AudienzzRemoteConfig.shared.remoteConfig(for: kLegacyBannerConfigId) else {
            print("[LegacyBannerViewController] Remote config not available for 300×250.")
            return
        }

        let size = rc.gamConfig.adSizes
            .compactMap { parseLegacyAdSize($0) }
            .sorted { $0.width * $0.height > $1.width * $1.height }
            .first ?? CGSize(width: 300, height: 250)

        let container = makeContainer(label: "300×250 (v0.1.8 — no smartRefresh)", height: size.height)

        gamBanner_300x250 = AdManagerBannerView(adSize: adSizeFor(cgSize: size))
        gamBanner_300x250.adUnitID = rc.gamConfig.adUnitPath
        gamBanner_300x250.rootViewController = self
        gamBanner_300x250.delegate = self

        banner_300x250 = AUBannerView(
            configId: rc.prebidConfig.placementId,
            adSize: size,
            adFormats: [.banner],
            isLazyLoad: false
        )
        banner_300x250.frame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: size.height))
        banner_300x250.backgroundColor = .clear
        container.addSubview(banner_300x250)

        // v0.1.8: no setAutoRefreshMillis call for 300×250 (same as original)
        // v0.1.8: smartRefresh is NOT set
        // v0.1.8: prefetchMarginPoints is NOT set

        let gamRequest = AdManagerRequest()
        banner_300x250.createAd(
            with: gamRequest,
            gamBanner: gamBanner_300x250,
            eventHandler: AUBannerEventHandler(
                adUnitId: rc.gamConfig.adUnitPath,
                gamView: gamBanner_300x250
            )
        )

        banner_300x250.onLoadRequest = { [weak self] request in
            guard let request = request as? AdManagerRequest else { return }
            self?.gamBanner_300x250?.load(request)
        }
    }
}


// MARK: - BannerViewDelegate

extension LegacyBannerViewController_v0_1_8: BannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else { return }
        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { size in
                bannerView.resize(adSizeFor(cgSize: size))
            },
            failure: { error in
                print("findCreativeSize: \(error.localizedDescription)")
            }
        )
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("❌ Banner failed: \(error.localizedDescription)")
    }
}
