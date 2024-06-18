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
class AUInterstitialRenderingConfiguration: AUAdUnitConfigurationType {
    
    private var renderInterAdUnit: InterstitialRenderingAdUnit!
    
    init(adUnit: InterstitialRenderingAdUnit) {
        self.renderInterAdUnit = adUnit
    }
}

//MARK: - AUAdUnitConfigurationAppContentProtocol - App Content (app.content.data)
extension AUInterstitialRenderingConfiguration: AUAdUnitConfigurationAppContentProtocol {
    public func setAppContent(_ appContentObject: AUMORTBAppContent) {
        renderInterAdUnit.setAppContent(appContentObject.unwrap())
    }
    
    public func getAppContent() -> AUMORTBAppContent? {
        nil
    }
    
    public func clearAppContent() {
        renderInterAdUnit.clearAppContent()
    }
    
    public func addAppContentData(_ dataObjects: [AUMORTBContentData]) {
        renderInterAdUnit.addAppContentData(dataObjects.compactMap { $0.unwrap() })
    }
    
    public func removeAppContentData(_ dataObject: AUMORTBContentData) {
        renderInterAdUnit.removeAppContentDataObject(dataObject.unwrap())
    }
    
    public func clearAppContentData() {
        renderInterAdUnit.clearAppContent()
    }
}

//MARK: - AUAdUnitConfigurationContextKeywordProtocol - adunit ext keywords (imp[].ext.keywords)
extension AUInterstitialRenderingConfiguration: AUAdUnitConfigurationContextKeywordProtocol {
    public func addExtKeyword(_ newElement: String) {
        renderInterAdUnit.addExtKeyword(newElement)
    }

    public func addExtKeywords(_ newElements: Set<String>) {
        renderInterAdUnit.addExtKeywords(newElements)
    }
    
    public func removeExtKeyword(_ element: String) {
        renderInterAdUnit.removeExtKeyword(element)
    }

    public func clearExtKeywords() {
        renderInterAdUnit.clearExtKeywords()
    }
}

// MARK: - User Data (user.data)
extension AUInterstitialRenderingConfiguration: AUAdUnitConfigurationUserDataProtocol {
    public func getUserData() -> [AUMORTBContentData]? {
        nil
    }

    public func addUserData(_ userDataObjects: [AUMORTBContentData]) {
        renderInterAdUnit.addUserData(userDataObjects.compactMap { $0.unwrap() })
    }

    public func removeUserData(_ userDataObject: AUMORTBContentData) {
        renderInterAdUnit.removeUserData(userDataObject.unwrap())
    }
    
    public func clearUserData() {
        renderInterAdUnit.clearUserData()
    }
}

//MARK: - Data Object
extension AUInterstitialRenderingConfiguration: AUADunitConfigurationDataObjectProtocol {
    public func addExtData(key: String, value: String) {
        renderInterAdUnit.addExtData(key: key, value: value)
    }

    public func updateExtData(key: String, value: Set<String>) {
        renderInterAdUnit.updateExtData(key: key, value: value)
    }

    public func removeExtData(forKey: String) {
        renderInterAdUnit.removeExtData(forKey: forKey)
    }

    public func clearExtData() {
        renderInterAdUnit.clearExtData()
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AUInterstitialRenderingConfiguration: AUAdUnitConfigurationAutorefreshProtocol {
    public func setAutoRefreshMillis(time: Double) {}
    
    public func stopAutoRefresh() {}
    
    public func resumeAutoRefresh() {}
}

//MARK: - AUAdUnitConfigurationGRIPProtocol
extension AUInterstitialRenderingConfiguration: AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?) {}
    
    func getGPID() -> String? { nil }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUInterstitialRenderingConfiguration: AUAdUnitConfigurationSlotProtocol {
    var adSlot: String? {
        get {
            nil
        }
        set {
            
        }
    }
}
