/*   Copyright 2018-2024 Audienzz.org, Inc.
 
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
import GoogleInteractiveMediaAds

class ExamplesViewController: UIViewController {
    @IBOutlet private weak var exampleScrollView: UIScrollView!
    @IBOutlet weak var adContainerView: UIView!
    @IBOutlet weak var lazyAdContainerView: LazyAdContainerView!
    var playButton: UIButton!
    
    let adSize = CGSize(width: 320, height: 50)
    let adVideoSize = CGSize(width: 320, height: 250)
    var adLoader: GADAdLoader!
    var adLazyLoader: GADAdLoader!
    
    internal var bannerView: AUBannerView!
    internal var bannerLazyView: AUBannerView!

    internal var bannerVideoView: AUBannerView!
    internal var bannerMultiplatformView: AUBannerView!
    
    
    // Instream
    // IMA
    var adsLoader: IMAAdsLoader!
    var adsManager: IMAAdsManager?
    var contentPlayhead: IMAAVPlayerContentPlayhead?
    var contentPlayer: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var instreamView: AUInstreamView!
    
    internal var adMultiLoader: GADAdLoader!
    internal var adMultiLoaderSecond: GADAdLoader!
    internal var multiformatView: AUMultiplatformView!
    internal var multiformatViewSecond: AUMultiplatformView!

    // Multiformat Lazy
    internal var adLazyMultiLoader: GADAdLoader!
    internal var multiformatLazyView: AUMultiplatformView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        exampleScrollView.backgroundColor = .black
        
        setupAdContainer()
//        setupALazydContainer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        playerLayer?.frame = instreamView.layer.bounds
        adsManager?.destroy()
        contentPlayer?.pause()
        contentPlayer = nil
    }
    
    private func setupAdContainer() {
        createBannerView()
        createVideoBannerView()
        createBannerMultiplatformView()
//        
//        createNativeView()
//        createNativeBannerView()
//        
//        createInstreamView()
//        
//        createRenderingBannerView()
//        createRenderingBannerVideoView()
    }
    
    private func setupALazydContainer() {
        createBannerLazyView()

        createInterstitialView()
        createInterstitialVideoView()
        createInterstitialMultiplatformView()
        
        createLazyNativeView()
        createLazyNativeBannerView()
        
        createRewardedView()
        createRenderingBannerLazyView()
        createRenderingRewardLazyView()
        
        createRenderingIntertitiaView()
        createRenderingRewardLazyView()
    }
    
    @IBAction private func refreshAdContainerDidTap() {
        var subviews = adContainerView.subviews
        subviews.remove(at: 0)
        
        guard !subviews.isEmpty else { return }
        
        for subview in subviews {
            subview.removeFromSuperview()
        }
        
        setupAdContainer()
    }
}

// MARK: - Helpers
extension ExamplesViewController {
    func getPositionY(_ parent: UIView) -> CGFloat {
        guard let lastView = parent.subviews.last else {
            return 0
        }
        
        return lastView.frame.origin.y + lastView.frame.height
    }
}

extension UIView {
    class func fromNib<T: UIView>() -> T {
        return Bundle(for: T.self).loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
    }
}
