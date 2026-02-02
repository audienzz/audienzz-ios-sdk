/*   Copyright 2018-2025 Audienzz.org, Inc.

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

private let customPrebidServerURL = "https://ib.adnxs.com/openrtb2/prebid"
private let prebidServerAccountId = "3927"
private let customStatusEndpoint = "https://ib.adnxs.com/status"

@objcMembers
public class Audienzz: NSObject {
    var audienzzSchainObjectConfig: String?

    // MARK: - Properties (SDK)

    public var timeoutUpdated: Bool {
        get { Prebid.shared.timeoutUpdated }
        set { Prebid.shared.timeoutUpdated = newValue }
    }

    public var audienzServerAccountId: String {
        get { Prebid.shared.prebidServerAccountId }
        set { Prebid.shared.prebidServerAccountId = newValue }
    }

    public var pbsDebug: Bool {
        get { Prebid.shared.pbsDebug }
        set { Prebid.shared.pbsDebug = newValue }
    }

    public var customHeaders: [String: String] {
        get { Prebid.shared.customHeaders }
        set { Prebid.shared.customHeaders = newValue }
    }

    public var storedBidResponses: [String: String] {
        get { Prebid.shared.storedBidResponses }
        set { Prebid.shared.storedBidResponses = newValue }
    }

    public static let shared = Audienzz()

    public func configureSDK(companyId: String, enablePPID: Bool = false) {
        setupPrebid(companyId)

        do {
            try Prebid.initializeSDK(serverURL: customPrebidServerURL) {
                status,
                    error in
                self.handleInitializationResultStatus(status: status)

                PPIDManager.shared.setAutomaticPpidEnabled(enablePPID)

                if let error = error {
                    AULogEvent.logDebug("Initialization Error: \(error)")
                }
            }
        } catch {
            AULogEvent.logDebug(
                "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
            )
        }
    }

    public func configureSDK(
        companyId: String,
        gadMobileAdsVersion: String? = nil,
        enablePPID: Bool = false
    ) {
        setupPrebid(companyId)

        do {
            try Prebid.initializeSDK(
                serverURL: customPrebidServerURL,
                gadMobileAdsVersion: gadMobileAdsVersion
            ) { status, error in
                if let error = error {
                    AULogEvent.logDebug(
                        "Initialization Error: \(error.localizedDescription)"
                    )
                    return
                }

                self.handleInitializationResultStatus(status: status)
                PPIDManager.shared.setAutomaticPpidEnabled(enablePPID)
            }
        } catch {
            AULogEvent.logDebug(
                "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
            )
        }
    }

    public func configureWithRemoteSDK(
        gadMobileAdsVersion: String? = nil,
        enablePPID: Bool = false
    ) async throws {
        try await AudienzzRemoteConfig.shared.fetchPublisherConfig()

        guard let publisherConfig = AudienzzRemoteConfig.shared.publisherConfig else {
            AULogEvent.logDebug(
                "Initialization Failed because PrebidUrl is empty"
            )
            return
        }

        setupRemotePrebid(
            publisherConfig.ortb?.schain?.sellerId ?? "1",
            prebidServerAccountId: publisherConfig.prebidServer.accountId,
            prebidStatusUrl: publisherConfig.prebidServer.statusUrl
        )

        if let schain = publisherConfig.ortb?.schain {
            let schainJson = """
            {
                "source": {
                    "ext": {
                        "schain": {
                            "complete": 1,
                            "nodes": [{
                                "asi": "\(schain.advertisingSystemDomain)",
                                "sid": "\(schain.sellerId)",
                                "hp": 1
                            }],
                            "ver": "1.0"
                        }
                    }
                }
            }
            """
            setSchainObject(schain: schainJson)
        }

        if let ortb = publisherConfig.ortb {
            AUTargeting.shared.publisherName = ortb.publisherName
            AUTargeting.shared.domain = ortb.domain
        }

        if let iosOrtb = publisherConfig.ios?.ortb {
            AUTargeting.shared.storeURL = iosOrtb.storeUrl
            AUTargeting.shared.sourceapp = iosOrtb.sourceApp
            AUTargeting.shared.itunesID = iosOrtb.bundleId
        }

        do {
            try Prebid.initializeSDK(
                serverURL: publisherConfig.prebidServer.url,
                gadMobileAdsVersion: gadMobileAdsVersion
            ) { status, error in
                if let error = error {
                    AULogEvent.logDebug(
                        "Initialization Error: \(error.localizedDescription)"
                    )
                    return
                }

                self.handleInitializationResultStatus(status: status)
                PPIDManager.shared.setAutomaticPpidEnabled(enablePPID)
            }
        } catch {
            AULogEvent.logDebug(
                "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Public Init For RN Bridg (Audienzz)

    /// Special method used for RN bridging initialization
    public func configureSDK_RN(
        companyId: String,
        enablePPID: Bool = false,
        _ completion: (() -> Void)? = nil
    ) {
        Task {
            setupPrebid(companyId)

            do {
                try Prebid.initializeSDK(serverURL: customPrebidServerURL) {
                    status,
                        error in
                    self.handleInitializationResultStatus(status: status)

                    if let error = error {
                        AULogEvent.logDebug("Initialization Error: \(error)")
                    }

                    PPIDManager.shared.setAutomaticPpidEnabled(enablePPID)
                    completion?()
                }
            } catch {
                AULogEvent.logDebug(
                    "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
                )
                // You may want to call completion here as well depending on your error handling strategy
                completion?()
            }
        }
    }

    /// Special method used for RN bridging initialization
    public func configureSDK_RN(
        companyId: String,
        gadMobileAdsVersion: String?,
        enablePPID: Bool = false,
        _ completion: (() -> Void)? = nil
    ) {
        Task {
            setupPrebid(companyId)

            do {
                try Prebid.initializeSDK(
                    serverURL: customPrebidServerURL,
                    gadMobileAdsVersion: gadMobileAdsVersion
                ) { status, error in
                    if let error = error {
                        AULogEvent.logDebug(
                            "Initialization Error: \(error.localizedDescription)"
                        )
                        return
                    }

                    self.handleInitializationResultStatus(status: status)
                    PPIDManager.shared.setAutomaticPpidEnabled(enablePPID)
                    completion?()
                }
            } catch {
                AULogEvent.logDebug(
                    "Audienzz SDK initialization failed with error: \(error.localizedDescription)"
                )
                // You may want to call completion here as well depending on your error handling strategy
                completion?()
            }
        }
    }

    // MARK: - Public Properties (Audienzz)

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

        for (bidder, responseId) in Prebid.shared.storedBidResponses {
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

    /// Set publisher schain object to use with ad requests
    public func setSchainObject(schain: String) {
        audienzzSchainObjectConfig = schain
        AUTargeting.shared.setGlobalOrtbConfig(ortbConfig: schain)
    }

    private func setupPrebid(_ companyId: String) {
        AUEventsManager.shared.configure(companyId: companyId)
        Prebid.shared.prebidServerAccountId = prebidServerAccountId
        Prebid.shared.customStatusEndpoint = customStatusEndpoint
    }

    private func setupRemotePrebid(
        _ companyId: String,
        prebidServerAccountId: String,
        prebidStatusUrl: String
    ) {
        AUEventsManager.shared.configure(companyId: companyId)
        Prebid.shared.prebidServerAccountId = prebidServerAccountId
        Prebid.shared.customStatusEndpoint = prebidStatusUrl
    }

    private func handleInitializationResultStatus(
        status: PrebidInitializationStatus
    ) {
        switch status {
        case .succeeded:
            AULogEvent.logDebug("Audienzz SDK initialized")
        case .failed:
            AULogEvent.logDebug("Audienzz SDK initialization failed")
        case .serverStatusWarning:
            AULogEvent.logDebug("Audienzz SDK server status warning")
        default:
            AULogEvent.logDebug("Audienzz SDK encountered unexpected error")
        }
    }
}
