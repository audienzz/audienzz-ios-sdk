//
//  RemoteAdConfiguration.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 28.10.2025.
//

import Foundation

public struct RemoteAdConfiguration: Codable {
    public struct Config: Codable {
        public let adType: String
        /// Seconds between auto-refresh cycles. `nil` when absent or null in the remote payload.
        public let refreshTimeSeconds: Int?
        /// Prefetch margin in points, from the backend's `prefetchDistanceDp` — the key every
        /// platform reads (a dp and a pt are the same density-independent unit). `nil` when absent
        /// or null in the remote payload.
        public let prefetchDistancePt: Int?
        /// Whether the banner defers its auction until it approaches the viewport.
        /// `nil` when absent or null in the remote payload; the SDK default applies
        /// (see `AURemoteConfigBannerView.defaultLazyLoad`).
        public let lazyLoad: Bool?
        /// Reserved height (points) for the sticky ad wrapper. `nil` falls back to the SDK default (600).
        public let stickyMaxHeight: Int?
        /// Y offset (points) from the scroll viewport top where the sticky ad should pin.
        /// `nil` falls back to the scroll view's safe-area inset.
        public let stickyTopOffset: Int?

        /// Explicit so the one backend key is used for decoding AND for the local cache, which
        /// re-encodes this struct. iOS alone read `prefetchDistancePt`, so a margin the backend
        /// set for every platform would have reached Android, Flutter and React Native only.
        private enum CodingKeys: String, CodingKey {
            case adType, refreshTimeSeconds, lazyLoad, stickyMaxHeight, stickyTopOffset
            case prefetchDistancePt = "prefetchDistanceDp"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            adType = try container.decode(String.self, forKey: .adType)
            // decodeIfPresent returns nil for both absent keys and JSON null,
            // so callers apply a default via the nil-coalescing operator.
            refreshTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshTimeSeconds)
            prefetchDistancePt = try container.decodeIfPresent(Int.self, forKey: .prefetchDistancePt)
            lazyLoad = try container.decodeIfPresent(Bool.self, forKey: .lazyLoad)
            stickyMaxHeight = try container.decodeIfPresent(Int.self, forKey: .stickyMaxHeight)
            stickyTopOffset = try container.decodeIfPresent(Int.self, forKey: .stickyTopOffset)
        }
    }

    public enum WidthStrategy: String, Codable {
        case fullWidth = "FULL_WIDTH"
        case custom = "CUSTOM"
    }

    public struct GamConfig: Codable {
        public let adUnitPath: String
        public let adSizes: [String]
        public let adaptiveBannerConfig: AdaptiveBannerConfig?

        public struct AdaptiveBannerConfig: Codable {
            public let enabled: Bool
            public let type: String?
            public let widthStrategy: WidthStrategy?
            public let customWidth: CGFloat?
            public let maxHeight: CGFloat?
            public let orientationHandling: String?
            public let includeReservationSizes: Bool?
        }
    }

    public struct PrebidConfig: Codable {
        public let placementId: String
        public let adSizes: [String]
        /// Interstitials: the media formats the bid request asks for — `banner`, `video` or
        /// `bannerAndVideo`. The raw backend value; `AUInterstitialCapabilities` validates it.
        /// `nil` when absent or not a string.
        public let format: String?
        /// Interstitials: the OpenRTB API framework ids the impression advertises. Only integral
        /// numbers are kept; `nil` when absent or not an array. Validated like ``format``.
        public let apis: [Int]?

        private enum CodingKeys: String, CodingKey {
            case placementId, adSizes, format, apis
        }

        /// Both interstitial fields are read leniently. A strict decode that met, say, a string in
        /// `apis` threw, and one malformed field cost the publisher every ad config — banners too.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            placementId = try container.decode(String.self, forKey: .placementId)
            adSizes = try container.decode([String].self, forKey: .adSizes)
            format = (try? container.decodeIfPresent(String.self, forKey: .format)) ?? nil
            apis = (try? container.decodeIfPresent([LossyInteger].self, forKey: .apis))?
                .map { $0.value }
                .compactMap { $0 }
        }
    }

    /// One element of a number array that may hold anything: an integral JSON number (`3` or
    /// `3.0`) decodes to its value, everything else — strings, booleans, fractions — to `nil`.
    private struct LossyInteger: Decodable {
        let value: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self),
               number.rounded() == number, abs(number) <= Double(Int32.max) {
                value = Int(number)
            } else {
                value = nil
            }
        }
    }
    
    public let id: String
    public let config: Config
    public let gamConfig: GamConfig
    public let prebidConfig: PrebidConfig
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = String(idInt)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: container.codingPath,
                                      debugDescription: "Expected String or Int for id")
            )
        }
        
        self.config = try container.decode(Config.self, forKey: .config)
        self.gamConfig = try container.decode(GamConfig.self, forKey: .gamConfig)
        self.prebidConfig = try container.decode(PrebidConfig.self, forKey: .prebidConfig)
    }
}
