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

/// The scheduling and clock primitives the refresh controller needs, behind a protocol so tests
/// drive time by hand instead of sleeping.
internal protocol AURefreshScheduler: AnyObject {

    /// Schedules `action`, replacing whatever was pending. At most one task exists at a time.
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void)

    /// Cancels the pending task, if any.
    func cancel()

    /// Monotonic seconds. Never wall-clock: a device clock change (or an NTP correction) would
    /// otherwise make a banner instantly overdue or suppress its refresh indefinitely.
    func now() -> TimeInterval
}

/// Production scheduler: one cancellable work item on the main queue.
internal final class AUMainQueueRefreshScheduler: AURefreshScheduler {

    private var pending: DispatchWorkItem?

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        cancel()
        let item = DispatchWorkItem(block: action)
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: item)
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }

    /// `systemUptime` is monotonic and immune to clock changes. It excludes time the device spent
    /// asleep, which costs nothing here: a sleeping device is a backgrounded app, and refresh is
    /// blocked for the whole of that anyway.
    func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    deinit {
        cancel()
    }
}
