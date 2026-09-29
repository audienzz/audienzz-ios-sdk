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

/// One presentation, including foreground interruptions. Duplicate presentation callbacks are inert.
final class AUFullScreenViewabilityTimer {
    private let successSeconds: TimeInterval
    private let onStart: () -> Void
    private let onSuccess: () -> Void
    private var successWorkItem: DispatchWorkItem?
    private var shown = false
    private var terminal = false
    private var measuring = false
    private var backgrounded = false
    private var generation = 0

    init(successSeconds: TimeInterval = 1, onStart: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.successSeconds = successSeconds; self.onStart = onStart; self.onSuccess = onSuccess
    }
    func onShown() {
        guard !shown, !terminal else { return }
        shown = true
        backgrounded = Audienzz.shared.isAppBackgrounded
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
        resume()
    }
    private func resume() {
        guard shown, !terminal, !measuring, !backgrounded, !Audienzz.shared.isAppBackgrounded else { return }
        measuring = true
        let token = generation
        onStart()
        guard shown, !terminal, token == generation else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.shown, !self.terminal, token == self.generation else { return }
            guard !self.backgrounded, !Audienzz.shared.isAppBackgrounded else { self.pause(); return }
            self.cancel()
            self.onSuccess()
        }
        successWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + successSeconds, execute: work)
    }
    private func pause() {
        generation += 1; measuring = false
        successWorkItem?.cancel(); successWorkItem = nil
    }
    func cancel() {
        terminal = true; shown = false
        pause()
        NotificationCenter.default.removeObserver(self)
    }
    @objc private func background() { backgrounded = true; pause() }
    @objc private func foreground() { backgrounded = false; resume() }
    deinit { cancel() }
}
