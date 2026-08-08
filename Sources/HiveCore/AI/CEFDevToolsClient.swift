import Foundation

// MARK: - CEFDevToolsClient
//
// In-process Chrome DevTools Protocol client for agentic browsing.
// Uses CefBrowserHost.sendDevToolsMessage for production CDP access,
// replacing the #if DEBUG-gated remote debugging port (localhost:9223).
//
// Phase 2 — P2.1: Foundation for CDP Agent Tools.
// Phase 3 — Astro alignment: 16 CDP agent tools mirroring BrowserOS's browser
// automation surface (tabs, navigation, snapshot, act, read, grep, screenshot,
// wait, evaluate). See https://github.com/Blueturboguy07/Astro.

struct CDPError: Error, Sendable {
    let code: Int
    let message: String
}

// MARK: - Agent Tool Results

/// A single browser tab reference. CDP target IDs are opaque strings
/// (e.g. "1ECD4966AF6B0DD1227E3DD0AA509E87"), so `id` is a String.
public struct AgentTab: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let url: String
    public let active: Bool
}

// MARK: - CDPClient

/// Manages a CDP session with a CEF browser host.
/// All methods are @MainActor since they touch CEF state.
@MainActor
public final class CDPClient {
    public init() {}
    private var nextID = 1
    @preconcurrency private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var sendRaw: (String) -> Void = { json in
        print("[CDP] sendRaw not wired — override required. Message: \(json.prefix(100))...")
    }
    private var lastSnapshotNodes: [AXNode]? = nil

    /// Wire up the actual CEF send function. Call once after creating the client.
    public func wireSend(_ block: @escaping (String) -> Void) {
        sendRaw = block
    }

    /// Send a CDP command and await the JSON response as a dictionary.
    public func send(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
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
    public func handleResponse(_ jsonString: String) {
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

    /// Unwraps the method-specific result object from a full CDP response.
    /// `send` returns the complete envelope (`{"id":N,"result":{...}}`);
    /// every consumer must read its method-specific keys from this inner
    /// object, never from the envelope itself.
    private func unwrapResult(_ response: [String: Any]) -> [String: Any]? {
        response["result"] as? [String: Any]
    }

    // MARK: Navigation

    public func navigate(url: String) async throws {
        _ = try await send(method: "Page.navigate", params: ["url": url])
    }

    public func reload() async throws {
        _ = try await send(method: "Page.reload", params: [:])
    }

    public func goBack() async throws {
        _ = try await send(method: "Page.navigateToHistoryEntry", params: ["entryId": -1])
    }

    public func goForward() async throws {
        _ = try await send(method: "Page.navigateToHistoryEntry", params: ["entryId": 1])
    }

    // MARK: Tab Management

    public func listTabs() async throws -> [AgentTab] {
        let result = try await send(method: "Target.getTargets", params: [:])
        // Target.getTargets returns targetInfos (id/type/title/url);
        // Browser.getWindowForTarget returns only windowId/bounds.
        var tabs: [AgentTab] = []
        if let targets = unwrapResult(result)?["targetInfos"] as? [[String: Any]] {
            for t in targets where (t["type"] as? String) == "page" {
                tabs.append(AgentTab(
                    id: t["targetId"] as? String ?? "",
                    title: t["title"] as? String ?? "",
                    url: t["url"] as? String ?? "",
                    active: (t["attached"] as? Bool) ?? false
                ))
            }
        }
        return tabs
    }

    public func newTab(url: String, background: Bool = true) async throws -> String {
        let result = try await send(method: "Target.createTarget", params: [
            "url": url,
            "background": background
        ])
        // Target.createTarget returns the opaque string targetId.
        guard let inner = unwrapResult(result) else { return "" }
        return inner["targetId"] as? String ?? ""
    }

    public func closeTab(id: String) async throws {
        _ = try await send(method: "Target.closeTarget", params: ["targetId": id])
    }

    public func activateTab(id: String) async throws {
        _ = try await send(method: "Target.activateTarget", params: ["targetId": id])
    }

    // MARK: Page Snapshot — Accessibility Tree

    /// Takes an accessibility-tree snapshot with stable element reference IDs.
    /// This is the primary observation tool — "observe before you act".
    public func snapshot() async throws -> [AXNode] {
        // getFullAXTree returns the whole page's tree with no params.
        // (getPartialAXTree with backendNodeId: 0 fails with
        // "No node found for given backend id" — 0 is not a valid ID.)
        let result = try await send(method: "Accessibility.getFullAXTree", params: [:])

        var nodes: [AXNode] = []
        if let axNodes = unwrapResult(result)?["nodes"] as? [[String: Any]] {
            for (i, n) in axNodes.enumerated() {
                // CDP Accessibility.AXNode: role/name/value/description are
                // top-level AXValue objects; properties is an array of
                // {name, value} pairs.
                let name = (n["name"] as? [String: Any])?["value"] as? String
                let value = (n["value"] as? [String: Any])?["value"] as? String
                let desc = (n["description"] as? [String: Any])?["value"] as? String
                var focusable = false
                if let props = n["properties"] as? [[String: Any]] {
                    for prop in props {
                        if prop["name"] as? String == "focusable",
                           let val = prop["value"] as? [String: Any],
                           val["value"] as? Bool == true {
                            focusable = true
                        }
                    }
                }
                nodes.append(AXNode(
                    ref: "ref_\(i)",
                    role: (n["role"] as? [String: Any])?["value"] as? String ?? "unknown",
                    name: name,
                    value: value,
                    desc: desc,
                    bounds: nil,
                    focusable: focusable,
                    children: nil
                ))
            }
        }

        lastSnapshotNodes = nodes
        return nodes
    }

    // MARK: Page Read

    /// Extracts readable text content from the page.
    public func readPage(format: String = "text") async throws -> String {
        let script: String
        switch format {
        case "links":
            script = "Array.from(document.querySelectorAll('a[href]')).map(a => a.href + ' | ' + (a.textContent?.trim().substring(0,80) || '')).join('\\n')"
        case "markdown":
            script = "document.body.innerText"
        default:
            script = "document.body.innerText"
        }
        let result = try await evaluate(expression: script)
        return (result as? String) ?? ""
    }

    // MARK: Act — Click, Fill, Type, Press, Scroll

    /// Click an element referenced by accessibility ref or CSS selector.
    public func click(ref: String? = nil, selector: String? = nil) async throws {
        let targetSelector = selector ?? "[data-ax-ref=\"\(ref ?? "")\"]"
        let script = """
        (function() {
            const el = document.querySelector('\(targetSelector)');
            if (!el) return 'not found';
            el.click();
            return 'clicked';
        })()
        """
        _ = try await evaluate(expression: script)
    }

    /// Fill a form field.
    public func fill(selector: String, value: String) async throws {
        let script = """
        (function() {
            const el = document.querySelector('\(selector)');
            if (!el) return 'not found';
            el.value = '\(value.replacingOccurrences(of: "'", with: "\\'"))';
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return 'filled';
        })()
        """
        _ = try await evaluate(expression: script)
    }

    /// Type text into the focused element via input events.
    public func type(text: String) async throws {
        for char in text {
            let key = String(char)
            _ = try await send(method: "Input.dispatchKeyEvent", params: [
                "type": "keyDown",
                "text": key,
                "key": key
            ])
        }
    }

    /// Press a key (Enter, Escape, Tab, etc.).
    public func press(key: String) async throws {
        _ = try await send(method: "Input.dispatchKeyEvent", params: [
            "type": "rawKeyDown",
            "key": key,
            "windowsVirtualKeyCode": keyCode(for: key)
        ])
        _ = try await send(method: "Input.dispatchKeyEvent", params: [
            "type": "keyUp",
            "key": key,
            "windowsVirtualKeyCode": keyCode(for: key)
        ])
    }

    /// Scroll the page.
    public func scroll(direction: String = "down", amount: Int = 300) async throws {
        let y = direction == "down" ? amount : -amount
        _ = try await evaluate(expression: "window.scrollBy(0, \(y))")
    }

    // MARK: Evaluate

    public func evaluate(expression: String) async throws -> String {
        let result = try await send(method: "Runtime.evaluate", params: [
            "expression": expression,
            "returnByValue": true
        ])
        guard let inner = unwrapResult(result) else { return "" }
        // Runtime.evaluate always nests the RemoteObject under result.result:
        //   {"result":{"result":{"type":"string","value":"…"}, ...}}
        if let remote = inner["result"] as? [String: Any], let value = remote["value"] {
            return String(describing: value)
        }
        return ""
    }

    // MARK: Grep — Search page content

    /// Search page content for a string or selector without dumping the whole page.
    public func grep(query: String) async throws -> [String] {
        let script = """
        (function() {
            const q = '\(query.replacingOccurrences(of: "'", with: "\\'"))';
            const results = [];
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while (walker.nextNode()) {
                const text = walker.currentNode.textContent || '';
                if (text.includes(q)) {
                    results.push(text.trim().substring(0, 200));
                }
            }
            return results.slice(0, 20);
        })()
        """
        let result = try await evaluate(expression: script)
        // Parse JSON array from evaluate result
        if let data = result.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }
        return result.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // MARK: Wait

    /// Wait for a condition: text to appear, selector to exist, or timeout.
    public func wait(condition: String = "timeout", ms: Int = 1000) async throws {
        switch condition {
        case "load":
            _ = try await send(method: "Page.waitForLoadState", params: ["state": "load"])
        default:
            try await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
        }
    }

    // MARK: Screenshot

    public func captureScreenshot() async throws -> Data? {
        let result = try await send(method: "Page.captureScreenshot", params: ["format": "png"])
        guard let inner = unwrapResult(result) else { return nil }
        if let dataStr = inner["data"] as? String {
            return Data(base64Encoded: dataStr)
        }
        return nil
    }

    // MARK: Diff — What changed since last snapshot

    /// Returns nodes added or changed since the last snapshot.
    public func diff() async throws -> (added: [AXNode], removed: [AXNode]) {
        let current = try await snapshot()
        let prev = lastSnapshotNodes ?? []
        let prevRefs = Set(prev.compactMap(\.name))
        let currRefs = Set(current.compactMap(\.name))

        let added = current.filter { !prevRefs.contains($0.name ?? "") }
        let removed = prev.filter { !currRefs.contains($0.name ?? "") }

        return (added, removed)
    }

    // MARK: Helpers

    private func keyCode(for key: String) -> Int {
        switch key {
        case "Enter": return 13
        case "Escape": return 27
        case "Tab": return 9
        case "Backspace": return 8
        case "Delete": return 46
        case "ArrowUp": return 38
        case "ArrowDown": return 40
        case "ArrowLeft": return 37
        case "ArrowRight": return 39
        case " ": return 32
        default: return 0
        }
    }
}
