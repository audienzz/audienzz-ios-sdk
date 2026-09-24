import GoogleMobileAds

class CustomTargetingManager {

    private var targetingMap: [String: String] = [:]

    /// Keys set by SDK/bridge init — invisible to publishers.
    /// Cannot be removed via removeCustomTargeting / clearCustomTargeting.
    private var reservedTargetingMap: [String: String] = [:]

    /// The single SDK identification key sent on every GAM request: platform and version in one
    /// value, e.g. `ios-0.3.2`.
    ///
    /// It used to be two keys — `au_sdk = ios` and `au_v = 0.3.2`. One key is what GAM line-item
    /// targeting and reporting actually want, because "this platform on this version" is a single
    /// condition; expressing it as two forced every rule to AND them together.
    ///
    /// **`au_v` is no longer sent.** Anything keyed on it in Ad Manager needs to move to `au_sdk`
    /// matching `<platform>-<version>`. The version is omitted only when the SDK could not resolve
    /// one, in which case the value is the bare platform. Android sends the identical shape.
    private let sdkPlatformVersion: String

    init(sdkPlatform: String = "ios", sdkVersion: String = "") {
        // Combined once here rather than at every request: the two halves have no separate
        // meaning any more, so keeping them as fields would just invite someone to send one.
        sdkPlatformVersion = sdkVersion.isEmpty ? sdkPlatform : "\(sdkPlatform)-\(sdkVersion)"
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

    /** The reserved (SDK-internal) keys currently set. */
    var reservedKeys: Set<String> { Set(reservedTargetingMap.keys) }

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
        // Merge into whatever the publisher already set on the request (e.g.
        // direct-sold GAM line-item keys) — assigning outright wiped those and
        // broke direct-sold delivery. Then overlay SDK keys, then reserved keys
        // last so the SDK's own values always win.
        var targeting = request.customTargeting ?? [:]
        targetingMap.forEach { targeting[$0.key] = $0.value }
        targeting["au_sdk"] = sdkPlatformVersion
        reservedTargetingMap.forEach { targeting[$0.key] = $0.value }
        request.customTargeting = targeting

        AULogEvent.logDebug("GAM custom targeting applied:")
        AULogEvent.logDebug("  au_sdk = \(sdkPlatformVersion)")
        reservedTargetingMap.forEach { AULogEvent.logDebug("  \($0.key) = \($0.value) [reserved]") }
        targetingMap.forEach { AULogEvent.logDebug("  \($0.key) = \($0.value)") }

        return request
    }
}
