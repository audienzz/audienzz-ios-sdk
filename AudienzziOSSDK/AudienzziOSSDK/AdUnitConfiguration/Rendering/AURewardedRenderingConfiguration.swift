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

import Foundation
import PrebidMobile

@objcMembers
class AURewardedRenderingConfiguration: AUAdUnitConfigurationType {
    
    private var rewardedAdUnit: RewardedAdUnit!

    init(adUnit: RewardedAdUnit) {
        self.rewardedAdUnit = adUnit
    }
}

//MARK: - AUAdUnitConfigurationAppContentProtocol - App Content (app.content.data)
extension AURewardedRenderingConfiguration: AUAdUnitConfigurationAppContentProtocol {
    public func setAppContent(_ appContentObject: AUMORTBAppContent) {
        rewardedAdUnit.setAppContent(appContentObject.unwrap())
    }
    
    public func getAppContent() -> AUMORTBAppContent? {
        nil
    }
    
    public func clearAppContent() {
        rewardedAdUnit.clearAppContent()
    }
    
    public func addAppContentData(_ dataObjects: [AUMORTBContentData]) {
        rewardedAdUnit.addAppContentData(dataObjects.compactMap { $0.unwrap() })
    }
    
    public func removeAppContentData(_ dataObject: AUMORTBContentData) {
        rewardedAdUnit.removeAppContentDataObject(dataObject.unwrap())
    }
    
    public func clearAppContentData() {
        rewardedAdUnit.clearAppContent()
    }
}

//MARK: - AUAdUnitConfigurationContextKeywordProtocol - adunit ext keywords (imp[].ext.keywords)
extension AURewardedRenderingConfiguration: AUAdUnitConfigurationContextKeywordProtocol {
    public func addExtKeyword(_ newElement: String) {
        rewardedAdUnit.addExtKeyword(newElement)
    }

    public func addExtKeywords(_ newElements: Set<String>) {
        rewardedAdUnit.addExtKeywords(newElements)
    }
    
    public func removeExtKeyword(_ element: String) {
        rewardedAdUnit.removeExtKeyword(element)
    }

    public func clearExtKeywords() {
        rewardedAdUnit.clearExtKeywords()
    }
}

// MARK: - User Data (user.data)
extension AURewardedRenderingConfiguration: AUAdUnitConfigurationUserDataProtocol {
    public func getUserData() -> [AUMORTBContentData]? {
        nil
    }

    public func addUserData(_ userDataObjects: [AUMORTBContentData]) {
        rewardedAdUnit.addUserData(userDataObjects.compactMap { $0.unwrap() })
    }

    public func removeUserData(_ userDataObject: AUMORTBContentData) {
        rewardedAdUnit.removeUserData(userDataObject.unwrap())
    }
    
    public func clearUserData() {
        rewardedAdUnit.clearUserData()
    }
}

//MARK: - Data Object
extension AURewardedRenderingConfiguration: AUADunitConfigurationDataObjectProtocol {
    public func addExtData(key: String, value: String) {
        rewardedAdUnit.addExtData(key: key, value: value)
    }

    public func updateExtData(key: String, value: Set<String>) {
        rewardedAdUnit.updateExtData(key: key, value: value)
    }

    public func removeExtData(forKey: String) {
        rewardedAdUnit.removeExtData(forKey: forKey)
    }

    public func clearExtData() {
        rewardedAdUnit.clearExtData()
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AURewardedRenderingConfiguration: AUAdUnitConfigurationAutorefreshProtocol {
    public func setAutoRefreshMillis(time: Double) {}
    
    public func stopAutoRefresh() {}
    
    public func resumeAutoRefresh() {}
}

//MARK: - AUAdUnitConfigurationGRIPProtocol
extension AURewardedRenderingConfiguration: AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?) {}
    
    func getGPID() -> String? { nil }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AURewardedRenderingConfiguration: AUAdUnitConfigurationSlotProtocol {
    var adSlot: String? {
        get {
            nil
        }
        set {
            
        }
    }
}
