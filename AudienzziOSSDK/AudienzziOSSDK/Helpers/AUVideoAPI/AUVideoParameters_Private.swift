/*   Copyright 2018-2025 Audienzz.org, Inc.

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

extension AUVideoParameters {
    func toSingleContainerInt(_ value: Int?) -> SingleContainerInt? {
        guard let param = value else {
            return nil
        }

        return SingleContainerInt(integerLiteral: param)
    }

    func toProtocols() -> [Signals.Protocols]? {
        guard let values = protocols else {
            return nil
        }

        let array = values.compactMap({ $0.type.toProtocol })
        return array
    }

    func toPlaybackMethods() -> [Signals.PlaybackMethod]? {
        guard let values = playbackMethod else {
            return nil
        }

        let array = values.compactMap({ $0.type.toPlaybackMethod })
        return array
    }

    func toApi() -> [Signals.Api]? {
        guard let values = api else {
            return nil
        }

        let array = values.compactMap({ $0.apiType.toAPI })
        return array
    }

    func unwrap() -> VideoParameters {
        let parameters = VideoParameters(mimes: mimes)
        parameters.protocols = toProtocols()
        parameters.playbackMethod = toPlaybackMethods()
        parameters.placement = placement?.toPlacement

        parameters.api = toApi()
        parameters.startDelay = startDelay?.toStartDelay
        parameters.adSize = adSize

        parameters.maxBitrate = toSingleContainerInt(maxBitrate)
        parameters.minBitrate = toSingleContainerInt(minBitrate)
        parameters.maxDuration = toSingleContainerInt(maxDuration)
        parameters.minDuration = toSingleContainerInt(minDuration)
        parameters.linearity = toSingleContainerInt(linearity)

        return parameters
    }

    convenience init(_ pbVideoParams: VideoParameters) {
        self.init(mimes: pbVideoParams.mimes)

        self.protocols = pbVideoParams.protocols?.compactMap { value in
            let type = AUVideoProtocolsType(rawValue: value.value) ?? .VAST_2_0
            return AUVideoProtocols(type: type)
        }
        self.playbackMethod = pbVideoParams.playbackMethod?.compactMap {
            value in
            let type =
                AUVideoPlaybackMethodType(rawValue: value.value)
                ?? .AutoPlaySoundOff
            return AUVideoPlaybackMethod(type: type)
        }

        if let value = pbVideoParams.placement?.value {
            self.placement = AUPlacement(rawValue: value)
        }

        self.api = pbVideoParams.api?.compactMap {
            AUApi(apiType: AUApiType(rawValue: $0.value) ?? .MRAID_2)
        }

        if let value = pbVideoParams.startDelay?.value {
            self.startDelay = AUVideoStartDelay(rawValue: value)
        }

        self.adSize = pbVideoParams.adSize

        self.maxBitrate = pbVideoParams.maxBitrate?.value
        self.minBitrate = pbVideoParams.minBitrate?.value
        self.maxDuration = pbVideoParams.maxDuration?.value
        self.minDuration = pbVideoParams.minDuration?.value
        self.linearity = pbVideoParams.linearity?.value
    }
}
