import GoogleMobileAds

class CustomTargetingManager {

    private var targetingMap: [String: String] = [:]

    /** Add single key-value targeting */
    func addCustomTargeting(key: String, value: String) {
        targetingMap[key] = value
    }

    /** Add single key - multiple values targeting */
    func addCustomTargeting(key: String, values: Set<String>) {
        targetingMap[key] = values.joined(separator: ",")
    }

    /** Remove targeting for specific key */
    func removeCustomTargeting(key: String) {
        targetingMap.removeValue(forKey: key)
    }

    /** Clear all targeting */
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
        request.customTargeting = targetingMap
        return request
    }
}
