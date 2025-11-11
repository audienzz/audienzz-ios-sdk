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
            isLazyLoad: false
        )

        if let refreshTimeSeconds = remoteConfig.config.refreshTimeSeconds {
            bannerView.adUnit.setAutoRefreshMillis(time: Double(refreshTimeSeconds * 1000))
        }

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

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: gadSize.size.width),
            bannerView.heightAnchor.constraint(equalToConstant: gadSize.size.height),
            container.widthAnchor.constraint(equalToConstant: gadSize.size.width),
            container.heightAnchor.constraint(equalToConstant: gadSize.size.height)
        ])
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

}
