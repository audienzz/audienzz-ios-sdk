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

/// Tracks viewability for a banner ad view and reports two events (mirrors Android `ViewabilityTracker`):
/// - `onStart` fires each time the view crosses **up** through `threshold` (default 50%) visible,
///   while `onSuccess` has not yet fired (re-arms after a drop).
/// - `onSuccess` fires **once**, after the view stays ≥ `threshold` for `successSeconds` continuous
///   seconds; the session is then terminal until `start()` is called again (next creative).
///
/// Visibility is polled on a timer (iOS has no per-frame pre-draw hook like Android); the success
/// timer runs independently so it elapses even if the view is static.
final class AUViewabilityTracker {

    private weak var view: VisibleView?
    private let onStart: () -> Void
    private let onSuccess: () -> Void
    private let threshold: CGFloat
    private let successSeconds: TimeInterval
    private let pollInterval: TimeInterval

    private var pollTimer: Timer?
    private var successWorkItem: DispatchWorkItem?
    private var aboveThreshold = false
    private var successSent = false

    init(view: VisibleView,
         threshold: CGFloat = 0.5,
         successSeconds: TimeInterval = 1.0,
         pollInterval: TimeInterval = 0.2,
         onStart: @escaping () -> Void,
         onSuccess: @escaping () -> Void) {
        self.view = view
        self.threshold = threshold
        self.successSeconds = successSeconds
        self.pollInterval = pollInterval
        self.onStart = onStart
        self.onSuccess = onSuccess
    }

    /// Begins (or restarts) a viewability session for the current creative.
    func start() {
        stop()
        successSent = false
        aboveThreshold = false
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        observeAppState()
        evaluate()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
        cancelSuccess()
        aboveThreshold = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - App state

    private func observeAppState() {
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(handleBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(
            self, selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// A pending success must not elapse while backgrounded (the `asyncAfter` deadline passes off
    /// screen and would fire on resume). Cancel it and drop below threshold so foreground re-arms.
    @objc private func handleBackground() {
        guard !successSent else { return }
        cancelSuccess()
        aboveThreshold = false
    }

    /// On return to foreground re-evaluate immediately; if the ad is still ≥ threshold this re-fires
    /// start and reschedules the full continuous-view window.
    @objc private func handleForeground() {
        guard !successSent else { return }
        evaluate()
    }

    private func evaluate() {
        guard !successSent, let view = view else { return }
        let isAbove = view.currentVisibleHeightFraction() >= threshold
        if isAbove && !aboveThreshold {
            aboveThreshold = true
            onStart()
            scheduleSuccess()
        } else if !isAbove && aboveThreshold {
            aboveThreshold = false
            cancelSuccess()
        }
    }

    private func scheduleSuccess() {
        cancelSuccess()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.successSent = true
            self.onSuccess()
            self.stop()
        }
        successWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + successSeconds, execute: work)
    }

    private func cancelSuccess() {
        successWorkItem?.cancel()
        successWorkItem = nil
    }
}
