import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

/// Gallery (ePaper) ads: slots preloaded by page distance, kept across page transitions.
@MainActor
final class AUGalleryAdsTests: AudienzzLifecycleTestCase {

    private var host: UIViewController!
    private var gallery: AUGalleryAds!
    private var owners: [String: AURemoteConfigBannerView] = [:]
    private var created: [String] = []
    private let events = Events()

    private final class Events: AUGalleryAdsDelegate {
        var created: [String] = []
        var failed: [String] = []
        func galleryAds(_ galleryAds: AUGalleryAds, didCreateAdViewFor slotKey: String) { created.append(slotKey) }
        func galleryAds(_ galleryAds: AUGalleryAds, didFailToLoadAdFor slotKey: String, error: Error?) {
            failed.append(slotKey)
        }
    }

    private static let slots = [
        AUGalleryAdSlot(slotKey: "ad-1", adConfigId: "a", pageIndex: 4),
        AUGalleryAdSlot(slotKey: "ad-2", adConfigId: "b", pageIndex: 12),
    ]

    private func config(
        _ id: String, distance: String? = nil, lazy: Bool = true, refreshOnBack: String? = nil
    ) throws -> RemoteAdConfiguration {
        let field = (distance.map { ",\"preloadDistancePages\":\($0)" } ?? "")
            + (refreshOnBack.map { ",\"refreshOnBack\":\($0)" } ?? "")
        return try JSONDecoder().decode(RemoteAdConfiguration.self, from: Data("""
        {"id":"\(id)", "config":{"adType":"banner","refreshTimeSeconds":30,"lazyLoad":\(lazy)\(field)},
         "gamConfig":{"adUnitPath":"/test/\(id)","adSizes":["300x250","300x600"]},
         "prebidConfig":{"placementId":"p-\(id)","adSizes":["300x250"]}}
        """.utf8))
    }

    private func seed(_ configs: [RemoteAdConfiguration]) {
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(configs)
    }

    private func makeGallery(_ slots: [AUGalleryAdSlot] = slots) -> AUGalleryAds {
        let gallery = AUGalleryAds(slots: slots, rootViewController: host)
        gallery.delegate = events
        gallery.makeOwner = { [unowned self] id in
            let owner = AURemoteConfigBannerView(adConfigId: id)
            owner.loadGoogle = { _, _ in }
            owners[id] = owner
            created.append(id)
            return owner
        }
        self.gallery = gallery
        return gallery
    }

    private func banner(in view: UIView?) -> AUBannerView? {
        view?.subviews.compactMap { $0 as? AUBannerView }.first
    }

    private func drainMain() {
        let done = expectation(description: "main queue")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            host = UIViewController()
            try? seed([config("a"), config("b")])
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            gallery?.destroy()
            gallery = nil; host = nil; owners = [:]; created = []
            AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil)
        }
        super.tearDown()
    }

    // MARK: - config.preloadDistancePages

    func testPreloadDistancePagesIsReadLeniently() throws {
        XCTAssertNil(try config("a").config.preloadDistancePages)
        XCTAssertEqual(try config("a", distance: "3").config.preloadDistancePages, 3)
        XCTAssertEqual(try config("a", distance: "0").config.preloadDistancePages, 0)
        XCTAssertEqual(try config("a", distance: "2.0").config.preloadDistancePages, 2)
        XCTAssertNil(try config("a", distance: "-1").config.preloadDistancePages)
        XCTAssertNil(try config("a", distance: "1.5").config.preloadDistancePages)
        XCTAssertNil(try config("a", distance: "\"2\"").config.preloadDistancePages)
        XCTAssertNil(try config("a", distance: "true").config.preloadDistancePages)
        XCTAssertNil(try config("a", distance: "null").config.preloadDistancePages)
    }

    func testRefreshOnBackIsReadLenientlyAndOffByDefault() throws {
        XCTAssertFalse(try config("a").config.refreshOnBack)
        XCTAssertFalse(try config("a", refreshOnBack: "false").config.refreshOnBack)
        XCTAssertTrue(try config("a", refreshOnBack: "true").config.refreshOnBack)
        XCTAssertFalse(try config("a", refreshOnBack: "\"true\"").config.refreshOnBack)
        XCTAssertFalse(try config("a", refreshOnBack: "null").config.refreshOnBack)
        let cached = try JSONDecoder().decode(
            RemoteAdConfiguration.self,
            from: try JSONEncoder().encode(config("a", refreshOnBack: "true"))
        )
        XCTAssertTrue(cached.config.refreshOnBack, "kept in the cache")
    }

    func testRefreshOnBackMakesAGalleryAdReloadOnReturnStillPreloadedEagerly() throws {
        seed([try config("a", lazy: true, refreshOnBack: "true"), try config("b")])
        let gallery = makeGallery()
        gallery.updatePosition(4)
        let banner = try XCTUnwrap(banner(in: gallery.adView(for: "ad-1")))
        XCTAssertFalse(banner.keepsAdAcrossPages)
        XCTAssertFalse(try XCTUnwrap(owners["a"]).resolvedLazyLoad(for: try config("a", lazy: true)))
    }

    func testPreloadDistancePagesSurvivesTheCache() throws {
        let cached = try JSONDecoder().decode(
            RemoteAdConfiguration.self,
            from: try JSONEncoder().encode(config("a", distance: "5"))
        )
        XCTAssertEqual(cached.config.preloadDistancePages, 5)
    }

    // MARK: - Preload distance

    func testNothingIsRequestedBeforeAPositionOrFarFromTheSlots() {
        let gallery = makeGallery()
        XCTAssertTrue(created.isEmpty)
        gallery.updatePosition(0)
        gallery.updatePosition(1)
        XCTAssertTrue(created.isEmpty, "page 1 is 3 pages from slot 4")
    }

    func testASlotIsRequestedOnceWithinTheDefaultDistance() {
        let gallery = makeGallery()
        gallery.updatePosition(1.9)
        XCTAssertTrue(created.isEmpty)
        gallery.updatePosition(2)
        XCTAssertEqual(created, ["a"])
        gallery.updatePosition(4)
        gallery.updatePosition(3)
        XCTAssertEqual(created, ["a"], "requested once")
        gallery.updatePosition(10)
        XCTAssertEqual(created, ["a", "b"])
    }

    func testSwipingBackwardsPreloadsToo() {
        let gallery = makeGallery()
        gallery.updatePosition(15)
        XCTAssertTrue(created.isEmpty)
        gallery.updatePosition(14)
        XCTAssertEqual(created, ["b"])
    }

    func testTheBackendDistanceIsPerPlacement() throws {
        seed([try config("a", distance: "0"), try config("b", distance: "12")])
        let gallery = makeGallery()
        gallery.updatePosition(0)
        XCTAssertEqual(created, ["b"], "b preloads on open")
        gallery.updatePosition(3.5)
        XCTAssertEqual(created, ["b"], "a only on its own page")
        gallery.updatePosition(4)
        XCTAssertEqual(created, ["b", "a"])
    }

    // MARK: - Each slot's banner

    func testASlotsBannerLoadsEagerlyKeepsItsAdAndBelongsToTheScreen() throws {
        // The ad config says lazy; gallery mode overrides it.
        let gallery = makeGallery()
        gallery.updatePosition(4)
        let banner = try XCTUnwrap(banner(in: gallery.adView(for: "ad-1")))
        XCTAssertTrue(banner.keepsAdAcrossPages)
        XCTAssertFalse(try XCTUnwrap(owners["a"]).resolvedLazyLoad(for: try config("a", lazy: true)))
        XCTAssertTrue(banner.hostScreenOverride === host)
        XCTAssertNil(gallery.adView(for: "ad-2"))
    }

    func testAnOrdinaryRemoteBannerKeepsItsLazyLoadAndPageReload() throws {
        let owner = AURemoteConfigBannerView(adConfigId: "a")
        XCTAssertTrue(owner.resolvedLazyLoad(for: try config("a", lazy: true)))
    }

    func testTheScreenCanBeAPageId() throws {
        let gallery = AUGalleryAds(slots: Self.slots, rootViewController: host, screen: "epaper#1" as NSString)
        gallery.makeOwner = { id in
            let owner = AURemoteConfigBannerView(adConfigId: id)
            owner.loadGoogle = { _, _ in }
            return owner
        }
        self.gallery = gallery
        gallery.updatePosition(4)
        let banner = try XCTUnwrap(banner(in: gallery.adView(for: "ad-1")))
        XCTAssertEqual(banner.hostScreenOverride as? String, "epaper#1")
    }

    // MARK: - Embedding

    func testEmbedMovesTheHostButNeverTheBanner() throws {
        let gallery = makeGallery()
        let first = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let second = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        XCTAssertFalse(gallery.embed("ad-1", in: first), "not in range yet")
        gallery.updatePosition(4)
        let hostView = try XCTUnwrap(gallery.adView(for: "ad-1"))
        let banner = try XCTUnwrap(banner(in: hostView))
        XCTAssertTrue(gallery.embed("ad-1", in: first))
        XCTAssertTrue(hostView.superview === first)
        XCTAssertTrue(gallery.embed("ad-1", in: first), "embedding the same page again is harmless")
        XCTAssertEqual(first.subviews.count, 1)
        XCTAssertTrue(gallery.embed("ad-1", in: second))
        XCTAssertTrue(hostView.superview === second)
        XCTAssertTrue(first.subviews.isEmpty, "taken out of the reused page")
        // Removing an AUBannerView from its superview destroys it; it must never leave its host.
        XCTAssertTrue(banner.superview === hostView)
        XCTAssertFalse(banner.refreshController.isDestroyed)
        second.layoutIfNeeded()
        XCTAssertEqual(hostView.frame.width, 390, "full width")
        XCTAssertEqual(hostView.center.y, 350, accuracy: 0.5, "centered vertically")
    }

    func testEmbeddingAReusedPageTakesOutTheOtherSlotsAd() throws {
        let gallery = makeGallery()
        let page = UIView()
        gallery.updatePosition(4)
        gallery.updatePosition(12)
        let firstBanner = try XCTUnwrap(banner(in: gallery.adView(for: "ad-1")))
        XCTAssertTrue(gallery.embed("ad-1", in: page))
        XCTAssertTrue(gallery.embed("ad-2", in: page))
        XCTAssertEqual(page.subviews.count, 1)
        XCTAssertTrue(page.subviews.first === gallery.adView(for: "ad-2"))
        XCTAssertFalse(firstBanner.refreshController.isDestroyed, "only its host left the page")
    }

    func testEmbeddingASlotWithoutAnAdStillClearsTheReusedPage() {
        let gallery = makeGallery()
        let page = UIView()
        gallery.updatePosition(4)
        XCTAssertTrue(gallery.embed("ad-1", in: page))
        XCTAssertFalse(gallery.embed("ad-2", in: page), "ad-2 is not in range yet")
        XCTAssertTrue(page.subviews.isEmpty, "ad-1 must not show as if it were ad-2")
    }

    func testTheSlotsViewIsAnnouncedOutsideTheScrollCallback() {
        let gallery = makeGallery()
        gallery.updatePosition(4)
        XCTAssertTrue(events.created.isEmpty, "not inside the caller's scroll callback")
        drainMain()
        XCTAssertEqual(events.created, ["ad-1"])
    }

    // MARK: - Failures and lifetime

    private final class GalleryScreen: UIViewController {
        var gallery: AUGalleryAds?
    }

    func testTheGalleryAndItsBannersDoNotKeepTheirScreenAlive() throws {
        weak var released: GalleryScreen?
        var banner: AUBannerView?
        autoreleasepool {
            let screen = GalleryScreen()
            let gallery = AUGalleryAds(slots: Self.slots, rootViewController: screen)
            gallery.makeOwner = { id in
                let owner = AURemoteConfigBannerView(adConfigId: id)
                owner.loadGoogle = { _, _ in }
                return owner
            }
            screen.gallery = gallery
            gallery.updatePosition(4)
            banner = self.banner(in: gallery.adView(for: "ad-1"))
            XCTAssertTrue(banner?.hostScreenOverride === screen, "owned by its screen while it lives")
            released = screen
        }
        XCTAssertNil(released, "the screen was kept alive by its own gallery")
        XCTAssertNil(banner?.hostScreenOverride)
    }

    func testAScreenGoneBeforeTheBannerIsBuiltLeavesItWithNoScreen() {
        let owner = AURemoteConfigBannerView(adConfigId: "a")
        owner.loadGoogle = { _, _ in }
        autoreleasepool {
            let screen = UIViewController()
            owner.setScreen(screen)
        }
        let container = UIView()
        owner.load(in: container, rootViewController: host, delegate: nil)
        let banner = try? XCTUnwrap(self.banner(in: container))
        XCTAssertEqual(banner?.hostScreenOverrideExpired, true,
                       "an owner that expired before the build is carried over, not dropped")
        let other = UIViewController()
        if let banner { other.view.addSubview(banner) }
        XCTAssertEqual(banner?.isHostedBy(other), false)
        owner.destroy()
    }

    func testARouteKeyScreenIsStillMatchedByValue() {
        let banner = AUBannerView(configId: "c", adSize: CGSize(width: 320, height: 50), adFormats: [.banner])
        banner.setScreen("route-1")
        XCTAssertTrue(banner.isHostedBy("route-1" as NSString))
    }

    func testAPlacementWithoutConfigFailsOnceAndLoadsWhenItsConfigArrives() throws {
        let gallery = makeGallery([AUGalleryAdSlot(slotKey: "x", adConfigId: "late", pageIndex: 4)])
        gallery.updatePosition(4)
        gallery.updatePosition(4.5)
        drainMain()
        XCTAssertTrue(created.isEmpty)
        XCTAssertEqual(events.failed, ["x"], "reported once")
        seed([try config("late")])
        gallery.updatePosition(4)
        XCTAssertEqual(created, ["late"])
    }

    func testDestroyReleasesTheAdsAndStopsRequesting() throws {
        let gallery = makeGallery()
        let page = UIView()
        gallery.updatePosition(4)
        let banner = try XCTUnwrap(banner(in: gallery.adView(for: "ad-1")))
        gallery.embed("ad-1", in: page)
        gallery.destroy()
        XCTAssertTrue(page.subviews.isEmpty)
        XCTAssertNil(gallery.adView(for: "ad-1"))
        XCTAssertTrue(banner.refreshController.isDestroyed)
        gallery.updatePosition(12)
        XCTAssertEqual(created, ["a"])
    }
}
