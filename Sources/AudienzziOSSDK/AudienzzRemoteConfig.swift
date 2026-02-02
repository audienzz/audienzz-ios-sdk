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

    private(set) var publisherConfig: RemotePublisherConfiguration?
    private(set) var adUnitConfigs: [RemoteAdConfiguration]?

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

        AULogEvent.logDebug("Audienzz Remote Config started fetching new config")

        do {
            let publisherConfig = try await RemoteConfigFetcher.shared.fetchPublisherConfig(
                remoteUrl: remoteUrl,
                publisherId: publisherId
            )
            let adUnitConfigs = try await RemoteConfigFetcher.shared.fetchAdUnitConfigs(
                remoteUrl: remoteUrl,
                publisherId: publisherId
            )
            remoteConfigCache.save(publisherConfig: publisherConfig, adUnitConfigs: adUnitConfigs)

            self.publisherConfig = publisherConfig
            self.adUnitConfigs = adUnitConfigs

            AULogEvent.logDebug("Audienzz Remote Config finished fetching new config, using it")
        } catch {
            AULogEvent.logDebug("Audienzz Remote Config fetch failed: \(error)")

            adUnitConfigs = remoteConfigCache.load()
            publisherConfig = remoteConfigCache.load()

            if remoteConfigCache.isCacheValid() {
                AULogEvent.logDebug("Audienzz Remote Config using valid cached config")
            }

            if adUnitConfigs == nil {
                throw error
            }
            
            AULogEvent.logDebug("Audienzz Remote Config using stale cached config")
        }
    }

    public func remoteConfig(for adConfigId: String) -> RemoteAdConfiguration? {
        adUnitConfigs?.first(where: { $0.id == adConfigId })
    }
}
