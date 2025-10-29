//
//  RemoteConfigManager.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 28.10.2025.
//

import Foundation

@objcMembers
public class RemoteConfigManager: NSObject {
    public static let shared = RemoteConfigManager()

    // MARK: - Properties

    private var publisherId: String?
    private var remoteUrl: URL?

    public func getPublisherId() -> String? {
        return publisherId
    }

    public func setPublisherId(_ publisherId: String) {
        self.publisherId = publisherId
    }

    public func getRemoteUrl() -> URL? {
        return remoteUrl
    }

    public func setRemoteUrl(_ remoteUrl: URL) {
        self.remoteUrl = remoteUrl
    }
}
