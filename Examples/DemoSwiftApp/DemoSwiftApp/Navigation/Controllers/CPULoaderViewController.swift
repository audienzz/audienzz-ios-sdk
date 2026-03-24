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
import AudienzziOSSDK
import GoogleInteractiveMediaAds
import GoogleMobileAds
import UIKit

private let kBannerAdConfigId = "46"

private let adSizeSmall  = CGSize(width: 320, height: 50)
private let adSizeMiddle = CGSize(width: 300, height: 250)

/*
 * CPU Load Debug — Banner View Reuse *
 *
 * This screen demonstrates how to significantly reduce CPU usage in a
 * high-frequency banner feed (1 000 rows, alternating 320×50 and 300×250).
 *
 * THE PROBLEM
 * ───────────
 * Each GAM/Prebid banner embeds a WKWebView. Creating and destroying a
 * WKWebView for every UITableViewCell that scrolls on/off screen is
 * expensive: the WebView must be initialised, load the ad creative, run
 * JavaScript, and tear itself down — over and over. On long feeds this
 * causes measurable CPU spikes and jank.
 * Reference: https://stackoverflow.com/a/69893642
 *
 * Additionally, rich-media creatives (video, animated/interactive content)
 * keep the GPU busy for rendering, compounding the load even further.
 *
 * THE SOLUTION — BANNER REUSE
 * ───────────────────────────
 * Instead of creating a new AdManagerBannerView per cell, we pre-allocate
 * a small, fixed pool of banner views (6 in this example) and rotate them
 * across all rows using modular index arithmetic. The WKWebView is kept
 * alive and simply reassigned to whichever cell is currently visible.
 *
 * Additional tips shown here:
 *   • stopAutoRefresh() — disables the built-in GAM refresh timer while
 *     the banner is being reused; avoids spurious reload requests when the
 *     cell is not on screen.
 *   • isLazyLoad: true — defers the Prebid bid request until the banner
 *     actually enters the viewport, reducing wasted bid calls.
*/

class CPULoaderViewController: UIViewController {
    @IBOutlet private weak var tableview: UITableView!

    /// One entry per row: the ad size to display (alternates small/middle).
    fileprivate var sizes: [CGSize] = []

    /// Resolved at viewDidLoad from remote config "46".
    fileprivate var resolvedConfigId: String = ""
    fileprivate var resolvedGamUnit: String = ""

    ///create loaca reuse banners
    fileprivate var gamBannerOne: AdManagerBannerView = AdManagerBannerView(
        adSize: AdSizeFluid
    )
    fileprivate var gamBannerTwo: AdManagerBannerView = AdManagerBannerView(
        adSize: AdSizeFluid
    )
    fileprivate var gamBannerThree: AdManagerBannerView = AdManagerBannerView(
        adSize: AdSizeFluid
    )
    fileprivate var gamBannerFour: AdManagerBannerView = AdManagerBannerView(
        adSize: AdSizeFluid
    )
    fileprivate var gamBannerFive: AdManagerBannerView = AdManagerBannerView(
        adSize: AdSizeFluid
    )
    fileprivate var gamBannerSix: AdManagerBannerView = AdManagerBannerView(
        adSize: AdSizeFluid
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        // Resolve ad unit values from remote config.
        if let rc = AudienzzRemoteConfig.shared.remoteConfig(for: kBannerAdConfigId) {
            resolvedConfigId = rc.prebidConfig.placementId
            resolvedGamUnit  = rc.gamConfig.adUnitPath
        } else {
            print("[CPULoaderViewController] Remote ad config '\(kBannerAdConfigId)' not yet available — ads will not load.")
        }

        // Build the row list: 1 000 rows alternating 320×50 and 300×250.
        for index in 0..<1000 {
            sizes.append(index % 2 == 0 ? adSizeSmall : adSizeMiddle)
        }

        let gamBanners: [AdManagerBannerView] = [
            gamBannerOne,
            gamBannerTwo,
            gamBannerThree,
            gamBannerFour,
            gamBannerSix,
        ]

        for banner in gamBanners {
            banner.delegate = self
        }

        tableview.register(
            CPUTableCell.self,
            forCellReuseIdentifier: "CPUTableCell"
        )
        tableview.dataSource = self
        tableview.delegate = self
        tableview.reloadData()

        /// GAM banners auto-refresh frequently, increasing CPU usage.
        /// Set longer refresh intervals. Use static banners (no refresh) if possible.
    }
}

extension CPULoaderViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
        -> Int
    {
        sizes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        guard
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "CPUTableCell"
            ) as? CPUTableCell
        else { fatalError() }

        let adSize = sizes[indexPath.row]
        let selectIndex: Int = indexPath.row % 6

        let gamRequest = AdManagerRequest()
        var localGAMBanner: AdManagerBannerView!

        switch selectIndex {
        case 0:
            localGAMBanner = gamBannerOne
        case 1:
            localGAMBanner = gamBannerTwo
        case 2:
            localGAMBanner = gamBannerThree
        case 3:
            localGAMBanner = gamBannerFour
        case 4:
            localGAMBanner = gamBannerFive
        case 5:
            localGAMBanner = gamBannerSix
        default:
            break
        }

        localGAMBanner.resize(adSizeFor(cgSize: adSize))
        localGAMBanner.adUnitID = resolvedGamUnit
        cell.setupViews(
            configId: resolvedConfigId,
            adSize: adSize,
            gamBanner: localGAMBanner,
            gamRequest: gamRequest
        )
        cell.onLoadRequest = { request in
            localGAMBanner.load(request)
        }

        return cell
    }

    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        sizes[indexPath.row].height
    }

    func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        if let adCell = cell as? CPUTableCell {
            adCell.endDisplaying()
        }
    }
}

class CPUTableCell: UITableViewCell {
    fileprivate var bannerView: AUBannerView!
    var onLoadRequest: ((Request) -> Void)?

    /// setting for reuse cell
    override func prepareForReuse() {
        super.prepareForReuse()
        bannerView?.removeFromSuperview()
        bannerView = nil
    }

    func endDisplaying() {
        bannerView?.removeFromSuperview()
    }

    // MARK: - Initializer
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupViews(
        configId: String,
        adSize: CGSize,
        gamBanner: AdManagerBannerView,
        gamRequest: AdManagerRequest
    ) {
        bannerView = AUBannerView(
            configId: configId,
            adSize: adSize,
            adFormats: [.banner],
            isLazyLoad: true
        )
        ///use lazy load
        bannerView.frame = CGRect.zero
        bannerView.backgroundColor = .clear
        contentView.addSubview(bannerView)
        bannerView.adUnitConfiguration.stopAutoRefresh()
        /// if autorefresh is nessesary please stop it.

        let handler = AUBannerEventHandler(adUnitId: gamBanner.adUnitID ?? "", gamView: gamBanner)

        bannerView.createAd(
            with: gamRequest,
            gamBanner: gamBanner,
            eventHandler: handler
        )

        bannerView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? Request else {
                print("Faild request unwrap")
                return
            }
            self?.onLoadRequest?(request)
        }

        setupConstraints()
    }

    private func setupConstraints() {
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bannerView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            ),
            bannerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            bannerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
        ])
    }
}

// MARK: - GADBannerViewDelegate
extension CPULoaderViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard let bannerView = bannerView as? AdManagerBannerView else {
            return
        }
        AUAdViewUtils.findCreativeSize(
            bannerView,
            success: { size in
                bannerView.resize(adSizeFor(cgSize: size))
            },
            failure: { (error) in
                print(error)
            }
        )
    }

    func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: Error
    ) {
        print("GAM did fail to receive ad with error: \(error)")
    }
}
