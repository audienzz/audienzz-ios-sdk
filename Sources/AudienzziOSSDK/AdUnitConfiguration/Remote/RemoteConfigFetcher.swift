//
//  RemoteConfigFetcher.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 28.10.2025.
//

import Foundation

enum RemoteConfigError: Error {
    case missingBaseURL
    case invalidResponse
    case decodingFailed(Error)
}

final class RemoteConfigFetcher {
    static let shared = RemoteConfigFetcher()

    private init() {}

    func fetchPublisherConfig(remoteUrl: URL, publisherId: String) async throws -> RemotePublisherConfiguration {
        try await fetch(
            remoteUrl: remoteUrl,
            pathComponents: ["publishers", publisherId],
            as: RemotePublisherConfiguration.self
        )
    }

    func fetchAdUnitConfigs(remoteUrl: URL, publisherId: String) async throws -> [RemoteAdConfiguration] {
        try await fetch(
            remoteUrl: remoteUrl,
            pathComponents: ["publishers", publisherId, "ad-configs"],
            as: [RemoteAdConfiguration].self
        )
    }

    func fetchAdUnitConfig(remoteUrl: URL, publisherId: String, adConfigId: String) async throws -> RemoteAdConfiguration {
        try await fetch(
            remoteUrl: remoteUrl,
            pathComponents: ["publishers", publisherId, "ad-configs", adConfigId],
            as: RemoteAdConfiguration.self
        )
    }
}

// MARK: - Private

private extension RemoteConfigFetcher {
    func fetch<T: Decodable>(
        remoteUrl: URL,
        pathComponents: [String],
        as type: T.Type
    ) async throws -> T {
        let requestURL = pathComponents.reduce(remoteUrl) { url, component in
            url.appendingPathComponent(component)
        }

        let (data, response) = try await URLSession.shared.data(from: requestURL)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw RemoteConfigError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RemoteConfigError.decodingFailed(error)
        }
    }
}
