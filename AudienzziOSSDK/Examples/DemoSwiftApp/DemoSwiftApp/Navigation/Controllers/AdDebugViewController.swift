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

// 320x250
fileprivate let storedImpDisplayBanner_320x250 = "33994718"
fileprivate let gamAdUnitDisplayBannerOriginal_320x250 = "/96628199/de_audienzz.ch_v2/de_audienzz.ch_320_adnz_wideboard_1"

class AdDebugViewController: UIViewController {
    @IBOutlet private weak var exampleScrollView: UIScrollView!
    @IBOutlet internal weak var adContainerView: UIView!
    @IBOutlet internal weak var lazyAdContainerView: UIView!
    
    internal let adSize = CGSize(width: 320, height: 50)
    internal let adSizeMult = CGSize(width: 300, height: 250)
    internal let adVideoSize = CGSize(width: 300, height: 250)
    internal var adaptiveSize: GADAdSize!
    
    fileprivate var bannerView_300x250: AUBannerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        exampleScrollView.backgroundColor = .black
        
        setupAdContainer()
        setupALazydContainer()
    }
    
    private func setupAdContainer() {
        createBannerView_320x250()
    }
    
    private func setupALazydContainer() {
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
        
        exampleScrollView.setContentOffset(CGPoint(x: 0, y: lazyAdContainerView.frame.origin.y - (view.bounds.size.height)), animated: true)
        
        for subview in subviews {
            subview.removeFromSuperview()
        }
        
        setupALazydContainer()
    }
    
    deinit {
        print("deinit AdDebugViewController")
    }
    
    private func createBannerView_320x250() {
        let gamBanner = GAMBannerView(adSize: GADAdSizeFromCGSize(adVideoSize))
        gamBanner.adUnitID = gamAdUnitDisplayBannerOriginal_320x250
        gamBanner.rootViewController = self
        gamBanner.delegate = self
        let gamRequest = GAMRequest()
        
        bannerView_300x250 = AUBannerView(configId: storedImpDisplayBanner_320x250, adSize: adSizeMult, adFormats: [.banner], isLazyLoad: false)
        bannerView_300x250.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)),
                                          size: CGSize(width: self.view.frame.width, height: 250))
        bannerView_300x250.backgroundColor = .clear
        adContainerView.addSubview(bannerView_300x250)
        
        let handler = AUBannerEventHandler(adUnitId: gamAdUnitDisplayBannerOriginal_320x250, gamView: gamBanner)
        
        bannerView_300x250.createAd(with: gamRequest, gamBanner: gamBanner, eventHandler: handler)
        
        bannerView_300x250.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else {
                print("Faild request unwrap")
                return
            }
            gamBanner.load(request)
        }
    }
    
    private func getPositionY(_ parent: UIView) -> CGFloat {
        guard let lastView = parent.subviews.last else {
            return 0
        }
        
        return lastView.frame.origin.y + lastView.frame.height
    }
}

// MARK: - GADBannerViewDelegate
extension AdDebugViewController: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        guard let bannerView = bannerView as? GAMBannerView else { return }
        AUAdViewUtils.findCreativeSize(bannerView, success: { size in
            bannerView.resize(GADAdSizeFromCGSize(size))
        }, failure: { (error) in
            print(error)
        })
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("GAM did fail to receive ad with error: \(error)")
    }
}
