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
import PrebidMobile
import GoogleMobileAds

typealias GAMRequest = GoogleMobileAds.AdManagerRequest
typealias PrebidAdFormat = PrebidMobile.AdFormat

@objcMembers
public class AUAdView: VisibleView {
    var isLazyLoaded: Bool = false
    private(set) var isLazyLoad: Bool
    private(set) var configId: String
    private(set) var adSize: CGSize
    
    public var adUnitConfiguration: AUAdUnitConfigurationType!
    public var onLoadRequest: ((AnyObject) -> Void)?
    /// Fired after every ad load with the actual rendered size GAM chose to serve.
    /// Use this to update your container constraints when the served size differs
    /// from the initially declared slot size (e.g. GAM picks a 300×600 direct ad
    /// against a slot that Prebid bid at 300×250).
    public var onAdSizeChanged: ((CGSize) -> Void)?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public init(configId: String, adSize: CGSize, isLazyLoad: Bool) {
        self.configId = configId
        self.adSize = adSize
        self.isLazyLoad = isLazyLoad
        super.init(frame: .zero)
    }
    
    public init(configId: String, isLazyLoad: Bool) {
        self.configId = configId
        self.adSize = .zero
        self.isLazyLoad = isLazyLoad
        super.init(frame: .zero)
    }
    
    public init(configId: String, adSize: CGSize) {
        self.configId = configId
        self.adSize = adSize
        self.isLazyLoad = false
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        self.configId = ""
        self.adSize = .zero
        self.isLazyLoad = false
        super.init(coder: coder)
    }
    
    public func setupConfigId(_ configId: String) {
        self.configId = configId
    }
    
    internal dynamic func fetchRequest(_ gamRequest: GAMRequest) {}
    internal var isInitialAutorefresh: Bool = true

    /// M8: re-run the lazy-load trigger after `createAd` has wired up the request.
    /// Visibility is edge-triggered, so if the view became visible *before*
    /// createAd ran (e.g. async remote-config setup), `detectVisible` already
    /// fired and bailed on the nil request — leaving the slot permanently dead.
    /// Calling it again here loads it if it's currently on screen.
    internal func loadIfAlreadyVisible() {
        guard isLazyLoad, !isLazyLoaded, isViewCurrentlyVisible else { return }
        detectVisible()
    }

    // prefetchMarginPoints is declared and implemented in VisibleView.
    // See VisibleView.prefetchMarginPoints for the full KDoc.
    // Defaults to 200 pt. Set to 0 for exact-visibility loading.
    // Not effective in UITableView / UICollectionView — use isLazyLoad = false there.

    /// Pause auto-refresh when the ad scrolls off-screen and resume when it returns.
    /// Defaults to `false`. When `true`, pairs with the refresh interval to avoid refreshing
    /// stale off-screen creatives.
    public var smartRefresh: Bool = false

    // MARK: - Smart refresh internals

    /// When the last request completed, or nil if none ever has. Read as "has this slot ever
    /// loaded?" — the refresh *interval* is measured by `AURefreshController` on a monotonic clock,
    /// not from this wall-clock stamp.
    internal var lastRefreshTime: Date?

    /// Whether this ad's host screen is the currently-active one. Defaults to `true` so ads in apps
    /// that never call `pageImpression` behave exactly as before. Flipped by `AUScreenAdCoordinator`
    /// on page transitions; while `false` the ad is released and the viewport gate must not resume it.
    internal var screenActive: Bool = true

    /// The page epoch this ad was created under (see `AUScreenAdCoordinator.epoch`). A stamp older
    /// than the coordinator's current epoch means the ad was created before its screen's
    /// `pageImpression` — an ordering violation the coordinator reports and later repairs on attach.
    internal var pageEpoch: Int = 0

    /// Incremented whenever this ad's liveness changes (page release). An auction captures it at
    /// `fetchRequest` and the completion re-checks it, so a response that lands after the user has
    /// left the screen cannot push a creative into a released slot.
    internal var auctionGeneration: Int = 0

    /// True once a first request has actually been issued, so re-activation can't double-auction.
    internal var initialLoadRequested: Bool = false

    
    internal func unwrapAdFormat(_ formats: [AUAdFormat]) -> [PrebidAdFormat] {
        formats.compactMap { element in
            switch element {
            case .banner:
                return PrebidAdFormat.banner
            case .video:
                return PrebidAdFormat.video
            case .native:
                return PrebidAdFormat.native
            default:
                return nil
            }
        }
    }
    
    public func collapseBehaviour(forView: UIView) {
        for subview in self.subviews {
            subview.removeFromSuperview()
        }
        let origin = self.frame.origin
        self.frame = CGRect(x: origin.x, y: origin.y, width: 0, height: 0)
    }
    
    /// Builds the fallback video parameters used when the publisher doesn't
    /// supply their own. `placement`/`plcmnt` must reflect the ad format so
    /// DSPs classify (and price) the inventory correctly — a fixed `.InBanner`
    /// default misclassified all interstitial/rewarded video.
    internal func defaultVideoParameters(
        placement: Signals.Placement = .InBanner,
        plcmnt: Signals.Plcmnt? = nil
    ) -> VideoParameters {
        let videoParameters = VideoParameters(mimes: ["video/mp4"])
        videoParameters.api = [Signals.Api.MRAID_1, Signals.Api.MRAID_2, Signals.Api.MRAID_3, Signals.Api.OMID_1]
        videoParameters.protocols = [Signals.Protocols.VAST_2_0]
        videoParameters.playbackMethod = [Signals.PlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = placement
        videoParameters.plcmnt = plcmnt
        return videoParameters
    }
}
