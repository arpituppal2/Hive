//
//  WebChromeHandler+AgentTools.swift
//  Hive
//
//  Carved out of WebChromeHandler.swift by scripts/split_webchrome_handler.py.
//  CDP-driven browser-automation bridge (`hive.agent.*`) extracted from the
//  formerly 800-line `WebChromeBridge.register(with:)` method.
//

import Foundation
import AppKit
import CefKit


// MARK: - WebChromeBridge + AgentTools

@MainActor
extension WebChromeBridge {

    /// Registers the CDP-driven agent tool bridge (`hive.agent.*`) — the
    /// Astro-aligned browser-automation surface for AI-driven browsing.
    /// Called from `register(with:)`. Every handler is token-gated via
    /// `Self.authorize` and runs its CDP work through `state.cdpClient`.
    static func registerAgentTools(with state: BrowserState, bridge: CefBridge) {
        bridge.register("hive.agent.navigate") { (request: WebChromeAgentNavigate) async throws -> Bool in
            try Self.authorize(request.token)
            _ = try await state.cdpClient.navigate(url: request.url)
            return true
        }

        bridge.register("hive.agent.snapshot") { (request: WebChromeToken) async throws -> WebChromeAgentSnapshotResult in
            try Self.authorize(request.token)
            let nodes = try await state.cdpClient.snapshot()
            return WebChromeAgentSnapshotResult(
                nodes: nodes.map { WebChromeAXNode(ref: $0.ref, role: $0.role, name: $0.name, value: $0.value) },
                count: nodes.count
            )
        }

        bridge.register("hive.agent.axContext") { (request: WebChromeToken) async throws -> String in
            try Self.authorize(request.token)
            // AXTree → LLM-readable context (Phase 2, P2.2): a structured
            // page overview with stable refs the agent can target. Rendered
            // by AXTree.toPromptContext (flat prompt lines, BFS from roots).
            let tree = try await state.cdpClient.snapshotContext()
            return tree.toPromptContext()
        }

        bridge.register("hive.agent.read") { (request: WebChromeAgentQuery) async throws -> String in
            try Self.authorize(request.token)
            return try await state.cdpClient.readPage(format: request.format ?? "text")
        }

        bridge.register("hive.agent.click") { (request: WebChromeAgentClick) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.click(ref: request.ref, selector: request.selector)
            return true
        }

        bridge.register("hive.agent.fill") { (request: WebChromeAgentFill) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.fill(selector: request.selector, value: request.value)
            return true
        }

        bridge.register("hive.agent.type") { (request: WebChromeAgentType) async throws -> Bool in
            try Self.authorize(request.token)
            if let text = request.text { try await state.cdpClient.type(text: text) }
            else if let key = request.key { try await state.cdpClient.press(key: key) }
            return true
        }

        bridge.register("hive.agent.scroll") { (request: WebChromeAgentScroll) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.scroll(direction: request.direction ?? "down", amount: request.amount ?? 300)
            return true
        }

        bridge.register("hive.agent.evaluate") { (request: WebChromeAgentEvaluate) async throws -> String in
            try Self.authorize(request.token)
            let result = try await state.cdpClient.evaluate(expression: request.expression)
            return String(describing: result ?? "undefined")
        }

        bridge.register("hive.agent.grep") { (request: WebChromeAgentQuery) async throws -> WebChromeAgentGrepResult in
            try Self.authorize(request.token)
            let matches = try await state.cdpClient.grep(query: request.query)
            return WebChromeAgentGrepResult(matches: matches)
        }

        bridge.register("hive.agent.screenshot") { (request: WebChromeToken) async throws -> WebChromeAgentScreenshotResult in
            try Self.authorize(request.token)
            let data = try await state.cdpClient.captureScreenshot()
            return WebChromeAgentScreenshotResult(base64: data?.base64EncodedString() ?? "")
        }

        bridge.register("hive.agent.wait") { (request: WebChromeAgentWait) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.wait(ms: request.ms ?? 1000)
            return true
        }

        bridge.register("hive.agent.press") { (request: WebChromeAgentKeyRequest) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.press(key: request.key)
            return true
        }

        bridge.register("hive.agent.back") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.goBack()
            return true
        }

        bridge.register("hive.agent.forward") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.goForward()
            return true
        }

        bridge.register("hive.agent.reload") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.reload()
            return true
        }

        // ---- Tab management (completes the 16-tool agent surface) ----

        bridge.register("hive.agent.tabs") { (request: WebChromeToken) async throws -> WebChromeAgentTabsResult in
            try Self.authorize(request.token)
            let tabs = try await state.cdpClient.listTabs()
            return WebChromeAgentTabsResult(
                tabs: tabs.map { tab in
                    WebChromeAgentTabInfo(id: tab.id, title: tab.title, url: tab.url, active: tab.active)
                },
                count: tabs.count
            )
        }

        bridge.register("hive.agent.newTab") { (request: WebChromeAgentNewTab) async throws -> String in
            try Self.authorize(request.token)
            return try await state.cdpClient.newTab(url: request.url)
        }

        bridge.register("hive.agent.closeTab") { (request: WebChromeAgentTabID) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.closeTab(id: request.id)
            return true
        }

        bridge.register("hive.agent.activateTab") { (request: WebChromeAgentTabID) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.activateTab(id: request.id)
            return true
        }

        // ---- Extended act tools (Astro-derived: hover, focus, check, uncheck, select, drag, markdown read, diff) ----

        bridge.register("hive.agent.hover") { (request: WebChromeAgentClick) async throws -> Bool in
            try Self.authorize(request.token)
            guard let ref = request.ref else { return false }
            try await state.cdpClient.hover(ref: ref)
            return true
        }

        bridge.register("hive.agent.focus") { (request: WebChromeAgentClick) async throws -> Bool in
            try Self.authorize(request.token)
            guard let ref = request.ref else { return false }
            try await state.cdpClient.focus(ref: ref)
            return true
        }

        bridge.register("hive.agent.check") { (request: WebChromeAgentClick) async throws -> Bool in
            try Self.authorize(request.token)
            guard let ref = request.ref else { return false }
            try await state.cdpClient.check(ref: ref)
            return true
        }

        bridge.register("hive.agent.uncheck") { (request: WebChromeAgentClick) async throws -> Bool in
            try Self.authorize(request.token)
            guard let ref = request.ref else { return false }
            try await state.cdpClient.uncheck(ref: ref)
            return true
        }

        bridge.register("hive.agent.select") { (request: WebChromeAgentFill) async throws -> Bool in
            try Self.authorize(request.token)
            try await state.cdpClient.select(ref: request.selector, value: request.value)
            return true
        }

        bridge.register("hive.agent.drag") { (request: WebChromeAgentFill) async throws -> Bool in
            try Self.authorize(request.token)
            let parts = request.selector.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return false }
            try await state.cdpClient.drag(ref: String(parts[0]), targetRef: String(parts[1]))
            return true
        }

        bridge.register("hive.agent.readMarkdown") { (request: WebChromeAgentQuery) async throws -> String in
            try Self.authorize(request.token)
            let selector = request.format == "selector" ? request.query : nil
            return try await state.cdpClient.readPageMarkdown(selector: selector)
        }

        bridge.register("hive.agent.diff") { (request: WebChromeToken) async throws -> WebChromeAgentSnapshotResult in
            try Self.authorize(request.token)
            let (added, _) = try await state.cdpClient.diff()
            return WebChromeAgentSnapshotResult(
                nodes: added.map { WebChromeAXNode(ref: $0.ref, role: $0.role, name: $0.name, value: $0.value) },
                count: added.count
            )
        }
    }

}
