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

enum AUAPIError: Error, Equatable, LocalizedError {
    case connectionError(Error)
    case couldNotParseResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .connectionError(let error): return error.localizedDescription
        case .couldNotParseResponse: return "Could not parse analytics response"
        case .httpStatus(let status): return "Analytics HTTP \(status)"
        }
    }
}

func == (lhs: AUAPIError, rhs: AUAPIError) -> Bool {
  switch (lhs, rhs) {
  case (.couldNotParseResponse, .couldNotParseResponse):
    return true
  case (.httpStatus(let lhs), .httpStatus(let rhs)):
    return lhs == rhs
  default:
    return false
  }
}
