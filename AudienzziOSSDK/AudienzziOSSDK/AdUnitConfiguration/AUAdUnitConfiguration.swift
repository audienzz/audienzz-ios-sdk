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

struct AutorefreshEventModel {
    var isAutorefresh: Bool
    var autorefreshTime: Double
}

@objcMembers
public class AUAdUnitConfiguration: AUAdUnitConfigurationType,
    AUAdUnitConfigurationEventProtocol
{
    private var adUnit: AdUnit!
    private var prebidAdUnit: PrebidAdUnit?
    private var prebidRequest: PrebidRequest?

    internal var autorefreshEventModel: AutorefreshEventModel

    init(adUnit: AdUnit) {
        self.adUnit = adUnit
        self.autorefreshEventModel = AutorefreshEventModel(
            isAutorefresh: false,
            autorefreshTime: 0
        )
    }

    init(multiplatformAdUnit: PrebidAdUnit, request: PrebidRequest) {
        self.prebidAdUnit = multiplatformAdUnit
        self.prebidRequest = request
        self.autorefreshEventModel = AutorefreshEventModel(
            isAutorefresh: false,
            autorefreshTime: 0
        )
    }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUAdUnitConfiguration: AUAdUnitConfigurationSlotProtocol {

    public var adSlot: String? {
        get { get_AdSlot() }
        set { set_AdSlot(newValue: newValue) }
    }

    public func get_AdSlot() -> String? {
        guard let multiplatformAdUnit = prebidAdUnit else {
            return adUnit.pbAdSlot
        }

        return multiplatformAdUnit.pbAdSlot
    }
    public func set_AdSlot(newValue: String?) {
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.pbAdSlot = newValue
            return
        }

        multiplatformAdUnit.pbAdSlot = newValue
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AUAdUnitConfiguration: AUAdUnitConfigurationAutorefreshProtocol {
    public func setAutoRefreshMillis(time: Double) {
        setAutorefresh(time: time)
    }

    public func stopAutoRefresh() {
        stop()
    }

    public func resumeAutoRefresh() {
        resume()
    }

    private func setAutorefresh(time: Double) {
        autorefreshEventModel.autorefreshTime = time
        autorefreshEventModel.isAutorefresh = true
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.setAutoRefreshMillis(time: time)
            return
        }

        multiplatformAdUnit.setAutoRefreshMillis(time: time)
    }

    private func stop() {
        autorefreshEventModel.isAutorefresh = false
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.stopAutoRefresh()
            return
        }

        multiplatformAdUnit.stopAutoRefresh()
    }

    private func resume() {
        autorefreshEventModel.isAutorefresh = true
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.resumeAutoRefresh()
            return
        }

        multiplatformAdUnit.resumeAutoRefresh()
    }
}

// MARK: GPID
extension AUAdUnitConfiguration: AUAdUnitConfigurationGRIPProtocol {
    public func setGPID(_ gpid: String?) {
        set_GPID(gpid)
    }

    public func getGPID() -> String? {
        get_GPID()
    }

    private func set_GPID(_ gpid: String?) {
        guard let request = prebidRequest else {
            adUnit.setGPID(gpid)
            return
        }

        request.setGPID(gpid)
    }

    private func get_GPID() -> String? {
        guard prebidRequest != nil else {
            return adUnit.getGPID()
        }

        return nil
    }
}
