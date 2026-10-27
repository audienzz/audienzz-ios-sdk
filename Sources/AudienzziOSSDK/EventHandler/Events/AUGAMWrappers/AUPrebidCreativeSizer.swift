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
import WebKit
import GoogleMobileAds

/// Sizes a banner to the Prebid creative it is showing, when that differs from the GAM creative it
/// was served in.
///
/// The Prebid line item's GAM creative has its own size, and GAM sizes the view to it: a 300x250 bid
/// served through a 300x600 creative was left smaller and off-centre in a 300x600 slot, and a 300x600
/// bid served through a 300x250 creative was cut off. The banner is sized to the winning `hb_size`
/// only once both hold for the CURRENT load: Google finished loading it, and the Prebid creative
/// rendered. Acting on the app event alone would resize the previous creative, and acting without
/// it would resize a creative GAM served itself.
///
/// "Prebid rendered" is GAM's `Prebid` app event, or — because some bidders' creatives never
/// dispatch it (nexx360's do not) — `hb_size` found in the creative's own markup, which a creative
/// GAM served itself does not contain. The markup is read again until the creative has rendered, or
/// until `probeTimeout`. Meanwhile GAM's size is held back rather than reported: reporting it first
/// made the slot bounce, 250 (reserved) → 600 (GAM's creative) → 250 (the Prebid bid).
final class AUPrebidCreativeSizer {

    /// Reports the size the slot shows.
    var report: (CGSize) -> Void = { _ in }

    /// Whether Google's callbacks still belong to the creative on screen.
    var isCurrent: () -> Bool = { true }

    /// Answers the Prebid size in the view's creative markup, or nil when it has none (yet). A seam
    /// for tests: the real one needs a rendered page.
    var findSizeInMarkup: (UIView, @escaping (CGSize?) -> Void) -> Void = AUPrebidCreativeSizer.readHbSizeFromMarkup

    /// Runs a closure later on the main queue. A seam so tests control time.
    var after: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// How long after the load GAM's size may be held back while the markup is read.
    var probeTimeout: TimeInterval = 1
    /// Pause between markup reads: the creative renders after `bannerViewDidReceiveAd`.
    var probeRetry: TimeInterval = 0.2

    private weak var gamView: AdManagerBannerView?

    /// Bumped for every Google request, so a late markup read cannot act on a newer load.
    private var generation = 0
    private var prebidSize: CGSize?
    private var prebidRendered = false
    private var googleLoaded = false
    /// The markup is being read: GAM's size for this load is not reported yet.
    private(set) var probing = false
    /// GAM's size for this load, held back until it is known whether it is the one to show.
    private var heldSize: CGSize?
    /// GAM's latest size for this load.
    private var deliveredSize: CGSize?

    init(gamView: AdManagerBannerView) {
        self.gamView = gamView
    }

    /// A new Google request is starting: forget the previous delivery. `prebidSize` is the winning
    /// bid's `hb_size`, or nil when Prebid did not win (or resizing is off).
    func beginLoad(prebidSize: CGSize?) {
        generation += 1
        probing = false
        heldSize = nil
        deliveredSize = nil
        prebidRendered = false
        googleLoaded = false
        self.prebidSize = prebidSize.flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil }
    }

    /// GAM reported a size for this load (`willChangeAdSizeTo`). GAM applies it to its own view
    /// after the callback, so a correction made here is applied again afterwards.
    func gamSizeChanged(_ size: CGSize) {
        deliveredSize = size
        if holdsSize {
            heldSize = size
            return
        }
        report(adjusted(size, reapply: true) ?? size)
    }

    /// Google finished loading this request. `size` is the creative's size, nil while an inline
    /// adaptive request has none yet.
    func googleDidLoad(size: CGSize?) {
        googleLoaded = true
        if let size { deliveredSize = size }
        if !prebidRendered, prebidSize != nil {
            heldSize = heldSize ?? deliveredSize
            probeMarkup()
        } else {
            // The app event may have landed after this load's size callback but before this one.
            settle()
        }
    }

    /// GAM's `Prebid` app event: the Prebid line item's creative rendered.
    func prebidDidRender() {
        prebidRendered = true
        if probing {
            probing = false
            settle()
            return
        }
        // Before the load completes, its own size callback applies the correction instead.
        guard googleLoaded, let target = adjusted(deliveredSize) else { return }
        report(target)
    }

    private var holdsSize: Bool {
        prebidSize != nil && !prebidRendered && (!googleLoaded || probing)
    }

    /// Reports this load's size once: the Prebid size when the Prebid creative rendered, GAM's otherwise.
    private func settle() {
        let delivered = heldSize ?? deliveredSize
        heldSize = nil
        if let target = adjusted(delivered) {
            report(target)
        } else if let delivered, delivered.width > 0, delivered.height > 0 {
            report(delivered)
        }
    }

    /// The Prebid size to show instead of `delivered`, with GAM's view resized to it; nil when the
    /// Prebid creative has not rendered for this load or the sizes match. Both directions: smaller
    /// fixes the off-centre gap, larger the cut-off creative.
    private func adjusted(_ delivered: CGSize?, reapply: Bool = false) -> CGSize? {
        guard prebidRendered, let target = prebidSize, target != delivered, let gamView else { return nil }
        gamView.resize(adSizeFor(cgSize: target))
        if reapply {
            DispatchQueue.main.async { [weak gamView] in gamView?.resize(adSizeFor(cgSize: target)) }
        }
        AUDiagnostics.log(
            "slot", "prebidResize",
            [("adUnit", gamView.adUnitID),
             ("from", delivered.map { "\(Int($0.width))x\(Int($0.height))" }),
             ("to", "\(Int(target.width))x\(Int(target.height))")]
        )
        return target
    }

    private func probeMarkup() {
        let load = generation
        probing = true
        after(probeTimeout) { [weak self] in
            guard let self, load == self.generation, self.probing else { return }
            self.probing = false
            AUDiagnostics.log("slot", "prebidSizeMissing", [("adUnit", self.gamView?.adUnitID)])
            if self.isCurrent() { self.settle() }
        }
        readMarkup(load: load)
    }

    private func readMarkup(load: Int) {
        guard load == generation, probing, let gamView else { return }
        findSizeInMarkup(gamView) { [weak self] size in
            guard let self, load == self.generation, self.probing else { return }
            guard self.isCurrent() else {
                self.probing = false
                return
            }
            guard let size else {
                self.after(self.probeRetry) { [weak self] in self?.readMarkup(load: load) }
                return
            }
            self.probing = false
            self.prebidRendered = true
            self.prebidSize = size
            self.settle()
        }
    }

    // MARK: - Markup

    /// The `hb_size` in a creative's markup, or nil. Only `hb_size` counts: an inline
    /// `width:…px;height:…px;` style is in any creative, GAM's own included.
    static func sizeInMarkup(_ markup: String?) -> CGSize? {
        guard let markup,
              let object = AUAdViewUtils.findHbSizeObject(in: markup),
              let value = AUAdViewUtils.findHbSizeValue(in: object),
              let size = AUAdViewUtils.stringToCGSize(value),
              size.width > 0, size.height > 0 else { return nil }
        return size
    }

    static func readHbSizeFromMarkup(_ view: UIView, answer: @escaping (CGSize?) -> Void) {
        guard let webView = AUAdViewUtils.findView(view, closure: AUAdViewUtils.isWKWebView) as? WKWebView else {
            answer(nil)
            return
        }
        webView.evaluateJavaScript("document.body.innerHTML") { value, _ in
            answer(sizeInMarkup(value as? String))
        }
    }
}
