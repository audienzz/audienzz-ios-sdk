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

/// One delivery's journey through the ad server, as a single greppable line per step.
///
/// The question this exists to answer is "which requests never became impressions, and where did
/// they stop?" — so the trace follows the **Google** load, which is the only thing that can produce
/// an impression. Prebid auctions are a separate stream (`prebid.*`) and are deliberately not
/// merged into it: a Prebid no-bid still proceeds to Google, so counting the two together is what
/// made the existing funnel hard to read.
///
/// Every line carries the placement and a load id, so repeated loads of the same placement can be
/// told apart — the case where two live banners were serving one slot was invisible precisely
/// because their log lines were indistinguishable.
///
/// Deliberately carries no targeting, PPID, creative markup, user identifier or ad content.
internal enum AUAdTraceEvent: String {
    /// A placement owner accepted a load and owns the slot from here on. `load=` on these three
    /// lines is the OWNER's generation, a different counter from the per-delivery one below —
    /// which is why they carry their own `owner.` prefix rather than sharing the `load.` one.
    case ownerAccepted = "owner.accepted"
    /// A repeat of the active load; no second banner was built.
    case ownerCoalesced = "owner.coalesced"
    /// The owner released its banner.
    case ownerRetired = "owner.retired"
    /// One delivery started. `load=` from here on is the banner's auction generation, and every
    /// google.* line for that delivery repeats it.
    case loadAccepted = "load.accepted"
    /// Handed to the Google ad server. Exactly one impression can follow.
    case googleRequested = "google.requested"
    /// Google returned a creative.
    case googleLoaded = "google.loaded"
    /// Google returned no creative.
    case googleFailed = "google.failed"
    /// Google recorded the impression — the only terminal state that earns.
    case googleImpression = "google.impression"
}

internal enum AUAdTrace {

    /// - Parameters:
    ///   - placement: the config/placement id — stable across loads, so a slot can be followed.
    ///   - load: which load of that placement this line belongs to.
    ///   - reason: why the request was made (first load, page impression, periodic refresh, retry).
    ///   - visible: the viewport verdict at the moment of the event, when it is known.
    static func log(
        placement: String,
        load: Int,
        event: AUAdTraceEvent,
        reason: String? = nil,
        visible: Bool? = nil,
        detail: String? = nil
    ) {
        emit(placement: placement, identity: "owner=\(load)", event: event,
             reason: reason, visible: visible, detail: detail)
    }

    /// - Parameter delivery: identifies one Google load for the life of that creative — slot
    ///   instance plus auction — so request, result and impression can be paired even when a later
    ///   auction is already running. A bare counter could not: it collided between two banners on
    ///   the same placement and restarted whenever a slot was replaced.
    static func log(
        placement: String,
        delivery: String?,
        event: AUAdTraceEvent,
        reason: String? = nil,
        visible: Bool? = nil,
        detail: String? = nil
    ) {
        emit(placement: placement, identity: "delivery=\(delivery ?? "none")", event: event,
             reason: reason, visible: visible, detail: detail)
    }

    private static func emit(
        placement: String,
        identity: String,
        event: AUAdTraceEvent,
        reason: String?,
        visible: Bool?,
        detail: String?
    ) {
        var line = "[AUAdTrace] placement=\(placement) \(identity) event=\(event.rawValue)"
        if let reason { line += " reason=\(reason)" }
        if let visible { line += " visible=\(visible)" }
        if let detail { line += " detail=\(detail)" }
        AULogEvent.logDebug(line)
    }
}
