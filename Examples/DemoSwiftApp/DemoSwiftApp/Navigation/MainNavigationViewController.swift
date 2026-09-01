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
import AppTrackingTransparency
import AdSupport

enum AdTypeExample: String {
    case bannerOrigin = "Banner Origin HTML"
    case bannerOriginVideo = "Banner Origin Video"
    case bannerOriginMulti = "Banner Origin Multiformat"
    case interstitalOrigin = "Interstitial Origin"
    case interstitalOriginVideo = "Interstitial Video"
    case interstitalOriginMulti = "Interstitial Origin Multiformat"
    case rewardedOrigin = "Rewarded Origin"
    case bannerRender = "Banner Render HTML"
    case bannerRenderVideo = "Banner Render Video"
    case interstitialRender = "Interstitial Render"
    case interstitialRenderVideo = "Interstitial Render Video"
    case rewardedRender = "Rewarded Render"
    case allExample = "All examples"
    case debug = "Ad Debug"
    case cpu = "CPU LOAD DEBUG"
    case adaptive = "Adaptive - 'multi-size GAM'"
    case targetingTesting = "Targeting Testing Page"
    case remoteConfig = "Remote Configuration Testing Page"
    case stickyAdExample = "Sticky Ad Example"
    case longArticleStickyAds = "Long Article – 5 Sticky Ads"
    case fixedBanner = "Fixed Banner Example"
    case legacyBanner = "Legacy Banner (v0.1.8)"

    var indexRow: Int {
        switch self {
        case .allExample:
            return 0
        case .debug:
            return 1
        case .adaptive:
            return 2
        case .bannerOrigin:
            return 3
        case .interstitalOrigin:
            return 6
        case .interstitalOriginVideo:
            return 7
        case .interstitalOriginMulti:
            return 8
        case .rewardedOrigin:
            return 9
        case .cpu:
            return 10
        case .targetingTesting:
            return 11
        case .remoteConfig:
            return 12
        default: return 0
        }
    }
}

class MainNavigationViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    // the commented types will be implemented in next version
    fileprivate var rows: [AdTypeExample] = [
        .allExample,
        .debug,
        .adaptive,
        .bannerOrigin,
//        .bannerOriginVideo,
//        .bannerOriginMulti,
        .interstitalOrigin,
        .interstitalOriginVideo,
        .interstitalOriginMulti,
        .rewardedOrigin,
        .cpu,
        .targetingTesting,
        .remoteConfig,
        .stickyAdExample,
        .longArticleStickyAds,
        .fixedBanner,
        .legacyBanner
//        .bannerRender,
//        .bannerRenderVideo,
//        .interstitialRender,
//        .interstitialRenderVideo,
//        .rewardedRender
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        setupSmartRefreshV2Toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.requestTrackingAuthorization()
        }
    }

    /// Demo control: a Smart Refresh v2 switch in the nav bar. Persists the choice and restarts the
    /// app so the SDK picks up the new `smartRefreshV2Override` at launch (applied in AppDelegate).
    private func setupSmartRefreshV2Toggle() {
        title = "Audienzz Examples"
        let toggle = UISwitch()
        toggle.isOn = DemoFeatureFlags.smartRefreshV2Enabled
        toggle.addTarget(self, action: #selector(smartRefreshV2Changed(_:)), for: .valueChanged)
        let label = UILabel()
        label.text = "SR v2"
        label.font = .systemFont(ofSize: 13)
        let stack = UIStackView(arrangedSubviews: [label, toggle])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: stack)
    }

    @objc private func smartRefreshV2Changed(_ sender: UISwitch) {
        DemoFeatureFlags.smartRefreshV2Enabled = sender.isOn
        let alert = UIAlertController(
            title: "Smart Refresh v2 \(sender.isOn ? "enabled" : "disabled")",
            message: "The app will restart to apply the change.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Restart", style: .default) { _ in
            exit(0)
        })
        present(alert, animated: true)
    }
    
    private func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("enable tracking")
                case .denied:
                    print("disable tracking")
                default:
                    print("disable tracking")
                }
            }
        } else {
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                print("asked")
            }
        }
    }
}

extension MainNavigationViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = rows[indexPath.row].rawValue
        config.textProperties.font = UIFont.systemFont(ofSize: 28)
        cell.contentConfiguration = config
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mainStoryboard:UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let choosedRow = rows[indexPath.row]
        
        switch choosedRow {
        case .bannerOrigin, .bannerOriginVideo, .bannerOriginMulti, .interstitalOrigin, .interstitalOriginVideo,.interstitalOriginMulti,.rewardedOrigin, .bannerRender, .bannerRenderVideo, .interstitialRender, .interstitialRenderVideo, .rewardedRender:
            let destination = mainStoryboard.instantiateViewController(withIdentifier: "SeparateViewController") as! SeparateViewController
            destination.selectedType = choosedRow
            self.navigationController?.pushViewController(destination, animated: true)
        case .allExample:
            let destination = mainStoryboard.instantiateViewController(withIdentifier: "ExamplesViewController") as! ExamplesViewController
            self.navigationController?.pushViewController(destination, animated: true)
        case .debug:
            let destination = mainStoryboard.instantiateViewController(withIdentifier: "AdDebugViewController") as! AdDebugViewController
            self.navigationController?.pushViewController(destination, animated: true)
        case .adaptive:
            let destination = mainStoryboard.instantiateViewController(withIdentifier: "AdAdaptiveViewController") as! AdAdaptiveViewController
            self.navigationController?.pushViewController(destination, animated: true)
        case .cpu:
            let destination = mainStoryboard.instantiateViewController(withIdentifier: "CPULoaderViewController") as! CPULoaderViewController
            self.navigationController?.pushViewController(destination, animated: true)
        case .targetingTesting:
            let destination = mainStoryboard.instantiateViewController(withIdentifier: "TargetingTestingViewController") as! TargetingTestingViewController
            self.navigationController?.pushViewController(destination, animated: true)
        case .remoteConfig:
            let destination = mainStoryboard.instantiateViewController(
                withIdentifier: "RemoteConfigViewController"
            ) as! RemoteConfigViewController
            self.navigationController?.pushViewController(destination, animated: true)
        case .stickyAdExample:
            let destination = StickyAdExampleViewController()
            self.navigationController?.pushViewController(destination, animated: true)
        case .longArticleStickyAds:
            let destination = LongArticleStickyAdsViewController()
            self.navigationController?.pushViewController(destination, animated: true)
        case .fixedBanner:
            let destination = FixedBannerViewController()
            self.navigationController?.pushViewController(destination, animated: true)
        case .legacyBanner:
            let destination = LegacyBannerViewController_v0_1_8()
            self.navigationController?.pushViewController(destination, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }
}
