import Foundation

class AUTargetingUtils {
    
    // MARK: - JSON

    static func dictionary(from jsonString: String) throws -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AUOrtbError.createError(description: "Could not convert jsonString to data: \(jsonString)")
        }
        
        return try dictionary(from: jsonData)
    }
    
    static func dictionary(from jsonData: Data) throws -> [String: Any]? {
        guard !jsonData.isEmpty else {
            throw AUOrtbError.createError(description: "Invalid JSON data: \(jsonData)")
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)
        
        guard let jsonDictionary = jsonObject as? [String: Any] else {
            throw AUOrtbError.createError(description: "Could not cast jsonObject to JsonDictionary: \(jsonData)")
        }
        
        return jsonDictionary
    }
    
    static func toString(jsonDictionary: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(jsonDictionary) else {
            throw AUOrtbError.createError(description: "Not valid JSON object: \(jsonDictionary)")
        }
        
        let data: Data
        if #available(iOS 11.0, *) {
            data = try JSONSerialization.data(withJSONObject: jsonDictionary, options: .sortedKeys)
        } else {
            data = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
        }
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AUOrtbError.createError(description: "Could not convert JsonDictionary: \(jsonDictionary)")
        }
        
        return jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func dictionaries(for passthrough: Any) -> [[String: Any]]? {
        if let arrayResponse = passthrough as? [[String: Any]] {
            return arrayResponse
        } else if let dictionaryResponse = passthrough as? [String: Any] {
            return [dictionaryResponse]
        } else {
            return nil
        }
    }
}


enum AUOrtbError: Error {
    case invalidData(String)
    
    static func createError(description: String) -> Error {
        return AUOrtbError.invalidData(description)
    }
}



class ArbitraryGlobalORTBHelper {
    
    private let ortb: String
    
    struct ProtectedFields {
        
        static var deviceProps: [String] {
            [
                "w" ,"h" ,"lmt", "ifa","make", "model", "os", "osv", "hwv", "language",
                "connectiontype", "mccmnc", "carrier", "ua", "pxratio", "geo"
            ]
        }
        
        static var deviceExtProps: [String] {
            [ "atts", "ifv" ]
        }
        
        static var regsProps: [String] {
            [ "gpp_sid", "gpp", "coppa" ]
        }
        
        static var regsExtProps: [String] {
            [ "gdpr", "us_privacy" ]
        }
        
        static var userProps: [String] {
            [ "geo" ]
        }
        
        static var userExtProps: [String] {
            [ "consent" ]
        }
    }
    
    init(ortb: String) {
        self.ortb = ortb
    }
    
    func getValidatedORTBDict() -> [String : Any]? {
        guard var ortbDict = try? AUTargetingUtils.dictionary(from: ortb) else {
            AULogEvent.logDebug(
                "The provided global-level ortbConfig object is not valid JSON and will be ignored."
            )
            return nil
        }
        
        ortbDict["regs"] = removeProtectedFields(
            from: ortbDict["regs"] as? [String: Any],
            props: ProtectedFields.regsProps,
            extProps: ProtectedFields.regsExtProps
        )
        
        ortbDict["device"] = removeProtectedFields(
            from: ortbDict["device"] as? [String: Any],
            props: ProtectedFields.deviceProps,
            extProps: ProtectedFields.deviceExtProps
        )
        
        ortbDict["user"] = removeProtectedFields(
            from: ortbDict["user"] as? [String: Any],
            props: ProtectedFields.userProps,
            extProps: ProtectedFields.userExtProps
        )
        
        return ortbDict
    }
    
    private func removeProtectedFields(
        from dict: [String: Any]?,
        props: [String],
        extProps: [String]
    ) -> [String: Any]? {
        guard var dict = dict else { return nil }
        
        if var ext = dict["ext"] as? [String: Any] {
            extProps.forEach { ext[$0] = nil }
            dict["ext"] = ext
        }
        
        props.forEach { dict[$0] = nil }
        return dict
    }
}
