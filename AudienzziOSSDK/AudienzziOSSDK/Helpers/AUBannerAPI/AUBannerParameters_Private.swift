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
import PrebidMobile

extension AUBannerParameters {
    
    internal func makeBannerParameters() -> BannerParameters {
        let bannerParameters = BannerParameters()
        bannerParameters.api = api?.compactMap { $0.apiType.toAPI }
        
        bannerParameters.interstitialMinWidthPerc = interstitialMinWidthPerc
        bannerParameters.interstitialMinHeightPerc = interstitialMinHeightPerc
        bannerParameters.adSizes = adSizes
        
        return bannerParameters
    }
    
    internal convenience init(with pbParams: BannerParameters) {
        self.init()
        self.api = pbParams.api?.compactMap { AUApi(apiType: AUApiType(rawValue: $0.value) ?? .MRAID_2) }
        self.interstitialMinWidthPerc = pbParams.interstitialMinWidthPerc
        self.interstitialMinHeightPerc = pbParams.interstitialMinHeightPerc
        self.adSizes = pbParams.adSizes
    }
}
