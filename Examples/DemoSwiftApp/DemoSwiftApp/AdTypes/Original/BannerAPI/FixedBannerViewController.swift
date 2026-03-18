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

// =============================================================================
// FixedBannerViewController
//
// This screen shows how to integrate FIXED (non-adaptive) banner sizes with
// the Audienzz SDK and Google Ad Manager. It covers three common scenarios
// that developers encounter when placing standard IAB banner units inside a
// scrollable app layout:
//
//   1. Single fixed size — 320×50  (leaderboard / top-of-screen)
//   2. Single fixed size — 300×250 (medium rectangle / mid-article)
//   3. Multi-size banner — one ad slot that accepts either 320×50 or 300×250,
//      letting the auction pick the size with the highest bid
//
// ─── THE ROOT CAUSE OF "validAdSizes is ignored" ─────────────────────────────
//
//   ❌ WRONG — using inlineAdaptiveBanner:
//
//       let gamBanner = AdManagerBannerView(
//           adSize: GoogleMobileAds.inlineAdaptiveBanner(withAdWidth: 336, maxHeight: 50)
//       )
//       gamBanner.validAdSizes = [...]   // ← IGNORED by GAM when using adaptive
//
//   When you create an AdManagerBannerView with an *adaptive* ad size, GAM
//   ignores `validAdSizes` and restricts to the given adaptive width.
//   Any Prebid bid with a different width (e.g. 320px vs 336px) will not match
//   and the bid is wasted.
//
//   ✅ CORRECT — using a fixed size:
//
//       let gamBanner = AdManagerBannerView(
//           adSize: adSizeFor(cgSize: CGSize(width: 320, height: 50))
//       )
//       // For multi-size, set validAdSizes explicitly:
//       gamBanner.validAdSizes = [
//           nsValue(for: adSizeFor(cgSize: CGSize(width: 320, height: 50))),
//           nsValue(for: adSizeFor(cgSize: CGSize(width: 300, height: 250))),
//       ]
//
// ─── REPLACE THESE CONSTANTS WITH YOUR OWN VALUES ────────────────────────────
//
//   - configId:    your Prebid stored impression ID (from your Prebid Server)
//   - gamAdUnitId: your GAM ad unit ID (from Google Ad Manager)
//
// =============================================================================


// MARK: - Your ad unit configuration (replace with your real values)

private enum AdConfig {

    // ── Scenario 1: Single 320x50 banner ──────────────────────────────────────
    static let configId_320x50    = "37116627"
    static let gamAdUnitId_320x50 = "/21775744923/example/fixed-size-banner"

    // ── Scenario 2: Single 300x250 banner ─────────────────────────────────────
    static let configId_300x250    = "37116627"
    static let gamAdUnitId_300x250 = "/21775744923/example/fixed-size-banner"

    // ── Scenario 3: Multi-size banner (320x50 + 300x250 from ONE ad unit) ─────
    //
    // Use this when your GAM ad unit and Prebid config accept multiple sizes.
    // If you have separate GAM ad units per size, use scenarios 1 and 2 instead.
    static let configId_multisize    = "37116627"
    static let gamAdUnitId_multisize = "/21775744923/example/fixed-size-banner"
}


// MARK: - FixedBannerViewController

class FixedBannerViewController: UIViewController {

    // ── AUBannerView instances ─────────────────────────────────────────────────
    private var banner_320x50: AUBannerView!
    private var banner_300x250: AUBannerView!
    private var banner_multisize: AUBannerView!

    // ── GAM banner views (stored so we can identify them in the delegate) ──────
    private var gamBanner_320x50: AdManagerBannerView!
    private var gamBanner_300x250: AdManagerBannerView!
    private var gamBanner_multisize: AdManagerBannerView!

    // ── Container height constraint for the multi-size slot ───────────────────
    // We update this in bannerViewDidReceiveAd so the container grows/shrinks
    // to fit whichever size actually wins the Prebid auction.
    private var multisizeContainerHeight: NSLayoutConstraint!

    // ── Layout ─────────────────────────────────────────────────────────────────
    private let scrollView  = UIScrollView()
    private let stackView   = UIStackView()


    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Fixed Banner Example"
        view.backgroundColor = .systemBackground
        buildLayout()
        setupBanner_320x50()
        setupBanner_300x250()
        setupBanner_multisize()
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

    /// Creates a labelled container view that the AUBannerView and GAM banner
    /// live inside. Returns both the container and a mutable height constraint
    /// so the caller can resize it in the delegate callback.
    private func makeContainer(label: String, height: CGFloat) -> (UIView, NSLayoutConstraint) {
        let header = UILabel()
        header.text = label
        header.font = .systemFont(ofSize: 12, weight: .medium)
        header.textColor = .secondaryLabel
        stackView.addArrangedSubview(header)

        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        let heightConstraint = container.heightAnchor.constraint(equalToConstant: height)
        heightConstraint.isActive = true
        stackView.addArrangedSubview(container)
        return (container, heightConstraint)
    }


    // MARK: ── Scenario 1: Single fixed 320×50 ──────────────────────────────────
    //
    // One fixed size. No validAdSizes needed — GAM only needs to accept 320x50.
    // AUBannerView bids only for 320x50 in Prebid.

    private func setupBanner_320x50() {
        let size = CGSize(width: 320, height: 50)
        let (container, _) = makeContainer(label: "Scenario 1 — Fixed 320×50", height: size.height)

        // ✅ Fixed adSize — NOT inlineAdaptiveBanner(withAdWidth:)
        gamBanner_320x50 = AdManagerBannerView(adSize: adSizeFor(cgSize: size))
        gamBanner_320x50.adUnitID = AdConfig.gamAdUnitId_320x50
        gamBanner_320x50.rootViewController = self
        gamBanner_320x50.delegate = self

        banner_320x50 = AUBannerView(
            configId: AdConfig.configId_320x50,
            adSize: size,
            adFormats: [.banner],
            isLazyLoad: false    // set to true if this slot is below the fold
        )
        banner_320x50.frame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: size.height))
        banner_320x50.backgroundColor = .clear
        container.addSubview(banner_320x50)

        // Optional: enable auto-refresh every 30 s
        banner_320x50.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)

        let gamRequest = AdManagerRequest()
        banner_320x50.createAd(
            with: gamRequest,
            gamBanner: gamBanner_320x50,
            eventHandler: AUBannerEventHandler(
                adUnitId: AdConfig.gamAdUnitId_320x50,
                gamView: gamBanner_320x50
            )
        )

        // onLoadRequest fires after Prebid has finished (win or no bid).
        // We call gamBanner.load() here — GAM will then serve whatever won.
        banner_320x50.onLoadRequest = { [weak self] request in
            guard let request = request as? AdManagerRequest else { return }
            self?.gamBanner_320x50?.load(request)
        }
    }


    // MARK: ── Scenario 2: Single fixed 300×250 ─────────────────────────────────

    private func setupBanner_300x250() {
        let size = CGSize(width: 300, height: 250)
        let (container, _) = makeContainer(label: "Scenario 2 — Fixed 300×250", height: size.height)

        // ✅ Fixed adSize
        gamBanner_300x250 = AdManagerBannerView(adSize: adSizeFor(cgSize: size))
        gamBanner_300x250.adUnitID = AdConfig.gamAdUnitId_300x250
        gamBanner_300x250.rootViewController = self
        gamBanner_300x250.delegate = self

        banner_300x250 = AUBannerView(
            configId: AdConfig.configId_300x250,
            adSize: size,
            adFormats: [.banner],
            isLazyLoad: false
        )
        banner_300x250.frame = CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: size.height))
        banner_300x250.backgroundColor = .clear
        container.addSubview(banner_300x250)

        let gamRequest = AdManagerRequest()
        banner_300x250.createAd(
            with: gamRequest,
            gamBanner: gamBanner_300x250,
            eventHandler: AUBannerEventHandler(
                adUnitId: AdConfig.gamAdUnitId_300x250,
                gamView: gamBanner_300x250
            )
        )

        banner_300x250.onLoadRequest = { [weak self] request in
            guard let request = request as? AdManagerRequest else { return }
            self?.gamBanner_300x250?.load(request)
        }
    }


    // MARK: ── Scenario 3: Multi-size (320×50 + 300×250) ───────────────────────
    //
    // Use this when a single GAM ad unit can deliver either size.
    //
    // Two things must happen together:
    //
    //   A) Tell Prebid to request bids for BOTH sizes:
    //      → auBannerView is created with the primary size (320x50)
    //      → auBannerView.addAdditionalSize(sizes: [300x250]) adds the second
    //
    //   B) Tell GAM to accept BOTH sizes:
    //      → gamBanner is created with the primary size
    //      → gamBanner.validAdSizes includes both sizes as NSValue
    //
    // In bannerViewDidReceiveAd, AUAdViewUtils.findCreativeSize reads the
    // winning bid size from the ad creative HTML and we call bannerView.resize()
    // so the GAM view snaps to the exact winning size.

    private func setupBanner_multisize() {
        let primarySize   = CGSize(width: 320, height: 50)
        let secondarySize = CGSize(width: 300, height: 250)

        // The container starts at the primary (smaller) height.
        // We store the height constraint to update it in the delegate if a
        // 300x250 creative wins.
        let (container, heightConstraint) = makeContainer(
            label: "Scenario 3 — Multi-size (320×50 + 300×250)",
            height: primarySize.height
        )
        multisizeContainerHeight = heightConstraint

        // ✅ Start with a FIXED primary adSize — not adaptive
        gamBanner_multisize = AdManagerBannerView(adSize: adSizeFor(cgSize: primarySize))
        gamBanner_multisize.adUnitID = AdConfig.gamAdUnitId_multisize
        gamBanner_multisize.rootViewController = self
        gamBanner_multisize.delegate = self

        // ✅ CRITICAL — let GAM accept both sizes.
        //    Without this, GAM only accepts ads that exactly match primarySize.
        gamBanner_multisize.validAdSizes = [
            nsValue(for: adSizeFor(cgSize: primarySize)),
            nsValue(for: adSizeFor(cgSize: secondarySize)),
        ]

        banner_multisize = AUBannerView(
            configId: AdConfig.configId_multisize,
            adSize: primarySize,
            adFormats: [.banner],
            isLazyLoad: false
        )
        banner_multisize.frame = CGRect(
            origin: .zero,
            size: CGSize(width: view.bounds.width, height: primarySize.height)
        )
        banner_multisize.backgroundColor = .clear
        container.addSubview(banner_multisize)

        // ✅ CRITICAL — tell Prebid to bid for the secondary size too.
        //    Without this, Prebid only sends a bid request for primarySize.
        banner_multisize.addAdditionalSize(sizes: [secondarySize])

        let gamRequest = AdManagerRequest()
        banner_multisize.createAd(
            with: gamRequest,
            gamBanner: gamBanner_multisize,
            eventHandler: AUBannerEventHandler(
                adUnitId: AdConfig.gamAdUnitId_multisize,
                gamView: gamBanner_multisize
            )
        )

        banner_multisize.onLoadRequest = { [weak self] request in
            guard let request = request as? AdManagerRequest else { return }
            self?.gamBanner_multisize?.load(request)
        }
    }
}


// MARK: - BannerViewDelegate

extension FixedBannerViewController: BannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else { return }

        // NOTE: If you passed `eventHandler:` to `createAd(...)`, the SDK's
        // AUBannerHandler has already called `bannerView.resize()` automatically
        // using the cached `lastPrebidCreativeSize`. You still need to update your
        // container constraints here (the SDK can't know about your layout).
        //
        // `AUAdViewUtils.findCreativeSize` now uses a fast, reliable path:
        //   1. It first checks `AUBannerView.lastPrebidCreativeSize` — a CGSize
        //      populated directly from `customTargeting["hb_size"]` after
        //      `fetchDemand` completes. This is synchronous, always present when
        //      this delegate fires, and has NO dependency on WKWebView load state.
        //   2. Only if that cache is empty does it fall back to WKWebView HTML
        //      scraping (the old, unreliable behaviour).
        //
        // Alternatively, if you only need the size (not the full findCreativeSize
        // API), you can read it directly from the parent AUBannerView:
        //
        //   if let auBanner = bannerView.superview as? AUBannerView,
        //      let size = auBanner.lastPrebidCreativeSize {
        //       bannerView.resize(adSizeFor(cgSize: size))
        //       containerHeight?.constant = size.height
        //   }
        //
        // findCreativeSize succeeds only when a Prebid bid won. When GAM's own
        // ad wins (house ad, direct campaign), `lastPrebidCreativeSize` is nil
        // and the failure block fires — that is expected, not an error.

        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { [weak self, weak bannerView] size in
                guard let bannerView else { return }

                // Resize the GAM banner view to the winning creative size.
                // (AUBannerHandler has already done this if you used eventHandler:,
                //  so this is idempotent — calling it twice is harmless.)
                bannerView.resize(adSizeFor(cgSize: size))

                // Update the container height so the parent view fits the ad.
                if bannerView === self?.gamBanner_multisize {
                    self?.multisizeContainerHeight?.constant = size.height
                    UIView.animate(withDuration: 0.2) {
                        self?.view.layoutIfNeeded()
                    }
                }
            },
            failure: { error in
                // A GAM-direct ad won — no Prebid creative size available.
                // Safe to ignore unless you need to handle zero-height slots.
                print("findCreativeSize: \(error.localizedDescription)")
            }
        )
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("❌ Banner failed: \(error.localizedDescription)")
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        print("✅ Impression recorded for \(bannerView.adUnitID ?? "-")")
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        print("👆 Click recorded for \(bannerView.adUnitID ?? "-")")
    }
}
