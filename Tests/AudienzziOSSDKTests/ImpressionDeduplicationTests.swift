import XCTest
import GoogleMobileAds
@testable import AudienzziOSSDK

private final class FixturePaidValue: AdValue {
    override var value: NSDecimalNumber { NSDecimalNumber(string: "0.0025") }
    override var currencyCode: String { "CHF" }
}

@MainActor
final class ImpressionDeduplicationTests: AudienzzLifecycleTestCase {
    func testInstalledDelegateReportsOneImpressionPerCreativeAcrossReplacement() {
        Audienzz.shared.pageImpression("A")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let banner = AUBannerView(configId: "fixture", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: false)
        banner.setScreen("A")
        banner.frame = CGRect(x: 0, y: 100, width: 320, height: 50)
        window.addSubview(banner)
        let google = AdManagerBannerView(adSize: AdSizeBanner)
        google.adUnitID = "/fixture/banner"
        var handoffs = 0
        banner.demand = { _, _, complete in complete(.prebidDemandNoBids) }
        banner.onLoadRequest = { _ in handoffs += 1 } // Google is a fake terminal callback below.
        var impressions: [AUEventDomain] = []
        AUEventsManager.shared.observerForTesting = { if $0.type == .adImpression { impressions.append($0) } }
        defer { banner.destroy(); AUEventsManager.shared.observerForTesting = nil }
        banner.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(handoffs, 1)
        let firstAuction = banner.currentAuctionId
        XCTAssertNotNil(firstAuction)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.paidEventHandler?(FixturePaidValue())
        for _ in 0..<5 { google.delegate?.bannerViewDidRecordImpression?(google) }
        XCTAssertEqual(impressions.count, 1)
        XCTAssertEqual(impressions.first?.auctionId, firstAuction)
        XCTAssertEqual(impressions.first?.cpm, 2.5, "Google reports per-impression revenue, not CPM")
        XCTAssertEqual(impressions.first?.currency, "CHF")
        XCTAssertEqual(impressions.first?.cpmSource, "google_paid")
        banner.reloadAd()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(handoffs, 2)
        // Starting an auction alone must not reopen the displayed creative's impression.
        google.delegate?.bannerViewDidRecordImpression?(google)
        XCTAssertEqual(impressions.count, 1)
        google.delegate?.bannerViewDidReceiveAd?(google)
        google.delegate?.bannerViewDidRecordImpression?(google)
        XCTAssertEqual(impressions.count, 2)
        XCTAssertEqual(impressions.last?.auctionId, banner.currentAuctionId)
        XCTAssertNotEqual(impressions.last?.auctionId, firstAuction)
    }

    func testStockPrebidReportsTheBucketWithoutInventingExactEconomics() {
        Audienzz.shared.pageImpression("A")
        let banner = AUBannerView(configId: "fixture", adSize: CGSize(width: 320, height: 50), adFormats: [.banner], isLazyLoad: false)
        banner.setScreen("A")
        banner.demand = { _, request, complete in
            request.customTargeting = ["hb_bidder": "seat-A", "hb_pb": "1.42"]
            complete(.prebidDemandFetchSuccess)
        }
        var wins: [AUEventDomain] = []
        AUEventsManager.shared.observerForTesting = { if $0.type == .bidWon { wins.append($0) } }
        defer { banner.destroy(); AUEventsManager.shared.observerForTesting = nil }
        banner.onLoadRequest = { _ in } // No live Google request.
        let google = AdManagerBannerView(adSize: AdSizeBanner)
        google.adUnitID = "/fixture/banner"
        banner.createAd(with: AdManagerRequest(), gamBanner: google)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(wins.count, 1)
        XCTAssertEqual(wins.first?.priceBucket, "1.42")
        XCTAssertEqual(wins.first?.bidderCode, "seat-A")
        XCTAssertNil(wins.first?.cpm)
        XCTAssertNil(wins.first?.currency)
        XCTAssertNil(wins.first?.creativeId)
        XCTAssertNil(wins.first?.adId)
    }

    func testResponseIdentityDeduplicatesDuplicateLoadCallbacksButAllowsANewCreative() {
        let banner = AUBannerView(configId: "fixture", adSize: CGSize(width: 320, height: 50), adFormats: [.banner])
        banner.commitDisplayedCreative()
        XCTAssertTrue(banner.claimDisplayedImpression(responseId: "A"))
        banner.commitDisplayedCreative()
        XCTAssertFalse(banner.claimDisplayedImpression(responseId: "A"))
        XCTAssertTrue(banner.claimDisplayedImpression(responseId: "B"))
        XCTAssertFalse(banner.claimDisplayedImpression(responseId: "B"))
    }
}
