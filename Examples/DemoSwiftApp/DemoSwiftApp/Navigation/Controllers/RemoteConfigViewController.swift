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
        static let inlineAdaptiveConfigId = 118
    }

    // MARK: - IBOutlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var stackView: UIStackView!

    // Ad display
    @IBOutlet private weak var adContainerView: UIView!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requestAd()
    }

    func requestAd() {
        adContainerView.subviews.forEach { $0.removeFromSuperview() }

        let bannerView = AURemoteConfigBannerView(adConfigId: Constants.inlineAdaptiveConfigId)
        bannerView.load(in: adContainerView,
                        rootViewController: self)
    }
}
