import Foundation
import Testing
@testable import HiveCore

// MARK: - Web Chrome Bridge Inventory Contract
//
// Guards the JS <-> Swift bridge surface (WebChromeHandler.swift registers,
// WebChrome/app.js calls). The Eng review flagged this as a CRITICAL failure
// mode: "renamed bridge call silently kills feature" — if the Swift side
// renames/removes a registration but the JS still calls it, `api()` rejects
// and the feature dies with no build error and often no visible log. These
// tests close that gap without booting CEF:
//   1. Every `hive.*` method CALLED from the web chrome must be REGISTERED.
//   2. The critical feature surface (agent, council, tabs, split) is present.
//   3. The bridge reference doc exists (DX review action: docs 3/10).

@Suite("WebChromeBridgeContract")
struct WebChromeBridgeContractTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // HiveCoreTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // repo root
    }

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(rel), encoding: .utf8)
    }

    /// Capture-group-1 names matched by `pattern` across `text`.
    private func names(pattern: String, in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let ns = text as NSString
        var found = Set<String>()
        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let group = match.range(at: 1)
            if group.location != NSNotFound {
                found.insert(ns.substring(with: group))
            }
        }
        return found
    }

    /// Methods the Swift side registers via `bridge.register("hive.<name>")`.
    /// Line comments are stripped first so a commented-out registration can
    /// never mask a real removal.
    private func registeredMethods() throws -> Set<String> {
        let source = try read("Sources/Hive/WebChromeHandler.swift")
        let swift = source.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        // Note the [a-zA-Z.] character class — bridge names are camelCase
        // (hive.newTab, hive.closeTab, hive.dismissCouncilVerdict, ...).
        return names(pattern: #"register\("hive\.([a-zA-Z.]+)"#, in: swift)
    }

    /// `hive.<name>` literals the JS sends through the `api(...)` helper.
    /// The pattern matches api call sites only — direct `api('hive.x', …)`
    /// AND the ternary form `api(s.tabID ? 'hive.selectTab' : 'hive.navigate', …)`.
    /// `[^)]*` stays inside one argument list, so unrelated `hive.*` literals
    /// elsewhere in the file (event names, localStorage keys) can never become
    /// false positives that demand a registration.
    private func calledMethods() throws -> Set<String> {
        let js = try read("Sources/Hive/WebChrome/app.js")
        return names(pattern: #"api\([^)]*["']hive\.([a-zA-Z.]+)"#, in: js)
    }

    @Test func everyBridgeCallFromWebChromeIsRegistered() throws {
        let registered = try registeredMethods()
        let called = try calledMethods()
        // Fail loudly and with the exact offenders — this is the silent-feature-kill guard.
        let missing = called.subtracting(registered).sorted()
        #expect(missing.isEmpty,
                "JS calls bridge methods the Swift side never registers: \(missing). A renamed/removed registration silently kills the feature.")
    }

    @Test func bridgeSurfaceIsNonEmpty() throws {
        let registered = try registeredMethods()
        #expect(registered.count >= 40, "Expected the full bridge surface to be registered, found \(registered.count).")
    }

    @Test func criticalFeatureMethodsExist() throws {
        let registered = try registeredMethods()
        let critical: Set<String> = [
            "getStartData", "navigate", "submit", "suggest", "newTab", "newPrivateTab",
            "selectTab", "closeTab", "reorderTab", "switchWorkspace", "setLayout",
            "setPanel", "setChromeDimension", "toggleCompact", "toggleSplit",
            "conveneCouncil", "dismissCouncilVerdict", "agent.run", "agent.cancel",
        ]
        let absent = critical.subtracting(registered).sorted()
        #expect(absent.isEmpty, "Critical bridge methods missing: \(absent).")
    }

    @Test func agentToolSurfaceIsRegistered() throws {
        // The full 16-tool agent surface (ROADMAP_2027): 12 observe/act tools
        // plus 4 tab-management tools.
        let registered = try registeredMethods()
        let tools: Set<String> = [
            "agent.activateTab", "agent.click", "agent.closeTab", "agent.evaluate",
            "agent.fill", "agent.grep", "agent.navigate", "agent.newTab",
            "agent.read", "agent.reload", "agent.screenshot", "agent.scroll",
            "agent.snapshot", "agent.tabs", "agent.type", "agent.wait",
        ]
        let absent = tools.subtracting(registered).sorted()
        #expect(absent.isEmpty, "Agent tool methods missing: \(absent).")
    }

    @Test func bridgeDocumentationExists() throws {
        let doc = try read("docs/WEB_CHROME_BRIDGE.md")
        #expect(doc.contains("hive."), "WEB_CHROME_BRIDGE.md must document the api(name, params) surface.")
        #expect(doc.contains("api("), "WEB_CHROME_BRIDGE.md must document the JS api(name, params) helper.")
    }
}
