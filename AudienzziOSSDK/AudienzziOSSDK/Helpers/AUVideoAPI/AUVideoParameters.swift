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

/// VideoParameters..
/// If will be nill. Automatically create default video parameters
///
/// # Example #
/// *   AUVideoParameters(mimes: ["video/mp4"])
/// * protocols = [AdVideoParameters.Protocols.VAST_2_0]
/// * playbackMethod = [AdVideoParameters.PlaybackMethod.AutoPlaySoundOff]
/// * placement = AdVideoParameters.Placement.InBanner
@objcMembers
public class AUVideoParameters: NSObject {

    /// List of supported API frameworks for this impression. If an API is not explicitly listed, it is assumed not to be supported.
    public var api: [AUApi]?

    /// Maximum bit rate in Kbps.
    public var maxBitrate: Int?

    /// Minimum bit rate in Kbps.
    public var minBitrate: Int?

    /// Maximum video ad duration in seconds.
    public var maxDuration: Int?

    /// Minimum video ad duration in seconds.
    public var minDuration: Int?

    /**
     Content MIME types supported.
     Prebid Server required property.
    
     # Example #
     * "video/mp4"
     * "video/x-ms-wmv"
     */
    public var mimes: [String]

    /// Allowed playback methods. If none specified, assume all are allowed.
    public var playbackMethod: [AUVideoPlaybackMethod]?

    /// Array of supported video bid response protocols.
    public var protocols: [AUVideoProtocols]?

    /// Indicates the start delay in seconds for pre-roll, mid-roll, or post-roll ad placements.
    public var startDelay: AUVideoStartDelay?

    /// Placement type for the impression.
    public var placement: AUPlacement?

    /// Indicates if the impression must be linear, nonlinear, etc. If none specified, assume all are allowed.
    public var linearity: Int?

    public var adSize: CGSize?

    /// - Parameter mimes: supported MIME types
    public init(mimes: [String]) {
        self.mimes = mimes
    }

    // Objective-C API
    public func setSize(_ size: NSValue) {
        adSize = size.cgSizeValue
    }

    /// Indicates if the impression must be linear, nonlinear, etc. If none specified, assume all are allowed.
    public func setLinearity(_ linearity: NSNumber) {
        self.linearity = linearity.intValue
    }

    /// Maximum bit rate in Kbps.
    public func setMaxBitrate(_ value: NSNumber) {
        self.maxBitrate = value.intValue
    }

    /// Minimum bit rate in Kbps.
    public func setMinBitrate(_ value: NSNumber) {
        self.minBitrate = value.intValue
    }

    /// Maximum video ad duration in seconds.
    public func setMaxDuration(_ value: NSNumber) {
        self.maxDuration = value.intValue
    }

    /// Minimum video ad duration in seconds.
    public func setMinDuration(_ value: NSNumber) {
        self.minDuration = value.intValue
    }

    /// Indicates the start delay in seconds for pre-roll, mid-roll, or post-roll ad placements.
    public func setStartDelay(_ value: AUVideoStartDelay) {
        self.startDelay = value
    }

    /// Placement type for the impression.
    public func setPlacement(_ value: AUPlacement) {
        self.placement = value
    }
}
