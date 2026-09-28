import Foundation
import XCTest
@testable import AudienzziOSSDK

final class AnalyticsTransportTests: XCTestCase {
    private final class StubProtocol: URLProtocol {
        static var reply: ((URLRequest) -> (Int, Data?))!
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let (status, body) = Self.reply(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let body { client?.urlProtocol(self, didLoad: body) }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private var session: URLSession!
    private var network: AUEventsNetworkManager<AUBatchResultModel>!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self] // Never send fixture events to the collector.
        session = URLSession(configuration: config)
        network = AUEventsNetworkManager(urlSession: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        network = nil
        StubProtocol.reply = nil
        super.tearDown()
    }

    func testEveryHTTPResponseCompletesWithStatusBasedResult() {
        for (status, body) in [(200, ""), (202, ""), (204, ""),
                               (403, "<html>Forbidden</html>"), (500, ""),
                               (400, "{\"code\":200}")] {
            let done = expectation(description: "HTTP \(status) must settle")
            done.assertForOverFulfill = true
            StubProtocol.reply = { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.path, "/api/ws-clickstream-collector/submit/batch")
                return (status, body.data(using: .utf8))
            }
            network.request(.batchEvents([["event_id": "fixture"]])) { result in
                switch result {
                case .success(let value):
                    XCTAssertTrue((200..<300).contains(status), "HTTP errors cannot count as delivered")
                    XCTAssertEqual(value.code, status)
                case .failure(let error):
                    XCTAssertFalse((200..<300).contains(status), "Empty successful replies are valid")
                    XCTAssertEqual(error, .httpStatus(status))
                }
                done.fulfill()
            }
            wait(for: [done], timeout: 1)
        }
    }

    func testQueueRetriesAfterHTMLFailureAndContinuesAfterNoContentSuccess() {
        let oldEnabled = AUDiagnostics.isEnabled
        let oldSink = AUDiagnostics.sink
        let lock = NSLock()
        var lines: [String] = []
        let acknowledged = expectation(description: "Both batches acknowledged")
        acknowledged.expectedFulfillmentCount = 2
        acknowledged.assertForOverFulfill = true
        AUDiagnostics.isEnabled = true
        AUDiagnostics.sink = { line in
            lock.lock()
            lines.append(line)
            lock.unlock()
            if line.hasPrefix("AUDZ analytics sent ") { acknowledged.fulfill() }
        }
        defer { AUDiagnostics.isEnabled = oldEnabled; AUDiagnostics.sink = oldSink }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AUEventStore(directory: directory)
        let done = expectation(description: "Failed batch retries and the following event is sent")
        done.expectedFulfillmentCount = 3
        done.assertForOverFulfill = true
        var count = 0
        StubProtocol.reply = { _ in
            count += 1
            done.fulfill()
            return count == 1 ? (403, Data("<html>Forbidden</html>".utf8)) : (204, nil)
        }
        let queue = AUEventQueue(networkManager: network, store: store,
            config: .init(maxQueueSize: 10, retryBaseDelayMs: 1, maxRetryDelayMs: 10))
        queue.enqueue(["event_id": "secret-first", "event_type": "pageImpression", "device_id": "secret-device"])
        queue.enqueue(["event_id": "secret-second", "event_type": "adImpression"])
        withExtendedLifetime(queue) {
            wait(for: [done, acknowledged], timeout: 2)
            // Seeing a POST alone is insufficient: the final acknowledgement must also drain
            // persistence. Read the file rather than sharing the queue's non-thread-safe store.
            let file = directory.appendingPathComponent("events.jsonl")
            let drained = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !FileManager.default.fileExists(atPath: file.path)
            }, object: nil)
            wait(for: [drained], timeout: 2)
            lock.lock()
            let captured = lines
            lock.unlock()
            XCTAssertTrue(captured.contains { $0.hasPrefix("AUDZ analytics queued type=pageImpression") })
            XCTAssertTrue(captured.contains { $0.hasPrefix("AUDZ analytics failed ") && $0.contains("status=403") })
            XCTAssertFalse(captured.contains { $0.contains("secret-") || $0.contains("device_id") })
        }
    }

    func testNoBodyStillPreservesHTTPStatusAndTransportErrors() {
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid")!,
                                       statusCode: 204, httpVersion: nil, headerFields: nil)!
        guard case .success(let result) = HTTPResult(data: nil, urlResponse: response, error: nil) else {
            return XCTFail("No-content acknowledgements are HTTP responses")
        }
        XCTAssertEqual(result.statusCode, 204)
        let failure = URLError(.serverCertificateUntrusted)
        guard case .failure(.connectionError(let error)) = HTTPResult(data: nil, urlResponse: nil, error: failure) else {
            return XCTFail("Missing data must not hide a certificate failure")
        }
        XCTAssertEqual((error as NSError).code, failure.errorCode)
    }
}
