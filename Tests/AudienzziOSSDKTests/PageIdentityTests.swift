import XCTest
import UIKit
@testable import AudienzziOSSDK

/// A screen name is not an identity. Two article routes are both called "article"; their banners
/// must still belong to different pages, or the second article's page impression recreates the
/// first article's banners instead of releasing them.
@MainActor
final class PageIdentityTests: AudienzzLifecycleTestCase {

    private var host: UIViewController!
    private var container: UIView!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            host = UIViewController()
            container = UIView()
            host.view.addSubview(container)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.isHidden = false
        }
    }

    private func banner(page: String) -> AUBannerView {
        let view = AUBannerView(configId: "probe", adSize: CGSize(width: 320, height: 50),
                                adFormats: [.banner], isLazyLoad: false)
        view.hostScreenOverride = page as NSString
        container.addSubview(view)
        AUScreenAdCoordinator.shared.register(view)
        return view
    }

    func testTwoPagesSharingAScreenNameOwnTheirOwnBanners() {
        Audienzz.shared.pageImpression(pageId: "article#1", name: "article")
        let first = banner(page: "article#1")
        first.screenActive = true

        Audienzz.shared.pageImpression(pageId: "article#2", name: "article")
        let second = banner(page: "article#2")

        XCTAssertFalse(first.screenActive,
                       "the first article must be released when the second one opens")
        XCTAssertTrue(AUScreenAdCoordinator.shared.isActiveScreen(for: second))
    }

    func testReportingTheNameAsIdentityCannotSeparateThem() {
        // Documents exactly what the separate id buys: with the name used as the token, the two
        // pages are indistinguishable and the first page's banner stays active.
        Audienzz.shared.pageImpression("article")
        let first = banner(page: "article")
        first.screenActive = true

        Audienzz.shared.pageImpression("article")
        XCTAssertTrue(first.screenActive,
                      "name-as-identity cannot tell two article screens apart — this is the bug")
    }

    func testTheReportedNameIsStillWhatAnalyticsSees() {
        Audienzz.shared.pageImpression(pageId: "article#7", name: "article")
        let (screen, name) = try! XCTUnwrap(AUScreenAdCoordinator.shared.activeScreenAndName)
        XCTAssertEqual(name, "article", "analytics keeps the human name")
        XCTAssertEqual(screen as? NSString, "article#7", "ownership uses the instance id")
    }

    func testANewVisitToTheSamePageIdStillCountsAsATransition() {
        Audienzz.shared.pageImpression(pageId: "article#1", name: "article")
        let epochAfterFirst = AUScreenAdCoordinator.shared.epoch
        Audienzz.shared.pageImpression(pageId: "article#1", name: "article")
        XCTAssertEqual(AUScreenAdCoordinator.shared.epoch, epochAfterFirst + 1,
                       "returning to the same page is a new visit, not a no-op")
    }
}
