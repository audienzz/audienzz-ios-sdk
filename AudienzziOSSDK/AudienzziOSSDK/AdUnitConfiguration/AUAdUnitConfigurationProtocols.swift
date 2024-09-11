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

@objc public protocol AUAdUnitConfigurationType: AUAdUnitConfigurationSlotProtocol,
                                                 AUAdUnitConfigurationAutorefreshProtocol,
                                                 AUAdUnitConfigurationAppContentProtocol,
                                                 AUAdUnitConfigurationUserDataProtocol,
                                                 AUAdUnitConfigurationGRIPProtocol,
                                                 AUAdUnitConfigurationContextKeywordProtocol,
                                                 AUADunitConfigurationDataObjectProtocol {}

/// Ad Slot is an identifier tied to the placement the ad will be delivered in
@objc public protocol AUAdUnitConfigurationSlotProtocol {
    var adSlot: String? { get set }
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

/// The ContentObject allows you to provide more details about content within the app. All properties provided to the ContentObject will be sent in the app.content field of the bid request
/// Using the following methods you can add app.content.data objects to the bid requests.
@objc public protocol AUAdUnitConfigurationAppContentProtocol {
    
    func setAppContent(_ appContentObject: AUMORTBAppContent)
    
    func getAppContent() -> AUMORTBAppContent?
    
    func clearAppContent()
    
    func addAppContentData(_ dataObjects: [AUMORTBContentData])
    
    func removeAppContentData(_ dataObject: AUMORTBContentData)
    
    func clearAppContentData()
}

/// Using the following methods you can add user.data objects to the bid requests.
@objc public protocol AUAdUnitConfigurationUserDataProtocol {
    func getUserData() -> [AUMORTBContentData]?

    func addUserData(_ userDataObjects: [AUMORTBContentData])

    func removeUserData(_ userDataObject: AUMORTBContentData)

    func clearUserData()
}

/// Using the following method, you can set the impression-level GPID value to the bid request:
@objc public protocol AUAdUnitConfigurationGRIPProtocol {
    func setGPID(_ gpid: String?)

    func getGPID() -> String?
}

/// Ad Unit context keywords object is a free form list of comma separated keywords about the app as defined in app.keyword in OpenRTB 2.5. The addContextKeyword function adds a single keyword to the ad unit.
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

/**
 The Data object is free form data (also known as First Party Data) supplied by the publisher to provide additional targeting of the user or inventory context, used primarily for striking PMP (Private MarketPlace) deals with Advertisers. Data supplied in the data parameters are typically not sent to DSPs whereas information sent in non-data objects (i.e. setYearOfBirth, setGender, etc.) will be. Access to FPD can be limited to a supplied set of Prebid bidders via an access control list.

 Data is broken up into two different data types:

 User
 Global in scope only
 Inventory (context)
 Global scope
 Ad Unit grain
 */
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

internal protocol AUAdUnitConfigurationEventProtocol {
    var autorefreshEventModel: AutorefreshEventModel { get set }
}
