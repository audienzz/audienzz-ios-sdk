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

@objc public protocol AUAdUnitConfigurationSlotProtocol {
    var pbAdSlot: String? { get set }
}

@objc public protocol AUAdUnitConfigurationAutorefreshProtocol {
    /**
     * This method allows to set the auto refresh period for the demand
     *
     * - Parameter time: refresh time interval
     */
    func setAutoRefreshMillis(time: Double)
    
    /**
     * This method stops the auto refresh of demand
     */
    func stopAutoRefresh()
    
    /**
     * This method resume the auto refresh
     */
    func resumeAutoRefresh()
}

@objc public protocol AUAdUnitConfigurationAppContentProtocol {
    
    func setAppContent(_ appContentObject: AUMORTBAppContent)
    
    func getAppContent() -> AUMORTBAppContent?
    
    func clearAppContent()
    
    func addAppContentData(_ dataObjects: [AUMORTBContentData])
    
    func removeAppContentData(_ dataObject: AUMORTBContentData)
    
    func clearAppContentData()
}

@objc public protocol AUAdUnitConfigurationUserDataProtocol {
    func getUserData() -> [AUMORTBContentData]?

    func addUserData(_ userDataObjects: [AUMORTBContentData])

    func removeUserData(_ userDataObject: AUMORTBContentData)

    func clearUserData()
}

@objc public protocol AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?)

    func getGPID() -> String?
}

@objc public protocol AUAdUnitConfigurationContextKeywordProtocol {
    /**
     * This method obtains the keyword for adunit targeting
     * Inserts the given element in the set if it is not already present.
     */
    func addExtKeyword(_ newElement: String)

    /**
     * This method obtains the keyword set for adunit targeting
     * Adds the elements of the given set to the set.
     */
    func addExtKeywords(_ newElements: Set<String>)
    /**
     * This method allows to remove specific keyword from adunit targeting
     */
    func removeExtKeyword(_ element: String)

    /**
     * This method allows to remove all keywords from the set of adunit targeting
     */
    func clearExtKeywords()
}

@objc public protocol AUADunitConfigurationDataObjectProtocol {
    /**
     * This method obtains the ext data keyword & value for adunit targeting
     * if the key already exists the value will be appended to the list. No duplicates will be added
     */
    func addExtData(key: String, value: String)

    /**
     * This method obtains the ext data keyword & values for adunit targeting
     * the values if the key already exist will be replaced with the new set of values
     */
    func updateExtData(key: String, value: Set<String>)

    /**
     * This method allows to remove specific ext data keyword & values set from adunit targeting
     */
    func removeExtData(forKey: String)

    /**
     * This method allows to remove all ext data set from adunit targeting
     */
    func clearExtData()
}

@objcMembers
public class AUAdUnitConfiguration: NSObject {
    private var adUnit: AdUnit!
    
    public init(adUnit: AdUnit) {
        self.adUnit = adUnit
    }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUAdUnitConfiguration: AUAdUnitConfigurationSlotProtocol {
    
    public var pbAdSlot: String? {
        get { adUnit.pbAdSlot }
        set { adUnit.pbAdSlot = newValue }
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AUAdUnitConfiguration: AUAdUnitConfigurationAutorefreshProtocol {
    public func setAutoRefreshMillis(time: Double) {
        adUnit.setAutoRefreshMillis(time: time)
    }
    
    public func stopAutoRefresh() {
        adUnit.stopAutoRefresh()
    }
    
    public func resumeAutoRefresh() {
        adUnit.resumeAutoRefresh()
    }
}

//MARK: - AUAdUnitConfigurationAppContentProtocol - App Content (app.content.data)
extension AUAdUnitConfiguration: AUAdUnitConfigurationAppContentProtocol {
    public func setAppContent(_ appContentObject: AUMORTBAppContent) {
        adUnit.setAppContent(appContentObject.unwrap())
    }
    
    public func getAppContent() -> AUMORTBAppContent? {
        return AUMORTBAppContent(adUnit.getAppContent())
    }
    
    public func clearAppContent() {
        adUnit.clearAppContent()
    }
    
    public func addAppContentData(_ dataObjects: [AUMORTBContentData]) {
        adUnit.addAppContentData(dataObjects.compactMap { $0.unwrap() })
    }
    
    public func removeAppContentData(_ dataObject: AUMORTBContentData) {
        adUnit.removeAppContentData(dataObject.unwrap())
    }
    
    public func clearAppContentData() {
        adUnit.clearAppContentData()
    }
}

//MARK: - AUAdUnitConfigurationContextKeywordProtocol - adunit ext keywords (imp[].ext.keywords)
extension AUAdUnitConfiguration: AUAdUnitConfigurationContextKeywordProtocol {
    public func addExtKeyword(_ newElement: String) {
        adUnit.addExtKeyword(newElement)
    }

    public func addExtKeywords(_ newElements: Set<String>) {
        adUnit.addExtKeywords(newElements)
    }
    
    public func removeExtKeyword(_ element: String) {
        adUnit.removeExtKeyword(element)
    }

    public func clearExtKeywords() {
        adUnit.clearExtKeywords()
    }
}

// MARK: - User Data (user.data)
extension AUAdUnitConfiguration: AUAdUnitConfigurationUserDataProtocol {
    public func getUserData() -> [AUMORTBContentData]? {
        return adUnit.getUserData()?.compactMap { AUMORTBContentData($0) }
    }

    public func addUserData(_ userDataObjects: [AUMORTBContentData]) {
        adUnit.addUserData(userDataObjects.compactMap { $0.unwrap() })
    }

    public func removeUserData(_ userDataObject: AUMORTBContentData) {
        adUnit.removeUserData(userDataObject.unwrap())
    }
    
    public func clearUserData() {
        adUnit.clearUserData()
    }
}

// MARK: GPID
extension AUAdUnitConfiguration: AUAdUnitConfigurationGRIPProtocol {
    public func setGPID(_ gpid: String?) {
        adUnit.setGPID(gpid)
    }

    public func getGPID() -> String? {
        return adUnit.getGPID()
    }
}

//MARK: - Data Object
extension AUAdUnitConfiguration: AUADunitConfigurationDataObjectProtocol {
    public func addExtData(key: String, value: String) {
        adUnit.addExtData(key: key, value: value)
    }

    public func updateExtData(key: String, value: Set<String>) {
        adUnit.updateExtData(key: key, value: value)
    }

    public func removeExtData(forKey: String) {
        adUnit.removeExtData(forKey: forKey)
    }

    public func clearExtData() {
        adUnit.clearExtData()
    }
}
