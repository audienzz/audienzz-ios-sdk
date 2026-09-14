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

@objcMembers
class AUBannerRenderingConfiguration: AUAdUnitConfigurationType {

    private var bannerView: BannerView!

    init(bannerView: BannerView) {
        self.bannerView = bannerView
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol

/// Rendering banners have exactly one refresh owner, and it is not this SDK.
///
/// Prebid's rendering `BannerView` schedules its own refresh through `AutoRefreshManager`, reading
/// `refreshInterval` and gating every tick on `mayRefreshNow` — which already refuses to refresh
/// while the ad is off screen, opened, or presenting a creative. There is nothing for
/// ``AURefreshController`` to own here, and adding a second scheduler on top is exactly the
/// arrangement the original-API migration removed.
///
/// These stay no-ops deliberately:
/// - the interval is set through `AUBannerRenderingView.refreshInterval`, which writes Prebid's own
///   `refreshInterval` (seconds). Routing it through here as well would give two sources of truth.
/// - Prebid exposes `stopRefresh()` but no resume — it clears itself on the next bid request — so a
///   pause/resume pair cannot be implemented against this API without tearing the view down. The
///   bridges page-scope rendering banners by unmounting them instead.
extension AUBannerRenderingConfiguration:
    AUAdUnitConfigurationAutorefreshProtocol
{
    public func setAutoRefreshMillis(time: Double) {}

    public func stopAutoRefresh() {}

    public func resumeAutoRefresh() {}
}

//MARK: - AUAdUnitConfigurationGRIPProtocol
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?) {}

    func getGPID() -> String? { nil }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationSlotProtocol {
    var adSlot: String? {
        get {
            nil
        }
        set {

        }
    }
}
