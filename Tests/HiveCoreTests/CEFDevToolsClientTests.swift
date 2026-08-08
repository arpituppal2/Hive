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
                // Realistic CDP Runtime.evaluate envelope: the RemoteObject is
                // nested under result.result.
                client.handleResponse("{\"id\":\(id),\"result\":{\"result\":{\"type\":\"string\",\"value\":\"test\"}}}")
            }
        }

        let result = try await client.evaluate(expression: "1 + 1")
        #expect(lastMethod == "Runtime.evaluate")
        #expect(lastParams?["returnByValue"] as? Bool == true)
        #expect(result == "test")
    }

    // MARK: - Envelope unwrapping regressions

    @Test func evaluateExtractsNestedRemoteObjectValue() async throws {
        // Regression: consumers must read method keys from result.result, not
        // the envelope — real CDP responses nest the RemoteObject there.
        let client = CDPClient()
        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = dict["id"] as? Int {
                client.handleResponse("{\"id\":\(id),\"result\":{\"result\":{\"type\":\"string\",\"value\":\"The Hive Brief\"},\"exceptionDetails\":null}}")
            }
        }
        let result = try await client.evaluate(expression: "document.title")
        #expect(result == "The Hive Brief")
    }

    @Test func snapshotExtractsNodesFromEnvelope() async throws {
        // Regression: Accessibility.getPartialAXTree returns nodes under
        // result.nodes; AXValue fields (role/name) are top-level, properties
        // is an array of {name, value} pairs.
        let client = CDPClient()
        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = dict["id"] as? Int {
                let axNode = """
                {"nodeId":"1","ignored":false,
                 "role":{"type":"string","value":"heading"},
                 "name":{"type":"string","value":"Hello"},
                 "description":{"type":"string","value":"Greeting"},
                 "properties":[{"name":"focusable","value":{"type":"boolean","value":true}}]}
                """
                client.handleResponse("{\"id\":\(id),\"result\":{\"nodes\":[\(axNode)]}}")
            }
        }
        let nodes = try await client.snapshot()
        #expect(nodes.count == 1)
        #expect(nodes.first?.role == "heading")
        #expect(nodes.first?.name == "Hello")
        #expect(nodes.first?.desc == "Greeting")
        #expect(nodes.first?.focusable == true)
    }

    @Test func newTabReturnsStringTargetID() async throws {
        // Regression: Target.createTarget returns an opaque string targetId
        // (e.g. hex "1ECD4966…") that must survive as a String, not an Int.
        let client = CDPClient()
        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = dict["id"] as? Int {
                client.handleResponse("{\"id\":\(id),\"result\":{\"targetId\":\"1ECD4966AF6B0DD1227E3DD0AA509E87\"}}")
            }
        }
        let tabID = try await client.newTab(url: "https://example.com")
        #expect(tabID == "1ECD4966AF6B0DD1227E3DD0AA509E87")
    }

    @Test func listTabsUsesTargetGetTargets() async throws {
        // Regression: listing tabs requires Target.getTargets (which returns
        // targetInfos), not Browser.getWindowForTarget (windowId/bounds only).
        let client = CDPClient()
        var lastMethod: String?
        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = dict["id"] as? Int {
                lastMethod = dict["method"] as? String
                let target = "{\"targetId\":\"abc123\",\"type\":\"page\",\"title\":\"Hi\",\"url\":\"https://x\",\"attached\":true}"
                client.handleResponse("{\"id\":\(id),\"result\":{\"targetInfos\":[\(target)]}}")
            }
        }
        let tabs = try await client.listTabs()
        #expect(lastMethod == "Target.getTargets")
        #expect(tabs.count == 1)
        #expect(tabs.first?.id == "abc123")
        #expect(tabs.first?.title == "Hi")
        #expect(tabs.first?.active == true)
    }

    @Test func captureScreenshotReadsDataFromEnvelope() async throws {
        // Regression: Page.captureScreenshot returns base64 under result.data.
        let client = CDPClient()
        client.wireSend { json in
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = dict["id"] as? Int {
                client.handleResponse("{\"id\":\(id),\"result\":{\"data\":\"aGVsbG8=\"}}")
            }
        }
        let data = try await client.captureScreenshot()
        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8) == "hello")
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
