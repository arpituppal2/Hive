import Testing
import Foundation
@testable import HiveCore

// MARK: - CEFDevToolsClient Tests

@MainActor
struct CDPClientTests {

    // MARK: - Command serialization

    @Test func sendPageNavigateSerializesCorrectJSON() async throws {
        let client = CDPClient()
        var capturedJSON: String?

        client.wireSend { json in
            capturedJSON = json
        }

        Task {
            _ = try? await client.send(method: "Page.navigate", params: ["url": "https://example.com"])
        }

        // Give the continuation a moment
        try? await Task.sleep(for: .milliseconds(50))

        guard let json = capturedJSON else {
            Issue.record("Expected sendRaw to be called")
            return
        }

        let data = try #require(Data(json.utf8))
        let dict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(dict["method"] as? String == "Page.navigate")
        #expect((dict["params"] as? [String: String])?["url"] == "https://example.com")
        #expect(dict["id"] is Int)
    }

    @Test func sendRuntimeEvaluateSerializesExpression() async throws {
        let client = CDPClient()
        var capturedJSON: String?

        client.wireSend { json in
            capturedJSON = json
        }

        Task {
            _ = try? await client.send(
                method: "Runtime.evaluate",
                params: ["expression": "document.title", "returnByValue": true]
            )
        }

        try? await Task.sleep(for: .milliseconds(50))

        guard let json = capturedJSON else {
            Issue.record("Expected sendRaw to be called")
            return
        }

        let data = try #require(Data(json.utf8))
        let dict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(dict["method"] as? String == "Runtime.evaluate")
        let params = try #require(dict["params"] as? [String: Any])
        #expect(params["expression"] as? String == "document.title")
        #expect(params["returnByValue"] as? Bool == true)
    }

    // MARK: - Response handling

    @Test func handleResponseDeliversResult() async throws {
        let client = CDPClient()

        client.wireSend { json in
            // Synchronously respond — the continuation can resume inline
            let response = #"{"id":1,"result":{"value":"Hello, World!"}}"#
            client.handleResponse(response)
        }

        let result = try await client.send(method: "Runtime.evaluate",
                                            params: ["expression": "1 + 1"])

        let inner = try #require(result["result"] as? [String: Any])
        #expect(inner["value"] as? String == "Hello, World!")
    }

    @Test func handleResponseThrowsOnError() async {
        let client = CDPClient()

        client.wireSend { json in
            let response = #"{"id":1,"error":{"code":-32000,"message":"Syntax error"}}"#
            client.handleResponse(response)
        }

        do {
            _ = try await client.send(method: "Runtime.evaluate", params: [:])
            Issue.record("Expected error to be thrown")
        } catch let error as CDPError {
            #expect(error.code == -32000)
            #expect(error.message == "Syntax error")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func handleResponseHandlesEventWithoutId() async throws {
        let client = CDPClient()

        client.wireSend { json in
            // Send an event (no id) — should be silently skipped
            client.handleResponse(#"{"method":"Page.loadEventFired"}"#)
            // Then send the actual response that resolves the pending continuation
            client.handleResponse(#"{"id":1,"result":{"status":"ok"}}"#)
        }

        let result = try await client.send(method: "Page.reload", params: [:])
        #expect(result["result"] is [String: Any])
    }

    // MARK: - Convenience methods

    @Test func navigateCallsPageNavigate() async throws {
        let client = CDPClient()
        var lastMethod: String?

        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                lastMethod = dict["method"] as? String
                // Synchronously deliver the response
                client.handleResponse(#"{"id":1,"result":{}}"#)
            }
        }

        _ = try await client.navigate(url: "https://hive.com")
        #expect(lastMethod == "Page.navigate")
    }

    @Test func evaluateCallsRuntimeEvaluate() async throws {
        let client = CDPClient()
        var lastMethod: String?
        var lastParams: [String: Any]?

        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                lastMethod = dict["method"] as? String
                lastParams = dict["params"] as? [String: Any]
                let id = dict["id"] as? Int ?? 1
                client.handleResponse("{\"id\":\(id),\"result\":{\"value\":\"test\"}}")
            }
        }

        let result = try await client.evaluate(expression: "1 + 1")
        #expect(lastMethod == "Runtime.evaluate")
        #expect(lastParams?["returnByValue"] as? Bool == true)
        #expect(result as? String == "test")
    }

    // MARK: - ID sequencing

    @Test func commandIDsIncrement() async throws {
        let client = CDPClient()
        var ids: [Int] = []

        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = dict["id"] as? Int {
                ids.append(id)
                // Synchronously respond
                client.handleResponse("{\"id\":\(id),\"result\":{}}")
            }
        }

        // Send three commands sequentially
        _ = try await client.send(method: "Page.navigate", params: [:])
        _ = try await client.send(method: "Runtime.evaluate", params: [:])
        _ = try await client.send(method: "Page.reload", params: [:])

        #expect(ids.count == 3)
        #expect(ids == [1, 2, 3])
    }
}
