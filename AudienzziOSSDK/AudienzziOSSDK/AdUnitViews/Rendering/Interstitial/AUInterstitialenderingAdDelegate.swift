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

@objc public protocol AUInterstitialenderingAdDelegate: NSObjectProtocol {
    ///Called when ad is shoed on display and before load (used for lazy load)
    @objc optional func interstitialAdDidDisplayOnScreen()

    /// Called when an ad is loaded and ready for display
    @objc optional func interstitialDidReceiveAd()

    /// Called when the load process fails to produce a viable ad
    @objc optional func interstitialDidFailToReceiveAdWithError(error: Error?)

    /// Called when the interstitial view will be launched,  as a result of show() method.
    @objc optional func interstitialWillPresentAd()

    /// Called when the interstitial is dismissed by the user
    @objc optional func interstitialDidDismissAd()

    /// Called when an ad causes the sdk to leave the app
    @objc optional func interstitialWillLeaveApplication()

    /// Called when user clicked the ad
    @objc optional func interstitialDidClickAd()
}
