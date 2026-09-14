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

    /// Publisher-supplied PPID (e.g. hashed email). When set, always wins over the
    /// SDK-generated UUID. Cleared by passing nil.
    private var publisherPpid: String? = nil
    private let userDefaults = UserDefaults.standard

    // MARK: - Public Methods

    /// Provide a publisher-owned PPID (e.g. a hashed e-mail address).
    /// When set this always takes precedence over the SDK-generated UUID.
    /// Pass `nil` to clear and fall back to the generated UUID.
    public func setPublisherPPID(_ ppid: String?) {
        publisherPpid = ppid
    }

    /// Returns the active PPID:
    ///   1. `nil` when consent is missing, or the backend has switched PPIDs off entirely.
    ///   2. Publisher-supplied PPID (if set via `setPublisherPPID`).
    ///   3. SDK-generated UUID (persisted, rotated every 12 months), unless the backend has
    ///      switched automatic PPID off.
    ///
    /// There is no app-facing opt-out: a PPID is sent unless the backend disables it for this
    /// publisher. A missing PPID costs frequency capping and cross-session targeting, so the SDK
    /// generates and persists one rather than leaving the field empty.
    public func getPPID() -> String? {
        if AUTargeting.shared.purposeConsents?.isEmpty ?? false {
            LogEvent("Consent missing, cannot get PPID")
            return nil
        }

        // Master switch: suppresses the publisher's own identifier too. It is a per-publisher
        // privacy setting, so honouring it only for the generated UUID would miss the point.
        guard Audienzz.shared.isPpidEnabled else {
            LogEvent("PPID disabled by the publisher config")
            return nil
        }

        if let publisher = publisherPpid {
            return publisher
        }

        // The publisher's own identifier is theirs to send; this switch governs only the one the
        // SDK would invent.
        guard Audienzz.shared.isAutomaticPpidEnabled else {
            LogEvent("Automatic PPID disabled by the publisher config")
            return nil
        }

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
