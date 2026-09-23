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

/// What an interstitial's bid request advertises: the media formats it asks for, and the OpenRTB
/// API frameworks its renderer supports.
///
/// Backend-controlled only — the ad config's `prebidConfig.format` and `prebidConfig.apis` — and
/// the same on every platform. There is no publisher override: an interstitial constructor,
/// `bannerParameters.api`, `videoParameters.api` and `impOrtbConfig` all lose to this. A
/// hand-built interstitial has no ad config and always gets ``default``.
///
/// Validation (mirrored exactly by Android and pinned by the same table in both test suites):
/// - `format` must be exactly `banner`, `video` or `bannerAndVideo`; anything else, including a
///   missing or non-string value, is `bannerAndVideo`.
/// - `apis` keeps, in backend order and without duplicates, only the frameworks the renderer
///   supports ([3, 5, 6, 7]: MRAID 1, MRAID 2, MRAID 3, OMID 1). If nothing usable is left — the
///   key is missing, not an array, empty, or holds only unsupported or non-integer values — it is
///   the full supported list. An interstitial never goes out without an `api`.
///
/// None of this can fail a load: every input resolves to something sendable.
internal struct AUInterstitialCapabilities: Equatable {

    enum Format: String, CaseIterable {
        case banner, video, bannerAndVideo

        var includesBanner: Bool { self != .video }
        var includesVideo: Bool { self != .banner }
    }

    let format: Format
    let apis: [Int]

    /// MRAID 1, MRAID 2, MRAID 3 and OMID 1: what Google's renderer supports for the creatives an
    /// interstitial can receive. VPAID (1, 2) and ORMMA (4) are not, and are never advertised.
    static let supportedApis: [Int] = [3, 5, 6, 7]

    static let `default` = AUInterstitialCapabilities(format: .bannerAndVideo, apis: supportedApis)

    static func resolve(format rawFormat: String?, apis rawApis: [Int]?) -> AUInterstitialCapabilities {
        let format = rawFormat.flatMap(Format.init(rawValue:)) ?? Self.default.format
        var apis: [Int] = []
        for api in rawApis ?? [] where supportedApis.contains(api) && !apis.contains(api) {
            apis.append(api)
        }
        return AUInterstitialCapabilities(format: format, apis: apis.isEmpty ? supportedApis : apis)
    }

    static func resolve(_ prebidConfig: RemoteAdConfiguration.PrebidConfig?) -> AUInterstitialCapabilities {
        resolve(format: prebidConfig?.format, apis: prebidConfig?.apis)
    }

    var prebidFormats: Set<PrebidMobile.AdFormat> {
        var formats: Set<PrebidMobile.AdFormat> = []
        if format.includesBanner { formats.insert(.banner) }
        if format.includesVideo { formats.insert(.video) }
        return formats
    }

    var prebidApis: [Signals.Api] {
        apis.compactMap { api in
            switch api {
            case 3: return .MRAID_1
            case 5: return .MRAID_2
            case 6: return .MRAID_3
            case 7: return .OMID_1
            default: return nil
            }
        }
    }

    /// The analytics subtype for this format, as the other ad types report it.
    var adSubtype: String {
        switch format {
        case .banner: return AUAdSubtype.html
        case .video: return AUAdSubtype.video
        case .bannerAndVideo: return AUAdSubtype.multiformat
        }
    }

    /// Writes these capabilities onto the ad unit, just before its request.
    ///
    /// Everything else already on the unit is kept: its sizes and minimum size percentages, and a
    /// publisher's other video settings (duration, bitrate, protocols, …). Only the formats and
    /// the API lists are replaced. A video request without video parameters gets the SDK's
    /// interstitial defaults, so it is always playable.
    func apply(to unit: InterstitialAdUnit) {
        unit.adFormats = prebidFormats
        unit.bannerParameters.api = prebidApis
        if format.includesVideo {
            let video = unit.videoParameters.mimes.isEmpty
                ? Self.defaultVideoParameters()
                : unit.videoParameters
            video.api = prebidApis
            unit.videoParameters = video
        }
        unit.setImpORTBConfig(Self.sanitizedImpORTB(unit.getImpORTBConfig(), for: format))
    }

    /// The video parameters an interstitial sends when nobody supplied any: MP4 over VAST 2.0,
    /// muted autoplay, interstitial placement.
    static func defaultVideoParameters() -> VideoParameters {
        let video = VideoParameters(mimes: ["video/mp4"])
        video.protocols = [Signals.Protocols.VAST_2_0]
        video.playbackMethod = [Signals.PlaybackMethod.AutoPlaySoundOff]
        video.placement = .Interstitial
        video.plcmnt = .Interstitial
        return video
    }

    /// Removes from a publisher's imp-level ORTB what would override these capabilities.
    ///
    /// Prebid deep-merges the imp ORTB into every impression, so a `banner.api` or `video.api`
    /// there replaced the backend list, and a `video` object added video to a banner-only request.
    /// Those keys go; everything else — the React Native bridge's `banner.format` sizes among
    /// it — is kept. Unparseable ORTB is dropped: Prebid would reject it anyway.
    static func sanitizedImpORTB(_ ortb: String?, for format: Format) -> String? {
        guard let ortb, !ortb.isEmpty else { return ortb }
        guard let data = ortb.data(using: .utf8),
              var imp = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        for (key, allowed) in [("banner", format.includesBanner), ("video", format.includesVideo)] {
            guard imp[key] != nil else { continue }
            guard allowed, var object = imp[key] as? [String: Any] else { imp[key] = nil; continue }
            object["api"] = nil
            imp[key] = object
        }
        guard let clean = try? JSONSerialization.data(withJSONObject: imp, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: clean, encoding: .utf8)
    }
}
