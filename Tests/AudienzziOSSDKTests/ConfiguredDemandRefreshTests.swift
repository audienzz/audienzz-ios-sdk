import XCTest
import PrebidMobile
@testable import AudienzziOSSDK

final class ConfiguredDemandRefreshTests: XCTestCase {
    final class Clock: AURefreshScheduler {
        var time: TimeInterval = 0
        var action: (() -> Void)?
        var due: TimeInterval = 0
        func now() -> TimeInterval { time }
        func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
            self.action = action; due = time + delay
        }
        func cancel() { action = nil }
        func advance(_ seconds: TimeInterval) {
            time += seconds
            if let run = action, due <= time { action = nil; run() }
        }
    }
    var view: AUAdView!
    var owner: AUConfiguredDemandRefresh!
    var configuration: AUAdUnitConfiguration!
    var clock: Clock!
    var window: UIWindow!
    var requests = 0

    override func setUp() {
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        Audienzz.shared.pageImpression("configured")
        view = AUAdView(configId: "", isLazyLoad: false)
        configuration = AUAdUnitConfiguration(adUnit: NativeRequest(configId: ""))
        clock = Clock()
        owner = AUConfiguredDemandRefresh(view: view, configuration: configuration, scheduler: clock)
        view.configuredDemandRefresh = owner
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(view)
    }
    override func tearDown() {
        owner.destroy()
        window = nil; view = nil; owner = nil
    }
    func load() {
        guard let generation = owner.begin({ [weak self] in self?.load() }) else { return }
        requests += 1
        XCTAssertTrue(owner.finish(generation))
    }
    func testConfiguredCadenceAndLiveDisableReachScheduler() {
        configuration.setAutoRefreshMillis(time: 30_000)
        load()
        clock.advance(30)
        XCTAssertEqual(requests, 2)
        configuration.setAutoRefreshMillis(time: 0)
        clock.advance(300)
        XCTAssertEqual(requests, 2)
    }
    func testPublisherPauseSurvivesPageAndViewportRecovery() {
        view.smartRefresh = true
        configuration.setAutoRefreshMillis(time: 30_000)
        load()
        configuration.stopAutoRefresh()
        owner.viewport(visible: false)
        owner.viewport(visible: true)
        Audienzz.shared.pageImpression("configured")
        clock.advance(100)
        XCTAssertEqual(requests, 1)
        configuration.resumeAutoRefresh()
        XCTAssertEqual(requests, 2)
    }
    func testOtherPageStopsDemandAndReturningRestartsOnce() {
        configuration.setAutoRefreshMillis(time: 30_000)
        load()
        Audienzz.shared.pageImpression("other")
        clock.advance(100)
        XCTAssertEqual(requests, 1)
        Audienzz.shared.pageImpression("configured")
        XCTAssertEqual(requests, 2)
    }
    func testSupersededDemandCannotDeliverOrCompleteAReplacement() {
        let old = owner.begin({})!
        owner.background()
        owner.foreground()
        let replacement = owner.begin({})!
        XCTAssertFalse(owner.finish(old))
        XCTAssertTrue(owner.controller.hasRequestInFlight)
        XCTAssertTrue(owner.finish(replacement))
    }
    func testConstructionBeforeAnyPageBindsFirstReportAndCanLeaveAndReturn() {
        owner.destroy()
        let coordinator = AUScreenAdCoordinator()
        XCTAssertNil(coordinator.activeScreenAndName)
        owner = AUConfiguredDemandRefresh(view: view, configuration: configuration, scheduler: clock, coordinator: coordinator)
        view.configuredDemandRefresh = owner
        owner.attachmentChanged()
        configuration.setAutoRefreshMillis(time: 30_000)
        load()
        XCTAssertEqual(requests, 1)
        coordinator.onScreenResumed("first" as NSString, name: "first")
        XCTAssertEqual(requests, 2)
        clock.advance(30)
        XCTAssertEqual(requests, 3)
        coordinator.onScreenResumed("other" as NSString, name: "other")
        clock.advance(60)
        XCTAssertEqual(requests, 3)
        coordinator.onScreenResumed("first" as NSString, name: "first")
        XCTAssertEqual(requests, 4)
    }

    func testUnscopedNativeViewAdoptsOnlyItsActualController() {
        owner.destroy()
        let coordinator = AUScreenAdCoordinator()
        owner = AUConfiguredDemandRefresh(view: view, configuration: configuration, scheduler: clock, coordinator: coordinator)
        view.configuredDemandRefresh = owner
        let own = UIViewController(); let other = UIViewController()
        window.addSubview(own.view)
        own.view.addSubview(view)
        load()
        XCTAssertEqual(requests, 1)
        coordinator.onScreenResumed(other, name: "other")
        clock.advance(30)
        XCTAssertEqual(requests, 1)
        coordinator.onScreenResumed(own, name: "own")
        owner.attachmentChanged()
        XCTAssertEqual(requests, 2)
    }

}
