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

import ObjectiveC.runtime
@_spi(PBMInternal) import PrebidMobile
import UIKit
import GoogleMobileAds

private let adTypeString = "BANNER"
private let apiTypeString = "ORIGINAL"

@objc
extension AUBannerView {

    /// Primary lazy-load trigger: fires `prefetchMarginPoints` pt before the view enters the
    /// viewport so the Prebid demand fetch completes by the time the ad is visible.
    override func onEnteredPrefetchZone() {
        // A banner whose page has been released must not load, even if it scrolls into range —
        // its screen is no longer the one the user is on.
        guard screenActive else { return }
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest as? AdManagerRequest else {
            return
        }
        #if DEBUG
        AULogEvent.logDebug("[AUBannerView] entered prefetch zone (\(Int(prefetchMarginPoints))pt margin), starting fetchDemand")
        #endif
        isLazyLoaded = fetchRequest(request, reason: .firstLoad)
    }

    /// Safety fallback: fires when the view is exactly on screen.
    /// In normal operation `isLazyLoaded` is already `true` at this point (set by
    /// `onEnteredPrefetchZone`), so this is a no-op. It only triggers a load if the prefetch
    /// zone somehow never fired (e.g. `prefetchMarginPoints = 0` with no scroll event).
    override func detectVisible() {
        guard screenActive else { return }
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest as? AdManagerRequest else {
            return
        }
        #if DEBUG
        AULogEvent.logDebug("[AUBannerView] became visible (prefetch zone not reached), starting fetchDemand")
        #endif
        isLazyLoaded = fetchRequest(request, reason: .firstLoad)
    }

    override func onBecameVisible() {
        // ≥20% visible only drives the lazy-load fallback; smart refresh is gated by the
        // stricter eligibility rule via onRefreshBecameEligible()/onRefreshBecameIneligible().
        super.onBecameVisible() // triggers lazy load via detectVisible()
    }

    /// Smart-refresh RESUME. Fires when the ad enters the eligible zone (top edge fully on
    /// screen AND ≤50% off the bottom). Gates refreshes only — the first load happens earlier
    /// via the prefetch / ≥20% path, so this never triggers the initial fetch.
    override func onRefreshBecameEligible() {
        guard smartRefresh else { return }
        clearViewportBlock()
    }

    /// Smart-refresh PAUSE. Fires when the ad leaves the eligible zone (top edge clipped by
    /// ≥1pt, or >50% off the bottom).
    override func onRefreshBecameIneligible() {
        guard smartRefresh else { return }
        refreshController.block(.notVisible)
    }

    // MARK: - Public smart-refresh API (Flutter / external callers)

    /// Viewport resume, for view layers that do their own visibility detection (Flutter, React
    /// Native) and cannot rely on the `UIScrollView` KVO in ``VisibleView``.
    ///
    /// Clears **only** the visibility reason. A publisher pause or a released page is a separate,
    /// durable reason and stays in force, so scrolling a released banner back into view cannot
    /// revive it. The timing itself belongs to ``AURefreshController``: an overdue banner refreshes
    /// at once and an in-date one waits out the remainder of its interval.
    ///
    /// Mirrors Android's `AudienzzAdViewHandler.resumeSmartRefresh()`.
    public func resumeSmartRefresh() {
        refreshController.unblock(.hostReportedHidden, schedule: false)
        resumeEligibleWork()
    }

    /// Viewport pause: this banner is off screen, so a refresh into it would be an impression-less
    /// request. Mirrors Android's `AudienzzAdViewHandler.pauseSmartRefresh()`.
    public func pauseSmartRefresh() {
        refreshController.block(.hostReportedHidden)
    }

    /// Shared by the viewport gate and its external equivalent.
    private func clearViewportBlock() {
        refreshController.unblock(.notVisible, schedule: false)
        resumeEligibleWork()
    }

    /// Give a never-loaded banner its first load back, honouring the lazy settings. A lazy banner
    /// only loads if it is actually on screen now; otherwise its trigger is simply re-armed.
    func rearmInitialLoad() {
        guard lastRefreshTime == nil, !refreshController.hasRequestInFlight,
              let request = gamRequest as? AdManagerRequest else { return }
        if isLazyLoad {
            isLazyLoaded = false
            loadIfAlreadyVisible()
        } else {
            fetchRequest(request, reason: .firstLoad)
        }
    }

    // MARK: - Page transitions

    /// Retire the outstanding auction and any scheduled work, WITHOUT recording a block reason.
    ///
    /// Whether refresh is allowed afterwards is the caller's decision: a page release blocks
    /// `.pageInactive`, backgrounding blocks `.appBackground`, and a page activation blocks nothing.
    /// Routing this through `pauseSmartRefresh()` — as an earlier revision did — left the banner
    /// blocked on a visibility reason that nothing would ever clear.
    private func retireCurrentAuction() {
        // Bump first so an auction already in flight is recognised as stale by its completion.
        auctionGeneration += 1
        refreshController.invalidatePending()
        pendingLoadReason = nil
    }

    /// Page release: the ad's screen is no longer the active page, so stop everything. The slot is
    /// left dormant — no auctions, no GAM loads — until its page comes back and `recreateForPage()`
    /// runs. `screenActive` (set by the coordinator) and the `.pageInactive` block are what keep the
    /// viewport gate from resuming it in the meantime.
    func releaseForPage() {
        creativePageGeneration += 1
        refreshController.block(.pageInactive)
        retireCurrentAuction()
        // The creative is retired here, so blank it here too. Blanking only once the replacement
        // auction starts meant the outgoing creative was still on screen when the page came back —
        // the user saw the *previous* ad, then a blank, then the new one. Clearing it on the way out
        // means the slot is already empty on the way in.
        blankForReloadIfNeeded()
    }

    /// Page (re)activation: this ad's screen is the incoming page, so serve a fresh creative.
    /// Unlike a viewport resume (stale-aware), this always forces a new auction when the ad has
    /// loaded before — that is the "new page impression → fresh ad" semantics, and it's what makes a
    /// back-navigation or a return from the background show a current creative rather than a stale
    /// one. A never-loaded banner is left for its normal lazy/prefetch first load.
    func recreateForPage() {
        // A hard transition supersedes the outgoing auction even when the SAME page is re-reported,
        // so a response from the previous visit can't load a creative or overwrite this visit's
        // auction analytics.
        retireCurrentAuction()
        // A live page is not an inactive one, and returning to the foreground is what this
        // transition represents. The viewport and publisher reasons are deliberately untouched: a
        // page impression does not make an off-screen banner visible, nor undo a publisher pause.
        refreshController.unblock(.pageInactive, schedule: false)
        if !Audienzz.shared.isAppBackgrounded {
            refreshController.unblock(.appBackground, schedule: false)
        }
        // A hold recorded from a verdict that has since stopped being true must not outlive the
        // transition: the automatic foreground impression owns recovery and returns early from
        // `resumeAfterForeground`, so this is the only path left that can release it. Recomputing
        // rather than unblocking directly is what keeps the cached verdict and the hold in step —
        // and it can only ever clear `.notVisible`, never a host-reported pause the SDK cannot
        // see behind.
        refreshVisibilityNow()
        guard let request = gamRequest as? AdManagerRequest else { return }
        guard lastRefreshTime != nil else {
            // Never loaded: this banner's first load was deferred because its page wasn't active
            // (or its lazy trigger was consumed while released). Activation is its only remaining
            // chance — without this the slot stays blank forever.
            AULogEvent.logDebug("[AUBannerView] \(configId) — activating a never-loaded banner, starting first load")
            rearmInitialLoad()
            return
        }
        // Usually already blank from `releaseForPage`; this covers a page re-reported without an
        // intervening release.
        blankForReloadIfNeeded()
        if !fetchRequest(request, reason: .pageImpression) {
            // No replacement is coming, so showing the previous creative beats an empty slot that
            // nothing will ever fill.
            restoreFromBlankIfNeeded()
        }
    }

    /// Force a fresh auction now, ignoring the stale-aware timing of the viewport resume.
    ///
    /// Public entry point for a manual reload — e.g. the React Native / Flutter bridges reloading a
    /// banner when its screen (route/tab) becomes active again, or a publisher triggering a refresh
    /// on demand. Unlike `recreateForPage()` (driven by the page coordinator), this
    /// works for any banner that has completed its initial setup. No-op before the first `createAd`.
    public func reloadAd() {
        // Never re-auction a banner the page sweep has released — the bridges broadcast reloads,
        // and without this a released banner on a kept-mounted route would come back to life.
        guard screenActive else { return }
        guard let request = gamRequest as? AdManagerRequest else { return }
        // This reload owns the replacement, so a pending periodic refresh or retry is retired rather
        // than allowed to issue a second one for the same transition.
        retireCurrentAuction()
        blankForReloadIfNeeded()
        if !fetchRequest(request, reason: .pageImpression) {
            restoreFromBlankIfNeeded()
        }
    }

    /// Hide the current creative while its replacement is on the way, keeping the slot's size (the
    /// container view keeps its frame).
    ///
    /// Hides the GAM view *inside* the container rather than the container itself: the visibility
    /// gate measures this view's own `isHidden`/`alpha` and geometry, so blanking the container
    /// would make the slot ineligible for the very auction that is meant to refill it.
    func blankForReloadIfNeeded() {
        guard Audienzz.shared.blankOnScreenReload, !blankedForReload else { return }
        guard let gamView = eventHandler?.gamView, !gamView.isHidden else { return }
        gamView.isHidden = true
        blankedForReload = true
    }

    /// Reveal a creative hidden by `blankForReloadIfNeeded`. No-op unless this slot blanked itself.
    func restoreFromBlankIfNeeded() {
        guard blankedForReload else { return }
        blankedForReload = false
        eventHandler?.gamView?.isHidden = false
    }

    // MARK: - App lifecycle

    /// The app went to the background. A main-run-loop timer cannot fire while backgrounded, but an
    /// auction already in flight still delivers, and a request issued in the last moments before
    /// backgrounding produces a creative nobody can see.
    func blockForBackground() {
        refreshController.block(.appBackground)
        retireCurrentAuction()
    }

    /// The app came back to the foreground with no page impression to own the recovery.
    ///
    /// A page-scoped app gets a foreground page impression instead, and that impression recreates
    /// every banner on the active page — doing both is how a single return used to produce two
    /// auctions. An app that never calls `pageImpression` has no such transition, so this restores
    /// its refresh directly; otherwise backgrounding once would silently kill refresh for the rest
    /// of the process.
    func resumeAfterForeground() {
        guard !Audienzz.shared.hasPendingForegroundReimpression else { return }
        // Re-sync the cached verdict here as well as at request time. If the request-time gate held
        // a refresh because of a signal nothing observed, the block is cleared by whichever
        // recovery event comes next rather than waiting for a visibility event that may not exist.
        refreshVisibilityNow()
        refreshController.unblock(.appBackground, schedule: false)
        resumeEligibleWork()
    }

    /// Attach state. A detached view cannot render, so a refresh into it would be an
    /// impression-less request; re-attaching clears only this reason.
    func onAttachedToWindow() {
        refreshVisibilityNow()
        refreshController.unblock(.detached, schedule: false)
        resumeEligibleWork()
    }

    func onDetachedFromWindow() {
        refreshController.block(.detached)
    }

    /// The one place an auction can start. Every entry point — first load, prefetch, viewport
    /// resume, page activation, manual reload, periodic refresh — funnels through `fetchRequest`, so
    /// this is the single gate deciding whether auctioning is legitimate right now. Guarding the
    /// call sites individually is what let earlier revisions leak an auction through whichever path
    /// was missed.
    @nonobjc func canStartAuction(_ reason: AURefreshRequestReason = .firstLoad) -> Bool {
        guard !refreshController.isDestroyed, screenActive, !Audienzz.shared.isAppBackgrounded,
              !Audienzz.shared.hasPendingForegroundReimpression else { return false }
        // Prebid gets its account id only once the publisher config has been fetched, and the
        // remote flow awaits that. An above-the-fold banner fires its first load immediately, so it
        // routinely wins that race — and Prebid then answers `.prebidInvalidAccountId` while the
        // SDK goes on to load GAM, filling the slot with no header-bidding demand behind it. The
        // ad is not lost (unlike Android, where Prebid never calls back at all), but the most
        // valuable impression of the session is. Deferring records the pending reason; configuring
        // Prebid resumes it.
        guard Audienzz.shared.isPrebidConfigured else {
            AULogEvent.logDebug(
                "[AUBannerView] \(configId) — Prebid not configured yet, deferring \(reason.rawValue)")
            return false
        }
        // Prefetch may precede attachment and periodic-refresh visibility. Other gates still apply.
        return !refreshController.blockReasons.contains {
            // A first load may prefetch before the ad is visible or attached. The host-reported
            // reason is exempt on the same terms as the native one: they are two ways of saying
            // the same thing, and splitting them must not quietly change when a Flutter or React
            // Native banner takes its first load.
            reason != .firstLoad
                || ($0 != .detached && $0 != .notVisible && $0 != .hostReportedHidden)
        }
    }

    func resumeEligibleWork() {
        guard !refreshController.isDestroyed, screenActive else { return }
        if pendingLoadReason == .firstLoad || lastRefreshTime == nil {
            rearmInitialLoad()
        } else if let reason = pendingLoadReason, let request = gamRequest as? AdManagerRequest {
            fetchRequest(request, reason: reason)
        } else {
            refreshController.scheduleNext()
        }
    }

    /// Serialize Google loads until a terminal callback or watchdog expiry. Google callbacks have
    /// no request ID: after an expiry, a very late result cannot be distinguished from a newer one.
    /// Unsolicited terminal events belong to the view and must still reach its publisher.
    @nonobjc @discardableResult
    func completeGoogleLoad(received: Bool, retryableFailure: Bool) -> Bool {
        guard let load = googleLoad else { return acceptsGoogleEvents }
        googleLoadTimeout?.cancel()
        googleLoadTimeout = nil
        googleLoad = nil
        let current = load.auction == auctionGeneration && screenActive && !refreshController.isDestroyed
        if current {
            // Only a creative Google actually returned becomes the one on screen. A failed
            // replacement leaves the previous creative displayed, so promoting on every terminal
            // callback attributed that creative's impression to a delivery that never loaded.
            if received {
                renderedDeliveryId = pendingDeliveryId
            }
            lastRefreshTime = Date()
            refreshController.onRequestCompleted(generationAtRequest: load.refresh, success: !retryableFailure)
        } else {
            resumeEligibleWork()
        }
        return current
    }

    @nonobjc func watchGoogleLoad(_ load: GoogleLoad) {
        googleLoadTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, !self.refreshController.isDestroyed,
                  self.googleLoad?.auction == load.auction else { return }
            self.googleLoad = nil
            self.googleLoadTimeout = nil
            AULogEvent.logWarn("[AUBannerView] Google load timed out; releasing the wait for \(self.configId)")
            // Missing completion is not a classified network failure: use the configured cadence,
            // not fast retries. A page replacement already waiting for this load can proceed.
            if load.auction == self.auctionGeneration {
                self.lastRefreshTime = Date()
                self.refreshController.onRequestCompleted(generationAtRequest: load.refresh, success: true)
                self.restoreFromBlankIfNeeded()
            } else { self.resumeEligibleWork() }
        }
        googleLoadTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + googleLoadTimeoutSeconds, execute: timeout)
    }

    /// The base-class entry point. Everything that knows why it is loading calls
    /// `fetchRequest(_:reason:)` instead; this exists for the `AUAdView` override contract and for
    /// the non-lazy first load in `createAd`.
    override func fetchRequest(_ gamRequest: AdManagerRequest) {
        fetchRequest(gamRequest, reason: initialLoadRequested ? .periodicRefresh : .firstLoad)
    }

    /// Starts one auction, if the gate admits it.
    ///
    /// The `reason` is what ties the request into ``AURefreshController``'s lifecycle: it records
    /// the request, hands back the generation to check on completion, and — depending on how the
    /// request ends — schedules the next interval or a bounded retry. Nothing else in the SDK
    /// schedules a request.
    @nonobjc @discardableResult
    func fetchRequest(_ gamRequest: AdManagerRequest, reason: AURefreshRequestReason) -> Bool {
        guard canStartAuction(reason), googleLoad == nil else {
            if reason == .firstLoad || reason == .pageImpression { pendingLoadReason = reason }
            return false
        }
        guard !refreshController.hasRequestInFlight else { return false }
        pendingLoadReason = nil
        // Every new auction supersedes the previous one.
        auctionGeneration += 1
        pendingDeliveryId = "\(traceSlotId)-\(auctionGeneration)"
        AUAdTrace.log(placement: tracePlacement ?? configId, delivery: pendingDeliveryId,
                      event: .loadAccepted, reason: reason.rawValue, visible: isViewRefreshEligible)
        let refreshGeneration = refreshController.onRequestStarted(reason)
        initialLoadRequested = true
        let gamRequest = requestContext.nextRequest(from: gamRequest)
        // Re-read the PPID on every auction rather than trusting the one stamped at createAd.
        // A banner refreshes for the lifetime of its screen, so a publisher PPID set after the ad
        // was built, a 12-month rotation, or consent arriving late would otherwise never reach the
        // request. Mirrors Android's AudienzzAdViewHandler.buildRequest().
        gamRequest.publisherProvidedID = PPIDManager.shared.getPPID()

        // Mint the auction id up front so bidRequest and every later event of this auction share it.
        currentAuctionId = AUUniqHelper.makeUniqID()
        let requestStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        let generationAtRequest = auctionGeneration
        makeRequestEvent()
        var responseDelivered = false
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard !responseDelivered else { return }
            responseDelivered = true
            guard let self = self else { return }
            guard self.adUnit != nil else { return }
            // Stale-response guard: the page was released (or re-activated) while this auction was
            // in flight, so its creative belongs to a screen the user has left. Dropping it here is
            // what stops `onLoadRequest` from loading GAM into a released slot.
            guard generationAtRequest == self.auctionGeneration, self.screenActive else {
                // Drop only. There is ONE dispatcher per ad unit, so stopping it here would kill
                // the refresh belonging to the replacement auction that superseded this one.
                AULogEvent.logDebug(
                    "[AUBannerView] dropping superseded response (gen \(generationAtRequest) vs \(self.auctionGeneration), screenActive=\(self.screenActive))")
                return
            }
            let timeToRespond = Int64(Date().timeIntervalSince1970 * 1000) - requestStartMs

            // A prefetch-zone first load completes before the ad is on screen, so the banner is
            // not refresh-eligible yet. Record that as a block reason rather than a stopped timer:
            // the controller then simply never schedules, and `onRefreshBecameEligible` clears it
            // once the ad's top is fully on screen with ≥50% visible.
            if self.smartRefresh, !self.isViewRefreshEligible {
                self.refreshController.block(.notVisible)
            }

            AULogEvent.logDebug(
                "Audienz demand fetch for GAM \(resultCode.name())"
            )

            // Prebid targeting keywords are synchronously available on the GAM request after
            // fetchDemand. They arrive as [AnyHashable: Any]; a value can be a plain String or a
            // single-element Array depending on GAM SDK version — both handled by `keyword(_:)`.
            let rawTargeting = gamRequest.customTargeting as? [AnyHashable: Any] ?? [:]
            let hbSize = AUBannerView.keyword("hb_size", in: rawTargeting)
            let hbBidder = AUBannerView.keyword("hb_bidder", in: rawTargeting)
            let hbPb = AUBannerView.keyword("hb_pb", in: rawTargeting)
            let hbFormat = AUBannerView.keyword("hb_format", in: rawTargeting)
            // Fork-free economics come from the targeting keywords: hb_adid (ad id) and any
            // bidder-specific `*creative_id` key (crid isn't a standard keyword).
            let hbAdid = AUBannerView.keyword("hb_adid", in: rawTargeting)
            let creativeId = AUBannerView.creativeIdKeyword(in: rawTargeting)

            if let str = hbSize {
                self.lastPrebidCreativeSize = AUAdViewUtils.stringToCGSize(str)
            } else {
                self.lastPrebidCreativeSize = nil
            }

            self.prebidLineItemWon = false
            self.prebidWinningBidder = nil
            self.makeResultEvents(
                resultCode: resultCode,
                timeToRespond: timeToRespond,
                hbBidder: hbBidder,
                priceBucket: hbPb,
                hbSize: hbSize,
                hbFormat: hbFormat,
                adId: hbAdid,
                creativeId: creativeId
            )
            self.isInitialAutorefresh = false

            let load = GoogleLoad(auction: generationAtRequest, refresh: refreshGeneration)
            self.googleLoad = load
            self.googleEventPageGeneration = self.creativePageGeneration
            self.renderAuctionId = self.currentAuctionId
            self.eventHandler?.ensureListeners()
            self.watchGoogleLoad(load)
            self.onLoadRequest?(gamRequest)
        }
        return true
    }



    /// Reads a Prebid targeting keyword that may be a String or a single-element [String].
    static func keyword(_ key: String, in targeting: [AnyHashable: Any]) -> String? {
        if let str = targeting[key] as? String { return str }
        if let arr = targeting[key] as? [String] { return arr.first }
        return nil
    }

    /// Best-effort creative id from targeting. Stock Prebid has no standard `crid` keyword, but some
    /// SSP adapters emit a bidder-specific one (e.g. `hb_xandr_creative_id`). Returns the first
    /// non-empty `*creative_id` value; callers fall back to `"0"`.
    static func creativeIdKeyword(in targeting: [AnyHashable: Any]) -> String? {
        for key in targeting.keys {
            guard let k = key as? String, k.lowercased().hasSuffix("creative_id") else { continue }
            if let v = keyword(k, in: targeting), !v.isEmpty { return v }
        }
        return nil
    }

    func getPrivateBidRequester(from object: AnyObject)
        -> BidRequesterProtocol?
    {
        let objectClass: AnyClass = object_getClass(object)!

        // Get the instance variable for "bidRequester"
        if let ivar = class_getInstanceVariable(objectClass, "bidRequester") {
            // Get the value of the instance variable
            return object_getIvar(object, ivar) as? BidRequesterProtocol
        }

        return nil
    }
    
    private func isVisible(view: UIView) -> Bool {
        func isVisible(view: UIView, inView: UIView?) -> Bool {
            guard let inView = inView else { return true }
            let viewFrame = inView.convert(view.bounds, from: view)
            if viewFrame.intersects(inView.bounds) {
                return isVisible(view: view, inView: inView.superview)
            }
            return false
        }
        return isVisible(view: view, inView: view.superview)
    }

    private func makeRequestEvent() {
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        AUEventsManager.shared.bidRequest(
            adUnitId: adUnitID,
            adViewId: configId,
            sizes: AUUniqHelper.sizesJSON(adSize),
            adType: adTypeString,
            adSubtype: makeAdSubType(),
            apiType: apiTypeString,
            isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
            autorefreshTime: Int(autorefreshM.autorefreshEventModel.autorefreshTime),
            isRefresh: !isInitialAutorefresh,
            mediaTypes: Self.mediaTypesJSON(subtype: makeAdSubType()),
            auctionId: currentAuctionId,
            slotReload: emittedSlotReload
        )
    }

    /// `media_types` as a JSON array string (web-schema parity), derived from the ad subtype.
    static func mediaTypesJSON(subtype: String) -> String {
        switch subtype {
        case "NATIVE": return "[\"native\"]"
        case AUAdSubtype.video: return "[\"video\"]"
        case AUAdSubtype.multiformat: return "[\"banner\",\"video\"]"
        default: return "[\"banner\"]"
        }
    }

    /// Fires bidResponse, then bidWon (only when there's a real Prebid win — success AND hb_bidder)
    /// or noBid otherwise. Mirrors the Android win-gate that avoids spurious wins on empty SUCCESS.
    private func makeResultEvents(resultCode: ResultCode, timeToRespond: Int64,
                                  hbBidder: String?, priceBucket: String?,
                                  hbSize: String?, hbFormat: String?,
                                  adId: String?, creativeId: String?) {
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        let isAutorefresh = autorefreshM.autorefreshEventModel.isAutorefresh
        let autorefreshTime = Int(autorefreshM.autorefreshEventModel.autorefreshTime)
        let isRefresh = !isInitialAutorefresh
        let sizes = AUUniqHelper.sizesJSON(adSize)
        let subtype = makeAdSubType()
        let codeName = AUResulrCodeConverter.convertResultCodeName(resultCode)

        // Winning-bid economics, reused on bidResponse/bidWon and later render events.
        var economics: AURenderEconomics?
        if resultCode == .prebidDemandFetchSuccess, let bidder = hbBidder, !bidder.isEmpty {
            economics = AURenderEconomics(
                bidderCode: bidder, winnerBidderCode: bidder, winnerType: AUWinnerType.rtb,
                priceBucket: priceBucket, hbSize: hbSize, hbFormat: hbFormat,
                mediaType: hbFormat, size: hbSize,
                // Fork-free economics: exact cpm/currency/crid aren't on the original (GAM) API.
                // cpm = bucketed hb_pb; currency is backfilled from the GMA paid event at render;
                // creative_id = bidder-specific targeting key when present, else "0"; ad_id = hb_adid.
                cpm: priceBucket.flatMap { Double($0) }, currency: nil, creativeId: creativeId ?? "0",
                auctionId: currentAuctionId, adId: adId ?? "0",
                timeToRespond: timeToRespond, slotReload: emittedSlotReload)
        }

        AUEventsManager.shared.bidResponse(
            adUnitId: adUnitID, adViewId: configId, sizes: sizes,
            adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
            isAutorefresh: isAutorefresh, autorefreshTime: autorefreshTime, isRefresh: isRefresh,
            resultCode: codeName, timeToRespond: timeToRespond, economics: economics
        )

        if let economics {
            self.prebidWinningBidder = economics.bidderCode
            self.lastRenderEconomics = economics
            AUEventsManager.shared.bidWon(
                adUnitId: adUnitID, adViewId: configId, sizes: sizes,
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: isAutorefresh, autorefreshTime: autorefreshTime, isRefresh: isRefresh,
                economics: economics
            )
        } else {
            self.prebidWinningBidder = nil
            self.lastRenderEconomics = nil
            AUEventsManager.shared.noBid(
                adUnitId: adUnitID, adViewId: configId, sizes: sizes,
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: isAutorefresh, autorefreshTime: autorefreshTime, isRefresh: isRefresh,
                resultCode: codeName, mediaTypes: Self.mediaTypesJSON(subtype: subtype),
                auctionId: currentAuctionId, slotReload: emittedSlotReload
            )
        }
        // Count this load; next auction/refresh reports the incremented value.
        slotReloadCount += 1
    }

    /// Promote the pending auction's economics to "what is on screen".
    ///
    /// Called when Google confirms the creative was received, which is the moment the replacement
    /// actually becomes the thing the reader sees. Until then the previous creative keeps its own
    /// identity, so a late impression or viewability callback for it is reported under its own
    /// auction — and a replacement that never arrives changes nothing at all.
    @nonobjc func commitDisplayedCreative() {
        var ec = lastRenderEconomics ?? AURenderEconomics()
        ec.auctionId = ec.auctionId ?? currentAuctionId
        // The reported flag is binary and belongs to the creative, not to the slot's current count.
        ec.slotReload = ec.slotReload ?? emittedSlotReload
        displayedEconomics = ec
        displayedPrebidBidder = prebidWinningBidder
        displayedPrebidLineItemWon = prebidLineItemWon
        // The GMA paid event fires around this creative's impression; whatever was captured for the
        // previous one must not be attributed to this one.
        lastPaidCurrency = nil
        lastPaidCpm = nil
    }

    /// The Prebid line item's GAM app event can arrive either side of `bannerViewDidReceiveAd`.
    /// When it lands after, the displayed snapshot is corrected in place — this is the creative on
    /// screen, so the attribution belongs to it and not to whatever auction is running by then.
    @nonobjc func notePrebidLineItemRendered() {
        prebidLineItemWon = true
        if displayedEconomics != nil {
            displayedPrebidLineItemWon = true
            displayedPrebidBidder = displayedPrebidBidder ?? prebidWinningBidder
        }
    }

    /// Economics reported on the banner's render events (adImpression / adClick / viewability.*).
    /// Resolved lazily (at event-fire time) so `bidder_code` reflects the actual render winner — the
    /// Prebid line item only when its GAM app event fired, else the ad server. Shared by the handler
    /// (impression/click) and the viewability closures so all render events agree.
    @nonobjc func resolvedRenderEconomics() -> AURenderEconomics {
        // The DISPLAYED creative's snapshot, not the newest auction's. See `displayedEconomics`.
        var ec = displayedEconomics ?? AURenderEconomics()
        let isPrebidRender = displayedPrebidLineItemWon
        ec.bidderCode = isPrebidRender ? (displayedPrebidBidder ?? AD_SERVER_BIDDER) : AD_SERVER_BIDDER
        if !isPrebidRender {
            // The ad server (Google/direct) rendered — the Prebid bid's creative id would make the
            // enricher misclassify a direct-sold impression as RTB. Report the GAM creative id when
            // available, else the "0" stub. (GMA exposes no served-creative id for banners → "0".)
            ec.creativeId = "0"
        }
        // Always carry the SDK-minted auction id, even on a direct fill with no Prebid economics.
        ec.auctionId = ec.auctionId ?? renderAuctionId
        // Currency (and, on a direct fill with no Prebid bid, cpm) come from the GMA paid event,
        // which fires around impression — so they populate on adImpression/adClick/viewability.
        ec.currency = ec.currency ?? lastPaidCurrency
        ec.cpm = ec.cpm ?? lastPaidCpm
        return ec
    }

    /// Starts (or restarts) viewability tracking for the rendered banner creative.
    func startViewabilityTracking() {
        guard let adUnitID = eventHandler?.adUnitID else { return }
        let subtype = makeAdSubType()
        let viewId = configId
        let tracker = AUViewabilityTracker(
            view: self,
            onStart: { [weak self] in
                guard let self else { return }
                AUEventsManager.shared.viewabilityStart(
                    adUnitId: adUnitID, adType: adTypeString,
                    adSubtype: subtype, apiType: apiTypeString,
                    adViewId: viewId, economics: self.resolvedRenderEconomics()
                )
            },
            onSuccess: { [weak self] in
                guard let self else { return }
                AUEventsManager.shared.viewabilitySuccess(
                    adUnitId: adUnitID, adType: adTypeString,
                    adSubtype: subtype, apiType: apiTypeString,
                    adViewId: viewId, economics: self.resolvedRenderEconomics()
                )
            }
        )
        viewabilityTracker = tracker
        tracker.start()
    }

    func makeAdSubType() -> String {
        if demandFormats == [.native] { return "NATIVE" }
        if demandFormats.count >= 2 {
            return "MULTIFORMAT"
        } else if demandFormats.contains(where: { $0.rawValue == 1 })
            && demandFormats.count == 1
        {
            return "HTML"
        } else if demandFormats.contains(where: { $0.rawValue == 2 })
            && demandFormats.count == 1
        {
            return "VIDEO"
        }

        return ""
    }
}
