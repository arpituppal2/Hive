import Foundation
import Testing
@testable import HiveCore

// MARK: - Morning Brief / Web Chrome Asset Contract
//
// These tests guard the integration contract between the web chrome asset
// pipeline (Scripts/embed_webchrome.py → WebChromeAssets.swift →
// HiveSchemeHandler) and the on-disk sources. They catch the failure modes
// that silently break the shipped UI:
//   1. The brief's JSON placeholder is replaced by the scheme handler — if
//      someone edits brief/index.html and drops the placeholder, the brief
//      renders empty with no error.
//   2. The embed script inventory must match the fonts on disk — a renamed
//      font silently 404s over hive://brief/fonts/.
//   3. tokens.css must be referenced by the chrome shell so the U1 token
//      system actually reaches the UI.

@Suite("MorningBriefContract")
struct MorningBriefContractTests {

    private var repoRoot: URL {
        // Tests run from the package root: .build/../Sources/... resolve to repo root.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // HiveCoreTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // repo root
    }

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(rel), encoding: .utf8)
    }

    /// Mirrors `PolarAssetRoutePolicy.mimeType` so the contract test can
    /// assert the resolver's output for every embedded asset extension.
    private static func expectedMIME(for path: String) -> String {
        if path.hasSuffix(".png") { return "image/png" }
        if path.hasSuffix(".woff2") { return "font/woff2" }
        if path.hasSuffix(".woff") { return "font/woff" }
        if path.hasSuffix(".ttf") { return "font/ttf" }
        if path.hasSuffix(".css") { return "text/css" }
        return "application/javascript"
    }

    @Test func briefTemplateHasJSONPlaceholder() throws {
        let html = try read("Sources/Hive/WebChrome/brief/index.html")
        #expect(html.contains("__HIVE_BRIEF_JSON__"),
                "brief/index.html must keep the __HIVE_BRIEF_JSON__ placeholder — HiveSchemeHandler replaces it at serve time.")
    }

    @Test func briefTemplateBrandedAsHive() throws {
        let html = try read("Sources/Hive/WebChrome/brief/index.html")
        #expect(html.contains("The Hive Brief"), "Title must be branded Hive, not Dia.")
        #expect(!html.contains("The Morning Brief"), "Dia title must not leak into the shipped brief.")
        #expect(html.contains(">Hive<"), "Footer brand chip must read Hive.")
        #expect(!html.contains("Dia</span>"), "Footer brand must not read Dia.")
    }

    @Test func chromeShellReferencesTokens() throws {
        let html = try read("Sources/Hive/WebChrome/index.html")
        #expect(html.contains("/tokens.css"),
                "index.html must link /tokens.css so the U1 token system reaches the chrome shell.")
    }

    @Test func embedInventoryMatchesFontsOnDisk() throws {
        // The embed script lists fonts explicitly; a rename on disk without a
        // script update silently 404s at serve time. Cross-check the two.
        let script = try read("scripts/embed_webchrome.py")
        let fileManager = FileManager.default
        let fontsDir = repoRoot.appendingPathComponent("Sources/Hive/WebChrome/brief/fonts")
        let onDisk = try fileManager.contentsOfDirectory(atPath: fontsDir.path)
            .filter { $0.hasSuffix(".woff2") }
            .sorted()

        // Every font on disk must be declared in the embed script.
        for font in onDisk {
            #expect(script.contains(font),
                    "\(font) exists on disk but Scripts/embed_webchrome.py does not declare it — it would never ship in the .app.")
        }
        // Every font declared in the script must exist on disk.
        let declared = ["Exposure-400.woff2", "Exposure-500.woff2", "Exposure-550.woff2",
                        "Exposure-550-Italic.woff2", "Exposure-600.woff2"]
        for font in declared {
            #expect(onDisk.contains(font), "Embed script declares \(font) but it is missing on disk.")
        }
        #expect(onDisk.count == 5, "Expected exactly the 5 Exposure font files.")
    }

    @Test func briefAppJSBrandedAsHive() throws {
        let js = try read("Sources/Hive/WebChrome/brief/app.js")
        #expect(!js.contains("BCNY"), "BCNY training-data copy must not leak into the Hive brief.")
        #expect(js.contains("Hive assembles this brief"), "Intro mission copy must be Hive-branded.")
        #expect(js.contains("Your daily Hive brief"), "Intro eyebrow must be Hive-branded.")
    }

    @Test func polarWorkspaceIsReachableAndClassifiedAsInternalChrome() throws {
        let browserState = try read("Sources/Hive/BrowserState.swift")
        let core = try read("Sources/Hive/BrowserState+Core.swift")
        let handler = try read("Sources/Hive/WebChromeHandler.swift")
        let app = try read("Sources/Hive/WebChrome/app.js")

        #expect(browserState.contains("webChromePolarURL"),
                "Polar needs a stable internal URL constant.")
        #expect(browserState.contains("hive://polar"),
                "The Polar URL constant must use the internal hive://polar route.")
        #expect(core.contains("isInternalWebChromeURL"),
                "Polar must be included in the centralized internal web-chrome classifier.")
        #expect(core.contains("case \"start\", \"brief\", \"polar\": return true"),
                "Polar must be included alongside the existing Hive-owned routes.")
        #expect(handler.contains("hive.openPolar"),
                "The shell must expose an explicit Polar bridge action.")
        #expect(handler.contains("state.newTab(url: BrowserState.webChromePolarURL)"),
                "The Polar action must open an ordinary Hive tab through BrowserState.")
        #expect(app.contains("label: 'Open Agent Workspace'"),
                "The user must be able to discover the workspace from the command palette.")
        #expect(app.contains("api('hive.openPolar')"),
                "The command palette must call the shell-gated bridge action.")
    }

    @Test func internalTabProvenanceCoversHibernatedRestoreAndDuplication() throws {
        let browserState = try read("Sources/Hive/BrowserState.swift")
        let setup = try read("Sources/Hive/BrowserState+Setup.swift")
        let sync = try read("Sources/Hive/BrowserState+Sync.swift")
        let tabs = try read("Sources/Hive/BrowserState+Tabs.swift")

        #expect(browserState.contains("savedURL: URL? = nil"),
                "Tab must expose a durable savedURL for hibernated destinations.")
        #expect(browserState.contains("self.savedURL = savedURL"),
                "Tab initialization must preserve the durable wake URL.")
        #expect(sync.contains("Self.isInternalWebChromeURL(tab.model.url) || Self.isInternalWebChromeURL(tab.savedURL)"),
                "Internal provenance must inspect both live and hibernated tab URLs.")
        #expect(setup.contains("profile: cefProfile(for: ti.workspaceID),\n                savedURL: savedURL"),
                "Session restoration must pass savedURL into the Tab initializer.")
        #expect(tabs.contains("let effectiveURL = source.model.url ?? source.savedURL"),
                "Duplicate-tab must derive its destination from the hibernated wake URL when needed.")
        #expect(tabs.contains("url: effectiveURL"),
                "Duplicate-tab must use the durable wake URL for hibernated sources.")
        #expect(!tabs.contains("tab.isHibernated = source.isHibernated"),
                "Duplicate-tab must create a live copy rather than an active cold renderer.")
    }

    @Test func polarBundleHasEveryDeclaredRuntimeAsset() throws {
        let script = try read("scripts/embed_webchrome.py")
        let handler = try read("Sources/Hive/WebChromeHandler.swift")
        let generated = try read("Sources/Hive/WebChromeAssets.swift")
        let polarIndex = try read("Sources/Hive/WebChrome/polar/index.html")

        // Derive the binary inventory from the embed script rather than
        // maintaining a second fixed list here. This catches newly added
        // Polar chunks that are embedded but not routed, and stale generated
        // declarations that would otherwise turn into runtime 404s.
        let binaryEntries = script
            .split(separator: "\n")
            .compactMap { line -> (name: String, path: String)? in
                let text = String(line)
                guard text.contains("polar/assets/"),
                      text.trimmingCharacters(in: .whitespaces).hasPrefix("(\"polar") else {
                    return nil
                }
                let fields = text.split(separator: "\"")
                guard fields.count > 3 else { return nil }
                return (String(fields[1]), String(fields[3]))
            }
        let binaryEntriesOnly = binaryEntries.filter { $0.path.hasSuffix(".js") || $0.path.hasSuffix(".png") }
        #expect(binaryEntriesOnly.count >= 12, "Polar binary inventory unexpectedly shrank.")
        for entry in binaryEntriesOnly {
            let routePath = "/" + entry.path.replacingOccurrences(of: "polar/", with: "")
            #expect(script.contains(entry.path), "Embed inventory is missing Polar asset \(entry.path).")
            #expect(handler.contains(routePath), "Polar route is missing asset mapping for \(routePath).")
            #expect(handler.contains("WebChromeAssets.\(entry.name)Base64"),
                    "Polar route must serve generated payload \(entry.name)Base64.")
            let declaration = "static let \(entry.name)Base64 = \""
            #expect(generated.contains(declaration),
                    "Generated WebChromeAssets.swift is missing \(entry.name)Base64.")
            if let start = generated.range(of: declaration)?.upperBound,
               let end = generated[start...].firstIndex(of: "\"") {
                let payload = String(generated[start..<end])
                #expect(payload.count > 32, "Generated \(entry.name) payload is unexpectedly empty.")
                #expect(Data(base64Encoded: payload) != nil,
                        "Generated \(entry.name) payload must be valid base64.")
            }
        }
        let polarTextAssets = ["index-BY6JzNer.css"]
        for asset in polarTextAssets {
            let routePath = "/assets/" + asset
            #expect(handler.contains(routePath), "Polar route is missing text asset mapping for \(routePath).")
            #expect(generated.contains("static let polarCSS"), "Generated Polar CSS payload is missing.")
        }

        // Exercise the same pure resolver used by the native handler. This
        // verifies route normalization and MIME contracts without requiring a
        // CEF runtime in the HiveCore test target. The expected MIME follows
        // the production policy's per-extension contract (js/png/css/woff2/
        // woff/ttf), not a fixed js-or-png split.
        for entry in binaryEntries {
            let routePath = "/" + entry.path.replacingOccurrences(of: "polar/", with: "")
            let resolved = PolarAssetRoutePolicy.resolve(routePath)
            #expect(resolved != nil, "Polar route resolver rejected \(routePath).")
            if let resolved {
                #expect(resolved.mimeType == Self.expectedMIME(for: entry.path),
                        "Polar route has the wrong MIME contract for \(routePath): got \(resolved.mimeType).")
            }
        }
        for font in ["KaTeX_Main-Regular-B22Nviop.woff2", "KaTeX_Main-Regular-Dr94JaBh.woff", "KaTeX_Main-Regular-ypZvNtVU.ttf"] {
            let resolved = PolarAssetRoutePolicy.resolve("/assets/\(font)")
            #expect(resolved == .font(name: font), "Polar font route was not resolved: \(font).")
        }
        #expect(PolarAssetRoutePolicy.resolve("/assets/not-embedded.js") == nil,
                "Unknown Polar assets must fail closed.")
        #expect(polarIndex.contains("index-QWD3Wno1.js"), "Polar entrypoint must reference its app bundle.")
        #expect(polarIndex.contains("index-BY6JzNer.css"), "Polar entrypoint must reference its stylesheet.")
        #expect(handler.contains("host == \"polar\""), "hive://polar must remain an explicit route.")
    }

    // MARK: - XSS hardening (reviewer finding: </script>-breakout)

    /// Mirrors the hardened `esc()` in BrowserState.buildBriefJSON: tab titles,
    /// hosts, and history domains are network/user-controlled strings injected
    /// into the brief's <script id="brief-data"> tag. A page titled
    /// `</script><script>…</script>` must never be able to break out of the
    /// JSON script tag. The escaper neutralizes < > & and U+2028/2029.
    private func hardenedEscape(_ s: String) -> String {
        var out = ""
        for ch in s.unicodeScalars {
            switch ch.value {
            case 0x5C: out += "\\\\"
            case 0x22: out += "\\\""
            case 0x0A: out += "\\n"
            case 0x0D: out += "\\r"
            case 0x09: out += "\\t"
            case 0x08: out += "\\b"
            case 0x0C: out += "\\f"
            case 0x3C: out += "\\u003c"
            case 0x3E: out += "\\u003e"
            case 0x26: out += "\\u0026"
            case 0x2028: out += "\\u2028"
            case 0x2029: out += "\\u2029"
            case 0x00...0x1F:
                out += String(format: "\\u%04X", ch.value)
            default:
                out.unicodeScalars.append(ch)
            }
        }
        return out
    }

    @Test func briefJSONEscapesScriptBreakout() {
        let evil = "</script><script>window.__pwned=1</script>"
        let escaped = hardenedEscape(evil)
        // The literal sequence must be fully neutralized — no raw "</script>"
        // can survive into the injected JSON blob.
        #expect(!escaped.contains("</script>"),
                "</script> breakout must be neutralized: got \(escaped)")
        #expect(!escaped.contains("<script>"),
                "<script> must be neutralized: got \(escaped)")
        #expect(escaped.contains("\\u003c"), "< must become \\u003c")
        #expect(escaped.contains("\\u003e"), "> must become \\u003e")
    }

    @Test func briefJSONEscapesJSONSpecials() {
        // Quotes/backslashes/newlines must survive as valid JSON escapes.
        let s = "tab \"title\\with\nnewline"
        let escaped = hardenedEscape(s)
        #expect(escaped.contains("\\\""), "double quote must be escaped")
        #expect(escaped.contains("\\\\"), "backslash must be escaped")
        #expect(escaped.contains("\\n"), "newline must be escaped")
        // Round-trip: the escaped output must parse as valid JSON content.
        let json = "{\"title\":\"\(escaped)\"}"
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            Issue.record("escaped output must be valid JSON: \(json)")
            return
        }
        #expect(obj["title"] == s, "escape round-trip must recover the original string")
    }

    @Test func briefJSONEscapesControlCharacters() {
        let escaped = hardenedEscape("a\u{01}b\u{1F}")
        #expect(escaped.contains("\\u0001"), "control chars must be \\u-escaped")
        #expect(escaped.contains("\\u001F"), "control chars must be \\u-escaped")
    }
}
