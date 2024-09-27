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

internal class AUResulrCodeConverter {
    static func convertResultCodeName(_ resultCode: ResultCode) -> String {
        switch resultCode {
        case .prebidDemandFetchSuccess:
            return "SUCCESS"
        case .prebidServerNotSpecified:
            return "ServerNotSpecified".capitalized
        case .prebidInvalidAccountId:
            return "INVALID_ACCOUNT_ID"
        case .prebidInvalidConfigId:
            return "INVALID_CONFIG_ID"
        case .prebidInvalidSize:
            return "INVALID_SIZE"
        case .prebidNetworkError:
            return "NETWORK_ERROR"
        case .prebidServerError:
            return "SERVER_ERROR"
        case .prebidDemandNoBids:
            return "NO_BIDS"
        case .prebidDemandTimedOut:
            return "TIMEOUT"
        case .prebidServerURLInvalid:
            return "ServerURLInvalid".capitalized
        case .prebidUnknownError:
            return "UnknownError".capitalized
        case .prebidInvalidResponseStructure:
            return "InvalidResponseStructure".capitalized
        case .prebidInternalSDKError:
            return "InternalSDKError".capitalized
        case .prebidWrongArguments:
            return "WrongArguments".capitalized
        case .prebidNoVastTagInMediaData:
            return "NoVastTagInMediaData".capitalized
        case .prebidSDKMisuse:
            return "SDKMisuse".capitalized
        case .prebidSDKMisusePreviousFetchNotCompletedYet:
            return "SDKMisusePreviousFetchNotCompletedYet".capitalized
        case .prebidInvalidRequest:
            return "InvalidRequest".capitalized
        @unknown default:
            fatalError("Unknown Error")
        }
    }
}
