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
        fetchRequest(request)
        isLazyLoaded = true
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
        fetchRequest(request)
        isLazyLoaded = true
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
        // Smart-refresh v2: never resume a banner whose screen isn't the active one — the screen
        // coordinator owns pause/reload for inactive screens. Always true under the legacy model.
        guard screenActive else { return }
        guard smartRefresh, isLazyLoaded || !isLazyLoad,
              let request = gamRequest as? AdManagerRequest else { return }

        // Don't trigger smart refresh until the first demand fetch has completed.
        // Without this guard, lastRefreshTime is nil → elapsed defaults to refreshInterval
        // → remaining = 0 → immediate fetchRequest, duplicating the prefetch fetch.
        // Mirrors Android's: if (lastRefreshTime == 0L) return
        guard lastRefreshTime != nil else {
            AULogEvent.logDebug("[AUBannerView] smartRefresh — eligible before first load, skipping")
            return
        }

        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil

        // autorefreshTime is stored in milliseconds (set via setAutoRefreshMillis).
        // Convert to seconds for comparison with Date().timeIntervalSince() which returns seconds.
        let refreshIntervalMs = (adUnitConfiguration as? AUAdUnitConfigurationEventProtocol)?
            .autorefreshEventModel.autorefreshTime ?? 0
        guard refreshIntervalMs > 0 else {
            adUnitConfiguration?.resumeAutoRefresh()
            return
        }
        let refreshInterval = refreshIntervalMs / 1000.0

        let elapsed = lastRefreshTime.map { Date().timeIntervalSince($0) } ?? refreshInterval
        let remaining = max(0, refreshInterval - elapsed)

        if remaining == 0 {
            fetchRequest(request)
            adUnitConfiguration?.resumeAutoRefresh()
        } else {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, let req = self.gamRequest as? AdManagerRequest else { return }
                self.fetchRequest(req)
                self.adUnitConfiguration?.resumeAutoRefresh()
            }
            pendingSmartRefreshWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
        }
    }

    /// Smart-refresh PAUSE. Fires when the ad leaves the eligible zone (top edge clipped by
    /// ≥1pt, or >50% off the bottom).
    override func onRefreshBecameIneligible() {
        guard smartRefresh else { return }
        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil
        adUnitConfiguration?.stopAutoRefresh()
    }

    // MARK: - Public smart-refresh API (Flutter / external callers)

    /// Stale-aware smart-refresh resume.
    ///
    /// Intended for external view-layers (e.g. Flutter) that perform their own
    /// viewport detection and cannot rely on the UIScrollView-based KVO in
    /// ``VisibleView``.  Unlike the raw ``adUnitConfiguration?.resumeAutoRefresh()``
    /// call (which always resets the full refresh interval to zero), this method:
    ///
    /// - Does nothing if the first demand fetch has not completed yet
    ///   (``lastRefreshTime`` is nil — avoids a duplicate load on first visibility).
    /// - Fires a new ``fetchRequest`` **immediately** when the ad is stale (elapsed
    ///   time ≥ configured refresh interval).
    /// - Schedules a delayed ``fetchRequest`` for the exact **remaining** time when
    ///   the ad is not yet stale, then resumes Prebid's auto-refresh timer.
    ///
    /// Mirrors Android's `AudienzzAdViewHandler.resumeSmartRefresh()`.
    public func resumeSmartRefresh() {
        guard screenActive else { return }
        guard isLazyLoaded || !isLazyLoad,
              let request = gamRequest as? GAMRequest else { return }
        guard let lastTime = lastRefreshTime else {
            AULogEvent.logDebug("[AUBannerView] resumeSmartRefresh — first load not yet complete, skipping")
            return
        }

        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil

        let refreshIntervalMs = (adUnitConfiguration as? AUAdUnitConfigurationEventProtocol)?
            .autorefreshEventModel.autorefreshTime ?? 0
        guard refreshIntervalMs > 0 else {
            adUnitConfiguration?.resumeAutoRefresh()
            return
        }
        let refreshInterval = refreshIntervalMs / 1000.0
        let elapsed = Date().timeIntervalSince(lastTime)
        let remaining = max(0, refreshInterval - elapsed)

        if remaining == 0 {
            // Ad is stale — fetch demand immediately, then restart the periodic timer.
            fetchRequest(request)
            adUnitConfiguration?.resumeAutoRefresh()
        } else {
            // Not yet stale — schedule the fetch for when the interval actually expires.
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, let req = self.gamRequest as? GAMRequest else { return }
                self.fetchRequest(req)
                self.adUnitConfiguration?.resumeAutoRefresh()
            }
            pendingSmartRefreshWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
        }
    }

    /// Pause smart refresh: cancels any pending stale-aware work item and stops
    /// the Prebid auto-refresh timer.
    ///
    /// Call this when the ad view leaves the viewport.
    /// Mirrors Android's `AudienzzAdViewHandler.pauseSmartRefresh()`.
    public func pauseSmartRefresh() {
        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil
        adUnitConfiguration?.stopAutoRefresh()
    }

    /// Page release: the ad's screen is no longer the active page, so stop everything. Cancels any
    /// pending stale-aware refresh and stops Prebid's auto-refresh dispatcher, leaving the slot
    /// dormant — no auctions, no GAM loads — until its page comes back and `recreateForPage()` runs.
    ///
    /// `screenActive` (set by the coordinator) is what keeps the viewport gate from resuming it in
    /// the meantime, so a released banner scrolling through the viewport stays silent.
    func releaseForPage() {
        // Bump first so an auction already in flight is recognised as stale by its completion.
        auctionGeneration += 1
        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil
        adUnitConfiguration?.stopAutoRefresh()
        adUnit?.stopAutoRefresh()
    }

    /// Page (re)activation: this ad's screen is the incoming page, so serve a fresh creative.
    /// Unlike `resumeSmartRefresh` (stale-aware), this always forces a new auction when the ad has
    /// loaded before — that is the "new page impression → fresh ad" semantics, and it's what makes a
    /// back-navigation or a return from the background show a current creative rather than a stale
    /// one. A never-loaded banner is left for its normal lazy/prefetch first load.
    func recreateForPage() {
        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil
        // A hard transition supersedes the outgoing auction even when the SAME page is re-reported,
        // so a response from the previous visit can't load a creative or overwrite this visit's
        // auction analytics.
        auctionGeneration += 1
        // Retire, don't merely invalidate: the replacement may be deferred (a lazy banner out of
        // range), and an un-retired dispatcher keeps auctioning while every callback is dropped.
        adUnitConfiguration?.stopAutoRefresh()
        guard let request = gamRequest as? AdManagerRequest else { return }
        guard lastRefreshTime != nil else {
            // Never loaded: this banner's first load was deferred because its page wasn't active
            // (or its lazy trigger was consumed while released). Activation is its only remaining
            // chance — without this the slot stays blank forever.
            AULogEvent.logDebug("[AUBannerView] \(configId) — activating a never-loaded banner, starting first load")
            if isLazyLoad {
                isLazyLoaded = false
                loadIfAlreadyVisible()
            } else {
                fetchRequest(request)
                // Prebid only auto-starts its dispatcher on the FIRST-EVER fetch
                // (`isInitialFetchDemandCallMade`), and the release already stopped it — so without
                // this the replacement creative loads but never refreshes again.
                adUnitConfiguration?.resumeAutoRefresh()
            }
            return
        }
        // Optionally blank the current creative (keeping the slot size — the container view keeps
        // its frame) so the refresh is visually obvious; restored when the fresh ad is received.
        if Audienzz.shared.blankOnScreenReload {
            eventHandler?.gamView?.isHidden = true
            blankedForReload = true
        }
        fetchRequest(request)
        adUnitConfiguration?.resumeAutoRefresh()
    }

    /// Force a fresh auction now, ignoring the stale-aware timing of `resumeSmartRefresh`.
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
        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil
        if Audienzz.shared.blankOnScreenReload {
            eventHandler?.gamView?.isHidden = true
            blankedForReload = true
        }
        fetchRequest(request)
        adUnitConfiguration?.resumeAutoRefresh()
    }

    /// The one place an auction can start. Every entry point — first load, prefetch, viewport
    /// resume, page activation, manual reload — funnels through `fetchRequest`, so this is the
    /// single gate deciding whether auctioning is legitimate right now. Guarding the call sites
    /// individually is what let earlier revisions leak an auction through whichever path was missed.
    func canStartAuction() -> Bool {
        guard screenActive else {
            AULogEvent.logDebug("[AUBannerView] auction blocked \(configId) — page released")
            return false
        }
        guard !Audienzz.shared.isAppBackgrounded else {
            AULogEvent.logDebug("[AUBannerView] auction deferred \(configId) — app is backgrounded")
            auctionDeferred = true
            return false
        }
        return true
    }

    /// Retry an auction the gate deferred. Called when the app reaches the foreground, so the
    /// interleaving of the SDK's and the publisher's lifecycle observers stops mattering.
    func retryDeferredAuction() {
        guard auctionDeferred else { return }
        auctionDeferred = false
        guard screenActive, let request = gamRequest as? AdManagerRequest else { return }
        AULogEvent.logDebug("[AUBannerView] \(configId) — retrying deferred auction now that the app is foreground")
        if lastRefreshTime == nil {
            if isLazyLoad {
                isLazyLoaded = false
                loadIfAlreadyVisible()
            } else {
                fetchRequest(request)
                adUnitConfiguration?.resumeAutoRefresh()
            }
        } else {
            fetchRequest(request)
            adUnitConfiguration?.resumeAutoRefresh()
        }
    }

    override func fetchRequest(_ gamRequest: AdManagerRequest) {
        guard canStartAuction() else { return }
        // Every new auction supersedes the previous one.
        auctionGeneration += 1
        initialLoadRequested = true
        // Re-read the PPID on every auction rather than trusting the one stamped at createAd.
        // A banner refreshes for the lifetime of its screen, so a publisher PPID set after the ad
        // was built, a 12-month rotation, or consent arriving late would otherwise never reach the
        // request. Mirrors Android's AudienzzAdViewHandler.buildRequest().
        gamRequest.publisherProvidedID = PPIDManager.shared.getPPID()

        // New auction → reset render-winner state until the bid result / GAM app event report back.
        prebidLineItemWon = false
        prebidWinningBidder = nil
        // Mint the auction id up front so bidRequest and every later event of this auction share it.
        currentAuctionId = AUUniqHelper.makeUniqID()
        let requestStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        let generationAtRequest = auctionGeneration
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
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
            self.lastRefreshTime = Date()
            let timeToRespond = Int64(Date().timeIntervalSince1970 * 1000) - requestStartMs

            // H12: Prebid starts its auto-refresh dispatcher synchronously on the
            // first fetchDemand. When that first fetch is a prefetch-zone load
            // (fired up to prefetchMarginPoints before the ad is on screen), the
            // dispatcher would otherwise keep auto-refreshing while the ad isn't in the
            // refresh-eligible zone. Under smart refresh, stop it whenever the ad isn't
            // eligible; onRefreshBecameEligible resumes it (stale-aware) once the ad's top
            // is fully on screen with ≥50% visible. This runs after the eligibility check
            // has resolved the already-eligible case, so a banner that's fully on screen at
            // load keeps refreshing normally.
            if self.smartRefresh, !self.isViewRefreshEligible {
                self.adUnitConfiguration?.stopAutoRefresh()
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

            self.onLoadRequest?(gamRequest)
        }
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
            auctionId: currentAuctionId
        )
    }

    /// `media_types` as a JSON array string (web-schema parity), derived from the ad subtype.
    static func mediaTypesJSON(subtype: String) -> String {
        switch subtype {
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
                timeToRespond: timeToRespond, slotReload: slotReloadCount)
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
                auctionId: currentAuctionId
            )
        }
        // Count this load; next auction/refresh reports the incremented value.
        slotReloadCount += 1
    }

    /// Economics reported on the banner's render events (adImpression / adClick / viewability.*).
    /// Resolved lazily (at event-fire time) so `bidder_code` reflects the actual render winner — the
    /// Prebid line item only when its GAM app event fired, else the ad server. Shared by the handler
    /// (impression/click) and the viewability closures so all render events agree.
    @nonobjc func resolvedRenderEconomics() -> AURenderEconomics {
        var ec = lastRenderEconomics ?? AURenderEconomics()
        let isPrebidRender = prebidLineItemWon
        ec.bidderCode = isPrebidRender ? (prebidWinningBidder ?? AD_SERVER_BIDDER) : AD_SERVER_BIDDER
        if !isPrebidRender {
            // The ad server (Google/direct) rendered — the Prebid bid's creative id would make the
            // enricher misclassify a direct-sold impression as RTB. Report the GAM creative id when
            // available, else the "0" stub. (GMA exposes no served-creative id for banners → "0".)
            ec.creativeId = "0"
        }
        // Always carry the SDK-minted auction id, even on a direct fill with no Prebid economics.
        ec.auctionId = ec.auctionId ?? currentAuctionId
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
        if adUnit.adFormats.count >= 2 {
            return "MULTIFORMAT"
        } else if adUnit.adFormats.contains(where: { $0.rawValue == 1 })
            && adUnit.adFormats.count == 1
        {
            return "HTML"
        } else if adUnit.adFormats.contains(where: { $0.rawValue == 2 })
            && adUnit.adFormats.count == 1
        {
            return "VIDEO"
        }

        return ""
    }
}
