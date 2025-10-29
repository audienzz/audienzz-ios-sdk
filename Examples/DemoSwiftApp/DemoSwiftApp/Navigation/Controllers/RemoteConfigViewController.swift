//
//  RemoteConfigViewController.swift
//  DemoSwiftApp
//
//  Created by Maksym Ovcharuk on 27.10.2025.
//

import AudienzziOSSDK
import GoogleInteractiveMediaAds
import GoogleMobileAds
import UIKit

class RemoteConfigViewController: UIViewController {
    private enum Constants {
        static let defaultPublisherId = "81"

        static let defaultConfigId = "118"

        static let defaultPublisherRemoteUrl = "https://dev-api.adnz.co/api/ws-sdk-config/public/v1/"
    }

    internal var bannerView: AURemoteConfigBannerView!

    // MARK: - IBOutlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var stackView: UIStackView!

    // Ad display
    @IBOutlet private weak var adContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDefaultPublisher()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requestAd()
    }

    func requestAd() {
        adContainerView.subviews.forEach { $0.removeFromSuperview() }

        let bannerView = AURemoteConfigBannerView(adConfigId: Constants.defaultConfigId)
        bannerView.load(in: adContainerView,
                        size: AdSizeBanner.size,
                        rootViewController: self)
    }
}

// MARK: - Private

private extension RemoteConfigViewController {
    func setupDefaultPublisher() {
        RemoteConfigManager.shared.setPublisherId(Constants.defaultPublisherId)
        RemoteConfigManager.shared.setRemoteUrl(
            URL(string: Constants.defaultPublisherRemoteUrl)!
        )
    }
}
