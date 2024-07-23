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

fileprivate let baseUrl: String = "https://dev-api.adnz.co/api/ws-event-ingester"
//fileprivate let baseUrl: String = "https://api.adnz.co/api/ws-event-ingester"

enum APIRoute<T: JSONObjectDecodable> {
    case visitorId
    case batchEvents([JSONObject])
    case submit(JSONObject)
    
    var parser: (JSONObject) -> T? {
      return T.init
    }
}

struct APIMethod<T: JSONObjectDecodable> {
    let request: HTTPRequest
    let resultParser: (JSONObject) -> T?
}

protocol APIMethodBuilderType {
  associatedtype T: JSONObjectDecodable
  func build(route: APIRoute<T>) -> APIMethod<T>
}

final class APIGateway<T: APIResult>: APIMethodBuilderType {
    
    func build(route: APIRoute<T>) -> APIMethod<T> {
        switch route {
        case .visitorId:
            return APIMethod(request: HTTPRequest(method: .GET,
                                                  url: URL(string: "")!,
                                                  headers: ["": ""],
                                                  body: nil),
                             resultParser: route.parser)
        case .batchEvents(let models):
            let jsonData = try? encodeJSON(json: models )
            return APIMethod(request: HTTPRequest(method: HTTPMethodType.POST,
                                                  url: URL(string: "\(baseUrl)/submit/batch")!,
                                                  headers: ["Content-Type": "application/cloudevents-batch+json"],
                                                  body: jsonData),
                             resultParser: route.parser)
            
            
        case .submit(let model):
            let jsonData = try? encodeJSON(json: model)
            return APIMethod(request: HTTPRequest(method: HTTPMethodType.POST,
                                                  url: URL(string: "\(baseUrl)/submit")!,
                                                  headers: ["Content-Type": "application/cloudevents+json"],
                                                  body: jsonData),
                             resultParser: route.parser)
        }
    }
}
