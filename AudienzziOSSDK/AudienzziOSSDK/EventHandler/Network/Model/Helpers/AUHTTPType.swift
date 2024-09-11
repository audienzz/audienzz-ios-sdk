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

typealias Query = String
typealias JSON = Any
typealias JSONObject = [Query: JSON]
typealias JSONArray = [JSON]
typealias JSONArrayOfJSONObject = [JSONObject]

protocol BodyObjectEncodable {
  func encode() -> JSONObject
}

enum HTTPSchemaType: String {
  case http
  case https
}

enum HTTPMethodType: String {
  case GET
  case POST
  case PUT
  case PATCH
  case DELETE
}

struct HTTPRequest {
  let method: HTTPMethodType
  let url: URL
  let headers: [String: String]
  let body: Data?
}

extension HTTPRequest {
  var URLRequest: URLRequest {
    let result = NSMutableURLRequest(url: url)
    result.httpMethod = method.rawValue
    result.setHTTPHeaders(headers)
    result.httpShouldHandleCookies = true
    result.httpBody = nil
    return result as URLRequest
  }
}

struct HTTPResponse {
  let statusCode: Int
  let headers: [String: String]
  let body: Data?
}

extension HTTPResponse {
  init(urlResponse: HTTPURLResponse, responseData: Data?) {
    self.statusCode = urlResponse.statusCode
    self.headers = urlResponse.stringifiedHeaderFields
    self.body = responseData
  }
}

enum HTTPResult {
  case success(HTTPResponse)
  case failure(HTTPClientError)
}

extension HTTPResult {
  init(data: Data?, urlResponse: URLResponse?, error: Error?) {
    if data == nil {
      self = .failure(.emptyData)
    } else if let error = error {
      self = .failure(.connectionError(error as NSError))
    } else if let httpURLResponse = urlResponse as? HTTPURLResponse {
      self = HTTPResult.success(HTTPResponse(urlResponse: httpURLResponse, responseData: data))
    } else {
      self = .failure(.unexpectedURLResponse)
    }
  }
}

protocol APIResult: JSONObjectDecodable {}

enum AUAPIResult<T: APIResult> {
    case success(T)
    case failure(Error)
}

enum HTTPClientError: Error {
  case connectionError(Error)
  case emptyData
  case unexpectedURLResponse
}

// MARK: Foundation extensions
extension NSMutableURLRequest {
  func setHTTPHeaders(_ headers: [String: String]) {
    for (header, value) in headers {
      setValue(value, forHTTPHeaderField: header)
    }
  }
}

extension HTTPURLResponse {
  var stringifiedHeaderFields: [String: String] {
    var result = [String: String]()
    for (header, value) in allHeaderFields {
      guard let headerString = header as? String, let valueString = value as? String else {
        continue
      }
      result[headerString] = valueString
    }
    return result
  }
}

protocol JSONObjectDecodable {
  init?(jsonObject: JSONObject)
}

protocol JSONEncodable {
  func encode() -> JSONObject
}

func decodeJSON(_ data: Data) throws -> JSON {
  return try JSONSerialization.jsonObject(with: data, options: [])
}

func encodeJSON(json: JSON) throws -> Data {
  return try JSONSerialization.data(withJSONObject: json, options: [])
}
