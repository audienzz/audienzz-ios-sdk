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
import Network

class AUEventsNetworkManager<T: APIResult> {
    private var monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    private let urlSession: URLSession!
    
    init() {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: OperationQueue.main)
        self.urlSession = session
        self.startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private(set) var isConnection: Bool = false
    
    func request(_ route: APIRoute<T>, handler: @escaping (Result<T, AUAPIError>) -> Void) {
        let method = APIGateway<T>().build(route: route)
        run(request: method.request) { [weak self] result in
            guard let strongSelf = self else { handler(.failure(.couldNotParseResponse)); return }
            switch result {
            case .success(let responce):
                self?.handleResult(responce: responce, method: method, handler: handler)
            case .failure(let error):
                handler(.failure(strongSelf.makeApiError(for: error)))
            }
        }
    }
}

// MARK: - Network Request
fileprivate extension AUEventsNetworkManager {
    func run(request: HTTPRequest, completion: @escaping (HTTPResult) -> Void) {
        let taskCompletion: (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void = {
            completion(HTTPResult(data: $0, urlResponse: $1, error: $2))
        }
        
        let task = URLSessionTask.fromHTTPRequest(request: request, urlSession: urlSession, completion: taskCompletion)
        task.resume()
    }
    
    func handleResult(responce: HTTPResponse, method: APIMethod<T>, handler: @escaping (Result<T, AUAPIError>) -> Void) {
        
        if responce.statusCode == 200 {
            var jObject = JSONObject()
            jObject["code"] = responce.statusCode
            handler(extractAPIResponce(jsonObject: jObject, parser: method.resultParser))
        }
        
        guard let data = responce.body, let json = try? decodeJSON(data), let jsonObject = json as? JSONObject else {
            return
        }
        
        handler(extractAPIResponce(jsonObject: jsonObject, parser: method.resultParser))
    }
    
    func extractAPIResponce(jsonObject: JSONObject, parser: (JSONObject) -> T?) -> Result<T, AUAPIError> {
      if let result = parser(jsonObject) {
        return .success(result)
      }

      return .failure(.couldNotParseResponse)
    }
    
    func makeApiError(for clentError: HTTPClientError) -> AUAPIError {
        switch clentError {
        case .connectionError(let error):
            return AUAPIError.connectionError(error)
        case .emptyData:
            return AUAPIError.couldNotParseResponse
        case .unexpectedURLResponse:
            return AUAPIError.couldNotParseResponse
        }
    }
}

// MARK: - Rechabillity
fileprivate extension AUEventsNetworkManager {
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                AULogEvent.logDebug("We're connected!")
                self?.isConnection = true
            } else {
                AULogEvent.logDebug("No connection.")
                self?.isConnection = false
            }
            
            AULogEvent.logDebug("Is expensive: \(path.isExpensive)")
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

extension URLSessionTask {
    static func fromHTTPRequest(request: HTTPRequest,
                                urlSession: URLSession,
                                completion: @escaping (_ data: Data?, _ urlResponse: URLResponse?, _ error: Error?) -> Void) -> URLSessionTask {
        switch request.method {
        case .GET:
            return urlSession.dataTask(with: request.URLRequest, completionHandler: completion)
        case .POST:
            return urlSession.uploadTask(with: request.URLRequest, from: request.body, completionHandler: completion)
        case .PUT:
            return urlSession.uploadTask(with: request.URLRequest, from: request.body, completionHandler: completion)
        case .DELETE:
            return urlSession.dataTask(with: request.URLRequest, completionHandler: completion)
        case .PATCH:
            return urlSession.uploadTask(with: request.URLRequest, from: request.body, completionHandler: completion)
        }
    }
}
