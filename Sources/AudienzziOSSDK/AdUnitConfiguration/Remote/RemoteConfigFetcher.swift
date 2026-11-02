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
    /// HTTP 404: the server does not serve this route.
    case notFound
    case decodingFailed(Error)
}

/// ws-sdk-config. The SDK id the app initializes with addresses `sdks/{sdkId}`; the `publishers/`
/// routes are what released SDKs call and are kept as a fallback when `sdks/` is not served.
final class RemoteConfigFetcher {
    static let shared = RemoteConfigFetcher()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchPublisherConfig(remoteUrl: URL, publisherId: String) async throws -> RemotePublisherConfiguration {
        try await fetch(
            remoteUrl: remoteUrl,
            sdkId: publisherId,
            route: [],
            as: RemotePublisherConfiguration.self
        )
    }

    func fetchAdUnitConfigs(remoteUrl: URL, publisherId: String) async throws -> [RemoteAdConfiguration] {
        let data = try await fetchData(remoteUrl: remoteUrl, sdkId: publisherId, route: ["ad-configs"])

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
            sdkId: publisherId,
            route: ["ad-configs", adConfigId],
            as: RemoteAdConfiguration.self
        )
    }
}

// MARK: - Private

private extension RemoteConfigFetcher {
    func fetch<T: Decodable>(
        remoteUrl: URL,
        sdkId: String,
        route: [String],
        as type: T.Type
    ) async throws -> T {
        let data = try await fetchData(remoteUrl: remoteUrl, sdkId: sdkId, route: route)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RemoteConfigError.decodingFailed(error)
        }
    }

    /// `sdks/{sdkId}/…` first. Only a 404 — a server that does not serve that route yet — falls back
    /// to `publishers/{id}/…`; any other failure is reported as it is.
    func fetchData(remoteUrl: URL, sdkId: String, route: [String]) async throws -> Data {
        do {
            return try await fetchData(remoteUrl: remoteUrl, pathComponents: ["sdks", sdkId] + route)
        } catch RemoteConfigError.notFound {
            AULogEvent.logDebug("Remote Config: sdks/ route not found; falling back to publishers/")
            return try await fetchData(remoteUrl: remoteUrl, pathComponents: ["publishers", sdkId] + route)
        }
    }

    func fetchData(
        remoteUrl: URL,
        pathComponents: [String]
    ) async throws -> Data {
        let requestURL = pathComponents.reduce(remoteUrl) { url, component in
            url.appendingPathComponent(component)
        }

        let (data, response) = try await session.data(from: requestURL)

        if (response as? HTTPURLResponse)?.statusCode == 404 { throw RemoteConfigError.notFound }
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
