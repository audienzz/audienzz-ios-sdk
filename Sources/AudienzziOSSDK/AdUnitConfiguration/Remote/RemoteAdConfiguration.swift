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
        public let refreshTimeSeconds: Int?
    }

    public enum WidthStrategy: String, Codable {
        case fullWidth = "FULL_WIDTH"
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
    }
    
    public let id: Int
    public let config: Config
    public let gamConfig: GamConfig
    public let prebidConfig: PrebidConfig
}
