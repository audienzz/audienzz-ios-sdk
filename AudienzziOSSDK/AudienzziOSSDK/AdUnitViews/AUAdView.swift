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

public class AUAdView: VisibleView {
    var isLazyLoaded: Bool = false
    private(set) var isLazyLoad: Bool
    private(set) var configId: String
    private(set) var adSize: CGSize
    
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
    
    public func setConfigId(_ configId: String) {
        self.configId = configId
    }
    
    internal func fillVideoParams(_ parameters: AUVideoParameters?) -> VideoParameters {
        guard let videoParams = parameters else {
            let videoParameters = VideoParameters(mimes: ["video/mp4"])
            videoParameters.protocols = [Signals.Protocols.VAST_2_0]
            videoParameters.playbackMethod = [Signals.PlaybackMethod.AutoPlaySoundOff]
            videoParameters.placement = Signals.Placement.InBanner
            return videoParameters
        }
        
        let parameters = VideoParameters(mimes: videoParams.mimes)
        parameters.protocols = videoParams.toProtocols()
        parameters.playbackMethod = videoParams.toPlaybackMethods()
        parameters.placement = videoParams.placement?.toPlacement
        
        parameters.api = videoParams.toApi()
        parameters.startDelay = videoParams.startDelay?.toStartDelay
        parameters.adSize = videoParams.adSize
        
        parameters.maxBitrate = videoParams.toSingleContainerInt(videoParams.maxBitrate)
        parameters.minBitrate = videoParams.toSingleContainerInt(videoParams.minBitrate)
        parameters.maxDuration = videoParams.toSingleContainerInt(videoParams.maxDuration)
        parameters.minDuration = videoParams.toSingleContainerInt(videoParams.minDuration)
        parameters.linearity = videoParams.toSingleContainerInt(videoParams.linearity)
        
        return parameters
    }
}