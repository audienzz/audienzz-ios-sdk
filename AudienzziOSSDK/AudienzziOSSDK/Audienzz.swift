/*   Copyright 2018-2024 Audienzz.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import PrebidMobile

fileprivate let customPrebidServerURL = "https://prebid-server-test-j.prebid.org/openrtb2/auction"
fileprivate let prebidServerAccountId = "0689a263-318d-448b-a3d4-b02e8a709d9d"

@objcMembers
public class Audienzz: NSObject {
    
    // MARK: - Properties (SDK)
    public var timeoutUpdated: Bool {
        get { Prebid.shared.timeoutUpdated }
        set { Prebid.shared.timeoutUpdated = newValue }
    }
    
    public var audienzServerAccountId: String {
        get { Prebid.shared.prebidServerAccountId }
        set { Prebid.shared.prebidServerAccountId = newValue }
    }
    
    public var pbsDebug = false
    
    public var customHeaders: [String: String] {
        get { Prebid.shared.customHeaders }
        set { Prebid.shared.customHeaders = newValue }
    }
    
    public var storedBidResponses: [String: String] {
        get { Prebid.shared.storedBidResponses }
        set { Prebid.shared.storedBidResponses = newValue }
    }
    
    public static let shared = Audienzz()
    
    public func configureSDK(audienzzKey: String) {
        AUEventsManager.shared.configure(companyId: audienzzKey)
        Prebid.shared.prebidServerAccountId = prebidServerAccountId
        try! Prebid.shared.setCustomPrebidServer(url: customPrebidServerURL)
        
        // Initialize Prebid SDK
        Prebid.initializeSDK { status, error in
            // ....
            switch status {
            case .succeeded:
                AULogEvent.logDebug("Audienzz Status: succeeded")
            case .failed:
                AULogEvent.logDebug("Audienzz Status: failed")
            case .serverStatusWarning:
                AULogEvent.logDebug("Audienzz Status: serverStatusWarning")
            @unknown default:
                AULogEvent.logDebug("Audienzz Status: Unexpected Error")
            }
            
            if let error = error {
                AULogEvent.logDebug("Error: \(error)")
            }
        }
    }
    
    public func configureSDK(audienzzKey: String, gadMobileAdsVersion: String? = nil) {
        AUEventsManager.shared.configure(companyId: audienzzKey)
        Prebid.shared.prebidServerAccountId = prebidServerAccountId
        try! Prebid.shared.setCustomPrebidServer(url: customPrebidServerURL)
        
        Prebid.initializeSDK(gadMobileAdsVersion: gadMobileAdsVersion) { status, error in
            if let error = error {
                AULogEvent.logDebug("Initialization Error: \(error.localizedDescription)")
                return
            }
            
            switch status {
            case .succeeded:
                AULogEvent.logDebug("Audienzz Status: succeeded")
            case .failed:
                AULogEvent.logDebug("Audienzz Status: failed")
            case .serverStatusWarning:
                AULogEvent.logDebug("Audienzz Status: serverStatusWarning")
            @unknown default:
                AULogEvent.logDebug("Audienzz Status: Unexpected Error")
            }
            
            if let error = error {
                AULogEvent.logDebug("Error: \(error)")
            }
        }
    }
    
    // MARK: - Public Init For RN Bridg (Audienzz)
    /// Use this function only to make RN bridging initialize
    public func configureSDK_RN(audienzzKey: String, _ completion: (() -> Void)? = nil) {
        Task {
            AUEventsManager.shared.configure(companyId: audienzzKey)
            Prebid.shared.prebidServerAccountId = prebidServerAccountId
            try! Prebid.shared.setCustomPrebidServer(url: customPrebidServerURL)
            
            // Initialize Prebid SDK
            Prebid.initializeSDK { status, error in
                // ....
                switch status {
                case .succeeded:
                    AULogEvent.logDebug("Audienzz Status: succeeded")
                case .failed:
                    AULogEvent.logDebug("Audienzz Status: failed")
                case .serverStatusWarning:
                    AULogEvent.logDebug("Audienzz Status: serverStatusWarning")
                @unknown default:
                    AULogEvent.logDebug("Audienzz Status: Unexpected Error")
                }
                
                if let error = error {
                    AULogEvent.logDebug("Error: \(error)")
                }
                
                completion?()
            }
        }
    }
    
    /// Use this function only to make RN bridging initialize
    public func configureSDK_RN(audienzzKey: String, gadMobileAdsVersion: String?, _ completion: (() -> Void)? = nil) {
        Task {
            AUEventsManager.shared.configure(companyId: audienzzKey)
            Prebid.shared.prebidServerAccountId = prebidServerAccountId
            try! Prebid.shared.setCustomPrebidServer(url: customPrebidServerURL)
            
            Prebid.initializeSDK(gadMobileAdsVersion: gadMobileAdsVersion) { status, error in
                if let error = error {
                    AULogEvent.logDebug("Initialization Error: \(error.localizedDescription)")
                    return
                }
                
                switch status {
                case .succeeded:
                    AULogEvent.logDebug("Audienzz Status: succeeded")
                case .failed:
                    AULogEvent.logDebug("Audienzz Status: failed")
                case .serverStatusWarning:
                    AULogEvent.logDebug("Audienzz Status: serverStatusWarning")
                @unknown default:
                    AULogEvent.logDebug("Audienzz Status: Unexpected Error")
                }
                
                if let error = error {
                    AULogEvent.logDebug("Error: \(error)")
                }
                
                completion?()
            }
        }
    }
    
    // MARK: - Public Properties (Audienzz)
    private var prebidServerHost: PrebidHost = .Custom {
        didSet {
            timeoutMillisDynamic = NSNumber(value: timeoutMillis)
            timeoutUpdated = false
        }
    }
    
    public var timeoutMillis: Int {
        get { Prebid.shared.timeoutMillis }
        set {
            Prebid.shared.timeoutMillisDynamic = NSNumber(value: newValue)
        }
    }
    
    public var timeoutMillisDynamic: NSNumber?
    
    public var storedAuctionResponse: String?
    
    // MARK: - Stored Bid Response
    
    public func addStoredBidResponse(bidder: String, responseId: String) {
        Prebid.shared.storedBidResponses[bidder] = responseId
    }
    
    public func clearStoredBidResponses() {
        storedBidResponses.removeAll()
    }
    
    public func getStoredBidResponses() -> [[String: String]]? {
        var storedBidResponses: [[String: String]] = []
        
        for(bidder, responseId) in Prebid.shared.storedBidResponses {
            var storedBidResponse: [String: String] = [:]
            storedBidResponse["bidder"] = bidder
            storedBidResponse["id"] = responseId
            storedBidResponses.append(storedBidResponse)
        }
        return storedBidResponses.isEmpty ? nil : storedBidResponses
    }
    
    // MARK: - Custom Headers
    
    public func addCustomHeader(name: String, value: String) {
        customHeaders[name] = value
    }
    
    public func clearCustomHeaders() {
        customHeaders.removeAll()
    }
}
