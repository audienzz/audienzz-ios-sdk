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
    /// Stable logical placement, shared with replacement native ads.
    public lazy var requestContext = AUAdRequestContext()

    internal var adConfigId: String

    public var bannerParameters: AUBannerParameters?
    public var videoParameters: AUVideoParameters?

    // MARK: - Delivery settings
    //
    // Lazy loading and the prefetch margin are backend-driven only: the ad config's `lazyLoad` and
    // `prefetchDistanceDp`, else the SDK defaults. There is deliberately no publisher override, so
    // one placement behaves the same in every app and on every platform.

    /// Screen token applied to the underlying `AUBannerView` once it's built (see `setScreen`).
    private var pendingScreenKey: AnyObject?

    /// Publisher state requested before the inner banner existed.
    ///
    /// Remote config arrives asynchronously, so a host can legitimately stop or cover this banner
    /// while `bannerView` is still nil. Forwarding through an optional silently dropped those
    /// calls, and the banner built afterwards held neither — so a banner the publisher had stopped
    /// went on refreshing, and a reported cover was never applied.
    private var pendingPublisherStop = false
    private var pendingHostCover = false

    /// Held strongly: this class owns the banner's lifetime.
    ///
    /// It used to be `weak`, which meant the only thing keeping a banner alive was the container's
    /// subview list — so a second `load(in:)` simply added another one. Both stayed registered with
    /// the page coordinator and both kept their own refresh interval running, doubling the requests
    /// for a single placement while only the newest was visible.
    private var bannerView: AUBannerView?
    internal var loadGoogle: (AdManagerBannerView, Request) -> Void = { $0.load($1) }

    /// Exactly the constraints this class activated, so retiring a banner cannot deactivate a
    /// constraint the publisher put on their own container or on its other children.
    private var ownedConstraints: [NSLayoutConstraint] = []

    /// Identifies what an accepted load was for, so an identical repeat can be coalesced and a
    /// genuinely different one recognised as an intentional replacement.
    private struct LoadKey: Equatable {
        let adConfigId: String
        let container: ObjectIdentifier
        let rootViewController: ObjectIdentifier
        /// The size actually resolved for this load, not the size the caller asked for. Adaptive
        /// banners derive theirs from the container, so `nil` twice is not the same request twice.
        let resolvedSize: CGSize
        /// The resolved delivery settings. A refreshed ad config that changes them must not be
        /// coalesced into the banner built under the old values.
        let lazyLoad: Bool
        let prefetchMarginPoints: CGFloat
    }
    private var activeLoadKey: LoadKey?

    /// Bumped by every accepted load and every retirement. Asynchronous callbacks captured by a
    /// previous banner (`onLoadRequest`, `onAdSizeChanged`) compare against it and stand down, so a
    /// retired banner can neither drive the current GAM view nor resize the current container.
    private var loadGeneration: Int = 0

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

    /// Publisher pause. Durable: nothing else clears it — a scroll back into view or a page
    /// impression will not resume refresh until `resumeAutoRefresh()` is called.
    ///
    /// This used to forward to the viewport pause, so scrolling the banner back on screen silently
    /// undid it. Use `pauseSmartRefresh()` for a visibility pause; that is what the bridges report.
    @objc public func stopAutoRefresh() {
        pendingPublisherStop = true
        bannerView?.adUnitConfiguration.stopAutoRefresh()
    }

    /// Clears the publisher pause. Refresh only actually resumes once nothing else is holding it
    /// (the banner is on the active page, visible, and the app is in the foreground).
    @objc public func resumeAutoRefresh() {
        pendingPublisherStop = false
        bannerView?.adUnitConfiguration.resumeAutoRefresh()
    }

    /// Viewport pause, for view layers that do their own visibility detection (React Native,
    /// Flutter). Independent of the publisher pause above.
    @objc public func pauseSmartRefresh() {
        pendingHostCover = true
        bannerView?.pauseSmartRefresh()
    }

    /// Viewport resume. Clears only the visibility reason.
    @objc public func resumeSmartRefresh() {
        pendingHostCover = false
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
    /// High-level entry point for SDK users. Retain this owner (for example, as a view-controller
    /// property) for as long as the ad is used. The container retains the inner banner, not this
    /// owner; a local variable going out of scope would disable its Google-load and size callbacks.
    /// Report `pageImpression` before the first load and call `destroy()` when permanently finished.
    @MainActor
    public func load(
        in container: UIView,
        size: CGSize? = nil,
        rootViewController: UIViewController,
        delegate: GoogleMobileAds.BannerViewDelegate? = nil
    ) {
        // Resolved before the coalescing decision, because it is what a repeat has to match. A
        // container that has since been laid out wider produces a different adaptive size, and
        // treating that as a repeat left the banner pinned to the size it was first built for.
        guard let remoteConfig = AudienzzRemoteConfig.shared.remoteConfig(for: adConfigId) else {
            // Deliberately before any retirement: a momentarily missing config must not destroy a
            // banner that is working.
            AULogEvent.logDebug("[AURemoteConfigBannerView] Remote config is nil")
            return
        }

        let gadSize: AdSize

        if let adaptiveBannerConfig = remoteConfig.gamConfig.adaptiveBannerConfig, adaptiveBannerConfig.enabled {
            let adWidth: CGFloat = switch adaptiveBannerConfig.widthStrategy {
            case .fullWidth: container.bounds.width > 0 ? container.bounds.width : UIScreen.main.bounds.width
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

        // Inline adaptive descriptors have zero height until Google returns a creative.
        // Give the lazy viewport gate a real placeholder; keep GAM's descriptor unchanged.
        let configuredHeight = remoteConfig.gamConfig.adSizes.compactMap { CGSize.from(string: $0) }
            .first(where: { $0.height > 0 })?.height ?? 50
        let placeholderHeight = gadSize.size.height > 0 ? gadSize.size.height : configuredHeight
        let initialLayoutSize = CGSize(width: gadSize.size.width, height: placeholderHeight)

        let requestedKey = LoadKey(
            adConfigId: adConfigId,
            container: ObjectIdentifier(container),
            rootViewController: ObjectIdentifier(rootViewController),
            resolvedSize: gadSize.size,
            lazyLoad: resolvedLazyLoad(for: remoteConfig),
            prefetchMarginPoints: resolvedPrefetchMarginPoints(for: remoteConfig)
        )
        // An identical repeat is a no-op, not a second banner. React Native re-runs this whenever
        // any prop changes, and a publisher may call it from a layout pass that fires more than
        // once; each of those used to leave another live banner behind.
        //
        // "Identical" also requires the banner we are holding to still be usable. A publisher that
        // clears the container's children detaches and destroys ours without telling us, and
        // coalescing against that corpse left the slot permanently empty.
        if activeLoadKey == requestedKey, let current = bannerView, current.superview === container,
           !current.refreshController.isDestroyed {
            AUAdTrace.log(placement: adConfigId, load: loadGeneration, event: .ownerCoalesced)
            return
        }
        // Anything else is an intentional replacement: retire first, then build.
        retireCurrentBanner(reason: bannerView == nil ? "first load" : "replaced")
        activeLoadKey = requestedKey
        loadGeneration += 1
        let generation = loadGeneration
        AUAdTrace.log(placement: adConfigId, load: generation, event: .ownerAccepted)

        let gamBanner = AdManagerBannerView(adSize: gadSize)
        gamBanner.rootViewController = rootViewController
        gamBanner.delegate = delegate
        // Bridges need creative-size changes independently of load completion so their outer
        // layout can grow when an inline banner reports its height later.
        gamBanner.adSizeDelegate = delegate as? AdSizeDelegate
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

        // No Prebid sizes means the placement is sold through GAM alone. The ad unit still needs a
        // size to be built, so it takes GAM's; with header bidding off it is never sent.
        let headerBidding = !sortedSizes.isEmpty
        if !headerBidding {
            AULogEvent.logDebug("[AURemoteConfigBannerView] \(adConfigId) has no Prebid sizes — serving GAM-only")
        }

        let bannerView = AUBannerView(
            configId: remoteConfig.prebidConfig.placementId,
            adSize: sortedSizes.first ?? gadSize.size,
            adFormats: [.banner],
            isLazyLoad: resolvedLazyLoad(for: remoteConfig)
        )
        bannerView.headerBiddingEnabled = headerBidding
        bannerView.requestContext = requestContext
        self.bannerView = bannerView
        // So the delivery trace reports the ad config the publisher configured, not the Prebid
        // placement id, and matches the owner lines above.
        bannerView.tracePlacement = adConfigId
        if let pendingScreenKey { bannerView.hostScreenOverride = pendingScreenKey }

        // Routed through `adUnitConfiguration`, which is what owns the interval: it stores the value
        // for `AURefreshController` (and for analytics' `autorefresh_time`) and applies the 30s
        // floor. The banner installs its observer in `createAd`, which has already run by the time
        // the remote config arrives, so this reaches the controller.
        let configuredRefreshMs = Double((remoteConfig.config.refreshTimeSeconds ?? Self.defaultRefreshSeconds) * 1000)
        bannerView.adUnitConfiguration.setAutoRefreshMillis(time: configuredRefreshMs)
        bannerView.smartRefresh = true
        bannerView.prefetchMarginPoints = resolvedPrefetchMarginPoints(for: remoteConfig)

        bannerView.addAdditionalSize(sizes: Array(sortedSizes.dropFirst()))
        bannerView.videoParameters = videoParameters
        bannerView.bannerParameters = bannerParameters
        
        bannerView.frame = CGRect(origin: .zero, size: initialLayoutSize)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.backgroundColor = .clear
        container.addSubview(bannerView)

        let handler = AUBannerEventHandler(
            adUnitId: remoteConfig.gamConfig.adUnitPath,
            gamView: gamBanner
        )

        // Before createAd: a stop requested while config was resolving must be in place before the
        // banner can issue its first request.
        applyPendingPublisherState(to: bannerView)

        // Installed BEFORE createAd, which may issue the first request itself (an eager banner).
        bannerView.onLoadRequest = { [weak self] gamRequest in
            // A retired banner's demand callback must not drive a GAM view that is no longer the
            // one on screen.
            guard let self, self.loadGeneration == generation else { return }
            guard let request = gamRequest as? Request else {
                print("[AURemoteConfigBannerView] Failed to unwrap GAM request")
                return
            }
            // The delivery's own identity, not the owner's. Every other google.* line for this
            // load carries it, and mixing the two made a request impossible to pair with its
            // completion — the owner's counter was the same on every refresh.
            AUAdTrace.log(
                placement: self.adConfigId,
                delivery: self.bannerView?.pendingDeliveryId,
                event: .googleRequested
            )
            if remoteConfig.gamConfig.adaptiveBannerConfig?.enabled == true {
                // Layout and a previous creative's resize can turn adSize into a fixed size.
                // Restore the adaptive request descriptor without adSize's implicit request.
                // The outer AUBannerView keeps its nonzero lazy-loading placeholder.
                gamBanner.resize(gadSize)
            }
            self.loadGoogle(gamBanner, request)
        }

        bannerView.createAd(with: gamRequest, gamBanner: gamBanner, eventHandler: handler)

        let bannerWidthConstraint = bannerView.widthAnchor.constraint(equalToConstant: gadSize.size.width)
        let bannerHeightConstraint = bannerView.heightAnchor.constraint(equalToConstant: initialLayoutSize.height)
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
        let containerHeightConstraint = container.heightAnchor.constraint(equalToConstant: initialLayoutSize.height)

        let created = [
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerWidthConstraint,
            bannerHeightConstraint,
            containerWidthConstraint,
            containerHeightConstraint
        ]
        NSLayoutConstraint.activate(created)
        ownedConstraints = created

        // When GAM serves an ad at a different size than the initially declared slot
        // (e.g. a 300×600 direct campaign against a 300×250 Prebid bid), update the
        // bannerView and container constraints to match the actual rendered size so
        // the ad is neither clipped nor surrounded by blank space.
        bannerView.onAdSizeChanged = { [weak self, weak container] newSize in
            guard let self, self.loadGeneration == generation else { return }
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

    /// Releases the banner this view owns. Safe to call more than once, and safe to call when no
    /// banner was ever built. Leaves every other child of the container untouched.
    @objc public func destroy() {
        retireCurrentBanner(reason: "disposed")
    }

    // MARK: - Private

    /// Retires the current banner: stops its refresh, deregisters it from the page coordinator,
    /// removes only the views and constraints this class created, and invalidates any callback a
    /// previous load left outstanding.
    private func retireCurrentBanner(reason: String) {
        loadGeneration += 1
        NSLayoutConstraint.deactivate(ownedConstraints)
        ownedConstraints.removeAll()
        activeLoadKey = nil
        guard let banner = bannerView else { return }
        AUAdTrace.log(placement: adConfigId, load: loadGeneration, event: .ownerRetired, detail: reason)
        banner.onLoadRequest = nil
        banner.onAdSizeChanged = nil
        // destroy() stops the refresh controller and deregisters from the coordinator; the
        // removal takes only our own subview out of a container we do not own.
        banner.destroy()
        banner.removeFromSuperview()
        bannerView = nil
    }

    /// Applies whatever the host asked for while the inner banner was still being built.
    ///
    /// The stop goes on first, before `createAd` can request: installing it afterwards would let an
    /// eager banner issue one request the publisher had already stopped.
    private func applyPendingPublisherState(to banner: AUBannerView) {
        if pendingPublisherStop {
            banner.adUnitConfiguration.stopAutoRefresh()
        }
        if pendingHostCover {
            banner.pauseSmartRefresh()
        }
    }

    /// Resolved lazy loading: the ad config, then ``defaultLazyLoad``.
    internal func resolvedLazyLoad(for remoteConfig: RemoteAdConfiguration) -> Bool {
        remoteConfig.config.lazyLoad ?? Self.defaultLazyLoad
    }

    /// Resolved prefetch margin in points: the ad config's `prefetchDistanceDp`, then 200 pt.
    internal func resolvedPrefetchMarginPoints(for remoteConfig: RemoteAdConfiguration) -> CGFloat {
        CGFloat(remoteConfig.config.prefetchDistancePt ?? Self.defaultPrefetchDistancePt)
    }

    private static let defaultRefreshSeconds = 30
    private static let defaultPrefetchDistancePt = 200

    /// Remote-config banners defer their auction until the slot approaches the viewport unless the
    /// ad config asks otherwise.
    ///
    /// This was briefly flipped to eager. That made every mounted placement auction on `load(...)`
    /// regardless of position, so a publisher opening an article bought fills for below-fold slots
    /// the reader might never approach — responses that can never become impressions, which is the
    /// delivery pattern we are trying to reduce, not create. Eager remains available per placement
    /// (`lazyLoad: false` on the ad config) for slots that are always on screen.
    internal static let defaultLazyLoad = true
}
