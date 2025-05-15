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

@objc
public protocol AUAdUnitConfigurationType: AUAdUnitConfigurationSlotProtocol,
    AUAdUnitConfigurationAutorefreshProtocol,
    AUAdUnitConfigurationGRIPProtocol
{}

/// Ad Slot is an identifier tied to the placement the ad will be delivered in
@objc public protocol AUAdUnitConfigurationSlotProtocol {
    var adSlot: String? { get set }
}

@objc public protocol AUAdUnitConfigurationAutorefreshProtocol {
    /**
     * This method allows to set the auto refresh period for the demand
     *
     * - Parameter time: refresh time interval
     */
    func setAutoRefreshMillis(time: Double)

    /**
     * This method stops the auto refresh of demand
     */
    func stopAutoRefresh()

    /**
     * This method resume the auto refresh
     */
    func resumeAutoRefresh()
}

/// Using the following method, you can set the impression-level GPID value to the bid request:
@objc public protocol AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?)

    func getGPID() -> String?
}

internal protocol AUAdUnitConfigurationEventProtocol {
    var autorefreshEventModel: AutorefreshEventModel { get set }
}
