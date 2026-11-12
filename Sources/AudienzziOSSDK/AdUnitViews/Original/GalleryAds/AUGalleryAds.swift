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

import UIKit
import GoogleMobileAds

/// One ad placement in a paged screen, for `AUGalleryAds`.
public struct AUGalleryAdSlot: Equatable {
    /// Stable identity of the slot within its gallery; unique among the gallery's slots.
    public let slotKey: String
    /// Remote ad config id, as for `AURemoteConfigBannerView`.
    public let adConfigId: String
    /// Index of the page (ePaper tile) that shows this slot.
    public let pageIndex: Int

    public init(slotKey: String, adConfigId: String, pageIndex: Int) {
        self.slotKey = slotKey
        self.adConfigId = adConfigId
        self.pageIndex = pageIndex
    }
}

/// Ad events per gallery slot, on the main thread. Every method is optional.
public protocol AUGalleryAdsDelegate: AnyObject {
    /// The slot's ad view exists: embed it if its page is already shown. Delivered on the next
    /// main-queue turn, outside the scroll callback that triggered it.
    func galleryAds(_ galleryAds: AUGalleryAds, didCreateAdViewFor slotKey: String)
    /// A creative arrived (also after each refresh).
    func galleryAds(_ galleryAds: AUGalleryAds, didLoadAdFor slotKey: String)
    /// A request failed (no-fill, network), or the slot has no remote configuration
    /// (`error == nil`, reported once). The host can use it to drop the ad page.
    func galleryAds(_ galleryAds: AUGalleryAds, didFailToLoadAdFor slotKey: String, error: Error?)
}

public extension AUGalleryAdsDelegate {
    func galleryAds(_ galleryAds: AUGalleryAds, didCreateAdViewFor slotKey: String) {}
    func galleryAds(_ galleryAds: AUGalleryAds, didLoadAdFor slotKey: String) {}
    func galleryAds(_ galleryAds: AUGalleryAds, didFailToLoadAdFor slotKey: String, error: Error?) {}
}

/// Preloads the ads of a horizontally paged screen (an ePaper: one page per printed page) a few
/// pages before the reader reaches them.
///
/// A pager builds a page only when it is about to show it, so an ad on a later page is requested
/// too late if it is requested when its page is built, and requesting every ad page when the screen
/// opens buys ads for pages most readers never reach. This object owns the slots' ads instead of the
/// pages: each slot requests its ad once the reader is within its preload distance, keeps it while
/// its page is reused, and `embed(_:in:)` puts it into the page.
///
/// - **Ad config:** each slot is a remote banner ad config (ad unit, sizes, Prebid, refresh,
///   `gamConfig.includeFluid`). It loads as soon as it is in range; `lazyLoad` and
///   `prefetchDistanceDp` do not apply.
/// - **Preload distance:** the ad config's `config.preloadDistancePages`, else
///   `defaultPreloadDistancePages`: the reader is that many pages away or closer, in either
///   direction, counted from the fractional position while swiping.
/// - **Refresh:** `config.refreshTimeSeconds`, counted only while the ad is on screen.
/// - **Screen:** the slots belong to `screen` (default: `rootViewController`), the object you report
///   to `Audienzz.shared.pageImpression`. Leaving it and coming back (an article opened on top, the
///   app sent to the background) keeps the ads: they are paused, and refresh resumes where it
///   stopped.
///
/// Each slot's ad lives in a host view this object owns; a page embeds and releases the host view
/// as it is reused. The banner itself never leaves its host, because removing an `AUBannerView`
/// from its superview destroys it.
///
/// ```swift
/// let galleryAds = AUGalleryAds(slots: [
///     AUGalleryAdSlot(slotKey: "epaper-1", adConfigId: "123", pageIndex: 4),
///     AUGalleryAdSlot(slotKey: "epaper-2", adConfigId: "124", pageIndex: 12),
/// ], rootViewController: self)
/// // scrollViewDidScroll: galleryAds.updatePosition(scrollView.contentOffset.x / scrollView.bounds.width)
/// // Ad page cell: galleryAds.embed("epaper-1", in: cell.contentView)
/// // deinit / when done: galleryAds.destroy()
/// ```
@MainActor
public final class AUGalleryAds: NSObject {

    /// Preload distance when the ad config has no `config.preloadDistancePages`.
    public static let defaultPreloadDistancePages = 2

    public weak var delegate: AUGalleryAdsDelegate?

    public let slots: [AUGalleryAdSlot]
    /// Weak: the screen owns this object, and a strong reference back kept both alive after the
    /// screen was gone.
    private weak var rootViewController: UIViewController?
    /// A view controller screen is held weakly for the same reason; a page id is a value.
    private weak var weakScreen: AnyObject?
    private let valueScreen: AnyObject?
    private var screen: AnyObject? { valueScreen ?? weakScreen }

    private final class SlotAd {
        let owner: AURemoteConfigBannerView
        let host: UIView
        let events: SlotEvents

        init(owner: AURemoteConfigBannerView, host: UIView, events: SlotEvents) {
            self.owner = owner
            self.host = host
            self.events = events
        }
    }

    /// Forwards Google's callbacks for one slot. Held here: Google holds its delegate weakly.
    private final class SlotEvents: NSObject, GoogleMobileAds.BannerViewDelegate {
        weak var gallery: AUGalleryAds?
        let slotKey: String

        init(gallery: AUGalleryAds, slotKey: String) {
            self.gallery = gallery
            self.slotKey = slotKey
        }

        func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
            MainActor.assumeIsolated { gallery?.didLoad(slotKey) }
        }

        func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
            MainActor.assumeIsolated { gallery?.didFail(slotKey, error: error) }
        }
    }

    private var ads: [String: SlotAd] = [:]
    /// Slots already reported as having no config, so a missing config fails once, not per scroll.
    private var reportedMissing: Set<String> = []
    private var position: CGFloat?
    private var destroyed = false

    /// Builds a slot's banner owner. Replaceable for tests.
    internal var makeOwner: (String) -> AURemoteConfigBannerView = { AURemoteConfigBannerView(adConfigId: $0) }

    /// - Parameters:
    ///   - slots: the ad placements; slot keys must be unique.
    ///   - rootViewController: presents the ads' landing pages.
    ///   - screen: what you report to `pageImpression` for the gallery's screen; defaults to
    ///     `rootViewController`. Pass the page id string when you report one.
    public init(slots: [AUGalleryAdSlot], rootViewController: UIViewController, screen: AnyObject? = nil) {
        precondition(
            Set(slots.map(\.slotKey)).count == slots.count,
            "AUGalleryAds: duplicate slotKey"
        )
        self.slots = slots
        self.rootViewController = rootViewController
        let resolvedScreen = screen ?? rootViewController
        if resolvedScreen is UIViewController {
            weakScreen = resolvedScreen
            valueScreen = nil
        } else {
            valueScreen = resolvedScreen
        }
        super.init()
    }

    /// The reader's position in pages, fractional while swiping (a horizontal paging scroll view:
    /// `contentOffset.x / bounds.width`). Slots within their preload distance request their ad.
    public func updatePosition(_ page: CGFloat) {
        position = page
        evaluate()
    }

    /// The view to show for the slot, or `nil` while the slot has no ad (not yet in range, no
    /// config). It carries its own height (the creative's) and takes the width it is given.
    public func adView(for slotKey: String) -> UIView? {
        ads[slotKey]?.host
    }

    /// Puts the slot's ad into `container`, the view of its page: full width, centered
    /// vertically. Takes it out of the page it was in before. Returns `false` while the slot has no
    /// ad yet; `galleryAds(_:didCreateAdViewFor:)` says when to embed again.
    @discardableResult
    public func embed(_ slotKey: String, in container: UIView) -> Bool {
        guard let host = ads[slotKey]?.host else { return false }
        if host.superview === container { return true }
        // Only the host leaves its page; the banner inside it is never removed from its superview.
        host.removeFromSuperview()
        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return true
    }

    /// Releases every slot's ad. Call when the gallery's screen is gone for good.
    public func destroy() {
        guard !destroyed else { return }
        destroyed = true
        for ad in ads.values {
            ad.host.removeFromSuperview()
            ad.owner.destroy()
        }
        ads.removeAll()
    }

    // MARK: - Private

    private func evaluate() {
        // Nothing can be presented or owned once the screen is gone.
        guard !destroyed, let page = position, rootViewController != nil, screen != nil else { return }
        for slot in slots where ads[slot.slotKey] == nil {
            guard let config = AudienzzRemoteConfig.shared.remoteConfig(for: slot.adConfigId) else {
                reportMissing(slot)
                continue
            }
            let distance = config.config.preloadDistancePages ?? Self.defaultPreloadDistancePages
            // A hair of tolerance: a settled pager can report 3.9999999 for 4.
            guard abs(CGFloat(slot.pageIndex) - page) <= CGFloat(distance) + 1e-4 else { continue }
            create(slot, page: page, distance: distance)
        }
    }

    private func reportMissing(_ slot: AUGalleryAdSlot) {
        guard reportedMissing.insert(slot.slotKey).inserted else { return }
        AULogEvent.logDebug("[AUGalleryAds] Remote config not found for \(slot.adConfigId)")
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.destroyed else { return }
            self.delegate?.galleryAds(self, didFailToLoadAdFor: slot.slotKey, error: nil)
        }
    }

    private func create(_ slot: AUGalleryAdSlot, page: CGFloat, distance: Int) {
        AUDiagnostics.log("gallery", "preload", [
            ("slot", slot.slotKey), ("config", slot.adConfigId), ("pageIndex", slot.pageIndex),
            ("readerPage", String(format: "%.2f", page)), ("distance", distance),
        ])
        guard let rootViewController, let screen else { return }
        let owner = makeOwner(slot.adConfigId)
        owner.galleryMode = true
        owner.setScreen(screen)
        let host = UIView()
        host.backgroundColor = .clear
        let events = SlotEvents(gallery: self, slotKey: slot.slotKey)
        ads[slot.slotKey] = SlotAd(owner: owner, host: host, events: events)
        owner.load(in: host, rootViewController: rootViewController, delegate: events)
        // Posted, not called inline: this runs inside the host's scroll callback.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.destroyed, self.ads[slot.slotKey] != nil else { return }
            self.delegate?.galleryAds(self, didCreateAdViewFor: slot.slotKey)
        }
    }

    private func didLoad(_ slotKey: String) {
        guard !destroyed else { return }
        delegate?.galleryAds(self, didLoadAdFor: slotKey)
    }

    private func didFail(_ slotKey: String, error: Error) {
        guard !destroyed else { return }
        delegate?.galleryAds(self, didFailToLoadAdFor: slotKey, error: error)
    }
}
