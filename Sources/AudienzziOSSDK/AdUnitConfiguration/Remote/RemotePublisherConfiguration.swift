//
//  RemotePublisherConfiguration.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 24.11.2025.
//

import Foundation

public struct RemotePublisherConfiguration: Codable {
    public let prebidServerUrl: String
    public let prebidStatusUrl: String
    public let prebidServerAccountId: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prebidServerUrl = try container.decode(String.self, forKey: .prebidServerUrl)
        prebidStatusUrl = try container.decode(String.self, forKey: .prebidStatusUrl)
        prebidServerAccountId = String(try container.decode(Int.self, forKey: .prebidServerAccountId))
    }
}
