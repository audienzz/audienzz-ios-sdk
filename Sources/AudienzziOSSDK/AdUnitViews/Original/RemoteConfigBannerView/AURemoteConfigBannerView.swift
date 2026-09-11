//
//  AURemoteConfigBannerView.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 27.10.2025.
//

import UIKit
import PrebidMobile
import GoogleMobileAds

/**
 AURemoteConfigBannerView.
 Ad view for demand banner based on the remote configuration.
 */
@objcMembers
public class AURemoteConfigBannerView: VisibleView {
    internal var adConfigId: String

    public var bannerParameters: AUBannerParameters?
    public var videoParameters: AUVideoParameters?

    /// Screen token applied to the underlying `AUBannerView` once it's built (see `setScreen`).
    private var pendingScreenKey: AnyObject?
    private weak var bannerView: AUBannerView?

    /// Associate this banner with a screen the SDK can't infer from the view hierarchy (a SwiftUI
    /// destination, or a custom route). Pass the same token reported to
    /// `Audienzz.shared.pageImpression(token)`; matched by value. Call before or after `load(...)` —
    /// the underlying banner is built asynchronously, so the key is applied when ready.
    public func setScreen(_ screenKey: Any) {
        pendingScreenKey = screenKey as AnyObject
        bannerView?.hostScreenOverride = pendingScreenKey
    }

    /// Force a fresh auction now on the underlying banner, ignoring the stale-aware refresh timing.
    /// Forwards to `AUBannerView.reloadAd()` — used by the RN/Flutter bridges to reload on screen
    /// change, and for a manual reload. No-op until the underlying banner has been built.
    @objc public func reloadAd() {
        bannerView?.reloadAd()
    }

    /// Pause Prebid smart-refresh on the underlying banner. Forwards to
    /// `AUBannerView.pauseSmartRefresh()`. No-op until the banner has been built.
    @objc public func stopAutoRefresh() {
        bannerView?.pauseSmartRefresh()
    }

    /// Resume Prebid smart-refresh on the underlying banner previously paused via
    /// `stopAutoRefresh()`. Forwards to `AUBannerView.resumeSmartRefresh()`.
    @objc public func resumeAutoRefresh() {
        bannerView?.resumeSmartRefresh()
    }

    // MARK: - Init

    public init(adConfigId: String) {
        self.adConfigId = adConfigId
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API
    /// High-level entry point for SDK users.
    @MainActor
    public func load(
        in container: UIView,
        size: CGSize? = nil,
        rootViewController: UIViewController,
        delegate: GoogleMobileAds.BannerViewDelegate? = nil
    ) {
        guard let remoteConfig = AudienzzRemoteConfig.shared.remoteConfig(for: adConfigId) else {
            AULogEvent.logDebug("[AURemoteConfigBannerView] Remote config is nil")
            return
        }

        let gadSize: AdSize

        if let adaptiveBannerConfig = remoteConfig.gamConfig.adaptiveBannerConfig, adaptiveBannerConfig.enabled {
            let adWidth: CGFloat = switch adaptiveBannerConfig.widthStrategy {
            case .fullWidth: max(container.bounds.width, UIScreen.main.bounds.width)
            case .custom: adaptiveBannerConfig.customWidth ?? 0
            default: adaptiveBannerConfig.customWidth ?? 0
            }

            if let maxHeight = adaptiveBannerConfig.maxHeight {
                gadSize = inlineAdaptiveBanner(width: adWidth, maxHeight: maxHeight)
            } else {
                gadSize = currentOrientationInlineAdaptiveBanner(width: adWidth)
            }
        } else {
            if let size = size, size.height > 0 {
                gadSize = adSizeFor(cgSize: size)
            } else if let firstSizeString = remoteConfig.gamConfig.adSizes.first,
                      let firstSize = CGSize.from(string: firstSizeString) {
                gadSize = adSizeFor(cgSize: firstSize)
            } else {
                gadSize = adSizeFor(cgSize: size ?? .zero)
            }
        }

        let gamBanner = AdManagerBannerView(adSize: gadSize)
        gamBanner.rootViewController = rootViewController
        gamBanner.delegate = delegate
        gamBanner.adUnitID = remoteConfig.gamConfig.adUnitPath
        gamBanner.validAdSizes = remoteConfig.gamConfig.adSizes
            .compactMap { CGSize.from(string: $0) }
            .map { nsValue(for: adSizeFor(cgSize: $0)) }

        let gamRequest = AdManagerRequest()
        let ppid = PPIDManager.shared.getPPID()

        if let ppid = ppid {
            gamRequest.publisherProvidedID = ppid
        }

        let sortedSizes = remoteConfig.prebidConfig.adSizes
            .compactMap { CGSize.from(string: $0) }
            .sorted {
                ($0.width * $0.height) > ($1.width * $1.height)
            }

        let bannerView = AUBannerView(
            configId: remoteConfig.prebidConfig.placementId,
            adSize: sortedSizes.first ?? .zero,
            adFormats: [.banner],
            isLazyLoad: true
        )
        self.bannerView = bannerView
        if let pendingScreenKey { bannerView.hostScreenOverride = pendingScreenKey }

        // M4: route refresh through adUnitConfiguration (not adUnit directly) so
        // autorefreshEventModel is updated — otherwise the stale-aware smart
        // refresh logic reads autorefreshTime == 0 and never engages, and
        // analytics report isAutorefresh = false.
        // M22: Prebid enforces a 30s floor (values below are silently rejected).
        // Clamp positive values here so Prebid and the SDK's stale-aware refresh
        // use the same effective cadence.
        let configuredRefreshMs = Double((remoteConfig.config.refreshTimeSeconds ?? Self.defaultRefreshSeconds) * 1000)
        let refreshMs = configuredRefreshMs > 0 ? max(configuredRefreshMs, 30_000) : configuredRefreshMs
        bannerView.adUnitConfiguration.setAutoRefreshMillis(time: refreshMs)
        bannerView.smartRefresh = true
        bannerView.prefetchMarginPoints = CGFloat(remoteConfig.config.prefetchDistancePt ?? Self.defaultPrefetchDistancePt)

        bannerView.addAdditionalSize(sizes: Array(sortedSizes.dropFirst()))
        bannerView.videoParameters = videoParameters
        bannerView.bannerParameters = bannerParameters
        
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.backgroundColor = .clear
        container.addSubview(bannerView)

        let handler = AUBannerEventHandler(
            adUnitId: remoteConfig.gamConfig.adUnitPath,
            gamView: gamBanner
        )

        bannerView.createAd(with: gamRequest, gamBanner: gamBanner, eventHandler: handler)

        gamBanner.frame = CGRect(origin: .zero, size: gadSize.size)

        bannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("[AURemoteConfigBannerView] Failed to unwrap GAM request")
                return
            }
            gamBanner.load(request)
        }

        let bannerWidthConstraint = bannerView.widthAnchor.constraint(equalToConstant: gadSize.size.width)
        let bannerHeightConstraint = bannerView.heightAnchor.constraint(equalToConstant: gadSize.size.height)
        let containerWidthConstraint = container.widthAnchor.constraint(equalToConstant: gadSize.size.width)
        // The host owns the container's width: the RN bridge lets React Native size the
        // view (full width), and native callers pin it themselves (e.g. leading+trailing).
        // Pinning the container to the creative's own width at required priority forced it
        // to the leading edge — so a creative narrower than the screen (e.g. 300x600 on a
        // tablet) rendered left-aligned instead of centered, and conflicted with a host that
        // already constrained the width. Demote it to a fallback: a host-provided width wins
        // and `centerXAnchor` centers the banner; if no width is supplied, this still sizes
        // the container to the ad.
        containerWidthConstraint.priority = .defaultLow
        let containerHeightConstraint = container.heightAnchor.constraint(equalToConstant: gadSize.size.height)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerWidthConstraint,
            bannerHeightConstraint,
            containerWidthConstraint,
            containerHeightConstraint
        ])

        // When GAM serves an ad at a different size than the initially declared slot
        // (e.g. a 300×600 direct campaign against a 300×250 Prebid bid), update the
        // bannerView and container constraints to match the actual rendered size so
        // the ad is neither clipped nor surrounded by blank space.
        bannerView.onAdSizeChanged = { [weak container] newSize in
            bannerWidthConstraint.constant = newSize.width
            bannerHeightConstraint.constant = newSize.height
            containerWidthConstraint.constant = newSize.width
            containerHeightConstraint.constant = newSize.height
            // layoutIfNeeded on the superview ensures constraints attached to `container`
            // itself (not just inside it) are also resolved in the same layout pass.
            container?.superview?.layoutIfNeeded()
        }
    }
    
    @objc public func load(
        in container: UIView,
        width: CGFloat,
        height: CGFloat,
        rootViewController: UIViewController,
        delegate: GoogleMobileAds.BannerViewDelegate? = nil
    ) {
        let size = CGSize(width: width, height: height)
        load(in: container, size: size, rootViewController: rootViewController, delegate: delegate)
    }

    // MARK: - Private

    private static let defaultRefreshSeconds = 30
    private static let defaultPrefetchDistancePt = 200
}
