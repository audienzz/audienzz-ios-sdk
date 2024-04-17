//
//  AUAdViewUtils.swift
//  AudienzziOSSDK
//
//  Created by Konstantin Vasyliev on 05.04.2024.
//

import UIKit
import PrebidMobile

public final class AUAdViewUtils: NSObject {
    private override init() {}
    
    @objc
    public static func findCreativeSize(_ adView: UIView, success: @escaping (CGSize) -> Void, failure: @escaping (Error) -> Void) {
        AdViewUtils.findPrebidCreativeSize(adView, success: success, failure: failure)
    }
}


@objcMembers
public final class AUIMAUtils: NSObject {
    @objc public static let shared = AUIMAUtils()
    
    private override init() {}
    
    @objc public func generateInstreamUriForGAM(adUnitID: String, adSlotSizes: [IMAAdSlotSize], customKeywords: [String:String]?) throws -> String {
        try IMAUtils.shared.generateInstreamUriForGAM(adUnitID: adUnitID, adSlotSizes: adSlotSizes, customKeywords: customKeywords!)
    }
}
