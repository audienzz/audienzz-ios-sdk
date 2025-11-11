//
//  RemoteConfigBannerView.swift
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

    private var remoteConfig: RemoteAdConfiguration?

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
    public func load(in container: UIView, size: CGSize, rootViewController: UIViewController) {
        guard let publisherId = RemoteConfigManager.shared.getPublisherId() else {
            print("[AURemoteConfigBannerView] publisherId isn't configured, Can't load remote ads")
            return
        }

        Task {
            do {
                try await loadRemoteConfiguration(publisherId: publisherId, adConfigId: adConfigId)
                createRemoteAd(in: container, size: size, rootViewController: rootViewController)
            } catch {
                print("[AURemoteConfigBannerView] Failed to load or create remote ad:", error)
            }
        }
    }

    // MARK: - Internal Logic

    private func loadRemoteConfiguration(publisherId: String, adConfigId: String) async {
        do {
            let config = try await RemoteConfigFetcher.shared.fetchBannerConfig(
                publisherId: publisherId,
                adConfigId: adConfigId
            )
            self.remoteConfig = config
        } catch {
            print("[AURemoteConfigBannerView] Failed to fetch remote banner config:", error)
        }
    }
    
    private func createRemoteAd(in container: UIView,
                                size: CGSize,
                                rootViewController: UIViewController?) {
        guard let remoteConfig else {
            print("[AURemoteConfigBannerView] Remote config is nil")
            return
        }

        let gamBanner = AdManagerBannerView(adSize: adSizeFor(cgSize: size))
        gamBanner.rootViewController = rootViewController
        gamBanner.adUnitID = remoteConfig.gamConfig.adUnitPath
        gamBanner.validAdSizes = remoteConfig.gamConfig.adSizes
            .compactMap { CGSize.from(string: $0) }
            .map { nsValue(for: adSizeFor(cgSize: $0)) }

        let gamRequest = AdManagerRequest()
        let bannerView = AUBannerView(
            configId: remoteConfig.prebidConfig.placementId,
            adSize: size,
            adFormats: [.banner],
            isLazyLoad: false
        )

        bannerView.bannerParameters = bannerParameters
        bannerView.frame = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: container.frame.width, height: size.height)
        )
        bannerView.backgroundColor = .clear
        container.addSubview(bannerView)

        let handler = AUBannerEventHandler(
            adUnitId: remoteConfig.gamConfig.adUnitPath,
            gamView: gamBanner
        )

        bannerView.createAd(with: gamRequest, gamBanner: gamBanner, eventHandler: handler)
        bannerView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                print("[AURemoteConfigBannerView] Failed to unwrap GAM request")
                return
            }
            gamBanner.load(request)
        }

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
}
