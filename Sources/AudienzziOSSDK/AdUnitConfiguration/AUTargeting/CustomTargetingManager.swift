import GoogleMobileAds

class CustomTargetingManager {

    private let sdkPlatform: String
    private let sdkVersion: String
    private var targetingMap: [String: String] = [:]

    /// Keys set by SDK/bridge init — invisible to publishers.
    /// Cannot be removed via removeCustomTargeting / clearCustomTargeting.
    private var reservedTargetingMap: [String: String] = [:]

    init(sdkPlatform: String = "ios", sdkVersion: String = "") {
        self.sdkPlatform = sdkPlatform
        self.sdkVersion = sdkVersion
    }

    /** Add single key-value targeting */
    func addCustomTargeting(key: String, value: String) {
        targetingMap[key] = value
    }

    /** Add single key - multiple values targeting */
    func addCustomTargeting(key: String, values: Set<String>) {
        targetingMap[key] = values.joined(separator: ",")
    }

    /** Store a reserved (SDK-internal) key-value. Never cleared by publisher calls. */
    func setReservedTargeting(key: String, value: String) {
        reservedTargetingMap[key] = value
    }

    /** Returns true if the key is in the reserved map. */
    func isReserved(key: String) -> Bool {
        reservedTargetingMap[key] != nil
    }

    /** Remove targeting for specific key — silently skips reserved keys. */
    func removeCustomTargeting(key: String) {
        guard !isReserved(key: key) else { return }
        targetingMap.removeValue(forKey: key)
    }

    /** Clear all targeting — preserves reserved keys. */
    func clearCustomTargeting() {
        targetingMap.removeAll()
    }

    /** For ORTB - build the custom targeting part of JSON */
    func buildOrtbCustomTargeting() -> [String: Any] {
        var ortbDictionary: [String: Any] = [:]

        if !targetingMap.isEmpty {
            ortbDictionary["app"] = [
                "content": ["keywords": buildKeywordsString()]
            ]
        }

        return ortbDictionary
    }

    // Build keywords string in format "KEY=VALUE, KEY=VALUE2"
    private func buildKeywordsString() -> String {
        var keywordPairs: [String] = []

        targetingMap.forEach { (key, value) in
            if value.contains(",") {
                value.split(separator: ",").forEach { singleValue in
                    keywordPairs.append(
                        "\(key)=\(singleValue.trimmingCharacters(in: .whitespaces))"
                    )
                }
            } else {
                keywordPairs.append("\(key)=\(value)")
            }
        }

        return keywordPairs.joined(separator: ",")
    }

    /** For GAM requests - apply global targeting  */
    func applyToGamRequest(request: AdManagerRequest) -> AdManagerRequest {
        // Start with publisher keys, then overlay SDK-reserved keys so they
        // always win — publisher can never overwrite them.
        var targeting = targetingMap
        targeting["au_sdk"] = sdkPlatform
        if !sdkVersion.isEmpty {
            targeting["au_v"] = sdkVersion
        }
        reservedTargetingMap.forEach { targeting[$0.key] = $0.value }
        request.customTargeting = targeting

        AULogEvent.logDebug("GAM custom targeting applied:")
        AULogEvent.logDebug("  au_sdk = \(sdkPlatform)")
        if !sdkVersion.isEmpty { AULogEvent.logDebug("  au_v   = \(sdkVersion)") }
        reservedTargetingMap.forEach { AULogEvent.logDebug("  \($0.key) = \($0.value) [reserved]") }
        targetingMap.forEach { AULogEvent.logDebug("  \($0.key) = \($0.value)") }

        return request
    }
}
