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
        super.onBecameVisible() // triggers lazy load via detectVisible()

        guard smartRefresh, isLazyLoaded || !isLazyLoad,
              let request = gamRequest as? AdManagerRequest else { return }

        // Don't trigger smart refresh until the first demand fetch has completed.
        // Without this guard, lastRefreshTime is nil → elapsed defaults to refreshInterval
        // → remaining = 0 → immediate fetchRequest, duplicating the prefetch fetch.
        // Mirrors Android's: if (lastRefreshTime == 0L) return
        guard lastRefreshTime != nil else {
            AULogEvent.logDebug("[AUBannerView] smartRefresh — became visible before first load, skipping")
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

    override func onBecameHidden() {
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

    override func fetchRequest(_ gamRequest: AdManagerRequest) {
        // New auction → reset render-winner state until the bid result / GAM app event report back.
        prebidLineItemWon = false
        prebidWinningBidder = nil
        let requestStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            guard self.adUnit != nil else { return }
            self.lastRefreshTime = Date()
            let timeToRespond = Int64(Date().timeIntervalSince1970 * 1000) - requestStartMs

            /*
             use for debug more deep events
            
            if let bidRequester = getPrivateBidRequester(from: adUnit) {
                print("Got bidRequester: \(bidRequester)")
            
                bidRequester.requestBids { bidResponse, error in
                    guard let bidResponse else { return }
                    print(bidResponse)
                }
            } else {
                print("Failed to access bidRequester")
            }
            */

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
                hbFormat: hbFormat
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
            sizes: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString,
            adSubtype: makeAdSubType(),
            apiType: apiTypeString,
            isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
            autorefreshTime: Int(autorefreshM.autorefreshEventModel.autorefreshTime),
            isRefresh: !isInitialAutorefresh
        )
    }

    /// Fires bidResponse, then bidWon (only when there's a real Prebid win — success AND hb_bidder)
    /// or noBid otherwise. Mirrors the Android win-gate that avoids spurious wins on empty SUCCESS.
    private func makeResultEvents(resultCode: ResultCode, timeToRespond: Int64,
                                  hbBidder: String?, priceBucket: String?,
                                  hbSize: String?, hbFormat: String?) {
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        let isAutorefresh = autorefreshM.autorefreshEventModel.isAutorefresh
        let autorefreshTime = Int(autorefreshM.autorefreshEventModel.autorefreshTime)
        let isRefresh = !isInitialAutorefresh
        let sizes = AUUniqHelper.sizeMaker(adSize)
        let subtype = makeAdSubType()
        let codeName = AUResulrCodeConverter.convertResultCodeName(resultCode)

        AUEventsManager.shared.bidResponse(
            adUnitId: adUnitID, adViewId: configId, sizes: sizes,
            adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
            isAutorefresh: isAutorefresh, autorefreshTime: autorefreshTime, isRefresh: isRefresh,
            resultCode: codeName, timeToRespond: timeToRespond
        )

        if resultCode == .prebidDemandFetchSuccess, let bidder = hbBidder, !bidder.isEmpty {
            self.prebidWinningBidder = bidder
            AUEventsManager.shared.bidWon(
                adUnitId: adUnitID, adViewId: configId, sizes: sizes,
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: isAutorefresh, autorefreshTime: autorefreshTime, isRefresh: isRefresh,
                priceBucket: priceBucket, hbSize: hbSize, hbFormat: hbFormat
            )
        } else {
            self.prebidWinningBidder = nil
            AUEventsManager.shared.noBid(
                adUnitId: adUnitID, adViewId: configId, sizes: sizes,
                adType: adTypeString, adSubtype: subtype, apiType: apiTypeString,
                isAutorefresh: isAutorefresh, autorefreshTime: autorefreshTime, isRefresh: isRefresh,
                resultCode: codeName
            )
        }
    }

    /// Starts (or restarts) viewability tracking for the rendered banner creative.
    func startViewabilityTracking() {
        guard let adUnitID = eventHandler?.adUnitID else { return }
        let subtype = makeAdSubType()
        let tracker = AUViewabilityTracker(
            view: self,
            onStart: {
                AUEventsManager.shared.viewabilityStart(
                    adUnitId: adUnitID, adType: adTypeString,
                    adSubtype: subtype, apiType: apiTypeString
                )
            },
            onSuccess: {
                AUEventsManager.shared.viewabilitySuccess(
                    adUnitId: adUnitID, adType: adTypeString,
                    adSubtype: subtype, apiType: apiTypeString
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
