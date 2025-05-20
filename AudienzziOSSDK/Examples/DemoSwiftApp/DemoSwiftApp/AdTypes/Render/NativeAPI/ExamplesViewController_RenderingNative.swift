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
import GoogleMobileAds
import UIKit

private let nativeRenderingStoredImpression = "prebid-demo-banner-native-styles"
private let gamRenderingNativeAdUnitId =
    "/21808260008/apollo_custom_template_native_ad_unit"

extension ExamplesViewController {

    func createRenderingNativeView() {
        nativeRenderingView = AUNativeView(
            configId: nativeRenderingStoredImpression,
            isLazyLoad: false,
            adType: .rendering
        )
        nativeRenderingView.nativeParameter = nativeConfiguration()

        let gamRequest = AdManagerRequest()
        nativeRenderingView.createAd(with: gamRequest)

        nativeRenderingView.onNativeLoadRequest = {
            [weak self] request, targetingKeywords in
            guard let self = self else { return }
            guard let request = request as? AdManagerRequest else {
                print("Faild request unwrap")
                return
            }

            AudienzzGAMUtils.shared.prepareRequest(
                gamRequest,
                bidTargeting: targetingKeywords
            )

            self.adRenderingLoader = AdLoader(
                adUnitID: gamRenderingNativeAdUnitId,
                rootViewController: self,
                adTypes: [AdLoaderAdType.customNative],
                options: []
            )
            self.adRenderingLoader.delegate = self
            self.adRenderingLoader.load(request)
        }

        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        exampleView.frame = CGRect(
            x: 0,
            y: getPositionY(adContainerView),
            width: self.view.frame.width,
            height: 200
        )
        adContainerView.addSubview(exampleView)

        addConstrains(
            subView: exampleView,
            container: adContainerView,
            height: 200
        )

        nativeRenderingView.onGetNativeAd = { ad in
            exampleView.setupFromAd(ad: ad)
        }
    }

    func createRenderingNativeLazyView() {
        nativeLzyRenderingView = AUNativeView(
            configId: nativeRenderingStoredImpression,
            adType: .rendering
        )
        nativeLzyRenderingView.nativeParameter = nativeConfiguration()

        let gamRequest = AdManagerRequest()
        nativeLzyRenderingView.createAd(with: gamRequest)

        nativeLzyRenderingView.onNativeLoadRequest = {
            [weak self] request, keywords in
            guard let self = self else { return }
            guard let request = request as? AdManagerRequest else {
                print("Faild request unwrap")
                return
            }

            AudienzzGAMUtils.shared.prepareRequest(
                request,
                bidTargeting: keywords
            )

            self.adRenderingLazyLoader = AdLoader(
                adUnitID: gamRenderingNativeAdUnitId,
                rootViewController: self,
                adTypes: [AdLoaderAdType.customNative],
                options: []
            )
            self.adRenderingLazyLoader.delegate = self
            self.adRenderingLazyLoader.load(request)
        }

        let exampleView: ExampleNativeView = ExampleNativeView.fromNib()
        nativeLzyRenderingView.frame = CGRect(
            x: 0,
            y: getPositionY(lazyAdContainerView),
            width: self.view.frame.width,
            height: 200
        )
        exampleView.frame = CGRect(
            x: 0,
            y: 0,
            width: self.view.frame.width,
            height: 200
        )
        nativeLzyRenderingView.addSubview(exampleView)
        lazyAdContainerView.addSubview(nativeLzyRenderingView)

        nativeLzyRenderingView.onGetNativeAd = { ad in
            exampleView.setupFromAd(ad: ad)
        }
    }
}
