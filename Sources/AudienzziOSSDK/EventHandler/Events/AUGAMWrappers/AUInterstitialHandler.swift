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

import Foundation
import GoogleMobileAds

@objcMembers
public class AUInterstitialEventHandler: NSObject {
    let adUnit: InterstitialAd

    public init(adUnit: InterstitialAd) {
        self.adUnit = adUnit
    }
}

class AUInterstitialHandler: NSObject,
    FullScreenContentDelegate,
    AppEventDelegate,
    AULogEventType
{

    let handler: AUInterstitialEventHandler
    // weak: AUInterstitialView strongly holds this handler via `eventHandler`; a
    // strong back-reference leaked the view and the full GAM ad object per screen.
    weak var adView: AUInterstitialView?
    weak var fullScreentDelegate: FullScreenContentDelegate?
    private var recordedImpression = false
    private let economics: AURenderEconomics
    private let viewId: String
    private let subtype: String
    private var lastPaidCpm: Double?
    private var lastPaidCurrency: String?
    private var viewabilityTimer: AUFullScreenViewabilityTimer?
    private var terminal = false
    private let pageRecovery = AUInterstitialPageRecovery()

    init(handler: AUInterstitialEventHandler, adView: AUInterstitialView) {
        self.handler = handler
        self.fullScreentDelegate = handler.adUnit.fullScreenContentDelegate
        self.adView = adView
        var snapshot = adView.lastRenderEconomics ?? AURenderEconomics()
        snapshot.auctionId = snapshot.auctionId ?? adView.currentAuctionId
        snapshot.pageContext = adView.currentAnalyticsPage
        snapshot.bidderCode = adView.prebidWinningBidder ?? AD_SERVER_BIDDER
        snapshot.slotReload = snapshot.slotReload ?? 0
        self.economics = snapshot
        self.viewId = adView.configId
        self.subtype = adView.makeAdSubType()
        super.init()
        addListener()
    }

    func cancelMeasurement() { terminal = true; viewabilityTimer?.cancel(); pageRecovery.finish(dismissed: false) }

    var adUnitID: String {
        self.handler.adUnit.adUnitID
    }

    private func addListener() {
        handler.adUnit.fullScreenContentDelegate = self
        // GMA paid value + currency (the only fork-free currency source), stashed for the render events.
        handler.adUnit.paidEventHandler = { [weak self] adValue in
            self?.lastPaidCurrency = adValue.currencyCode
            self?.lastPaidCpm = adValue.value.doubleValue * 1_000
        }
    }

    deinit {
        viewabilityTimer?.cancel()
        AULogEvent.logDebug("AUInterstitialHandler")
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        guard !terminal, !recordedImpression else { return }
        recordedImpression = true
        LogEvent("adDidRecordImpression")
        AUEventsManager.shared.adImpression(
            adUnitId: adUnitID, adType: AUAdType.interstitial,
            adSubtype: subtype, apiType: AUEventApiType.original,
            adViewId: viewId, economics: renderEconomics()
        )
        fullScreentDelegate?.adDidRecordImpression?(ad)
    }

    func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
        guard !terminal else { return }
        LogEvent("adDidRecordClick")
        AUEventsManager.shared.adClick(
            adUnitId: adUnitID, adType: AUAdType.interstitial,
            adSubtype: subtype, apiType: AUEventApiType.original,
            adViewId: viewId, economics: renderEconomics()
        )
        fullScreentDelegate?.adDidRecordClick?(ad)
    }

    /// Full-screen ads expose no app event; carry the winning-bid economics and best-effort
    /// bidder_code (the Prebid auction winner if there was one, else the ad server).
    private func renderEconomics() -> AURenderEconomics {
        var ec = economics
        let bidder = ec.bidderCode ?? AD_SERVER_BIDDER
        ec.bidderCode = bidder
        if bidder == AD_SERVER_BIDDER {
            ec.creativeId = nil
            ec.adId = nil
            ec.cpm = nil
            ec.currency = nil
        }
        ec.applyGooglePaidValue(cpm: lastPaidCpm, currency: lastPaidCurrency)
        return ec
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        guard !terminal else { return }
        terminal = true
        pageRecovery.finish(dismissed: false)
        LogEvent("didFailToPresentFullScreenContentWithError")
        viewabilityTimer?.cancel()
        fullScreentDelegate?.ad?(
            ad,
            didFailToPresentFullScreenContentWithError: error
        )
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        guard !terminal, viewabilityTimer == nil else { return }
        pageRecovery.onShown()
        LogEvent("adWillPresentFullScreenContent")
        let adUnitID = self.adUnitID
        let subtype = self.subtype
        let viewId = self.viewId
        let economics = renderEconomics()
        let timer = AUFullScreenViewabilityTimer(
            onStart: {
                AUEventsManager.shared.viewabilityStart(
                    adUnitId: adUnitID, adType: AUAdType.interstitial,
                    adSubtype: subtype, apiType: AUEventApiType.original,
                    adViewId: viewId, economics: economics)
            },
            onSuccess: {
                AUEventsManager.shared.viewabilitySuccess(
                    adUnitId: adUnitID, adType: AUAdType.interstitial,
                    adSubtype: subtype, apiType: AUEventApiType.original,
                    adViewId: viewId, economics: economics)
            }
        )
        viewabilityTimer = timer
        timer.onShown()
        fullScreentDelegate?.adWillPresentFullScreenContent?(ad)
    }

    func adWillDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        LogEvent("adWillDismissFullScreenContent")
        fullScreentDelegate?.adWillDismissFullScreenContent?(ad)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        guard !terminal else { return }
        terminal = true
        pageRecovery.finish(dismissed: true)
        LogEvent("adDidDismissFullScreenContent")
        viewabilityTimer?.cancel()
        fullScreentDelegate?.adDidDismissFullScreenContent?(ad)
    }
}
