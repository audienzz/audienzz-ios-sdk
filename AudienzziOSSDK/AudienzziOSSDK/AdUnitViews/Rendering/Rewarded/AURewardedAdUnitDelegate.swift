//
//  AURewardedAdUnitDelegate.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 12.04.2024.
//

import PrebidMobile

@objc public protocol AURewardedAdUnitDelegate: NSObjectProtocol {
    ///Called when ad is shoed on display and before load (used for lazy load)
    @objc optional func rewardedAdDidDisplayOnScreen()

    /// Called when an ad is loaded and ready for display
    @objc optional func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit)

    /// Called when user is able to receive a reward from the app
    @objc optional func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit)
    
    /// Called when the load process fails to produce a viable ad
    @objc optional func rewardedAd(_ rewardedAd: RewardedAdUnit,
                                   didFailToReceiveAdWithError error: Error?)

    /// Called when the interstitial view will be launched,  as a result of show() method.
    @objc optional func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit)

    /// Called when the interstial is dismissed by the user
    @objc optional func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit)

    /// Called when an ad causes the sdk to leave the app
    @objc optional func rewardedAdWillLeaveApplication(_ rewardedAd: RewardedAdUnit)

    /// Called when user clicked the ad
    @objc optional func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit)
}
