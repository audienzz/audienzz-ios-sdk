import XCTest
import UIKit
import GoogleMobileAds
@testable import AudienzziOSSDK

/// A Prebid bid rendered through a GAM creative of another size: the 300x250 bid in a 300x600
/// creative that was left off-centre, and the reverse that was cut off. GAM's view is real; its
/// size choice is modelled by the size callbacks it would make. Time is a manual clock.
@MainActor
final class PrebidCreativeSizerTests: XCTestCase {
    private var google: AdManagerBannerView!
    private var sizer: AUPrebidCreativeSizer!
    private var reported: [CGSize] = []
    private var markupReads = 0
    private var markupAnswers: [CGSize?] = []
    private var pendingMarkupAnswer: ((CGSize?) -> Void)?
    private var answerMarkupLater = false
    private var now: TimeInterval = 0
    private var scheduled: [(at: TimeInterval, work: () -> Void)] = []

    private let small = CGSize(width: 300, height: 250)
    private let large = CGSize(width: 300, height: 600)

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            google = AdManagerBannerView(adSize: adSizeFor(cgSize: large))
            sizer = AUPrebidCreativeSizer(gamView: google)
            sizer.report = { [unowned self] in reported.append($0) }
            sizer.after = { [unowned self] delay, work in scheduled.append((now + delay, work)) }
            sizer.findSizeInMarkup = { [unowned self] _, answer in
                markupReads += 1
                if answerMarkupLater { pendingMarkupAnswer = answer; return }
                answer(markupAnswers.isEmpty ? nil : markupAnswers.removeFirst())
            }
        }
    }

    private func advance(_ seconds: TimeInterval) {
        let end = now + seconds
        while let next = scheduled.enumerated().filter({ $0.element.at <= end }).min(by: { $0.element.at < $1.element.at }) {
            scheduled.remove(at: next.offset)
            now = next.element.at
            next.element.work()
        }
        now = end
    }

    /// GAM served `size` for the current request.
    private func googleServes(_ size: CGSize) {
        google.resize(adSizeFor(cgSize: size))
        sizer.googleDidLoad(size: size)
    }

    func testAppEventThenLoadShowsThePrebidSize() {
        sizer.beginLoad(prebidSize: small)
        sizer.prebidDidRender()
        googleServes(large)
        XCTAssertEqual(reported, [small])
        XCTAssertEqual(google.adSize.size, small)
        XCTAssertEqual(markupReads, 0, "the app event settled it")
    }

    func testAppEventDuringTheMarkupReadReportsOnlyThePrebidSize() {
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        XCTAssertEqual(reported, [], "GAM's size is held back while it is unknown which one shows")
        sizer.prebidDidRender()
        XCTAssertEqual(reported, [small], "no 600 first: that was the bounce")
        XCTAssertEqual(google.adSize.size, small)
    }

    func testSizeCallbackBeforeTheLoadIsHeldToo() {
        sizer.beginLoad(prebidSize: small)
        sizer.gamSizeChanged(large)
        XCTAssertEqual(reported, [])
        googleServes(large)
        sizer.prebidDidRender()
        XCTAssertEqual(reported, [small])
    }

    func testABidLargerThanItsCreativeIsEnlargedNotCutOff() {
        google.resize(adSizeFor(cgSize: small))
        sizer.beginLoad(prebidSize: large)
        sizer.prebidDidRender()
        googleServes(small)
        XCTAssertEqual(reported, [large])
        XCTAssertEqual(google.adSize.size, large)
    }

    func testWithoutTheAppEventTheSizeIsFoundInTheMarkupOnceTheCreativeRenders() {
        markupAnswers = [nil, nil, small]
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        advance(sizer.probeRetry)
        XCTAssertEqual(reported, [])
        advance(sizer.probeRetry)
        XCTAssertEqual(reported, [small])
        XCTAssertEqual(markupReads, 3)
        advance(5)
        XCTAssertEqual(markupReads, 3, "found: no further reads")
        XCTAssertEqual(reported, [small], "and the timeout reports nothing more")
    }

    func testACreativeGamServedItselfIsReportedAtGamsSizeAfterTheTimeout() {
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        advance(sizer.probeTimeout - 0.01)
        XCTAssertEqual(reported, [])
        advance(0.02)
        XCTAssertEqual(reported, [large])
        XCTAssertEqual(google.adSize.size, large)
        let reads = markupReads
        advance(5)
        XCTAssertEqual(markupReads, reads, "no reads after the timeout")
    }

    func testAMarkupReadThatNeverAnswersCannotHoldTheSizeForever() {
        answerMarkupLater = true
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        advance(sizer.probeTimeout)
        XCTAssertEqual(reported, [large])
        pendingMarkupAnswer?(small)
        XCTAssertEqual(reported, [large], "an answer after the timeout is ignored")
    }

    func testAnAppEventAfterTheTimeoutStillCorrectsTheSize() {
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        advance(sizer.probeTimeout)
        sizer.prebidDidRender()
        XCTAssertEqual(reported, [large, small])
    }

    func testWithoutAPrebidWinGamsSizeIsReportedAtOnce() {
        sizer.beginLoad(prebidSize: nil)
        sizer.gamSizeChanged(large)
        googleServes(large)
        sizer.prebidDidRender()
        XCTAssertEqual(reported, [large, large])
        XCTAssertEqual(markupReads, 0)
        XCTAssertEqual(google.adSize.size, large)
    }

    func testTheAppEventBeforeTheLoadDoesNotResizeThePreviousCreative() {
        sizer.beginLoad(prebidSize: small)
        sizer.prebidDidRender()
        XCTAssertEqual(reported, [])
        XCTAssertEqual(google.adSize.size, large)
    }

    func testALateMarkupAnswerCannotResizeTheNextLoad() {
        answerMarkupLater = true
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        let late = pendingMarkupAnswer
        sizer.beginLoad(prebidSize: nil)
        late?(small)
        XCTAssertEqual(reported, [])
        XCTAssertEqual(google.adSize.size, large)
    }

    func testAReleasedSlotIsNotReported() {
        var current = true
        sizer.isCurrent = { current }
        markupAnswers = [small]
        answerMarkupLater = true
        sizer.beginLoad(prebidSize: small)
        googleServes(large)
        current = false
        pendingMarkupAnswer?(small)
        advance(5)
        XCTAssertEqual(reported, [])
    }

    func testHbSizeIsReadFromPrebidsCreativeMarkup() {
        let markup = #"<script>ucTagData.targetingMap = {"hb_size":["300x250"],"hb_pb":["0.50"]};</script>"#
        XCTAssertEqual(AUPrebidCreativeSizer.sizeInMarkup(markup), small)
        XCTAssertEqual(AUPrebidCreativeSizer.sizeInMarkup("var t = {'hb_size': ['320x50']};"), CGSize(width: 320, height: 50))
    }

    func testMarkupWithoutHbSizeIsNotAPrebidCreativeInlineSizesIncluded() {
        XCTAssertNil(AUPrebidCreativeSizer.sizeInMarkup(#"<div style="width:300px;height:250px;"></div>"#))
        XCTAssertNil(AUPrebidCreativeSizer.sizeInMarkup(nil))
        XCTAssertNil(AUPrebidCreativeSizer.sizeInMarkup(""))
    }
}

/// The handler drives the sizer from the GAM callbacks it installs, and the remote banner's
/// container follows what it reports.
@MainActor
final class PrebidCreativeResizeTests: AudienzzLifecycleTestCase {
    private var owner: AURemoteConfigBannerView!
    private var window: UIWindow!
    private var container: UIView!
    private var banner: AUBannerView!
    private var google: AdManagerBannerView!
    private var handler: AUBannerHandler!

    private func loadSlot(config extra: String = "") throws {
        let config = try JSONDecoder().decode(RemoteAdConfiguration.self, from: Data("""
        {"id":"resize", "config":{"adType":"banner","lazyLoad":false\(extra)},
         "gamConfig":{"adUnitPath":"/test/resize","adSizes":["300x600","300x250"]},
         "prebidConfig":{"placementId":"","adSizes":[]}}
        """.utf8))
        AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting([config])
        let host = UIViewController()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        container = UIView(frame: CGRect(x: 0, y: 100, width: 390, height: 600))
        host.view.addSubview(container)
        Audienzz.shared.pageImpression(host)
        owner = AURemoteConfigBannerView(adConfigId: "resize")
        let requested = expectation(description: "banner reaches Google")
        owner.loadGoogle = { [unowned self] view, _ in
            google = view
            requested.fulfill()
        }
        owner.load(in: container, rootViewController: host)
        banner = try XCTUnwrap(container.subviews.compactMap { $0 as? AUBannerView }.first)
        wait(for: [requested], timeout: 2)
        handler = try XCTUnwrap(banner.eventHandler)
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            owner?.destroy()
            window?.isHidden = true
            owner = nil; window = nil; container = nil; banner = nil; google = nil; handler = nil
            AudienzzRemoteConfig.shared.setAdUnitConfigsForTesting(nil)
        }
        super.tearDown()
    }

    func testAPrebidBidInALargerGamCreativeIsShownAndLaidOutAtItsOwnSize() throws {
        try loadSlot()
        // As startGoogleLoad does after a Prebid win at 300x250.
        handler.beginGoogleLoad(prebidSize: CGSize(width: 300, height: 250))
        handler.adView(google, willChangeAdSizeTo: adSizeFor(cgSize: CGSize(width: 300, height: 600)))
        handler.adView(google, didReceiveAppEvent: "Prebid", with: nil)
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertEqual(google.adSize.size, CGSize(width: 300, height: 250))
        XCTAssertEqual(banner.bounds.height, 250)
    }

    func testAGamServedCreativeKeepsGamsSize() throws {
        try loadSlot()
        handler.beginGoogleLoad(prebidSize: nil)
        handler.adView(google, didReceiveAppEvent: "Prebid", with: nil)
        handler.bannerViewDidReceiveAd(google)
        window.layoutIfNeeded()
        XCTAssertEqual(google.adSize.size, CGSize(width: 300, height: 600))
        XCTAssertEqual(banner.bounds.height, 600)
    }

    func testOnlyAPrebidWinWithTheSwitchOnIsResizedTo() throws {
        try loadSlot()
        XCTAssertTrue(banner.resizeToPrebidCreative, "on when the ad config does not say")
        banner.lastPrebidCreativeSize = CGSize(width: 300, height: 250)
        banner.prebidWinningBidder = nil
        XCTAssertNil(banner.prebidSizeToResizeTo, "hb_size without a win")
        banner.prebidWinningBidder = "nexx360"
        XCTAssertEqual(banner.prebidSizeToResizeTo, CGSize(width: 300, height: 250))
        banner.resizeToPrebidCreative = false
        XCTAssertNil(banner.prebidSizeToResizeTo)
    }

    func testTheAdConfigCanTurnItOff() throws {
        try loadSlot(config: #","resizeToPrebidCreative":false"#)
        XCTAssertFalse(banner.resizeToPrebidCreative)
    }
}
