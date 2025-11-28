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
