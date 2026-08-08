import Foundation

// MARK: - CEFDevToolsClient
//
// In-process Chrome DevTools Protocol client for agentic browsing.
// Uses CefBrowserHost.sendDevToolsMessage for production CDP access,
// replacing the #if DEBUG-gated remote debugging port (localhost:9223).
//
// Phase 2 — P2.1: Foundation for CDP Agent Tools.

struct CDPError: Error, Sendable {
    let code: Int
    let message: String
}

/// Manages a CDP session with a CEF browser host.
/// All methods are @MainActor since they touch CEF state.
@MainActor
final class CDPClient {
    private var nextID = 1
    @preconcurrency private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var sendRaw: (String) -> Void = { json in
        print("[CDP] sendRaw not wired — override required. Message: \(json.prefix(100))...")
    }

    /// Wire up the actual CEF send function. Call once after creating the client.
    func wireSend(_ block: @escaping (String) -> Void) {
        sendRaw = block
    }

    /// Send a CDP command and await the JSON response as a dictionary.
    func send(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let id = nextID
        nextID += 1

        let cmd: [String: Any] = [
            "id": id,
            "method": method,
            "params": params
        ]

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            guard let data = try? JSONSerialization.data(withJSONObject: cmd, options: []),
                  let json = String(data: data, encoding: .utf8) else {
                continuation.resume(throwing: CDPError(code: -1, message: "JSON serialization failed"))
                pending.removeValue(forKey: id)
                return
            }
            sendRaw(json)
        }
    }

    /// Handle an incoming DevTools message from CEF.
    func handleResponse(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        guard let id = dict["id"] as? Int else { return } // event, skip

        if let errorDict = dict["error"] as? [String: Any] {
            let code = errorDict["code"] as? Int ?? -1
            let message = errorDict["message"] as? String ?? "Unknown"
            pending[id]?.resume(throwing: CDPError(code: code, message: message))
        } else {
            // Return the full response dict — callers extract "result" sub-dict
            pending[id]?.resume(returning: dict)
        }
        pending.removeValue(forKey: id)
    }

    // MARK: Convenience

    func navigate(url: String) async throws -> [String: Any] {
        try await send(method: "Page.navigate", params: ["url": url])
    }

    func evaluate(expression: String) async throws -> Any? {
        let result = try await send(method: "Runtime.evaluate", params: [
            "expression": expression,
            "returnByValue": true
        ])
        guard let inner = result["result"] as? [String: Any] else { return nil }
        return inner["value"]
    }

    func captureScreenshot() async throws -> Data? {
        let result = try await send(method: "Page.captureScreenshot", params: ["format": "png"])
        if let dataStr = result["data"] as? String {
            return Data(base64Encoded: dataStr)
        }
        return nil
    }
}
