import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

/// Main-thread work a banner does while its page scrolls or its creative resizes (ESH report:
/// scroll stutter in a React Native app with several mounted slots).
///
/// Every slot evaluated its visibility twice per scroll frame — once for the scroll view's
/// `contentOffset` and again for its `bounds`, whose origin is the offset. And in React Native a
/// resize was laid out twice: once by the constraints this SDK put on the RN-owned container,
/// laid out through the container's superview, and again by Yoga when JS applied the new height.
@MainActor
final class ScrollCostAndHostLayoutTests: AudienzzLifecycleTestCase {

    // MARK: - One visibility evaluation per scroll frame

    private final class ProbeView: VisibleView {
        override var usesDirectionalRefreshGate: Bool { true }
        private(set) var eligible: Bool?
        override func onRefreshBecameEligible() { eligible = true }
        override func onRefreshBecameIneligible() { eligible = false }
    }

    private var window: UIWindow!

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    /// A 390x844 screen whose scroll view holds an ad at y=100 of a tall page.
    private func makeScrolledAd() -> (UIScrollView, ProbeView) {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scrollView = UIScrollView(frame: window.bounds)
        scrollView.contentSize = CGSize(width: 390, height: 5000)
        window.addSubview(scrollView)
        window.isHidden = false
        let content = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 5000))
        scrollView.addSubview(content)
        let ad = ProbeView(frame: CGRect(x: 0, y: 100, width: 320, height: 50))
        ad.prefetchMarginPoints = 0
        content.addSubview(ad)
        settle()
        return (scrollView, ad)
    }

    func testEachScrollStepEvaluatesVisibilityOnce() {
        let (scrollView, ad) = makeScrolledAd()
        let before = ad.visibilityEvaluationCount

        for step in 1...10 {
            scrollView.contentOffset = CGPoint(x: 0, y: CGFloat(step) * 3)
        }

        XCTAssertEqual(ad.visibilityEvaluationCount - before, 10,
                       "one evaluation per scroll step; the bounds origin moving with it is the same event")
    }

    func testScrollingStillUpdatesTheVerdict() {
        let (scrollView, ad) = makeScrolledAd()
        XCTAssertEqual(ad.eligible, true, "control — the ad starts on screen")

        scrollView.contentOffset = CGPoint(x: 0, y: 120)

        XCTAssertEqual(ad.eligible, false, "the ad's top edge scrolled above the viewport")
    }

    func testResizingTheScrollViewStillReevaluates() {
        let (scrollView, ad) = makeScrolledAd()
        XCTAssertEqual(ad.eligible, true)
        let before = ad.visibilityEvaluationCount

        // Shrinking the viewport so it clips the ad is a size change, not a scroll.
        scrollView.bounds = CGRect(origin: scrollView.bounds.origin, size: CGSize(width: 390, height: 110))

        XCTAssertGreaterThan(ad.visibilityEvaluationCount, before)
        XCTAssertEqual(ad.eligible, false, "the ad is now mostly clipped by its scroll view")
    }

    // MARK: - React Native owns the container's size

    private static let configJSON = """
    [{
      "id": "rn-banner",
      "config": { "adType": "banner", "refreshTimeSeconds": 30, "prefetchDistanceDp": 200 },
      "gamConfig": { "adUnitPath": "/1234/unit", "adSizes": ["320x50"] },
      "prebidConfig": { "placementId": "placement", "adSizes": ["320x50"] }
    }]
    """

    /// Counts its own layout passes: the React Native view that holds the slot.
    private final class LayoutCountingView: UIView {
        private(set) var layoutPasses = 0
        override func layoutSubviews() {
            super.layoutSubviews()
            layoutPasses += 1
        }
    }

    private var parent: LayoutCountingView!

    /// A container laid out by frame, like a React Native view, inside a plain host view.
    private func loadIntoFrameLaidOutContainer(hostSizesContainer: Bool)
        throws -> (owner: AURemoteConfigBannerView, container: UIView, banner: AUBannerView) {
        let configs = try JSONDecoder().decode([RemoteAdConfiguration].self, from: Data(Self.configJSON.utf8))
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(configs)
        let host = UIViewController()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        parent = LayoutCountingView(frame: host.view.bounds)
        host.view.addSubview(parent)
        let container = UIView(frame: CGRect(x: 0, y: 100, width: 390, height: 46))
        parent.addSubview(container)
        let owner = AURemoteConfigBannerView(adConfigId: "rn-banner")
        owner.hostSizesContainer = hostSizesContainer
        owner.load(in: container, rootViewController: host)
        let banner = try XCTUnwrap(container.subviews.compactMap { $0 as? AUBannerView }.first)
        return (owner, container, banner)
    }

    private func host(of container: UIView) -> UIView {
        window.rootViewController!.view
    }

    private func constraintsSizing(_ view: UIView) -> [NSLayoutConstraint] {
        view.constraints.filter {
            ($0.firstItem as? UIView) === view && $0.secondItem == nil
                && ($0.firstAttribute == .height || $0.firstAttribute == .width)
        }
    }

    func testAHostSizedContainerGetsNoSizeConstraints() throws {
        let (owner, container, _) = try loadIntoFrameLaidOutContainer(hostSizesContainer: true)
        defer { owner.destroy(); AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil) }

        XCTAssertEqual(constraintsSizing(container), [],
                       "the host sizes this container; a constraint would make Auto Layout size it too")
    }

    func testAHostSizedResizeLeavesTheContainerToTheHost() throws {
        let (owner, container, banner) = try loadIntoFrameLaidOutContainer(hostSizesContainer: true)
        defer { owner.destroy(); AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil) }
        var reported: [CGSize] = []
        owner.onAdSizeChanged = { reported.append($0) }
        host(of: container).layoutIfNeeded()
        let passesBefore = parent.layoutPasses

        banner.onAdSizeChanged?(CGSize(width: 300, height: 250))

        XCTAssertEqual(reported, [CGSize(width: 300, height: 250)], "the host still hears the size")
        XCTAssertEqual(banner.bounds.size, CGSize(width: 300, height: 250),
                       "the banner inside the container is laid out at once")
        XCTAssertEqual(container.frame, CGRect(x: 0, y: 100, width: 390, height: 46),
                       "the container keeps the host's frame until the host applies the size")
        XCTAssertEqual(parent.layoutPasses, passesBefore,
                       "the host's view is not laid out by us; the host lays it out when it applies the size")
    }

    func testByDefaultTheContainerStillFollowsTheAd() throws {
        let (owner, container, banner) = try loadIntoFrameLaidOutContainer(hostSizesContainer: false)
        defer { owner.destroy(); AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil) }
        XCTAssertFalse(constraintsSizing(container).isEmpty, "native hosts keep the container sized to the ad")
        host(of: container).layoutIfNeeded()

        banner.onAdSizeChanged?(CGSize(width: 300, height: 250))
        host(of: container).layoutIfNeeded()

        XCTAssertEqual(banner.bounds.size, CGSize(width: 300, height: 250))
        XCTAssertTrue(constraintsSizing(container).contains { $0.firstAttribute == .height && $0.constant == 250 })
    }

    func testSwitchingWhoSizesTheContainerIsANewLoad() throws {
        let (owner, container, first) = try loadIntoFrameLaidOutContainer(hostSizesContainer: false)
        defer { owner.destroy(); AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil) }

        owner.hostSizesContainer = true
        owner.load(in: container, rootViewController: try XCTUnwrap(window.rootViewController))

        let banners = container.subviews.compactMap { $0 as? AUBannerView }
        XCTAssertEqual(banners.count, 1)
        XCTAssertFalse(banners.first === first, "the banner was built under the other constraints")
        XCTAssertEqual(constraintsSizing(container), [])
    }
}
