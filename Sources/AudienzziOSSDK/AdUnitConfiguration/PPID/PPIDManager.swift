//
//  PPIDManager.swift
//  AudienzziOSSDK
//
//  Created by Puha Artur on 03.10.2025.
//

import Foundation

class PPIDManager: AULogEventType {
    static let shared = PPIDManager()
    
    // MARK: - Constants

    private let monthsAgo = 12
    private let ppidKey = "audienzz_ppid_string"
    private let ppidTimestampKey = "audienzz_ppid_timestamp"
    
    // MARK: - Properties

    private var automaticPpidEnabled: Bool = false
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if automatic PPID is enabled
    func getAutomaticPpidEnabled() -> Bool {
        return automaticPpidEnabled
    }
    
    /// Used to enable or disable automatic PPID usage
    func setAutomaticPpidEnabled(_ enabled: Bool) {
        automaticPpidEnabled = enabled
    }
    
    /// Used to obtain PPID if automaticPpid is enabled
    func getPPID() -> String? {
        if !automaticPpidEnabled {
            LogEvent("Automatic PPID is disabled")
            return nil
        } else if AUTargeting.shared.purposeConsents?.isEmpty ?? false {
            LogEvent("Consent missing, cannot get PPID")
            return nil
        } else {
            var ppid = getPpid()
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
