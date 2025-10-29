//
//  RemoteConfigFetcher.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 28.10.2025.
//

import Foundation

public final class RemoteConfigFetcher {
    public static let shared = RemoteConfigFetcher()

    private init() {}

    public func fetchBannerConfig(publisherId: String, adConfigId: String) async throws -> RemoteAdConfiguration {
        guard let baseURL = RemoteConfigManager.shared.getRemoteUrl() else {
            throw RemoteConfigError.missingBaseURL
        }

        let requestURL = baseURL
            .appendingPathComponent("publishers")
            .appendingPathComponent("\(publisherId)")
            .appendingPathComponent("ad-configs")
            .appendingPathComponent("\(adConfigId)")

        let (data, response) = try await URLSession.shared.data(from: requestURL)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw RemoteConfigError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(RemoteAdConfiguration.self, from: data)
        } catch {
            throw RemoteConfigError.decodingFailed(error)
        }
    }
}

public enum RemoteConfigError: Error {
    case missingBaseURL
    case invalidResponse
    case decodingFailed(Error)
}
