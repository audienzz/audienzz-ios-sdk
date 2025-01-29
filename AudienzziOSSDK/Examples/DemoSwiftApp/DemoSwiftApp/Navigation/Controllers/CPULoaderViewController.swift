/*   Copyright 2018-2024 Audienzz.org, Inc.
 
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
import AudienzziOSSDK
import GoogleMobileAds
import GoogleInteractiveMediaAds

// 320x250
fileprivate let storedImpDisplayBanner_320x250 = "33994718"
fileprivate let gamAdUnitDisplayBannerOriginal_320x250 = "/21775744923/example/fixed-size-banner"

// 320x50
fileprivate let storedImpDisplayBanner = "prebid-demo-banner-320-50"
fileprivate let gamAdUnitDisplayBannerOriginal = "ca-app-pub-3940256099942544/2934735716"

fileprivate let adSizeSmall = CGSize(width: 320, height: 50)
fileprivate let adSizeMiddle = CGSize(width: 300, height: 250)


/*
 * How to Reduce CPU Usage of GAMBannerView *
 
 In this example, we reuse existing GAMBannerView instances instead of creating new ones for every UITableViewCell. This significantly reduces CPU load, as frequent creation and destruction of banner views cause unnecessary resource usage, ad reloading, and rendering overhead.

 Additionally, CPU usage can be affected by animations and UI elements inside the WebView, which are embedded within GAM banners. If the banners contain rich media elements, such as videos, interactive ads, or animated content, they require additional rendering and processing power, increasing CPU load.
 
 The main reason CPU load in GAM -  Each native/banner ad has a WKWebView and many WKWebViews take CPU resources -
 https://stackoverflow.com/a/69893642
 
*/

class CPULoaderViewController: UIViewController {
    @IBOutlet private weak var tableview: UITableView!
    
    fileprivate var gams: [String] = []
    
    ///create loaca reuse banners
    fileprivate var gamBannerOne: GAMBannerView = GAMBannerView(adSize: GADAdSizeFluid)
    fileprivate var gamBannerTwo: GAMBannerView = GAMBannerView(adSize: GADAdSizeFluid)
    fileprivate var gamBannerThree: GAMBannerView = GAMBannerView(adSize: GADAdSizeFluid)
    fileprivate var gamBannerFour: GAMBannerView = GAMBannerView(adSize: GADAdSizeFluid)
    fileprivate var gamBannerFive: GAMBannerView = GAMBannerView(adSize: GADAdSizeFluid)
    fileprivate var gamBannerSix: GAMBannerView = GAMBannerView(adSize: GADAdSizeFluid)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var index = 0
        
        
        /// just add 1000 adunit ids for example and setup for working example
        while index < 1000 {
            if index % 2 == 0 {
                gams.append(gamAdUnitDisplayBannerOriginal)
            } else {
                gams.append(gamAdUnitDisplayBannerOriginal_320x250)
            }
            
            index += 1
        }
        
        let gamBanners: [GAMBannerView] = [
            gamBannerOne,
            gamBannerTwo,
            gamBannerThree,
            gamBannerFour,
            gamBannerSix
        ]
        
        for banner in gamBanners {
            banner.delegate = self
        }
        
        tableview.register(CPUTableCell.self, forCellReuseIdentifier: "CPUTableCell")
        tableview.dataSource = self
        tableview.delegate = self
        tableview.reloadData()
        
        /// GAM banners auto-refresh frequently, increasing CPU usage.
        /// Set longer refresh intervals. Use static banners (no refresh) if possible.
//        GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
    }
}

extension CPULoaderViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        gams.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CPUTableCell") as? CPUTableCell else { fatalError() }
        
        /// prepare setting for setup cell
        let selectIndex: Int = indexPath.row % 6
        var adSize = CGSize.zero
        let gamID = gams[indexPath.row]
        
        if gamID == gamAdUnitDisplayBannerOriginal {
            adSize = adSizeSmall
        } else {
            adSize = adSizeMiddle
        }
        
        let gamRequest = GAMRequest()
        var localGAMBanner: GAMBannerView! /// prepare reuse  banner
        
        /// setup current reusable banner
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
        
        ///setup local banner settings and setup cell
        localGAMBanner.resize(GADAdSizeFromCGSize(adSize))
        localGAMBanner.adUnitID = gamID
        cell.setupViews(by: gamID, gamBanner: localGAMBanner, gamRequest: gamRequest)
        cell.onLoadRequest = { request in
            localGAMBanner.load(request)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let gamID = gams[indexPath.row]
        
        if gamID == gamAdUnitDisplayBannerOriginal {
            return adSizeSmall.height
        } else {
            return adSizeMiddle.height
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let adCell = cell as? CPUTableCell {
            adCell.endDisplaying()
        }
    }
}

class CPUTableCell: UITableViewCell {
    fileprivate var bannerView: AUBannerView!
    var onLoadRequest: ((GADRequest) -> Void)?
    
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
    
    func setupViews(by gamID: String, gamBanner: GAMBannerView, gamRequest: GADRequest) {
        var adSize = CGSize.zero
        var configID: String!
        
        if gamID == gamAdUnitDisplayBannerOriginal {
            adSize = adSizeSmall
            configID = storedImpDisplayBanner
        } else {
            adSize = adSizeMiddle
            configID = storedImpDisplayBanner_320x250
        }
        
        bannerView = AUBannerView(configId: configID, adSize: adSize, adFormats: [.banner], isLazyLoad: true) ///use lazy load
        bannerView.frame = CGRect.zero
        bannerView.backgroundColor = .clear
        contentView.addSubview(bannerView)
        bannerView.adUnitConfiguration.stopAutoRefresh() /// if autorefresh is nessesary please stop it.
        
        let handler = AUBannerEventHandler(adUnitId: gamID, gamView: gamBanner)
        
        bannerView.createAd(with: gamRequest, gamBanner: gamBanner, eventHandler: handler)
        
        bannerView.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? GADRequest else {
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
            bannerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bannerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
}

// MARK: - GADBannerViewDelegate
extension CPULoaderViewController: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        guard let bannerView = bannerView as? GAMBannerView else { return }
        AUAdViewUtils.findCreativeSize(bannerView, success: { size in
            bannerView.resize(GADAdSizeFromCGSize(size))
        }, failure: { (error) in
            print(error)
        })
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("GAM did fail to receive ad with error: \(error)")
    }
}
