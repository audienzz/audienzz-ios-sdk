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
import WebKit

//@objcMembers
//public final class AUAdViewUtils: NSObject {
//    private override init() {}
//    
//    @objc
//    public static func findCreativeSize(_ adView: UIView, success: @escaping (CGSize) -> Void, failure: @escaping (Error) -> Void) {
//        AdViewUtils.findPrebidCreativeSize(adView, success: success, failure: failure)
//    }
//}

@objcMembers
public final class AUAdViewUtils: NSObject {

    private static let innerHtmlScript = "document.body.innerHTML"
    private static let sizeValueRegexExpression = "[0-9]+x[0-9]+"
    private static let sizeObjectRegexExpression = "hb_size\\W+\(sizeValueRegexExpression)" //"hb_size\\W+[0-9]+x[0-9]+"
    private static let sizeObjectRegexExpressionOtherWay = #"width:\d+px;height:\d+px;"# //"hb_size\\W+[0-9]+x[0-9]+"
    
    private override init() {}
    
    @objc
    public static func findCreativeSize(_ adView: UIView, success: @escaping (CGSize) -> Void, failure: @escaping (Error) -> Void) {
        
        let view = self.findView(adView) { (subView) -> Bool in
            return isWKWebView(subView)
        }
        
        if let wkWebView = view as? WKWebView  {
            Log.debug("subView is WKWebView")
            self.findSizeInWebViewAsync(wkWebView: wkWebView, success: success, failure: failure)
            
        } else {
            warnAndTriggerFailure(AUFindSizeErrorFactory.noWKWebView, failure: failure)
        }
    }
    
    static func triggerSuccess(size: CGSize, success: @escaping (CGSize) -> Void) {
        success(size)
    }
    
    static func warnAndTriggerFailure(_ error: AUFindSizeError, failure: @escaping (AUFindSizeError) -> Void) {
        Log.warn(error.localizedDescription)
        failure(error)
    }
    
    static func findView(_ view: UIView, closure:(UIView) -> Bool) -> UIView? {
        if closure(view)  {
            return view
        } else {
            return recursivelyFindView(view, closure: closure)
        }
    }
    
    static func recursivelyFindView(_ view: UIView, closure:(UIView) -> Bool) -> UIView? {
        for subview in view.subviews {
            
            if closure(subview)  {
                return subview
            }
            
            if let result = recursivelyFindView(subview, closure: closure) {
                return result
            }
        }
        
        return nil
    }
    
    static func findSizeInWebViewAsync(wkWebView: WKWebView, success: @escaping (CGSize) -> Void, failure: @escaping (AUFindSizeError) -> Void) {
        
        wkWebView.evaluateJavaScript(AUAdViewUtils.innerHtmlScript, completionHandler: { (value: Any!, error: Error!) -> Void in
            
            if error != nil {
                self.warnAndTriggerFailure(AUFindSizeErrorFactory.getWkWebViewFailedError(message: error.localizedDescription), failure: failure)
                return
            }
            
            self.findSizeInHtml(body: value as? String, success: success, failure: failure)
        })
    }
    
    static func findSizeInHtml(body: String?, success: @escaping (CGSize) -> Void, failure: @escaping (AUFindSizeError) -> Void) {
        let result = findSizeInHtml(body: body)
        
        if let size = result.size {
            triggerSuccess(size: size, success: success)
        } else if let error = result.error {
            warnAndTriggerFailure(error, failure: failure)
        } else {
            Log.error("The bouth values size and error are nil")
            warnAndTriggerFailure(AUFindSizeErrorFactory.unspecified, failure: failure)
        }
    }
    
    static func findSizeInHtml(body: String?) -> (size: CGSize?, error: AUFindSizeError?) {
        guard let htmlBody = body, !htmlBody.isEmpty else {
            return (nil, AUFindSizeErrorFactory.noHtml)
        }
        
        guard let hbSizeObject = findHbSizeObject(in: htmlBody) else {
            if let hbSizeObject = onaterWaytoFindSizeObject(in: htmlBody) {
                if let maybeSize = otherWayStringToSize(in: hbSizeObject) {
                    return (maybeSize, nil)
                } else {
                    return (nil, AUFindSizeErrorFactory.sizeUnparsed)
                }
            } else {
                return (nil, AUFindSizeErrorFactory.noSizeObject)
            }
        }
        
        guard let hbSizeValue = findHbSizeValue(in: hbSizeObject) else {
            return (nil, AUFindSizeErrorFactory.noSizeValue)
        }
        
        let maybeSize = stringToCGSize(hbSizeValue)
        if let size = maybeSize {
            return (size, nil)
        } else {
            return (nil, AUFindSizeErrorFactory.sizeUnparsed)
        }
    }
    
    static func onaterWaytoFindSizeObject(in text: String) -> String? {
        return onatherWayMatchAndCheck(regex: AUAdViewUtils.sizeObjectRegexExpressionOtherWay, text: text)
    }
    
    static func otherWayStringToSize(in styleString: String) -> CGSize? {
        let pattern = #"width:(\d+)px;height:(\d+)px;"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            if let match = regex.firstMatch(in: styleString, options: [], range: NSRange(location: 0, length: styleString.utf16.count)) {
                
                if let widthRange = Range(match.range(at: 1), in: styleString),
                   let width = Double(styleString[widthRange]) {

                    if let heightRange = Range(match.range(at: 2), in: styleString),
                       let height = Double(styleString[heightRange]) {

                        let size = CGSize(width: width, height: height)
                        return size
                    }
                }
            }
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return nil
        }

        return nil
    }
    
    static func findHbSizeObject(in text: String) -> String? {
        return matchAndCheck(regex: AUAdViewUtils.sizeObjectRegexExpression, text: text)
    }
    
    static func findHbSizeValue(in hbSizeObject: String) -> String? {
        return matchAndCheck(regex: AUAdViewUtils.sizeValueRegexExpression, text: hbSizeObject)
    }
    
    static func isWKWebView(_ view: UIView) -> Bool {
        return view is WKWebView
    }
    
    static func matchAndCheck(regex: String, text: String) -> String? {
        let matched = matches(for: regex, in: text)
        
        if matched.isEmpty {
            return nil
        }
        
        let firstResult = matched[0]
        
        return firstResult
    }
    
    static func onatherWayMatchAndCheck(regex: String, text: String) -> String? {
        let matched = matches(for: regex, in: text)
        
        if matched.isEmpty {
            return nil
        }
        
        let firstResult = matched[0]
        
        return firstResult
    }
    
    static func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            Log.warn("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    static func stringToCGSize(_ size: String) -> CGSize? {
        
        let sizeArr = size.split{$0 == "x"}.map(String.init)
        guard sizeArr.count == 2 else {
            Log.warn("\(size) has a wrong format")
            return nil
        }
        
        let nsNumberWidth = NumberFormatter().number(from: sizeArr[0])
        let nsNumberHeight = NumberFormatter().number(from: sizeArr[1])
        
        guard let numberWidth = nsNumberWidth, let numberHeight = nsNumberHeight else {
            Log.warn("\(size) can not be converted to CGSize")
            return nil
        }
        
        let width = CGFloat(truncating: numberWidth)
        let height = CGFloat(truncating: numberHeight)
        
        let gcSize = CGSize(width: width, height: height)
        
        return gcSize
    }

}

//It is not possible to use Enum because of compatibility with Objective-C
final class AUFindSizeErrorFactory {
    
    private init() {}
    
    // MARK: - Platform's errors
    static let unspecifiedCode = 101
    
    // MARK: - common errors
    static let noWKWebViewCode = 111
    static let wkWebViewFailedCode = 126
    static let noHtmlCode = 130
    static let noSizeObjectCode = 140
    static let noSizeValueCode = 150
    static let sizeUnparsedCode = 160
    
    //MARK: - fileprivate and private zone
    fileprivate static let unspecified = getUnspecifiedError()
    fileprivate static let noWKWebView = getNoWKWebViewError()
    fileprivate static let noHtml = getNoHtmlError()
    fileprivate static let noSizeObject = getNoSizeObjectError()
    fileprivate static let noSizeValue = getNoSizeValueError()
    fileprivate static let sizeUnparsed = getSizeUnparsedError()
    
    private static func getUnspecifiedError() -> AUFindSizeError{
        return getError(code: unspecifiedCode, description: "Unspecified error")
    }
    
    private static func getNoWKWebViewError() -> AUFindSizeError {
        return getError(code: noWKWebViewCode, description: "The view doesn't include WKWebView")
    }
    
    fileprivate static func getWkWebViewFailedError(message: String) -> AUFindSizeError {
        return getError(code: wkWebViewFailedCode, description: "WKWebView error:\(message)")
    }
    
    private static func getNoHtmlError() -> AUFindSizeError {
        return getError(code: noHtmlCode, description: "The WebView doesn't have HTML")
    }
    
    private static func getNoSizeObjectError() -> AUFindSizeError {
        return getError(code: noSizeObjectCode, description: "The HTML doesn't contain a size object")
    }
    
    private static func getNoSizeValueError() -> AUFindSizeError {
        return getError(code: noSizeValueCode, description: "The size object doesn't contain a value")
    }
    
    private static func getSizeUnparsedError() -> AUFindSizeError {
        return getError(code: sizeUnparsedCode, description: "The size value has a wrong format")
    }
    
    private static func getError(code: Int, description: String) -> AUFindSizeError {
        return AUFindSizeError(domain: "com.prebidmobile.ios", code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
}

class AUFindSizeError: NSError {
    convenience init(code: Int, userInfo dict: [String : Any]? = nil) {
        self.init()
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
