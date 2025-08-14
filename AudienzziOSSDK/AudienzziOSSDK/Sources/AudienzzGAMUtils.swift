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

import Foundation
import GoogleMobileAds
import PrebidMobile
import PrebidMobileGAMEventHandlers

@objcMembers
public class AudienzzGAMUtils: NSObject {
    // MARK: - Public
    public static let shared = AudienzzGAMUtils()

    @objc public static var errorDomain: String {
        "org.prebid.mobile.GAMEventHandlers"
    }

    public func initializeGAM() {
        GAMUtils.shared.initializeGAM()
    }

    public func prepareRequest(
        _ request: AdManagerRequest,
        bidTargeting: [String: String]
    ) {
        GAMUtils.shared.prepareRequest(request, bidTargeting: bidTargeting)
    }

}

extension AudienzzGAMUtils {

    public func findNativeAd(for nativeAd: GoogleMobileAds.NativeAd) -> Result<
        PrebidMobile.NativeAd, GAMEventHandlerError
    > {
        GAMUtils.shared.findNativeAd(for: nativeAd)
    }

    public func findNativeAdObjc(
        for nativeAd: GoogleMobileAds.NativeAd,
        completion: @escaping (PrebidMobile.NativeAd?, NSError?) -> Void
    ) {
        GAMUtils.shared.findNativeAdObjc(for: nativeAd, completion: completion)
    }

    public func findCustomNativeAd(
        for nativeAd: GoogleMobileAds.CustomNativeAd,
        completion: @escaping (AUNativeAd?, NSError?) -> Void
    ) {
        let result = GAMUtils.shared.findCustomNativeAd(for: nativeAd)

        switch result {
        case .success(let ad):
            completion(AUNativeAd(ad), nil)
        case .failure(let error):
            let nsError = NSError(
                domain: "org.audienzz.mobile.GAMEventHandlers",
                code: error.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(
                        error.localizedDescription,
                        comment: ""
                    )
                ]
            )
            completion(nil, nsError)
        }
    }

    public func findCustomNativeAdObjc(
        for nativeAd: GoogleMobileAds.CustomNativeAd,
        completion: @escaping (PrebidMobile.NativeAd?, NSError?) -> Void
    ) {
        GAMUtils.shared.findCustomNativeAdObjc(
            for: nativeAd,
            completion: completion
        )
    }
}
