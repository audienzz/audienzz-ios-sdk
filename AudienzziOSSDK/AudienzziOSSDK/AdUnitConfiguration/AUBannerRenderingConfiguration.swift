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
class AUBannerRenderingConfiguration: AUAdUnitConfigurationType {
    
    private var bannerView: BannerView!
    
    init(bannerView: BannerView) {
        self.bannerView = bannerView
    }
}

//MARK: - AUAdUnitConfigurationAppContentProtocol - App Content (app.content.data)
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationAppContentProtocol {
    public func setAppContent(_ appContentObject: AUMORTBAppContent) {
        bannerView.setAppContent(appContentObject.unwrap())
    }
    
    public func getAppContent() -> AUMORTBAppContent? {
        nil
    }
    
    public func clearAppContent() {
        bannerView.clearAppContent()
    }
    
    public func addAppContentData(_ dataObjects: [AUMORTBContentData]) {
        bannerView.addAppContentData(dataObjects.compactMap { $0.unwrap() })
    }
    
    public func removeAppContentData(_ dataObject: AUMORTBContentData) {
        bannerView.removeAppContentDataObject(dataObject.unwrap())
    }
    
    public func clearAppContentData() {
        bannerView.clearAppContent()
    }
}

//MARK: - AUAdUnitConfigurationContextKeywordProtocol - adunit ext keywords (imp[].ext.keywords)
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationContextKeywordProtocol {
    public func addExtKeyword(_ newElement: String) {
        bannerView.addExtKeyword(newElement)
    }

    public func addExtKeywords(_ newElements: Set<String>) {
        bannerView.addExtKeywords(newElements)
    }
    
    public func removeExtKeyword(_ element: String) {
        bannerView.removeExtKeyword(element)
    }

    public func clearExtKeywords() {
        bannerView.clearExtKeywords()
    }
}

// MARK: - User Data (user.data)
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationUserDataProtocol {
    public func getUserData() -> [AUMORTBContentData]? {
        nil
    }

    public func addUserData(_ userDataObjects: [AUMORTBContentData]) {
        bannerView.addUserData(userDataObjects.compactMap { $0.unwrap() })
    }

    public func removeUserData(_ userDataObject: AUMORTBContentData) {
        bannerView.removeUserData(userDataObject.unwrap())
    }
    
    public func clearUserData() {
        bannerView.clearUserData()
    }
}

//MARK: - Data Object
extension AUBannerRenderingConfiguration: AUADunitConfigurationDataObjectProtocol {
    public func addExtData(key: String, value: String) {
        bannerView.addExtData(key: key, value: value)
    }

    public func updateExtData(key: String, value: Set<String>) {
        bannerView.updateExtData(key: key, value: value)
    }

    public func removeExtData(forKey: String) {
        bannerView.removeExtData(forKey: forKey)
    }

    public func clearExtData() {
        bannerView.clearExtData()
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationAutorefreshProtocol {
    public func setAutoRefreshMillis(time: Double) {}
    
    public func stopAutoRefresh() {}
    
    public func resumeAutoRefresh() {}
}

//MARK: - AUAdUnitConfigurationGRIPProtocol
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?) {}
    
    func getGPID() -> String? { nil }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUBannerRenderingConfiguration: AUAdUnitConfigurationSlotProtocol {
    var adSlot: String? {
        get {
            nil
        }
        set {
            
        }
    }
}
