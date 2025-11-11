//
//  AudienzzRemoteConfig.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 28.10.2025.
//

import Foundation

public enum AudienzzRemoteConfigError: Error {
    case missingRemoteUrl
    case missingRemotePublisherId
}

@objcMembers
public class AudienzzRemoteConfig: NSObject {
    public static let shared = AudienzzRemoteConfig()

    private let remoteConfigCache = RemoteConfigCache()

    // MARK: - Properties

    private var publisherId: String?
    private var remoteUrl: URL?

    private var remoteConfig: [RemoteAdConfiguration]?

    public func configureRemote(remoteUrl: URL, publisherId: String) {
        self.remoteUrl = remoteUrl
        self.publisherId = publisherId
    }

    public func fetchPublisherConfig() async throws {
        guard let remoteUrl else {
            AULogEvent.logDebug("Audienzz Remote Config missing remote url")
            throw AudienzzRemoteConfigError.missingRemoteUrl
        }

        guard let publisherId else {
            AULogEvent.logDebug("Audienzz Remote Config missing publisher ur")
            throw AudienzzRemoteConfigError.missingRemotePublisherId
        }

        remoteConfig = remoteConfigCache.load()

        AULogEvent.logDebug("Audienzz Remote Config started fetching new config")

        let config = try await RemoteConfigFetcher.shared.fetchPublisherConfig(
            remoteUrl: remoteUrl,
            publisherId: publisherId
        )
        remoteConfigCache.save(config)
        remoteConfig = config
        
        AULogEvent.logDebug("Audienzz Remote Config finished fetching new config, using it")
    }

    public func remoteConfig(for adConfigId: Int) -> RemoteAdConfiguration? {
        remoteConfig?.first(where: { $0.id == adConfigId })
    }
}
