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

import UIKit
import PrebidMobile

fileprivate let adTypeString = "BANNER"
fileprivate let apiTypeString = "ORIGINAL"

@objc
extension AUBannerView {
    override func detectVisible() {
        guard isLazyLoad, !isLazyLoaded, let request = gamRequest else {
            return
        }

#if DEBUG
        AULogEvent.logDebug("AUBannerView --- I'm visible")
#endif
        fetchRequest(request)
        isLazyLoaded = true
    }

    override func fetchRequest(_ gamRequest: AnyObject) {
        makeRequestEvent()
        adUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            guard self.adUnit != nil else { return }

            if let bidRequester = getPrivateBidRequester(from: adUnit) {
                print("Got bidRequester: \(bidRequester)")

                bidRequester.requestBids { bidResponse, error in
                    guard let bidResponse else { return }
                    print(bidResponse)
                }
            } else {
                print("Failed to access bidRequester")
            }

            AULogEvent.logDebug("Audienz demand fetch for GAM \(resultCode.name())")
            self.makeWinnerEvent(AUResulrCodeConverter.convertResultCodeName(resultCode))
            self.isInitialAutorefresh = false
            self.onLoadRequest?(gamRequest)
        }
    }

    private func isVisible(view: UIView) -> Bool {
        func isVisible(view: UIView, inView: UIView?) -> Bool {
            guard let inView = inView else { return true }
            let viewFrame = inView.convert(view.bounds, from: view)
            if viewFrame.intersects(inView.bounds) {
                return isVisible(view: view, inView: inView.superview)
            }
            return false
        }
        return isVisible(view: view, inView: view.superview)
    }

    private func makeRequestEvent() {
        guard let autorefreshM = adUnitConfiguration as? AUAdUnitConfigurationEventProtocol,
              let adUnitID = eventHandler?.adUnitID else { return }

        let event = AUBidRequestEvent(adViewId: configId,
                                      adUnitID: adUnitID,
                                      size: AUUniqHelper.sizeMaker(adSize),
                                      isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
                                      autorefreshTime: Int(autorefreshM.autorefreshEventModel.autorefreshTime),
                                      initialRefresh: isInitialAutorefresh,
                                      adType: adTypeString,
                                      adSubType: makeAdSubType(),
                                      apiType: apiTypeString)

        guard let payload = event.convertToJSONString() else { return }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }

    private func makeWinnerEvent(_ resultCode: String) {
        AULogEvent.logDebug("makeWinnerEvent")
        guard let autorefreshM = adUnitConfiguration as? AUAdUnitConfigurationEventProtocol,
              let adUnitID = eventHandler?.adUnitID else { return }

        let event = AUBidWinnerEvent(resultCode: resultCode,
                                     adUnitID: adUnitID,
                                     targetKeywords: [:],
                                     isAutorefresh: autorefreshM.autorefreshEventModel.isAutorefresh,
                                     autorefreshTime: Int(autorefreshM.autorefreshEventModel.autorefreshTime),
                                     initialRefresh: isInitialAutorefresh,
                                     adViewId: configId,
                                     size: AUUniqHelper.sizeMaker(adSize),
                                     adType: adTypeString,
                                     adSubType: makeAdSubType(),
                                     apiType: apiTypeString)

        guard let payload = event.convertToJSONString() else { return }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }

    private func makeAdSubType() -> String {
        if adUnit.adFormats.count >= 2 {
            return "MULTIFORMAT"
        } else if adUnit.adFormats.contains(where: { $0.rawValue == 1 }) && adUnit.adFormats.count == 1 {
            return "HTML"
        } else if adUnit.adFormats.contains(where: { $0.rawValue == 2 }) && adUnit.adFormats.count == 1 {
            return "VIDEO"
        }

        return ""
    }

    internal func makeCreationEvent() {
        let event = AUAdCreationEvent(adViewId: configId,
                                      adUnitID: eventHandler?.adUnitID ?? "-1",
                                      size: AUUniqHelper.sizeMaker(adSize),
                                      adType: adTypeString,
                                      adSubType: makeAdSubType(),
                                      apiType: apiTypeString)

        guard let payload = event.convertToJSONString() else { return }

        AUEventsManager.shared.addEvent(event: AUEventDB(payload))
    }

    // Function to access private property via Objective-C runtime
    func getPrivateBidRequester(from object: AnyObject) -> PBMBidRequesterProtocol? {
        let objectClass: AnyClass = object_getClass(object)!

        // Get the instance variable for "bidRequester"
        if let ivar = class_getInstanceVariable(objectClass, "bidRequester") {
            // Get the value of the instance variable
            return object_getIvar(object, ivar) as? PBMBidRequesterProtocol
        }

        return nil
    }
}

protocol Reflectable: AnyObject {
    func reflected() -> [String: Any?]
}

extension Reflectable {

    func reflected() -> [String: Any?] {
        let mirror = Mirror(reflecting: self)
        var dict: [String: Any?] = [:]
        for child in mirror.children {
            guard let key = child.label else {
                continue
            }
            dict[key] = child.value
        }
        return dict
    }

    var reflectedString: String {
        let reflection = reflected()
        var result = String(describing: self)
        result += " { \n"
        for (key, val) in reflection {
            result += "\t\(key): \(val ?? "null")\n"
        }
        return result + "}"
    }

}

extension Reflectable where Self: NSObject {

    func reflected() -> [String : Any?] {

        var count: UInt32 = 0

        guard let properties = class_copyPropertyList(Self.self, &count) else {
            return [:]
        }

        var dict: [String: Any] = [:]
        for i in 0..<Int(count) {
            let name = property_getName(properties[i])
            guard let nsKey = NSString(utf8String: name) else {
                continue
            }
            let key = nsKey as String
            guard responds(to: Selector(key)) else {
                continue
            }
            dict[key] = value(forKey: key)
        }
        free(properties)

        return dict
    }
}