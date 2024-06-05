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
import Network

fileprivate let baseUrl: String = "https://api.adnz.co/api/ws-events-sink/"

class AUEventsNetworkManager {
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
}

extension AUEventsNetworkManager {
    
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
}

// MARK: - Rechabillity
fileprivate extension AUEventsNetworkManager {
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("We're connected!")
                self?.isConnection = true
            } else {
                print("No connection.")
                self?.isConnection = false
            }
            
            print("Is expensive: \(path.isExpensive)")
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
