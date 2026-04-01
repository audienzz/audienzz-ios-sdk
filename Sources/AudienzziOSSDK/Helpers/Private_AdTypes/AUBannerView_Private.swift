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
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest as? AdManagerRequest else {
            return
        }


        #if DEBUG
            AULogEvent.logDebug("[AUBannerView] became visible")
        #endif
        fetchRequest(request)
        isLazyLoaded = true
    }

    override func fetchRequest(_ gamRequest: AdManagerRequest) {
        makeBidRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            guard self.adUnit != nil else { return }

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
            let resultCodeStr = AUResulrCodeConverter.convertResultCodeName(resultCode)
            self.makeBidResponseEvent(resultCodeStr)
            if resultCode == .prebidDemandFetchSuccess {
                self.makeBidWonEvent()
            } else {
                self.makeNoBidEvent(resultCodeStr)
            }
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

    internal var adEventSubType: String { makeAdSubType() }

    private func makeBidRequestEvent() {
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
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeBidResponseEvent(_ resultCode: String) {
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        let event = AUBidResponseEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            resultCode: resultCode,
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
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeBidWonEvent() {
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        let event = AUBidWonEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            targetKeywords: [:],
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
        AUEventsManager.shared.sendEvent(event)
    }

    private func makeNoBidEvent(_ resultCode: String) {
        guard
            let autorefreshM = adUnitConfiguration
                as? AUAdUnitConfigurationEventProtocol,
            let adUnitID = eventHandler?.adUnitID
        else { return }

        let event = AUNoBidEvent(
            adViewId: configId,
            adUnitID: adUnitID,
            resultCode: resultCode,
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
        AUEventsManager.shared.sendEvent(event)
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

    internal func makeHeaderLoadedEvent() {
        let event = AUHeaderLoadedEvent(
            adViewId: configId,
            adUnitID: eventHandler?.adUnitID ?? "-1",
            size: AUUniqHelper.sizeMaker(adSize),
            adType: adTypeString,
            adSubType: makeAdSubType(),
            apiType: apiTypeString
        )
        AUEventsManager.shared.sendEvent(event)
    }
}
