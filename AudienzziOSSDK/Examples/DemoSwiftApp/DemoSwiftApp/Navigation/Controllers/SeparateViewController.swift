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

import AudienzziOSSDK
import GoogleInteractiveMediaAds
import GoogleMobileAds
import UIKit

class SeparateViewController: UIViewController {
    @IBOutlet private weak var exampleScrollView: UIScrollView!
    @IBOutlet internal weak var adContainerView: UIView!
    @IBOutlet internal weak var lazyAdContainerView: UIView!

    var selectedType: AdTypeExample!

    internal let adSize = CGSize(width: 320, height: 50)
    internal let adSizeMult = CGSize(width: 300, height: 250)
    internal let adVideoSize = CGSize(width: 300, height: 250)
    internal var adaptiveSize: AdSize!

    //HTML_Banner
    internal var bannerView_320x50: AUBannerView!
    internal var bannerView_300x250: AUBannerView!
    internal var bannerMultisizeView: AUBannerView!
    internal var bannerVideoView: AUBannerView!
    internal var bannerMultiplatformView: AUBannerView!
    internal var bannerLazyView_320x50: AUBannerView!
    internal var bannerLazyView_300x250: AUBannerView!
    internal var bannerLazyMultisizeView: AUBannerView!
    internal var bannerLazyVideoView: AUBannerView!
    internal var bannerLazyMultiplatformView: AUBannerView!
    internal var bannerUnfilledView: AUBannerView!

    // Multiformat
    internal var adMultiLoader: AdLoader!
    internal var adMultiLoaderSecond: AdLoader!
    internal var multiformatView: AUMultiplatformView!
    internal var multiformatViewSecond: AUMultiplatformView!
    // Multiformat Lazy
    internal var adLazyMultiLoader: AdLoader!
    internal var multiformatLazyView: AUMultiplatformView!

    // Interstitial API
    internal var interstitialView: AUInterstitialView!
    internal var interstitialVideoView: AUInterstitialView!
    internal var interstitialMultiplatformView: AUInterstitialView!

    // Native API
    internal var adLoader: AdLoader!
    internal var adLazyLoader: AdLoader!
    internal var adRenderingLoader: AdLoader!
    internal var adRenderingLazyLoader: AdLoader!
    internal var nativeView: AUNativeView!
    internal var nativeRenderingView: AUNativeView!
    internal var nativeBannerView: AUNativeBannerView!
    internal var nativeLzyView: AUNativeView!
    internal var nativeLzyRenderingView: AUNativeView!
    internal var nativeLazyBannerView: AUNativeBannerView!

    // Instream API
    internal var playButton: UIButton!
    internal var instreamView: AUInstreamView!
    internal var adsLoader: IMAAdsLoader!
    internal var adsManager: IMAAdsManager?
    internal var contentPlayhead: IMAAVPlayerContentPlayhead?
    internal var contentPlayer: AVPlayer?
    internal var playerLayer: AVPlayerLayer?

    // Rewarded
    internal var rewardedView: AURewardedView!

    override func viewDidLoad() {
        super.viewDidLoad()
        exampleScrollView.backgroundColor = .black

        setupAdContainer()
        setupALazydContainer()
    }

    private func setupAdContainer() {
        switch selectedType {
        case .bannerOrigin:
            createBannerView_320x50()
            createBannerView_300x250()
            createBannerUnfilledView()
        case .bannerOriginVideo:
            createVideoBannerView()
        case .bannerOriginMulti:
            createBannerMultiplatformView()
            createMultiplatformView()
        case .interstitalOrigin:
            break
        case .interstitalOriginVideo:
            break
        case .interstitalOriginMulti:
            break
        case .rewardedOrigin:
            break
        case .bannerRender:
            createRenderingBannerView()
        case .bannerRenderVideo:
            createRenderingBannerVideoView()
        case .interstitialRender:
            break
        case .interstitialRenderVideo:
            break
        case .rewardedRender:
            break
        case .allExample:
            break
        default: break
        }
    }

    private func setupALazydContainer() {
        switch selectedType {
        case .bannerOrigin:
            createBannerLazyView_320x50()
            createBannerLazyView_320x250()
        case .bannerOriginVideo:
            createVideoLazyBannerView()
        case .bannerOriginMulti:
            createBannerMultiplatformLazyView()
            createMultiplatformLazyView()
        case .interstitalOrigin:
            createInterstitialView()
        case .interstitalOriginVideo:
            createInterstitialVideoView()
        case .interstitalOriginMulti:
            createInterstitialMultiplatformView()
        case .rewardedOrigin:
            createRewardedView()
        case .bannerRender:
            createRenderingBannerLazyView()
        case .bannerRenderVideo:
            createRenderingBannerVideoLazyView()
        case .interstitialRender:
            createRenderingIntertitiaBannerView()
        case .interstitialRenderVideo:
            createRenderingIntertitiaVideoView()
        case .rewardedRender:
            createRenderingRewardLazyView()
        case .allExample:
            break
        default: break
        }
    }

    private func addRenderingLabel(_ viewContainer: UIView) {
        let nameLabel = UILabel(
            frame: CGRect(
                x: 0,
                y: getPositionY(viewContainer),
                width: viewContainer.frame.size.width,
                height: 60
            )
        )
        nameLabel.text = "GAM (Rendering API)"
        nameLabel.textColor = .black
        nameLabel.backgroundColor = .white
        viewContainer.addSubview(nameLabel)
    }

    @IBAction private func refreshAdContainerDidTap() {
        var subviews = adContainerView.subviews
        subviews.remove(at: 0)

        guard !subviews.isEmpty else {
            return
        }

        for subview in subviews {
            subview.removeFromSuperview()
        }

        setupAdContainer()
    }

    @IBAction private func refreshLazyAdContainerDidTap() {
        var subviews = lazyAdContainerView.subviews
        subviews.remove(at: 0)

        guard !subviews.isEmpty else { return }

        exampleScrollView.setContentOffset(
            CGPoint(
                x: 0,
                y: lazyAdContainerView.frame.origin.y
                    - (view.bounds.size.height)
            ),
            animated: true
        )

        for subview in subviews {
            subview.removeFromSuperview()
        }

        setupALazydContainer()
    }

    deinit {
        print("deinit SeparateViewController")
    }
}

// MARK: - Helpers
extension SeparateViewController {
    func getPositionY(_ parent: UIView) -> CGFloat {
        guard let lastView = parent.subviews.last else {
            return 0
        }

        return lastView.frame.origin.y + lastView.frame.height
    }

    func stopScroll() {
        DispatchQueue.main.async {
            let offset = self.exampleScrollView.contentOffset
            self.exampleScrollView.setContentOffset(offset, animated: false)
        }
    }

    func addDebugLabel(toView: UIView, name: String, color: UIColor = .black) {
        #if DEBUG
            let nameLabel = UILabel(
                frame: CGRect(
                    x: 20,
                    y: 10,
                    width: toView.frame.size.width,
                    height: 30
                )
            )
            nameLabel.text = name
            nameLabel.textColor = color
            toView.addSubview(nameLabel)
        #endif
    }

    func errorHandling(forView: UIView, error: Error) {
        guard let superview = forView.superview,
            let adView = superview as? AUAdView
        else { return }

        #if DEBUG
            adView.backgroundColor = .black
            addDebugLabel(
                toView: adView,
                name: error.localizedDescription,
                color: .white
            )
        #else
            // work on prod
            adView.backgroundColor = .black
            adView.collapseBehaviour(forView: superview)
            guard let parent = adView.superview else { return }
            updatesize(fromView: adView, parent: parent, size: .zero)
        #endif
    }

    func errorHandling(adView: AUAdView, error: Error) {
        //        #if DEBUG
        adView.backgroundColor = .black
        addDebugLabel(
            toView: adView,
            name: error.localizedDescription,
            color: .white
        )
        //        #else
        //        // work on prod
        //        adView.backgroundColor = .black
        //        adView.collapseBehaviour(forView: superview)
        //        guard let parent = adView.superview else { return }
        //        updatesize(fromView: adView, parent: parent, size: .zero)
        //        #endif
    }

    func showSizeError(forView: UIView, error: Error) {
        guard let superview = forView.superview,
            let adView = superview as? AUAdView
        else { return }
        guard (error as NSError).code != 111 else { return }

        let className = String(describing: type(of: adView.self))

        let alertController = UIAlertController(
            title: "Error - \(className)",
            message: "\(error.localizedDescription)",
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            print("OK tapped")
        }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }

    func updatesize(fromView: UIView, parent: UIView, size: CGSize) {
        //update y positions

        let parentSubviews = parent.subviews
        var maxYPostion: CGFloat = 0

        for subview in parentSubviews {
            subview.frame = CGRect(
                x: fromView.frame.origin.x,
                y: maxYPostion,
                width: subview.frame.size.width,
                height: subview.frame.size.height
            )
            print("SubView Size: \(subview.frame.size)")
            maxYPostion = subview.frame.origin.y + subview.frame.height
        }
    }

    func addConstrains(subView: UIView, container: UIView, height: CGFloat) {
        subView.translatesAutoresizingMaskIntoConstraints = false

        let previousView = container.subviews[container.subviews.count - 2]

        NSLayoutConstraint.activate([
            subView.topAnchor.constraint(equalTo: previousView.bottomAnchor),
            subView.heightAnchor.constraint(equalToConstant: height),
            subView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subView.trailingAnchor.constraint(
                equalTo: container.trailingAnchor
            ),

        ])

    }
}
