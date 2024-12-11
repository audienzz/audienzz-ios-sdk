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
public class AUTargeting: NSObject {
    
    public static var shared = AUTargeting()
    
    // MARK: - OMID Partner
    
    public var omidPartnerName: String? {
        get { Targeting.shared.omidPartnerName }
        set { Targeting.shared.omidPartnerName = newValue }
    }

    
    public var omidPartnerVersion: String? {
        get { Targeting.shared.omidPartnerVersion }
        set { Targeting.shared.omidPartnerVersion = newValue }
    }
    
    // MARK: - User Information
    
    /**
     Indicates user birth year.
     */
    public var yearOfBirth: Int {
        get { Targeting.shared.getYearOfBirth().intValue }
        set { Targeting.shared.setYearOfBirth(yob: newValue) }
    }
    
    /**
     * This method set the year of birth value
     */
    public func setYearOfBirth(yob: Int) {
        Targeting.shared.setYearOfBirth(yob: yob)
    }
    
    // Objective C API
    public func getYearOfBirth() -> NSNumber {
        Targeting.shared.getYearOfBirth()
    }
    
    /**
     * This method clears year of birth value set by the application developer
     */
    public func clearYearOfBirth() {
        Targeting.shared.clearYearOfBirth()
    }
    
    /**
     Indicates the end-user's gender.
     */
    public var userGender: AUGender {
        get {
            AUGender(with: Targeting.shared.userGender)
        }
        
        set {
            Targeting.shared.userGender = newValue.unwrap()
        }
    }
    
    /**
     String representation of the users gender,
     where “M” = male, “F” = female, “O” = known to be other (i.e., omitted is unknown)
     */
    public func userGenderDescription() -> String? {
        guard let currentValue = Targeting.shared.userGenderDescription() else {
            return nil
        }
        
        return currentValue
    }
    
    /**
     Indicates the customer-provided user ID, if different from the Device ID.
     */
    public var userID: String? {
        get { Targeting.shared.userID }
        set { Targeting.shared.userID = newValue }
    }
    
    /**
     Buyer-specific ID for the user as mapped by the exchange for the buyer.
     */
    public var buyerUID: String? {
        get { Targeting.shared.buyerUID }
        set { Targeting.shared.buyerUID = newValue }
    }
    
    /**
     Optional feature to pass bidder data that was set in the
     exchange’s cookie. The string must be in base85 cookie safe
     characters and be in any format. Proper JSON encoding must
     be used to include “escaped” quotation marks.
     */
    public var userCustomData: String? {
        get { Targeting.shared.buyerUID }
        set { Targeting.shared.buyerUID = newValue }
    }
    
    /**
     Placeholder for User Identity Links.
     The data from this property will be added to usr.ext.eids
     */
    public var eids: [[String : AnyHashable]]? {
        get { Targeting.shared.eids }
        set { Targeting.shared.eids = newValue }
    }
    
    /**
     Placeholder for exchange-specific extensions to OpenRTB.
     */
    public var userExt: [String : AnyHashable]? {
        get { Targeting.shared.userExt }
        set { Targeting.shared.userExt = newValue }
    }
    
    // MARK: - COPPA
    
    /**
     Objective C analog of subjectToCOPPA
     */
    public var coppa: NSNumber? {
        set { Targeting.shared.coppa = newValue }
        get { Targeting.shared.coppa }
    }
    
    /**
     Integer flag indicating if this request is subject to the COPPA regulations
     established by the USA FTC, where 0 = no, 1 = yes
     */
    public var subjectToCOPPA: Bool? {
        set { Targeting.shared.subjectToCOPPA = newValue}
        get { Targeting.shared.subjectToCOPPA }
    }
    
    // MARK: - GDPR
    
    /**
     * The boolean value set by the user to collect user data
     */
    public var subjectToGDPR: Bool? {
        set { Targeting.shared.subjectToGDPR = newValue }
        
        get { Targeting.shared.subjectToGDPR }
    }
    
    public func setSubjectToGDPR(_ newValue: NSNumber?) {
        Targeting.shared.setSubjectToGDPR(newValue)
    }
    
    public func getSubjectToGDPR() -> NSNumber? {
        Targeting.shared.getSubjectToGDPR()
    }
    
    // MARK: - GDPR Consent
    
    /**
     * The consent string for sending the GDPR consent
     */
    public var gdprConsentString: String? {
        set { Targeting.shared.gdprConsentString = newValue }
        get { Targeting.shared.gdprConsentString }
    }
    
    // MARK: - TCFv2
    
    public var purposeConsents: String? {
        set { Targeting.shared.purposeConsents = newValue }
        get { Targeting.shared.purposeConsents }
    }
    
    /*
     Purpose 1 - Store and/or access information on a device
     */
    public func getDeviceAccessConsent() -> Bool? {
        Targeting.shared.getDeviceAccessConsent()
    }
    
    public func getDeviceAccessConsentObjc() -> NSNumber? {
        Targeting.shared.getDeviceAccessConsent() as NSNumber?
    }
    
    public func getPurposeConsent(index: Int) -> Bool? {
        Targeting.shared.getPurposeConsent(index: index)
    }
    
    public func isAllowedAccessDeviceData() -> Bool {
        Targeting.shared.isAllowedAccessDeviceData()
    }
    
    // MARK: - External User Ids
    
    /**
     * This method allows to save External User Id in the User Defaults
     */
    public func storeExternalUserId(_ externalUserId: AUExternalUserId) {
        Targeting.shared.storeExternalUserId(externalUserId.unwrap())
    }
    /**
     * This method allows to get All External User Ids from User Defaults
     */
    public func fetchStoredExternalUserIds()->[AUExternalUserId]? {
        return  Targeting.shared.externalUserIds.compactMap { exid in
            return AUExternalUserId(with: exid)
        }
    }
    
    /**
     * This method allows to get External User Id from User Defaults by passing respective 'source' string as param
     */
    public func fetchStoredExternalUserId(_ source : String)-> AUExternalUserId? {
        guard let externalUserId = Targeting.shared.fetchStoredExternalUserId(source)  else{
            return nil
        }
        return AUExternalUserId(with: externalUserId)
    }
    
    /**
     * This method allows to remove specific External User Id from User Defaults by passing respective 'source' string as param
     */
    public func removeStoredExternalUserId(_ source : String) {
        Targeting.shared.removeStoredExternalUserId(source)
    }
    
    /**
     * This method allows to remove all the External User Ids from User Defaults
     */
    public func removeStoredExternalUserIds() {
        Targeting.shared.removeStoredExternalUserIds()
    }
    
    public func getExternalUserIds() -> [[AnyHashable: Any]]? {
        Targeting.shared.getExternalUserIds()
    }
    
    // MARK: - Application Information
    
    /**
     This is the deep-link URL for the app screen that is displaying the ad. This can be an iOS universal link.
     */
    public var contentUrl: String? {
        get { Targeting.shared.contentUrl }
        set { Targeting.shared.contentUrl = newValue }
    }
    
    /**
     App's publisher name.
     */
    public var publisherName: String? {
        get { Targeting.shared.publisherName }
        set { Targeting.shared.publisherName = newValue }
    }
    
    /**
     ID of publisher app in Apple’s App Store.
     */
    public var sourceapp: String? {
        get { Targeting.shared.sourceapp }
        set { Targeting.shared.sourceapp = newValue }
    }
    
    public var storeURL: String? {
        get { Targeting.shared.storeURL }
        set { Targeting.shared.storeURL = newValue }
    }
    
    public var domain: String? {
        get { Targeting.shared.domain }
        set { Targeting.shared.domain = newValue }
    }
    
    /**
     * The itunes app id for targeting
     */
    public var itunesID: String? {
        get { Targeting.shared.itunesID }
        set { Targeting.shared.itunesID = newValue }
    }
    
    /**
     * The application location for targeting
     */
    public var location: CLLocation? {
        get { Targeting.shared.location }
        set { Targeting.shared.location = newValue }
    }
    
    /**
     * The application location precision for targeting
     */
    public var locationPrecision: Int? {
        get { Targeting.shared.locationPrecision }
        set { Targeting.shared.locationPrecision = newValue }
    }
    
    public func setLocationPrecision(_ newValue: NSNumber?) {
        Targeting.shared.setLocationPrecision(newValue)
    }
    
    public func getLocationPrecision() -> NSNumber? {
        return Targeting.shared.getLocationPrecision() as NSNumber?
    }
    
    // MARK: - Location and connection information
    
    /**
     CLLocationCoordinate2D.
     See CoreLocation framework documentation.
     */
    public var coordinate: NSValue? {
        get { Targeting.shared.coordinate }
        set { Targeting.shared.coordinate = newValue }
    }
    
    
    // MARK: - Public Methods
    
    public func addParam(_ value: String, withName: String?) {
        Targeting.shared.addParam(value, withName: withName)
    }
    
    public func setCustomParams(_ params: [String : String]?) {
        Targeting.shared.setCustomParams(params)
    }
    
    public func addCustomParam(_ value: String, withName: String?) {
        Targeting.shared.addCustomParam(value, withName: withName)
    }
    
    // Store location in the user's section
    public func setLatitude(_ latitude: Double, longitude: Double) {
        Targeting.shared.setLatitude(latitude, longitude: longitude)
    }
    
    // MARK: - Access Control List (ext.prebid.data)
    
    public func addBidderToAccessControlList(_ bidderName: String) {
        Targeting.shared.addBidderToAccessControlList(bidderName)
    }
    
    public func removeBidderFromAccessControlList(_ bidderName: String) {
        Targeting.shared.removeBidderFromAccessControlList(bidderName)
    }
    
    public func clearAccessControlList() {
        Targeting.shared.clearAccessControlList()
    }
    
    public func getAccessControlList() -> [String] {
        Targeting.shared.getAccessControlList()
    }
    
    public var accessControlList: [String] {
        Targeting.shared.accessControlList
    }
    
    // MARK: - Global User Data (user.ext.data)
    
    public func addUserData(key: String, value: String) {
        Targeting.shared.addUserData(key: key, value: value)
    }
    
    public func updateUserData(key: String, value: Set<String>) {
        Targeting.shared.updateUserData(key: key, value: value)
    }
    
    public func removeUserData(for key: String) {
        Targeting.shared.removeUserData(for: key)
    }
    
    public func clearUserData() {
        Targeting.shared.clearUserData()
    }
    
    public func getUserData() -> [String: [String]] {
        Targeting.shared.getUserData()
    }
    
    public var userDataDictionary: [String : [String]] {
        Targeting.shared.userDataDictionary
    }
    
    // MARK: - Global User Keywords (user.keywords)
    
    public func addUserKeyword(_ newElement: String) {
        Targeting.shared.addUserKeyword(newElement)
    }
    
    public func addUserKeywords(_ newElements: Set<String>) {
        Targeting.shared.addUserKeywords(newElements)
    }
    
    public func removeUserKeyword(_ element: String) {
        Targeting.shared.removeUserKeyword(element)
    }
    
    public func clearUserKeywords() {
        Targeting.shared.clearUserKeywords()
    }
    
    public func getUserKeywords() -> [String] {
        Targeting.shared.getUserKeywords()
    }
    
    // MARK: - Global Data (app.ext.data)
    
    public func addAppExtData(key: String, value: String) {
        Targeting.shared.addAppExtData(key: key, value: value)
    }
    
    public func updateAppExtData(key: String, value: Set<String>) {
        Targeting.shared.updateAppExtData(key: key, value: value)
    }
    
    public func removeAppExtData(for key: String) {
        Targeting.shared.removeAppExtData(for: key)
    }
    
    public func clearAppExtData() {
        Targeting.shared.clearAppExtData()
    }
    
    public func getAppExtData() -> [String : [String]] {
        Targeting.shared.getAppExtData()
    }
    
    // MARK: - Global Keywords (app.keywords)
    
    public func addAppKeyword(_ newElement: String) {
        Targeting.shared.addAppKeyword(newElement)
    }
    
    public func addAppKeywords(_ newElements: Set<String>) {
        Targeting.shared.addAppKeywords(newElements)
    }
    
    public func removeAppKeyword(_ element: String) {
        Targeting.shared.removeAppKeyword(element)
    }
    
    public func clearAppKeywords() {
        Targeting.shared.clearAppKeywords()
    }
    
    public func getAppKeywords() -> [String] {
        Targeting.shared.getAppKeywords()
    }
}
