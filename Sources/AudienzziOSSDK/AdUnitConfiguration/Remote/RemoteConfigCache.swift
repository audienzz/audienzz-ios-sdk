//
//  RemoteConfigCache.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 11.11.2025.
//

import Foundation

final class RemoteConfigCache {
    private let remotePublisherConfigKey = "remote_publisher_configuration"

    private let userDefaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func save(_ remoteConfig: [RemoteAdConfiguration]) {
        saveToCache(remoteConfig, forKey: remotePublisherConfigKey)
    }

    func load() -> [RemoteAdConfiguration]? {
        loadFromCache(forKey: remotePublisherConfigKey)
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
