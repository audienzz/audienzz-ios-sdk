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

/// One creative's continuous exposure. Starts can repeat after an interruption; success is terminal.
final class AUViewabilityTracker {
    static let trackerVersion = "1.0.0"
    private weak var view: VisibleView?
    private let isEligible: () -> Bool
    private let onStart: () -> Void
    private let onSuccess: () -> Void
    private let threshold: CGFloat
    private let successSeconds: TimeInterval
    private let pollInterval: TimeInterval
    private var pollTimer: Timer?
    private var successWorkItem: DispatchWorkItem?
    private var running = false
    private var aboveThreshold = false
    private var backgrounded = false
    private var generation = 0

    init(view: VisibleView, threshold: CGFloat = 0.5, successSeconds: TimeInterval = 1,
         pollInterval: TimeInterval = 0.2, isEligible: @escaping () -> Bool = { true },
         onStart: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.view = view; self.threshold = threshold; self.successSeconds = successSeconds
        self.pollInterval = pollInterval; self.isEligible = isEligible
        self.onStart = onStart; self.onSuccess = onSuccess
    }
    func start() {
        stop()
        running = true
        backgrounded = Audienzz.shared.isAppBackgrounded
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
        startPolling()
        refreshVisibility()
    }
    private func startPolling() {
        guard running, !backgrounded, pollTimer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in self?.refreshVisibility() }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
    private var visible: Bool {
        running && !backgrounded && !Audienzz.shared.isAppBackgrounded && isEligible()
            && (view?.currentVisibleHeightFraction() ?? 0) >= threshold
    }
    func refreshVisibility() {
        guard running else { return }
        if !visible { interruptExposure(); return }
        guard !aboveThreshold else { return }
        aboveThreshold = true
        let token = generation
        onStart()
        guard running, token == generation else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.running, token == self.generation else { return }
            guard self.visible else { self.interruptExposure(); return }
            self.stop()
            self.onSuccess()
        }
        successWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + successSeconds, execute: work)
    }
    @objc private func background() {
        backgrounded = true
        pollTimer?.invalidate(); pollTimer = nil
        interruptExposure()
    }
    @objc private func foreground() {
        backgrounded = false
        startPolling()
        refreshVisibility()
    }
    private func interruptExposure() {
        generation += 1
        successWorkItem?.cancel(); successWorkItem = nil
        aboveThreshold = false
    }
    func stop() {
        running = false
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate(); pollTimer = nil
        interruptExposure()
    }
    deinit { stop() }
}
