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

    /// Installed by the owning banner so a publisher changing the interval after `createAd` reaches
    /// the refresh controller. Without it the interval would only be read once, and
    /// `AURemoteConfigBannerView` — which applies the backend interval asynchronously, after the
    /// banner exists — would never take effect.
    internal var autorefreshIntervalObserver: ((Double) -> Void)?

    /// Installed by the owning banner; `true` means the publisher paused refresh.
    internal var autorefreshPauseObserver: ((Bool) -> Void)?

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

    /// Sets the periodic refresh interval, in milliseconds. 0 disables refresh.
    ///
    /// The interval is stored by the SDK and never handed to Prebid. Prebid's `Dispatcher` is
    /// created only by `AdUnit.setAutoRefreshMillis`, so not calling it is what guarantees Prebid
    /// owns no timer — see ``AURefreshController`` for why two owners could not be reconciled.
    public func setAutoRefreshMillis(time: Double) {
        setAutorefresh(time: time)
    }

    /// Publisher pause. Durable: a viewport or page resume will not undo it, only
    /// ``resumeAutoRefresh()`` will.
    public func stopAutoRefresh() {
        stop()
    }

    /// Clears the publisher pause. Refresh only actually resumes once nothing else is holding it
    /// (the banner is on the active page, visible, and the app is in the foreground).
    public func resumeAutoRefresh() {
        resume()
    }

    private func setAutorefresh(time: Double) {
        let resolved = Self.clampInterval(time)
        autorefreshEventModel.autorefreshTime = resolved
        autorefreshEventModel.isAutorefresh = resolved > 0
        // Deliberately NOT forwarded to `adUnit` / `multiplatformAdUnit`. See the doc comment above.
        autorefreshIntervalObserver?(resolved)
    }

    private func stop() {
        autorefreshEventModel.isAutorefresh = false
        autorefreshPauseObserver?(true)
    }

    private func resume() {
        autorefreshEventModel.isAutorefresh = autorefreshEventModel.autorefreshTime > 0
        autorefreshPauseObserver?(false)
    }

    /// 0 (or less) disables refresh. Anything positive is raised to the floor the original Prebid
    /// API enforced (`AdUnit.PB_MIN_RefreshTime`, 30 000 ms): below it Prebid refused to arm a
    /// timer at all, so a smaller value never produced a periodic refresh and silently accepting
    /// one now would speed a slot up rather than preserve its behaviour.
    private static func clampInterval(_ millis: Double) -> Double {
        guard millis > 0 else { return 0 }
        if millis < minimumRefreshMillis {
            AULogEvent.logWarn(
                "[AUAdUnitConfiguration] refresh interval \(millis)ms is below the supported minimum; using \(minimumRefreshMillis)ms"
            )
            return minimumRefreshMillis
        }
        return millis
    }

    /// Mirrors Prebid's `AdUnit.PB_MIN_RefreshTime`, which is private to Prebid.
    internal static let minimumRefreshMillis: Double = 30_000
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
