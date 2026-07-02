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
import UIKit

/// Drives `viewability.start` / `viewability.success` for full-screen ads (interstitial, rewarded),
/// which are 100% visible while presented — no fraction sampling needed (mirrors Android
/// `FullScreenViewabilityTimer`). `onShown` fires `onStart` immediately and schedules `onSuccess`
/// after `successSeconds`; `cancel` stops a pending success (call on dismiss / failed-to-present).
///
/// While shown it observes app state: backgrounding cancels a pending success so it never elapses
/// off-screen, and returning to the foreground re-arms (re-fires start + reschedules the full
/// window) as long as success has not already been reported.
final class AUFullScreenViewabilityTimer {

    private let successSeconds: TimeInterval
    private let onStart: () -> Void
    private let onSuccess: () -> Void
    private var successWorkItem: DispatchWorkItem?
    private var succeeded = false

    init(successSeconds: TimeInterval = 1.0,
         onStart: @escaping () -> Void,
         onSuccess: @escaping () -> Void) {
        self.successSeconds = successSeconds
        self.onStart = onStart
        self.onSuccess = onSuccess
    }

    func onShown() {
        cancel()
        succeeded = false
        observeAppState()
        onStart()
        schedule()
    }

    func cancel() {
        NotificationCenter.default.removeObserver(self)
        successWorkItem?.cancel()
        successWorkItem = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func schedule() {
        successWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.succeeded = true
            self.onSuccess()
            // Terminal for this presentation — stop observing app state.
            NotificationCenter.default.removeObserver(self)
        }
        successWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + successSeconds, execute: work)
    }

    private func observeAppState() {
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(handleBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(
            self, selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func handleBackground() {
        guard !succeeded else { return }
        successWorkItem?.cancel()
        successWorkItem = nil
    }

    @objc private func handleForeground() {
        guard !succeeded else { return }
        // Still presented full-screen — restart the continuous-view window and re-fire start.
        onStart()
        schedule()
    }
}
