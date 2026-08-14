import Foundation

// MARK: - CEFDevToolsClient
//
// In-process Chrome DevTools Protocol client for agentic browsing.
// Uses CefBrowserHost.sendDevToolsMessage for production CDP access,
// replacing the #if DEBUG-gated remote debugging port (localhost:9223).
//
// Phase 2 — P2.1: Foundation for CDP Agent Tools.
// Phase 3 — Astro alignment: 28 CDP agent tools mirroring BrowserOS's browser
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
    /// Best-effort page URL for AX context headers (updated on navigate).
    private var lastNavigatedURL: String? = nil

    /// Wire up the actual CEF send function. Call once after creating the client.
    public func wireSend(_ block: @escaping (String) -> Void) {
        sendRaw = block
    }

    /// Send a CDP command and await the JSON response as a dictionary.
    ///
    /// Every command is bounded by `timeout` — if CEF never responds (a
    /// wedged target, e.g. cross-target commands like Target.closeTarget that
    /// some CEF builds never acknowledge), the continuation resumes with a
    /// clean CDPError instead of hanging the bridge call forever. The agent
    /// pipeline must never stall on a silent CEF.
    public func send(method: String, params: [String: Any] = [:], timeout: Duration = .seconds(30)) async throws -> [String: Any] {
        let id = nextID
        nextID += 1

        let cmd: [String: Any] = [
            "id": id,
            "method": method,
            "params": params
        ]

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            // Bound the wait: resuming twice is impossible because both this
            // and handleResponse remove the pending entry before resuming.
            let timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                if let cont = self.pending.removeValue(forKey: id) {
                    cont.resume(throwing: CDPError(code: -32000, message: "CDP command timed out after \(timeout): \(method)"))
                }
            }
            guard let data = try? JSONSerialization.data(withJSONObject: cmd, options: []),
                  let json = String(data: data, encoding: .utf8) else {
                timeoutTask.cancel()
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
        lastNavigatedURL = url
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
    /// Nodes are returned in capture order (never dictionary order).
    public func snapshot() async throws -> [AXNode] {
        let tree = try await snapshotContext()
        let ordered = tree.nodeOrder.compactMap { tree.nodes[$0] }
        lastSnapshotNodes = ordered
        return ordered
    }

    /// Captures the full accessibility tree, parsed into an ``AXTree`` with
    /// stable refs, wired children/roots, and an LLM-ready prompt renderer.
    public func snapshotContext() async throws -> AXTree {
        // getFullAXTree returns the whole page's tree with no params.
        // (getPartialAXTree with backendNodeId: 0 fails with
        // "No node found for given backend id" — 0 is not a valid ID.)
        let result = try await send(method: "Accessibility.getFullAXTree", params: [:])
        guard let payload = unwrapResult(result) else {
            throw CDPError(code: -32602, message: "Accessibility.getFullAXTree returned no result")
        }
        let tree = AXTreeParser.parse(payload, pageURL: lastNavigatedURL, pageTitle: nil)
        lastSnapshotNodes = tree.nodeOrder.compactMap { tree.nodes[$0] }
        return tree
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
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CDPError(code: -1, message: "empty key")
        }
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

    public func captureScreenshot(timeout: Duration = .seconds(30)) async throws -> Data? {
        let result = try await send(
            method: "Page.captureScreenshot",
            params: ["format": "png"],
            timeout: timeout
        )
        guard let inner = unwrapResult(result) else { return nil }
        if let dataStr = inner["data"] as? String {
            return Data(base64Encoded: dataStr)
        }
        return nil
    }

    /// Captures the entire scrollable page, not just the viewport (Chrome's
    /// "full page" screenshot / Safari's full-page capture). CDP's
    /// `captureBeyondViewport` stitches the whole document together, so a
    /// long article produces one tall PNG. Best-effort: some pages (fixed
    /// viewport layouts, infinite scroll) capture only what's reachable.
    public func captureFullPageScreenshot(timeout: Duration = .seconds(30)) async throws -> Data? {
        let result = try await send(
            method: "Page.captureScreenshot",
            params: ["format": "png", "captureBeyondViewport": true, "fromSurface": true],
            timeout: timeout
        )
        guard let inner = unwrapResult(result) else { return nil }
        if let dataStr = inner["data"] as? String {
            return Data(base64Encoded: dataStr)
        }
        return nil
    }

    // MARK: - Clear Browsing Data (Chrome parity)

    /// Clears the browser-wide HTTP cache (`Network.clearBrowserCache`). CDP
    /// cache clearing is browser-global regardless of which target issued it,
    /// so one call covers every workspace/profile.
    public func clearBrowserCache(timeout: Duration = .seconds(10)) async throws {
        _ = try await send(method: "Network.clearBrowserCache", timeout: timeout)
    }

    /// Clears all browser cookies (`Network.clearBrowserCookies`). Also
    /// browser-global; no per-site or time-scoped variant exists in CDP, which
    /// is why the Clear Browsing Data panel clears cookies in full.
    public func clearBrowserCookies(timeout: Duration = .seconds(10)) async throws {
        _ = try await send(method: "Network.clearBrowserCookies", timeout: timeout)
    }

    /// Returns every cookie the browser currently holds (`Network.getCookies`)
    /// as raw dictionaries (`name`, `domain`, `path`, `httpOnly`, …). Callers
    /// filter with `SiteDataPolicy.cookieDomainMatches` for per-site removal.
    public func networkCookies(timeout: Duration = .seconds(10)) async throws -> [[String: Any]] {
        let result = try await send(method: "Network.getCookies", timeout: timeout)
        guard let inner = unwrapResult(result),
              let cookies = inner["cookies"] as? [[String: Any]]
        else { return [] }
        return cookies
    }

    /// Deletes one cookie by name + exact domain (`Network.deleteCookies`).
    /// The domain is passed through as CDP reported it (leading dot
    /// preserved) so exact-domain matching deletes both host-only and
    /// domain-scoped cookies; `path` defaults to "/" to cover every path.
    public func deleteCookie(name: String, domain: String, path: String = "/", timeout: Duration = .seconds(10)) async throws {
        _ = try await send(method: "Network.deleteCookies", params: [
            "name": name,
            "domain": domain,
            "path": path
        ], timeout: timeout)
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

    // MARK: Astro-derived extended act tools

    /// Hover over an element by AX ref (Input.dispatchMouseEvent mouseMoved).
    public func hover(ref: String) async throws {
        let coords = try await centerOf(ref: ref)
        try await send(method: "Input.dispatchMouseEvent", params: [
            "type": "mouseMoved",
            "x": coords.x, "y": coords.y,
            "modifiers": 0, "button": "none", "clickCount": 0
        ])
    }

    /// Focus an element by AX ref (DOM.focus).
    public func focus(ref: String) async throws {
        let nodeId = try await resolveNode(ref: ref)
        _ = try await send(method: "DOM.focus", params: ["nodeId": nodeId])
    }

    /// Check a checkbox/radio by AX ref.
    public func check(ref: String) async throws {
        let nodeId = try await resolveNode(ref: ref)
        _ = try await send(method: "DOM.setChecked", params: ["nodeId": nodeId, "checked": true])
    }

    /// Uncheck a checkbox by AX ref.
    public func uncheck(ref: String) async throws {
        let nodeId = try await resolveNode(ref: ref)
        _ = try await send(method: "DOM.setChecked", params: ["nodeId": nodeId, "checked": false])
    }

    /// Select an option value on a <select> by AX ref.
    public func select(ref: String, value: String) async throws {
        let nodeId = try await resolveNode(ref: ref)
        _ = try await send(method: "DOM.setAttributeValue", params: [
            "nodeId": nodeId, "name": "value", "value": value
        ])
        // Fire a change event so the page reacts.
        try await send(method: "DOM.dispatchEvent", params: [
            "nodeId": nodeId, "type": "change"
        ])
    }

    /// Drag from one element ref to another.
    public func drag(ref: String, targetRef: String) async throws {
        let from = try await centerOf(ref: ref)
        let to = try await centerOf(ref: targetRef)
        // mousedown → mousemove → mouseup
        for (type, x, y) in [("mousePressed", from.x, from.y),
                              ("mouseMoved", to.x, to.y),
                              ("mouseReleased", to.x, to.y)] {
            try await send(method: "Input.dispatchMouseEvent", params: [
                "type": type, "x": x, "y": y,
                "modifiers": 0, "button": "left", "clickCount": 1
            ])
        }
    }

    /// Read page content as markdown (via content-markdown expression pattern from Astro).
    public func readPageMarkdown(selector: String? = nil) async throws -> String {
        let root = selector.map { "document.querySelector(\($0.debugDescription))" } ?? "document.body"
        // Heuristic markdown conversion: headings, links, images, lists
        let code = """
        (function(){var e=\(root);if(!e)return'';function t(n){var r='';for(var c=n.firstChild;c;c=c.nextSibling){if(c.nodeType===3){var s=c.textContent||'';r+=s}else if(c.nodeType===1){var m=c.tagName;if(/^H[1-6]$/.test(m)){var l=parseInt(m[1]);r+='\\n'+'#'.repeat(l)+' '+t(c)+'\\n'}else if(m==='A'){r+='['+t(c)+']('+(c.href||'')+')'}else if(m==='IMG'){r+='!['+(c.alt||'')+']('+(c.src||'')+')'}else if(m==='P'||m==='DIV'||m==='SECTION'){r+='\\n'+t(c)+'\\n'}else if(m==='LI'){r+='- '+t(c)+'\\n'}else if(m==='STRONG'||m==='B'){r+='**'+t(c)+'**'}else if(m==='EM'||m==='I'){r+='*'+t(c)+'*'}else if(m==='CODE'){r+='`'+t(c)+'`'}else if(m==='PRE'){r+='\\n```\\n'+t(c)+'\\n```\\n'}else if(m==='BR'){r+='\\n'}else{r+=t(c)}}}return r}return t(e)})()
        """
        return try await evaluate(expression: code)
    }

    // MARK: Helpers

    /// Resolves an AX ref (e.g. "e12") to a DOM node ID via the AX tree.
    private func resolveNode(ref: String) async throws -> Int {
        // Strip "e" prefix if present (Astro convention: eN = backendDOMNodeId N)
        let numeric = ref.hasPrefix("e") ? String(ref.dropFirst()) : ref
        guard let backendId = Int(numeric) else {
            throw CDPError(code: -32602, message: "Invalid ref: \(ref)")
        }
        // Resolve AX node → DOM node via Accessibility.getBackendNodeForDOMNode
        // Actually, we need DOM.describeNode with backendNodeId.
        // CDP path: Accessibility.getPartialAXTree → find the node → use its backendDOMNodeId
        // Simpler: use DOM.resolveNode with backendNodeId
        let result = try await send(method: "DOM.resolveNode", params: ["backendNodeId": backendId])
        if let object = unwrapResult(result)?["object"] as? [String: Any],
           let nodeId = object["nodeId"] as? Int {
            return nodeId
        }
        // Fallback: try DOM.describeNode
        let describe = try await send(method: "DOM.describeNode", params: ["backendNodeId": backendId])
        if let node = unwrapResult(describe)?["node"] as? [String: Any],
           let nodeId = node["nodeId"] as? Int {
            return nodeId
        }
        throw CDPError(code: -32602, message: "Cannot resolve node for ref: \(ref)")
    }

    /// Finds the center coordinates of an element by AX ref.
    private func centerOf(ref: String) async throws -> (x: Int, y: Int) {
        let nodeId = try await resolveNode(ref: ref)
        let result = try await send(method: "DOM.getBoxModel", params: ["nodeId": nodeId])
        if let model = unwrapResult(result)?["model"] as? [String: Any],
           let content = model["content"] as? [Double],
           content.count >= 4 {
            let x = Int((content[0] + content[2]) / 2)
            let y = Int((content[1] + content[5]) / 2)
            return (x, y)
        }
        throw CDPError(code: -32602, message: "Cannot get box model for ref: \(ref)")
    }

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
