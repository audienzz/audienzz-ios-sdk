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
class AUInterstitialRenderingConfiguration: AUAdUnitConfigurationType {

    private var renderInterAdUnit: InterstitialRenderingAdUnit!

    init(adUnit: InterstitialRenderingAdUnit) {
        self.renderInterAdUnit = adUnit
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AUInterstitialRenderingConfiguration:
    AUAdUnitConfigurationAutorefreshProtocol
{
    public func setAutoRefreshMillis(time: Double) {}

    public func stopAutoRefresh() {}

    public func resumeAutoRefresh() {}
}

//MARK: - AUAdUnitConfigurationGRIPProtocol
extension AUInterstitialRenderingConfiguration:
    AUAdUnitConfigurationGRIPProtocol
{
    func setGPID(_ gpid: String?) {}

    func getGPID() -> String? { nil }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUInterstitialRenderingConfiguration:
    AUAdUnitConfigurationSlotProtocol
{
    var adSlot: String? {
        get {
            nil
        }
        set {

        }
    }
}
