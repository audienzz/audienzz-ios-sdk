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
    private var prebidAdUnit: PrebidAdUnit?
    private var prebidRequest: PrebidRequest?
    
    init(adUnit: AdUnit) {
        self.adUnit = adUnit
    }
    
    init(multiplatformAdUnit: PrebidAdUnit, request: PrebidRequest) {
        self.prebidAdUnit = multiplatformAdUnit
        self.prebidRequest = request
    }
}

//MARK: - AUAdUnitConfigurationSlotProtocol
extension AUAdUnitConfiguration: AUAdUnitConfigurationSlotProtocol {
    
    public var pbAdSlot: String? {
        get { get_pbAdSlot() }
        set { set_pbAdSlot(newValue: newValue) }
    }
    
    public func get_pbAdSlot() -> String? {
        guard let multiplatformAdUnit = prebidAdUnit else {
            return adUnit.pbAdSlot
        }
        
        return multiplatformAdUnit.pbAdSlot
    }
    public func set_pbAdSlot(newValue: String?) {
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.pbAdSlot = newValue
            return
        }
        
        multiplatformAdUnit.pbAdSlot = newValue
    }
}

//MARK: - AUAdUnitConfigurationAutorefreshProtocol
extension AUAdUnitConfiguration: AUAdUnitConfigurationAutorefreshProtocol {
    public func setAutoRefreshMillis(time: Double) {
        setAutorefresh(time: time)
    }
    
    public func stopAutoRefresh() {
        stop()
    }
    
    public func resumeAutoRefresh() {
        resume()
    }
    
    private func setAutorefresh(time: Double) {
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.setAutoRefreshMillis(time: time)
            return
        }
        
        multiplatformAdUnit.setAutoRefreshMillis(time: time)
    }
    
    private func stop() {
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.stopAutoRefresh()
            return
        }
        
        multiplatformAdUnit.stopAutoRefresh()
    }
    
    private func resume() {
        guard let multiplatformAdUnit = prebidAdUnit else {
            adUnit.resumeAutoRefresh()
            return
        }
        
        multiplatformAdUnit.resumeAutoRefresh()
    }
}

//MARK: - AUAdUnitConfigurationAppContentProtocol - App Content (app.content.data)
extension AUAdUnitConfiguration: AUAdUnitConfigurationAppContentProtocol {
    public func setAppContent(_ appContentObject: AUMORTBAppContent) {
        set_AppContent(appContentObject)
    }
    
    public func getAppContent() -> AUMORTBAppContent? {
        get_AppContent()
    }
    
    public func clearAppContent() {
        clear_AppContent()
    }
    
    public func addAppContentData(_ dataObjects: [AUMORTBContentData]) {
        add_AppContentData(dataObjects)
    }
    
    public func removeAppContentData(_ dataObject: AUMORTBContentData) {
        remove_AppContentData(dataObject)
    }
    
    public func clearAppContentData() {
        clear_AppContentData()
    }
    
    private func set_AppContent(_ appContentObject: AUMORTBAppContent) {
        guard let request = prebidRequest else {
            adUnit.setAppContent(appContentObject.unwrap())
            return
        }

        request.setAppContent(appContentObject.unwrap())
    }
    
    private func get_AppContent() -> AUMORTBAppContent? {
        guard let request = prebidRequest else {
            return AUMORTBAppContent(adUnit.getAppContent())
        }

        return nil
    }
    
    private func clear_AppContent() {
        guard let request = prebidRequest else {
            adUnit.clearAppContent()
            return
        }

        request.clearAppContent()
    }
    
    private func add_AppContentData(_ dataObjects: [AUMORTBContentData]) {
        guard let request = prebidRequest else {
            adUnit.addAppContentData(dataObjects.compactMap { $0.unwrap() })
            return
        }
        
        request.addAppContentData(dataObjects.compactMap { $0.unwrap() })
    }
    
    private func remove_AppContentData(_ dataObject: AUMORTBContentData) {
        guard let request = prebidRequest else {
            adUnit.removeAppContentData(dataObject.unwrap())
            return
        }
        
        request.removeAppContentData(dataObject.unwrap())
    }
    
    private func clear_AppContentData() {
        guard let request = prebidRequest else {
            adUnit.clearAppContentData()
            return
        }
        
        request.clearAppContentData()
    }
}

//MARK: - AUAdUnitConfigurationContextKeywordProtocol - adunit ext keywords (imp[].ext.keywords)
extension AUAdUnitConfiguration: AUAdUnitConfigurationContextKeywordProtocol {
    public func addExtKeyword(_ newElement: String) {
        add_ExtKeyword(newElement)
    }

    public func addExtKeywords(_ newElements: Set<String>) {
        add_ExtKeywords(newElements)
    }
    
    public func removeExtKeyword(_ element: String) {
        remove_ExtKeyword(element)
    }

    public func clearExtKeywords() {
        clear_ExtKeywords()
    }
    
    private func add_ExtKeyword(_ newElement: String) {
        guard let request = prebidRequest else {
            adUnit.addExtKeyword(newElement)
            return
        }
        
        request.addExtKeyword(newElement)
    }

    private func add_ExtKeywords(_ newElements: Set<String>) {
        guard let request = prebidRequest else {
            adUnit.addExtKeywords(newElements)
            return
        }

        request.addExtKeywords(newElements)
    }
    
    private func remove_ExtKeyword(_ element: String) {
        guard let request = prebidRequest else {
            adUnit.removeExtKeyword(element)
            return
        }

        request.removeExtKeyword(element)
    }

    private func clear_ExtKeywords() {
        guard let request = prebidRequest else {
            adUnit.clearExtKeywords()
            return
        }
        
        request.clearExtKeywords()
    }
}

// MARK: - User Data (user.data)
extension AUAdUnitConfiguration: AUAdUnitConfigurationUserDataProtocol {
    public func getUserData() -> [AUMORTBContentData]? {
        get_UserData()
    }

    public func addUserData(_ userDataObjects: [AUMORTBContentData]) {
        add_UserData(userDataObjects)
    }

    public func removeUserData(_ userDataObject: AUMORTBContentData) {
        remove_UserData(userDataObject)
    }
    
    public func clearUserData() {
        clear_UserData()
    }
    
    private func get_UserData() -> [AUMORTBContentData]? {
        guard let request = prebidRequest else {
            return adUnit.getUserData()?.compactMap { AUMORTBContentData($0) }
        }
        
        return nil
    }

    private func add_UserData(_ userDataObjects: [AUMORTBContentData]) {
        guard let request = prebidRequest else {
            adUnit.addUserData(userDataObjects.compactMap { $0.unwrap() })
            return
        }
        
        request.addUserData(userDataObjects.compactMap { $0.unwrap() })
    }

    private func remove_UserData(_ userDataObject: AUMORTBContentData) {
        guard let request = prebidRequest else {
            adUnit.removeUserData(userDataObject.unwrap())
            return
        }
        
        request.removeUserData(userDataObject.unwrap())
    }
    
    private func clear_UserData() {
        guard let request = prebidRequest else {
            adUnit.clearUserData()
            return
        }
        
        request.clearUserData()
    }
}

// MARK: GPID
extension AUAdUnitConfiguration: AUAdUnitConfigurationGRIPProtocol {
    public func setGPID(_ gpid: String?) {
        set_GPID(gpid)
    }

    public func getGPID() -> String? {
        get_GPID()
    }
    
    private func set_GPID(_ gpid: String?) {
        guard let request = prebidRequest else {
            adUnit.setGPID(gpid)
            return
        }
        
        request.setGPID(gpid)
    }

    private func get_GPID() -> String? {
        guard let request = prebidRequest else {
            return adUnit.getGPID()
        }
        
        return nil
    }
}

//MARK: - Data Object
extension AUAdUnitConfiguration: AUADunitConfigurationDataObjectProtocol {
    public func addExtData(key: String, value: String) {
        add_ExtData(key: key, value: value)
    }

    public func updateExtData(key: String, value: Set<String>) {
        update_ExtData(key: key, value: value)
    }

    public func removeExtData(forKey: String) {
        remove_ExtData(forKey: forKey)
    }

    public func clearExtData() {
        clear_ExtData()
    }
    
    private func add_ExtData(key: String, value: String) {
        guard let request = prebidRequest else {
            adUnit.addExtData(key: key, value: value)
            return
        }
        
        request.addExtData(key: key, value: value)
    }

    private func update_ExtData(key: String, value: Set<String>) {
        guard let request = prebidRequest else {
            adUnit.updateExtData(key: key, value: value)
            return
        }
        
        request.updateExtData(key: key, value: value)
    }

    private func remove_ExtData(forKey: String) {
        guard let request = prebidRequest else {
            adUnit.removeExtData(forKey: forKey)
            return
        }
        
        request.removeExtData(forKey: forKey)
    }

    private func clear_ExtData() {
        guard let request = prebidRequest else {
            adUnit.clearExtData()
            return
        }
        
        request.clearExtData()
    }
}
