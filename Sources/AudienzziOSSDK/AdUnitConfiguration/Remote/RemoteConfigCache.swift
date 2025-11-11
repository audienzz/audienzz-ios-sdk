//
//  RemoteConfigCache.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 11.11.2025.
//

import Foundation

struct CachedConfig: Codable {
    let adUnitConfigs: [RemoteAdConfiguration]
    let publisherConfig: RemotePublisherConfiguration
    let timestamp: Date
}

final class RemoteConfigCache {
    private let remotePublisherConfigKey = "remote_publisher_configuration"

    private let cacheTTL: TimeInterval = 24 * 60 * 60

    private let userDefaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func save(publisherConfig: RemotePublisherConfiguration, adUnitConfigs: [RemoteAdConfiguration]) {
        let cachedConfig = CachedConfig(
            adUnitConfigs: adUnitConfigs,
            publisherConfig: publisherConfig,
            timestamp: Date()
        )
        saveToCache(cachedConfig, forKey: remotePublisherConfigKey)
    }

    func load() -> [RemoteAdConfiguration]? {
        guard let cachedConfig: CachedConfig = loadFromCache(forKey: remotePublisherConfigKey) else {
            return nil
        }

        return cachedConfig.adUnitConfigs
    }

    func load() -> RemotePublisherConfiguration? {
        guard let cachedConfig: CachedConfig = loadFromCache(forKey: remotePublisherConfigKey) else {
            return nil
        }

        return cachedConfig.publisherConfig
    }

    func isCacheValid() -> Bool {
        guard let cachedConfig: CachedConfig = loadFromCache(forKey: remotePublisherConfigKey) else {
            return false
        }
        
        return Date().timeIntervalSince(cachedConfig.timestamp) < cacheTTL
    }
}

// MARK: - Private

private extension RemoteConfigCache {
    func saveToCache<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            print("⚠️ Failed to encode cache for key \(key): \(error)")
        }
    }

    func loadFromCache<T: Codable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
