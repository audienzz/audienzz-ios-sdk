//
//  PPIDManager.swift
//  AudienzziOSSDK
//
//  Created by Puha Artur on 03.10.2025.
//

import Foundation

@objcMembers
public class PPIDManager: NSObject, AULogEventType {
    public static let shared = PPIDManager()

    // MARK: - Constants

    private let monthsAgo = 12
    private let ppidKey = "audienzz_ppid_string"
    private let ppidTimestampKey = "audienzz_ppid_timestamp"

    // MARK: - Properties

    /// Explicit publisher override. Set via `setAutomaticPpidEnabled(_:)`.
    private var clientOverride: Bool? = nil
    /// Backend-configured value. Set internally after remote config fetch.
    private var backendEnabled: Bool? = nil
    /// Publisher-provided PPID value (e.g. a hashed user account ID).
    /// When set, used instead of the auto-generated UUID.
    private var customPpid: String? = nil

    private let userDefaults = UserDefaults.standard

    /// Resolved enable state: client override → backend value → default (true).
    private var isEnabled: Bool { clientOverride ?? backendEnabled ?? true }

    // MARK: - Public Methods

    /// Returns the resolved PPID enabled state.
    public func getAutomaticPpidEnabled() -> Bool {
        return isEnabled
    }

    /// Explicitly enables or disables automatic PPID. Takes priority over the backend value.
    public func setAutomaticPpidEnabled(_ enabled: Bool) {
        clientOverride = enabled
    }

    /// Sets a publisher-provided PPID value (e.g. a hashed user account ID).
    /// When set, this value is sent on every ad request instead of the auto-generated UUID.
    /// Pass `nil` to clear and fall back to UUID generation.
    public func setCustomPpid(_ ppid: String?) {
        customPpid = ppid
    }

    /// Called internally after remote config is fetched. Not part of the public API.
    func setBackendPpidEnabled(_ enabled: Bool?) {
        backendEnabled = enabled
    }

    /// Returns the PPID to attach to ad requests, or `nil` if PPID is disabled or consent is missing.
    public func getPPID() -> String? {
        if !isEnabled {
            LogEvent("Automatic PPID is disabled")
            return nil
        } else if AUTargeting.shared.purposeConsents?.isEmpty ?? false {
            LogEvent("Consent missing, cannot get PPID")
            return nil
        }

        // Use publisher-provided PPID if set
        if let custom = customPpid {
            return custom
        }

        // Fallback: auto-generate / rotate UUID
        let ppid = getPpid()
        let ppidTimestamp = getPpidTimestamp()

        if let ppid = ppid, ppidTimestamp != 0 {
            if isOlderThanYear(ppidTimestamp) {
                LogEvent("PPID timestamp is older than 12 months, generating new one")
                let newPpid = UUID().uuidString
                storePpidToUserDefaults(newPpid)
                return newPpid
            } else {
                return ppid
            }
        } else {
            LogEvent("PPID is nil or timestamp is nil, generating new one")
            let newPpid = UUID().uuidString
            storePpidToUserDefaults(newPpid)
            return newPpid
        }
    }

    // MARK: - Private Methods

    private func getPpid() -> String? {
        return userDefaults.string(forKey: ppidKey)
    }

    private func getPpidTimestamp() -> Int64 {
        return userDefaults.object(forKey: ppidTimestampKey) as? Int64 ?? 0
    }

    private func storePpidToUserDefaults(_ ppid: String) {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        userDefaults.set(ppid, forKey: ppidKey)
        userDefaults.set(timestamp, forKey: ppidTimestampKey)
    }

    private func isOlderThanYear(_ timestamp: Int64) -> Bool {
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        let calendar = Calendar.current
        let currentDate = Date(timeIntervalSince1970: TimeInterval(currentTime / 1000))

        guard let oneYearAgo = calendar.date(byAdding: .month, value: -monthsAgo, to: currentDate) else {
            return false
        }

        let oneYearAgoTimestamp = Int64(oneYearAgo.timeIntervalSince1970 * 1000)
        return timestamp < oneYearAgoTimestamp
    }
}
