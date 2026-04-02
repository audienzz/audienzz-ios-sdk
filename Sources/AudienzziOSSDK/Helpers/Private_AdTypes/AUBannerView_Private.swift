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

        pendingSmartRefreshWorkItem?.cancel()
        pendingSmartRefreshWorkItem = nil

        let refreshInterval = (adUnitConfiguration as? AUAdUnitConfigurationEventProtocol)?
            .autorefreshEventModel.autorefreshTime ?? 0
        guard refreshInterval > 0 else {
            adUnitConfiguration?.resumeAutoRefresh()
            return
        }

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

    override func fetchRequest(_ gamRequest: AdManagerRequest) {
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            guard self.adUnit != nil else { return }
            self.lastRefreshTime = Date()

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
            self.makeWinnerEvent(
                AUResulrCodeConverter.convertResultCodeName(resultCode)
            )
            self.isInitialAutorefresh = false

            // Cache the winning creative size from Prebid's targeting keywords.
            // Reading "hb_size" from customTargeting is synchronous and always available
            // at this point — unlike WebView HTML scraping which can fail when the
            // WKWebView hasn't loaded yet (rapid navigation, high CPU/memory pressure).
            // customTargeting arrives as [AnyHashable: Any] at runtime (Prebid rebuilds
            // the dict internally), so every value access needs an explicit `as? String`.
            // hb_size can arrive as a plain String ("320x50") or a single-element
            // Array (["320x50"]) depending on GAM SDK version — both are handled.
            let rawTargeting = gamRequest.customTargeting as? [AnyHashable: Any] ?? [:]
            let hbSizeRaw = rawTargeting["hb_size"]
            if let str = hbSizeRaw as? String {
                self.lastPrebidCreativeSize = AUAdViewUtils.stringToCGSize(str)
            } else if let arr = hbSizeRaw as? [String], let first = arr.first {
                self.lastPrebidCreativeSize = AUAdViewUtils.stringToCGSize(first)
            } else {
                self.lastPrebidCreativeSize = nil
            }

            self.onLoadRequest?(gamRequest)
        }
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

        let event = AUBidRequestEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            size: AUUniqHelper.sizeMaker(adSize),
            isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
            autorefreshTime: Int(
                autorefreshM.autorefreshEventModel.autorefreshTime
            ),
            initialRefresh: isInitialAutorefresh,
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )

        guard let payload = event.convertToJSONString() else { return }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }

    private func makeWinnerEvent(_ resultCode: String) {
        AULogEvent.logDebug("makeWinnerEvent")
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        let event = AUBidWinnerEvent(
            resultCode: resultCode,
            adUnitID: adUnitID,
            targetKeywords: [:],
            isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
            autorefreshTime: Int(
                autorefreshM.autorefreshEventModel.autorefreshTime
            ),
            initialRefresh: isInitialAutorefresh,
            adViewId: configId,
            size: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )

        guard let payload = event.convertToJSONString() else { return }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }

    private func makeAdSubType() -> String {
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

    internal func makeCreationEvent() {
        let event = AUAdCreationEvent(
            adViewId: configId,
            adUnitID: eventHandler?.adUnitID ?? "-1",
            size: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )

        guard let payload = event.convertToJSONString() else { return }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }
}
