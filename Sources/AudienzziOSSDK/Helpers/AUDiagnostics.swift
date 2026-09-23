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

/// One greppable line per decision the SDK makes about a slot.
///
/// This exists so a run on a device can be captured, sent to someone who was not holding the
/// phone, and read back as a sequence: which page became current, which slot belongs to it, when
/// an auction actually started, and — the part that is otherwise invisible — *why* one did not.
///
/// It is deliberately separate from `AULogEvent`:
///
///  * `AULogEvent.logDebug` is `#if DEBUG`, so a TestFlight or release build of an example app
///    prints nothing. Diagnostics must survive that build, or the log you can actually collect
///    from a tester is empty.
///  * Its output is per-class prose. This is one stable format, so the same flow can be diffed
///    against the Android, Flutter and React Native SDKs, which emit the identical shape.
///
/// Off by default — a publisher's production console is not ours to fill. Turn it on before
/// configuring the SDK with ``Audienzz/diagnosticsEnabled``.
///
/// Format: `AUDZ <subsystem> <event> key=value key=value`
/// Keys are stable; unknown keys may be added over time, so parse by key, not by position.
@objcMembers
public final class AUDiagnostics: NSObject {

    /// Master switch. See ``Audienzz/diagnosticsEnabled``, which is the public spelling.
    internal static var isEnabled = false

    /// Where a line goes. Replaceable so a host can route diagnostics into its own log file —
    /// `print` reaches the Xcode console and `log stream`, but not a file a tester can email.
    public static var sink: (String) -> Void = { print($0) }

    internal static func log(_ subsystem: String,
                             _ event: String,
                             _ fields: [(String, Any?)] = []) {
        guard isEnabled else { return }
        var line = "AUDZ \(subsystem) \(event)"
        for (key, value) in fields {
            guard let value else { continue }
            line += " \(key)=\(format(value))"
        }
        sink(line)
    }

    /// Values are written bare unless they contain a space, which would break `key=value` parsing.
    private static func format(_ value: Any) -> String {
        let text = String(describing: value)
        return text.contains(" ") ? "\"\(text)\"" : text
    }
}
