import Foundation
import GoogleMobileAds

/// Identity of one logical placement. SDK adapters retain it across native ad replacements;
/// publishers do not have to provide slot numbers.
@objcMembers
public final class AUAdRequestContext: NSObject {
    private static var nextOrder = 0
    @nonobjc internal let registrationOrder: Int
    @nonobjc internal var bridgeIdentifier: String?

    public override init() {
        Self.nextOrder += 1
        registrationOrder = Self.nextOrder
        super.init()
    }

    /// Bridge-only identity, stable across native objects created for the same Dart/JS ad.
    public static func forSlot(_ identifier: String, pageKey: String? = nil) -> AUAdRequestContext {
        let coordinator = AUScreenAdCoordinator.shared
        let context = coordinator.requestLedger.forSlot(identifier)
        let active = coordinator.activeScreenAndName?.0
        if pageKey == nil || active == nil || (active as? String) == pageKey { context.register() }
        return context
    }

    @nonobjc internal func register() {
        AUScreenAdCoordinator.shared.requestLedger.reserve(self)
    }

    /// Copy the publisher's request: a later page or refresh must not mutate an in-flight request.
    @nonobjc internal func nextRequest(from template: AdManagerRequest) -> AdManagerRequest {
        let request = template.copy() as! AdManagerRequest
        let snapshot = AUScreenAdCoordinator.shared.requestLedger.nextRequest(self)
        var targeting = request.customTargeting ?? [:]
        snapshot.targeting.forEach { targeting[$0.key] = $0.value }
        request.customTargeting = targeting
        return request
    }
}

internal struct AUAdRequestSnapshot: Equatable {
    let pageSequence: Int
    let slot: Int
    let refresh: Int
    var targeting: [String: String] {
        ["au_page_seq": String(pageSequence), "au_slot": String(slot), "au_refresh": String(refresh)]
    }
}

/// Main-thread, page-local bookkeeping. Retains no view, controller, ad unit or publisher data.
internal final class AUAdRequestLedger {
    private struct Entry { let slot: Int; var requests = 0 }
    private var pageSequence = 0
    private var entries: [ObjectIdentifier: Entry] = [:]
    // Retain identities until the page ends so allocator addresses cannot be reused within a page.
    private var contexts: [ObjectIdentifier: AUAdRequestContext] = [:]
    private var bridgeSlots: [String: AUAdRequestContext] = [:]

    func beginPage(_ sequence: Int, retained: [AUAdRequestContext]) {
        pageSequence = sequence
        entries.removeAll()
        contexts.removeAll()
        bridgeSlots.removeAll()
        // Weak coordinator registries are unordered. Reserve before any recreation can request.
        for context in retained.sorted(by: { $0.registrationOrder < $1.registrationOrder }) {
            reserve(context)
        }
    }

    func reserve(_ context: AUAdRequestContext) {
        let key = ObjectIdentifier(context)
        if entries[key] == nil {
            entries[key] = Entry(slot: entries.count + 1)
            contexts[key] = context
        }
        if let identifier = context.bridgeIdentifier { bridgeSlots[identifier] = context }
    }

    func forSlot(_ identifier: String) -> AUAdRequestContext {
        if let context = bridgeSlots[identifier] { return context }
        let context = AUAdRequestContext()
        context.bridgeIdentifier = identifier
        bridgeSlots[identifier] = context
        return context
    }

    func nextRequest(_ context: AUAdRequestContext) -> AUAdRequestSnapshot {
        reserve(context)
        let key = ObjectIdentifier(context)
        let entry = entries[key]!
        entries[key]!.requests += 1
        return AUAdRequestSnapshot(pageSequence: pageSequence, slot: entry.slot, refresh: entry.requests)
    }
}
