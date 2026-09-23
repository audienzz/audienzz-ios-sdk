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

/// Why refresh is currently held.
///
/// Reasons are independent and durable: clearing one never clears another, so a viewport resume
/// cannot undo a publisher pause and a foreground transition cannot resume a banner whose page the
/// user has left. A single boolean could not express that, and the bug it caused — a resume from one
/// subsystem silently cancelling another's pause — is what these exist to prevent.
internal enum AURefreshBlockReason: String, CaseIterable {

    /// The publisher asked for refresh to stop (`stopAutoRefresh`).
    case publisher

    /// The banner's page is not the active one, so it holds no inventory.
    case pageInactive

    /// The app is in the background. Distinct from `notVisible`: returning to the foreground must
    /// not resume a banner that is also scrolled out of view.
    case appBackground

    /// The banner is not in a window / has been torn down.
    case detached

    /// Native geometry says the banner is out of the refresh-eligible zone. Owned exclusively by
    /// the SDK's own viewport gate, which is the only thing that may clear it.
    case notVisible

    /// A host that does its own visibility detection says the banner cannot be seen.
    ///
    /// Kept separate from ``notVisible`` because the two answer different questions and neither
    /// can speak for the other. Native geometry cannot see a Flutter or React Native overlay
    /// drawn above the platform view, so a page transition that recomputed geometry and cleared a
    /// single shared reason released a host pause it knew nothing about, and the covered banner
    /// immediately bought another ad.
    case hostReportedHidden
}

/// Why a request is being issued. Carried through the request lifecycle for logging and analytics,
/// and used by the controller to tell a retry apart from a fresh attempt.
internal enum AURefreshRequestReason: String {

    /// The banner's first ever load (explicit or lazy). Not scheduled by the controller.
    case firstLoad

    /// A page impression made this banner's page current, so it serves a fresh creative.
    case pageImpression

    /// The configured interval elapsed.
    case periodicRefresh

    /// A bounded retry after a failed request.
    case loadRetry
}
