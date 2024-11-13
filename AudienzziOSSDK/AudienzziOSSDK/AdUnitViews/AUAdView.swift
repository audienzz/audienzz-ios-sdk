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

@objcMembers
public class AUAdView: VisibleView {
    var isLazyLoaded: Bool = false
    private(set) var isLazyLoad: Bool
    private(set) var configId: String
    private(set) var adSize: CGSize
    
    public var adUnitConfiguration: AUAdUnitConfigurationType!
    public var onLoadRequest: ((AnyObject) -> Void)?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public init(configId: String, adSize: CGSize, isLazyLoad: Bool) {
        self.configId = configId
        self.adSize = adSize
        self.isLazyLoad = isLazyLoad
        super.init(frame: .zero)
    }
    
    public init(configId: String, isLazyLoad: Bool) {
        self.configId = configId
        self.adSize = .zero
        self.isLazyLoad = isLazyLoad
        super.init(frame: .zero)
    }
    
    public init(configId: String, adSize: CGSize) {
        self.configId = configId
        self.adSize = adSize
        self.isLazyLoad = false
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        self.configId = ""
        self.adSize = .zero
        self.isLazyLoad = false
        super.init(coder: coder)
    }
    
    public func setupConfigId(_ configId: String) {
        self.configId = configId
    }
    
    internal dynamic func fetchRequest(_ gamRequest: AnyObject) {}
    internal var isInitialAutorefresh: Bool = true
    
    internal func unwrapAdFormat(_ formats: [AUAdFormat]) -> [AdFormat] {
        formats.compactMap { element in
            switch element {
            case .banner:
                return AdFormat.banner
            case .video:
                return AdFormat.video
            case .native:
                return AdFormat.native
            default:
                return nil
            }
        }
    }
    
    public func collapseBehaviour(forView: UIView) {
        for subview in self.subviews {
            subview.removeFromSuperview()
        }
        let origin = self.frame.origin
        self.frame = CGRect(x: origin.x, y: origin.y, width: 0, height: 0)
    }
    
    internal func defaultVideoParameters() -> VideoParameters {
        let videoParameters = VideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [Signals.Protocols.VAST_2_0]
        videoParameters.playbackMethod = [Signals.PlaybackMethod.AutoPlaySoundOff]
        videoParameters.placement = Signals.Placement.InBanner
        return videoParameters
    }
}
