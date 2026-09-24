import Foundation
import GoogleMobileAds

/// How one auction's GAM custom targeting is assembled, and kept intact through Prebid.
///
/// The contract, on every original ad type: the SDK never removes a publisher's key-value, and a
/// publisher can never remove or override the SDK's.
/// - Layers, later winning a name clash: the publisher's per-request keys (the request passed to
///   `createAd`), then the current global targeting (`AUTargeting.addGlobalTargeting`), then the
///   SDK's own keys (`au_sdk`, reserved keys, and the per-slot counters).
/// - Assembled on a COPY for every auction. The publisher's request object is never modified, so
///   one request can serve several ads, and a global key-value added or removed after the ad was
///   created reaches its next auction instead of being frozen at `createAd`.
/// - Prebid iOS removes EVERY `hb_` key before it bids (`Utils.removeHBKeywords`), a publisher's
///   included. ``PrebidGuard`` puts back everything it removed, except the bid keys Prebid set in
///   this auction, which win on their own names. The SDK's keys come back whatever Prebid did.
enum AUAuctionTargeting {

    /// The publisher's request plus current global targeting and the SDK's keys, as a new object.
    static func request(from publisherRequest: AdManagerRequest) -> AdManagerRequest {
        let copy = publisherRequest.copy() as! AdManagerRequest
        return AUTargeting.shared.customTargetingManager.applyToGamRequest(request: copy)
    }

    /// Keys only the SDK sets. Restored after Prebid unconditionally.
    static var sdkKeys: Set<String> {
        Set(AUAdRequestSnapshot.keys)
            .union(["au_sdk"])
            .union(AUTargeting.shared.customTargetingManager.reservedKeys)
    }

    /// Everything on the request just before Prebid runs, put back just after.
    ///
    /// Must wrap a request that no earlier auction has touched — which is what ``request(from:)``
    /// produces — or it would put back a previous auction's bid keys along with the publisher's.
    struct PrebidGuard {
        private let before: [String: Any]

        init(_ request: AdManagerRequest) {
            before = request.customTargeting ?? [:]
        }

        func restore(into request: AdManagerRequest) {
            let sdkKeys = AUAuctionTargeting.sdkKeys
            var targeting = request.customTargeting ?? [:]
            for (key, value) in before where targeting[key] == nil || sdkKeys.contains(key) {
                targeting[key] = value
            }
            request.customTargeting = targeting
        }
    }
}
