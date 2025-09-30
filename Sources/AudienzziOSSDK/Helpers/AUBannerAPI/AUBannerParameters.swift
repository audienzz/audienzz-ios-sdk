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
import PrebidMobile

/// BannerParameters..
/// If will be nill. Automatically create default  parameters
///
/// # Example #
/// *   let parameters = BannerParameters()
/// * parameters.api = [Signals.Api.MRAID_2]
@objcMembers
public class AUBannerParameters: NSObject {
    /// List of supported API frameworks for this impression. If an API is not explicitly listed, it is assumed not to be supported.
    public var api: [AUApi]? = [
        AUApi(apiType: .MRAID_2),
        AUApi(apiType: .MRAID_3),
        AUApi(apiType: .OMID_1)
    ]

    public var interstitialMinWidthPerc: Int?
    public var interstitialMinHeightPerc: Int?

    public var adSizes: [CGSize]?
}
