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

@objc public enum AUResultCode: Int {
    case audienzzDemandFetchSuccess = 0
    case audienzzServerNotSpecified
    case audienzzInvalidAccountId
    case audienzzInvalidConfigId
    case audienzzInvalidSize
    case audienzzNetworkError
    case audienzzServerError
    case audienzzDemandNoBids
    case audienzzDemandTimedOut
    case audienzzServerURLInvalid
    case audienzzUnknownError
    
    case audienzzInvalidResponseStructure = 1000
    
    case audienzzInternalSDKError = 7000
    case audienzzWrongArguments
    case audienzzNoVastTagInMediaData

    case audienzzSDKMisuse = 8000
    case audienzzSDKMisusePreviousFetchNotCompletedYet
    
    case audienzzInvalidRequest
    
    public func name () -> String {
        switch self {
        
        case .audienzzDemandFetchSuccess:
            return "audienzz demand fetch successful"
        case .audienzzServerNotSpecified:
            return "audienzz server not specified"
        case .audienzzInvalidAccountId:
            return "audienzz server does not recognize account id"
        case .audienzzInvalidConfigId:
            return "audienzz server does not recognize config id"
        case .audienzzInvalidSize:
            return "audienzz server does not recognize the size requested"
        case .audienzzNetworkError:
            return "Network Error"
        case .audienzzServerError:
            return "audienzz server error"
        case .audienzzDemandNoBids:
            return "audienzz Server did not return bids"
        case .audienzzDemandTimedOut:
            return "audienzz demand timedout"
        case .audienzzServerURLInvalid:
            return "audienzz server url is invalid"
        case .audienzzUnknownError:
            return "audienzz unknown error occurred"
        case .audienzzInvalidResponseStructure:
            return "Response structure is invalid"
        case .audienzzInternalSDKError:
            return "Internal SDK error"
        case .audienzzWrongArguments:
            return "Wrong arguments"
        case .audienzzNoVastTagInMediaData:
            return "No VAST tag in media data"
        case .audienzzSDKMisuse:
            return "SDK misuse"
        case .audienzzSDKMisusePreviousFetchNotCompletedYet:
            return "SDK misuse, previous fetch has not complete yet"
        case .audienzzInvalidRequest:
            return "audienzz Request does not contain any parameters"
        }
    }
}
