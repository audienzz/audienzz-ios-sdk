//
//  RemotePublisherConfiguration.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 24.11.2025.
//

import Foundation

public struct RemotePublisherConfiguration: Codable {
    public struct PrebidServer: Codable {
        public let url: String
        public let accountId: String
        public let statusUrl: String
        
        enum CodingKeys: String, CodingKey {
            case url
            case accountId
            case statusUrl
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            url = try container.decode(String.self, forKey: .url)
            statusUrl = try container.decode(String.self, forKey: .statusUrl)
            
            // Handle accountId as both Int and String for backward compatibility
            if let accountIdInt = try? container.decode(Int.self, forKey: .accountId) {
                accountId = String(accountIdInt)
            } else {
                accountId = try container.decode(String.self, forKey: .accountId)
            }
        }
    }
    
    public struct Schain: Codable {
        public let sellerId: String
        public let advertisingSystemDomain: String
        
        enum CodingKeys: String, CodingKey {
            case sellerId
            case advertisingSystemDomain
        }
    }
    
    public struct OrtbConfig: Codable {
        public let schain: Schain?
        public let publisherName: String?
        public let domain: String?
    }
    
    public struct AppOrtbConfig: Codable {
        public let bundleId: String?
        public let sourceApp: String?
        public let storeUrl: String?
    }
    
    public struct IosConfig: Codable {
        public let ortb: AppOrtbConfig?
    }

    /// Google Mobile Ads global configuration, sourced from the backend publisher config.
    public struct GamConfig: Codable {
        /// Global app volume for GMA ad audio. Range: 0.0 (muted) – 1.0 (full volume).
        /// Defaults to 0.0 (muted) if absent.
        public let appVolume: Float?

        enum CodingKeys: String, CodingKey {
            case appVolume = "setAppVolume"
        }
    }

    public let id: Int
    public let prebidServer: PrebidServer
    public let gamConfig: GamConfig?
    public let ortb: OrtbConfig?
    public let ios: IosConfig?

    /// Backend switch for the screen-aware smart-refresh model (directional viewport gate +
    /// screen-navigation pause/reload). Absent/nil → the SDK default (legacy smart refresh).
    /// A local override on `Audienzz.shared.smartRefreshV2Override` takes precedence over this.
    public let smartRefreshV2: Bool?

    /// Master backend switch for Publisher Provided Identifiers. `false` suppresses every PPID,
    /// including one the app supplied through `setPublisherPPID` — it is a per-publisher privacy
    /// switch, not a preference. Absent/nil → enabled.
    public let ppidEnabled: Bool?

    /// Events per analytics POST. Missing/invalid → 10; positive integers capped at 15.
    public let analyticsBatchSize: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case prebidServer
        case gamConfig
        case ortb
        case ios
        case smartRefreshV2
        case ppidEnabled
        case analyticsBatchSize
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        prebidServer = try values.decode(PrebidServer.self, forKey: .prebidServer)
        gamConfig = try values.decodeIfPresent(GamConfig.self, forKey: .gamConfig)
        ortb = try values.decodeIfPresent(OrtbConfig.self, forKey: .ortb)
        ios = try values.decodeIfPresent(IosConfig.self, forKey: .ios)
        smartRefreshV2 = try values.decodeIfPresent(Bool.self, forKey: .smartRefreshV2)
        ppidEnabled = try values.decodeIfPresent(Bool.self, forKey: .ppidEnabled)
        // This optional tuning field must never break publisher config or cached-config decoding.
        let number = (try? values.decode(Int.self, forKey: .analyticsBatchSize)) ??
            (try? values.decode(String.self, forKey: .analyticsBatchSize))
                .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        analyticsBatchSize = number.flatMap { $0 > 0 ? min(15, $0) : nil }
    }
}
