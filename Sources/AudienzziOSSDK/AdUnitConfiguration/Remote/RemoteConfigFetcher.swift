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
        let data = try await fetchData(
            remoteUrl: remoteUrl,
            pathComponents: ["publishers", publisherId, "ad-configs"]
        )

        do {
            // Lossy decode: a single malformed ad-config entry must not discard
            // every other (valid) ad unit's config. Skip the bad ones instead.
            let items = try JSONDecoder().decode([FailableDecodable<RemoteAdConfiguration>].self, from: data)
            let configs = items.compactMap { $0.value }
            let skipped = items.count - configs.count
            if skipped > 0 {
                AULogEvent.logDebug("Remote Config: skipped \(skipped) malformed ad-config ent\(skipped == 1 ? "ry" : "ries")")
            }
            return configs
        } catch {
            throw RemoteConfigError.decodingFailed(error)
        }
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
        let data = try await fetchData(remoteUrl: remoteUrl, pathComponents: pathComponents)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RemoteConfigError.decodingFailed(error)
        }
    }

    func fetchData(
        remoteUrl: URL,
        pathComponents: [String]
    ) async throws -> Data {
        let requestURL = pathComponents.reduce(remoteUrl) { url, component in
            url.appendingPathComponent(component)
        }

        let (data, response) = try await URLSession.shared.data(from: requestURL)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw RemoteConfigError.invalidResponse
        }

        return data
    }
}

/// Decodes to `nil` instead of throwing when the underlying element is
/// malformed, so a lossy array decode can skip bad entries.
private struct FailableDecodable<Base: Decodable>: Decodable {
    let value: Base?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(Base.self)
    }
}
