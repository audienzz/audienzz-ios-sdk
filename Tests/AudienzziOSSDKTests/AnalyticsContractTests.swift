import XCTest
@testable import AudienzziOSSDK

/// The analytics contract, asserted on the SERIALIZED payload rather than on the domain object.
///
/// Every question analytics asked was about what arrives at the collector — a type, a unit, a
/// present-or-absent key. A test that stops at `AUEventDomain` cannot answer any of them: it would
/// pass with the field renamed, retyped, or dropped by the encoder's `encodeIfPresent`.
final class AnalyticsContractTests: AudienzzLifecycleTestCase {

    private let mapper = AUEventNetworkMapper()

    /// The flat JSON that is actually POSTed, via the same encoder path the manager uses.
    private func payload(_ event: AUEventDomain) throws -> [String: Any] {
        let network = mapper.toNetwork(event)
        let data = try JSONEncoder().encode(network)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func attributes(_ event: AUEventDomain) throws -> [String: String] {
        try XCTUnwrap(try payload(event)["attributes"] as? [String: String])
    }

    private func adEvent(slotReload: Int?) -> AUEventDomain {
        var e = AUEventDomain(type: .bidResponse)
        e.adUnitId = "/1234/unit"
        e.adViewId = "placement"
        e.adType = AUAdType.banner
        e.adSubtype = AUAdSubtype.html
        e.apiType = AUEventApiType.original
        e.auctionId = "auction-1"
        e.slotReload = slotReload
        e.sessionStartTimestamp = 1_789_978_756
        return e
    }

    // MARK: - slot_reload

    func testSlotReloadSerializesAsAStringLikeTheOtherAttributes() throws {
        // `attributes` is [String: String] by construction; decoding it as such is the assertion —
        // a numeric slot_reload would fail the cast for the whole map.
        let attributes = try attributes(adEvent(slotReload: 0))
        XCTAssertEqual(attributes["slot_reload"], "0")
    }

    func testSlotReloadIsBinaryAndNeverExceedsOne() throws {
        for emitted in [0, 1] {
            XCTAssertEqual(try attributes(adEvent(slotReload: emitted))["slot_reload"], String(emitted))
        }
    }

    /// The counter may keep climbing; what is REPORTED may not. Third load still emits "1".
    func testTheBannerReportsABinaryFlagHoweverManyTimesItReloaded() {
        let banner = AUBannerView(configId: "probe", adSize: CGSize(width: 300, height: 250), adFormats: [.banner])
        XCTAssertEqual(banner.emittedSlotReload, 0, "first load")
        banner.slotReloadCount = 1
        XCTAssertEqual(banner.emittedSlotReload, 1)
        banner.slotReloadCount = 7
        XCTAssertEqual(banner.emittedSlotReload, 1, "a slot that reloaded seven times is still just 'not the first load'")
    }

    // MARK: - session_start_timestamp

    func testSessionStartTimestampIsUnixSeconds() throws {
        // Through the manager, which is what chooses the unit: the mapper passes through whatever
        // it is handed, so a millisecond value would sail past a mapper-only assertion.
        let manager = AUEventsManager.shared
        let value = manager.sessionStartTimestampForTesting
        XCTAssertTrue((1_000_000_000...9_999_999_999).contains(value),
                      "expected Unix seconds, got \(value)")
    }

    func testDurationsStayInMilliseconds() throws {
        var e = adEvent(slotReload: 0)
        e.timeToRespond = 146
        e.autorefreshTime = 30_000
        let attributes = try attributes(e)
        XCTAssertEqual(attributes["time_to_respond"], "146")
        XCTAssertEqual(attributes["autorefresh_time"], "30000")
    }

    // MARK: - device_id

    func testDeviceIdIsOmittedEntirelyWhenUnavailable() throws {
        var e = adEvent(slotReload: 0)
        e.deviceId = nil
        let json = try payload(e)
        XCTAssertNil(json["device_id"],
                     "an absent identity must be an absent key, not an empty or placeholder value")
    }

    func testTheAllZeroIDFAIsNotAnIdentity() {
        // What ATT returns when tracking is not authorized, and what the simulator returns by
        // default. It is a sentinel, not a device.
        XCTAssertNil(AUEventsManager.usableDeviceId("00000000-0000-0000-0000-000000000000"))
        XCTAssertNil(AUEventsManager.usableDeviceId(""))
        XCTAssertNil(AUEventsManager.usableDeviceId(nil))
        XCTAssertEqual(AUEventsManager.usableDeviceId("AB12CD34-0000-1111-2222-333344445555"),
                       "ab12cd34-0000-1111-2222-333344445555")
    }

    // MARK: - noBid

    func testANoBidCarriesNoBidderCodeAtAll() throws {
        var e = AUEventDomain(type: .noBid)
        e.adUnitId = "/1234/unit"
        e.adViewId = "placement"
        e.adType = AUAdType.banner
        e.adSubtype = AUAdSubtype.html
        e.apiType = AUEventApiType.original
        e.auctionId = "auction-1"
        e.resultCode = "NO_BIDS"
        e.slotReload = 1
        let attributes = try attributes(e)
        XCTAssertNil(attributes["bidder_code"],
                     "a no-bid is auction-level: it cannot name a bidder, and must not invent one")
        XCTAssertNil(attributes["winner_bidder_code"])
        XCTAssertEqual(attributes["result_code"], "NO_BIDS")
        // It still belongs to its auction and still says whether this was a first load.
        XCTAssertEqual(attributes["auction_id"], "auction-1")
        XCTAssertEqual(attributes["slot_reload"], "1")
    }

    // MARK: - auction identity across a replacement

    /// The creative on screen keeps its own identity while a replacement is pending, arrives, or
    /// fails. Before this, render events read the newest auction, so a late impression or
    /// viewability callback for the visible creative was filed under the replacement.
    func testDisplayedCreativeKeepsItsIdentityWhileAReplacementIsPending() {
        let banner = AUBannerView(configId: "probe", adSize: CGSize(width: 300, height: 250), adFormats: [.banner])

        // Auction A responds and its creative renders.
        banner.currentAuctionId = "auction-A"
        banner.lastRenderEconomics = AURenderEconomics(
            bidderCode: "seatA", cpm: 1.42, creativeId: "crA", auctionId: "auction-A", slotReload: 0)
        banner.prebidWinningBidder = "seatA"
        banner.prebidLineItemWon = true
        banner.commitDisplayedCreative()
        XCTAssertEqual(banner.resolvedRenderEconomics().auctionId, "auction-A")
        XCTAssertEqual(banner.resolvedRenderEconomics().bidderCode, "seatA")

        // Replacement B starts: a new auction id, and the live per-auction state is reset.
        banner.currentAuctionId = "auction-B"
        banner.prebidWinningBidder = nil
        banner.prebidLineItemWon = false
        banner.slotReloadCount = 1

        // A late callback from the creative that is STILL on screen.
        let late = banner.resolvedRenderEconomics()
        XCTAssertEqual(late.auctionId, "auction-A", "a late event must not inherit the replacement's id")
        XCTAssertEqual(late.bidderCode, "seatA", "nor its attribution")
        XCTAssertEqual(late.cpm, 1.42)
        XCTAssertEqual(late.slotReload, 0, "nor its reload flag")

        // B's Prebid response lands. Still nothing on screen has changed.
        banner.lastRenderEconomics = AURenderEconomics(
            bidderCode: "seatB", cpm: 9.99, creativeId: "crB", auctionId: "auction-B", slotReload: 1)
        banner.prebidWinningBidder = "seatB"
        XCTAssertEqual(banner.resolvedRenderEconomics().auctionId, "auction-A")
        XCTAssertEqual(banner.resolvedRenderEconomics().cpm, 1.42)

        // Only when Google confirms B's creative does the identity move.
        banner.prebidLineItemWon = true
        banner.commitDisplayedCreative()
        let now = banner.resolvedRenderEconomics()
        XCTAssertEqual(now.auctionId, "auction-B")
        XCTAssertEqual(now.bidderCode, "seatB")
        XCTAssertEqual(now.slotReload, 1)
    }

    /// A replacement that fails must leave the visible creative's reporting untouched.
    func testAFailedReplacementDoesNotRewriteTheVisibleCreative() {
        let banner = AUBannerView(configId: "probe", adSize: CGSize(width: 300, height: 250), adFormats: [.banner])
        banner.currentAuctionId = "auction-A"
        banner.lastRenderEconomics = AURenderEconomics(
            bidderCode: "seatA", cpm: 1.42, creativeId: "crA", auctionId: "auction-A", slotReload: 0)
        banner.prebidWinningBidder = "seatA"
        banner.prebidLineItemWon = true
        banner.commitDisplayedCreative()

        // B starts and returns nothing usable: the no-bid path clears the live economics.
        banner.currentAuctionId = "auction-B"
        banner.lastRenderEconomics = nil
        banner.prebidWinningBidder = nil
        banner.prebidLineItemWon = false

        let stillOnScreen = banner.resolvedRenderEconomics()
        XCTAssertEqual(stillOnScreen.auctionId, "auction-A")
        XCTAssertEqual(stillOnScreen.bidderCode, "seatA")
        XCTAssertEqual(stillOnScreen.cpm, 1.42)
    }
}
