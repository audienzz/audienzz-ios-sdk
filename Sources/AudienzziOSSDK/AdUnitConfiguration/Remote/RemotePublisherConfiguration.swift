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
    
    public let id: Int
    public let prebidServer: PrebidServer
    public let ortb: OrtbConfig?
    public let ios: IosConfig?
    
    enum CodingKeys: String, CodingKey {
        case id
        case prebidServer
        case ortb
        case ios
    }
}
