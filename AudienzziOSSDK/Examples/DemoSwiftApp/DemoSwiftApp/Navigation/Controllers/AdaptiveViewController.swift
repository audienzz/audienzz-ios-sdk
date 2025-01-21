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

/**
Multi-Size Banner Options in Google Mobile Ads SDK for iOS

 - Adaptive Banner:
   - Description: Automatically adjusts the height based on the screen width.
   - Supported By: AdMob, Google Ad Manager.
   - Use Case: Best for dynamically resizing banners across devices and orientations.
   - Example:
     ```
     let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(UIScreen.main.bounds.width)
     let bannerView = GADBannerView(adSize: adSize)
     ```

 - Multi-Size Banner (`validAdSizes`):
   - Description: Allows specifying multiple valid ad sizes. The server determines the best size to serve.
   - Supported By: Google Ad Manager.
   - Use Case: Supports multiple predefined sizes (e.g., 320x50, 320x100, 300x250).
   - Example:
     ```
     bannerView.validAdSizes = [NSValueFromGADAdSize(GADAdSizeBanner), NSValueFromGADAdSize(GADAdSizeLargeBanner), NSValueFromGADAdSize(GADAdSizeMediumRectangle)]
     ```

 - Fluid Ads:
   - Description: Dynamically adjusts the banner size based on the content it displays.
   - Supported By: Google Ad Manager.
   - Use Case: Best for responsive layouts where the ad size adapts to fit content.
   - Example:
     ```x
     let bannerView = GAMBannerView(adSize: GADAdSizeFluid)
     ```

 Notes:
 - Adaptive banners are recommended for AdMob as they offer a simple, responsive solution.
 - Use `validAdSizes` or fluid ads when working with Google Ad Manager for more flexibility in ad sizing.
 */

class AdAdaptiveViewController: UIViewController {
    @IBOutlet private var containerView: UIView!
    @IBOutlet private var textField: UITextField!
    @IBOutlet private var applyButton: UIButton!
    @IBOutlet private var sizeDisplayLabel: UILabel!
    @IBOutlet private var maxHeightEnable: UISwitch!
    
    private var adWidth: CGFloat = 320
    private var selectedSegment: AdTypes = .adaptive
    
    /// id was used from https://developers.google.com/admob/ios/test-ads
    private let testAdUnitId: String = "ca-app-pub-3940256099942544/2435281174"
    
    private let storedImpDisplayBanner = "" /// https://github.com/prebid/prebid-mobile-ios/issues/836 - the issue describes the prebid can't support Adaptive banners.

    ///https://developers.google.com/admob/ios/banner/inline-adaptive#limit_inline_adaptive_banner_height  Limit inline adaptive banner height By default, inline adaptive banners instantiated without a maxHeight value have a maxHeight equal to the device height. To limit the inline adaptive banner height, use the GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight(CGFloat width, CGFloat maxHeight) method.
    private let maxHeightAdaptive: CGFloat = 250
    
    override func viewDidLoad() {
        textField.text = "\(Int(adWidth))"
        addAdaptiveBannerView()
    }
    
    private enum AdTypes: Int {
        case adaptive
        case multiSize
        case fluid
    }

    @IBAction func changeTypePress(_ sender: UISegmentedControl) {
        selectedSegment = AdTypes(rawValue: sender.selectedSegmentIndex) ?? .adaptive
        setupAd()
    }
    
    @IBAction private func applyTaped() {
        guard let size = Double(textField.text ?? "") else { return }
        adWidth = size
        setupAd()
    }
    
    private func setupAd() {
        removeAd()
        switch selectedSegment {
        case .adaptive:
            addAdaptiveBannerView()
            updateUIInputs(true)
        case .multiSize:
            addValideSizesBanner()
            updateUIInputs(false)
        case .fluid:
            addFluidBanner()
            updateUIInputs(false)
        }
    }
    
    private func removeAd() {
        containerView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    private func updateUIInputs(_ flag: Bool) {
        textField.isUserInteractionEnabled = flag
        applyButton.isUserInteractionEnabled = flag
        maxHeightEnable.isUserInteractionEnabled = flag
    }
    
    private func addAdaptiveBannerView() {
        /// https://developers.google.com/admob/ios/banner/inline-adaptive#limit_inline_adaptive_banner_height
        let adSize = maxHeightEnable.isOn ? GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight(adWidth, 250) : GADCurrentOrientationInlineAdaptiveBannerAdSizeWithWidth(adWidth)
        
        // Step 2: Create banner with the inline size and set ad unit ID.
        let gamBannerView = GAMBannerView(adSize: adSize)
        gamBannerView.adUnitID = testAdUnitId
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        /// Set the adSizeDelegate to respond to dynamically received sizes from Google Ad Manager. You can filter or reject ad sizes that do not fit within your desired range
//        gamBannerView.adSizeDelegate = self
        
        let bannerMultisizeView = AUBannerView(configId: storedImpDisplayBanner, adSize: adSize.size, adFormats: [.banner], isLazyLoad: false)
        bannerMultisizeView.frame = CGRect.zero
        containerView.addSubview(bannerMultisizeView)
        
        let request = GADRequest()
        bannerMultisizeView.createAd(with: request, gamBanner: gamBannerView)
        
        bannerMultisizeView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else { return }
            gamBannerView.load(request)
        }
        
        bannerMultisizeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set constraints to pin the child view to all sides of the parent view
        NSLayoutConstraint.activate([
            bannerMultisizeView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bannerMultisizeView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bannerMultisizeView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bannerMultisizeView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
    }
    
    private func addValideSizesBanner() {
        // Create a banner view
        let gamBannerView = GAMBannerView(adSize: GADAdSizeBanner)
        gamBannerView.adUnitID = testAdUnitId
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        
        // Define multiple valid ad sizes
        gamBannerView.validAdSizes = [
            NSValueFromGADAdSize(GADAdSizeBanner),          // 320x50
            NSValueFromGADAdSize(GADAdSizeLargeBanner),     // 320x100
            NSValueFromGADAdSize(GADAdSizeMediumRectangle)  // 300x250
        ]
        
        let bannerMultisizeView = AUBannerView(configId: storedImpDisplayBanner, adSize: GADAdSizeBanner.size, adFormats: [.banner], isLazyLoad: false)
        bannerMultisizeView.frame = CGRect.zero
        containerView.addSubview(bannerMultisizeView)
        
        let request = GADRequest()
        bannerMultisizeView.createAd(with: request, gamBanner: gamBannerView)
        
        bannerMultisizeView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else { return }
            gamBannerView.load(request)
        }
        
        bannerMultisizeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set constraints to pin the child view to all sides of the parent view
        NSLayoutConstraint.activate([
            bannerMultisizeView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bannerMultisizeView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bannerMultisizeView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bannerMultisizeView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
    }
    
/// An ad size that spans the full width of its container, with a height dynamically determined by
/// the ad.
    private func addFluidBanner() {
        // Create a fluid ad size banner
        let gamBannerView = GAMBannerView(adSize: GADAdSizeFluid)
        gamBannerView.adUnitID = testAdUnitId
        gamBannerView.rootViewController = self
        gamBannerView.delegate = self
        
        let bannerMultisizeView = AUBannerView(configId: storedImpDisplayBanner, adSize: GADAdSizeFluid.size, adFormats: [.banner], isLazyLoad: false)
        bannerMultisizeView.frame = CGRect.zero
        containerView.addSubview(bannerMultisizeView)
        
        let request = GADRequest()
        bannerMultisizeView.createAd(with: request, gamBanner: gamBannerView)
        
        bannerMultisizeView.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? GADRequest else { return }
            gamBannerView.load(request)
        }
        
        bannerMultisizeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set constraints to pin the child view to all sides of the parent view
        NSLayoutConstraint.activate([
            bannerMultisizeView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bannerMultisizeView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bannerMultisizeView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bannerMultisizeView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
    }
}

// MARK: - GADBannerViewDelegate
extension AdAdaptiveViewController: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        guard let bannerView = bannerView as? GAMBannerView else { return }
        AUAdViewUtils.findCreativeSize(bannerView, success: { [weak self] size in
            self?.sizeDisplayLabel.text = "Ad size is: \(size)"
            bannerView.resize(GADAdSizeFromCGSize(size))
        }, failure: { (error) in
            print(error)
        })
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("GAM did fail to receive ad with error: \(error)")
    }
}

// MARK: - GADAdSizeDelegate
/// Set the adSizeDelegate to respond to dynamically received sizes from Google Ad Manager. You can filter or reject ad sizes that do not fit within your desired range
extension AdAdaptiveViewController: GADAdSizeDelegate {
    func adView(_ bannerView: GADBannerView, willChangeAdSizeTo size: GADAdSize) {
        // Check if the received size fits your desired range
        let minHeight: CGFloat = 50
        let maxHeight: CGFloat = 250
        
        if size.size.height >= minHeight && size.size.height <= maxHeight {
            print("Ad size within range: \(size.size)")
            // Update banner view constraints if necessary
            bannerView.frame.size = size.size
        } else {
            print("Ad size out of range: \(size.size). Fixing to default size.")
            // Fix to a default size if out of range
        }
        
        sizeDisplayLabel.text = "GADAdSizeDelegate size is:\(size.size)"
    }
}
