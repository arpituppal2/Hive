# SALVAGE-MANIFEST — files allowed into v2 from archive/v1

Rule: nothing enters `Sources/` except via this list. Each entry names the archive
path, what v2 takes from it, and the adaptation. Everything else stays archived.

| Archive path (@ ff74c457 / tag archive/v1) | Take | Adaptation |
|---|---|---|
| `Vendor/CefSwift/` | Whole vendored package (MIT pin @2dca11e incl. per-context scheme-handler replay fix D-002) | Restored verbatim at `Vendor/CefSwift` |
| `Sources/Hive/WebChromeHandler.swift` | `HiveSchemeHandler` structure, `CefRuntime.registerSchemeHandler` usage, session-token-in-HTML pattern, `bridge.autoInjectsShim = false`, typed `bridge.register("hive.x") { req -> resp }` pattern, http/https URL whitelist | Rewritten small: one shell token + one page token (no brief/polar), asset serving from `Bundle.module` instead of base64 Swift structs, dot-delimited methods, event queue |
| `Sources/Hive/BrowserWindow.swift` | Window construction: hidden titlebar + full-size content view + traffic-light integration over sidebar, two CEF view containers (chrome pane + content pane) with manual layout | Stripped to single-window, no workspaces/split/compact machinery |
| `Sources/Hive/HiveApp.swift` | CEF init ordering (`CefSwiftApp.main()` before scheme registration), `HIVE_DEBUG_CDP=1` devtools-port gate, quit-path flush | Cut to minimal app lifecycle |
| `Tests/HiveCoreTests/WebChromeBridgeContractTests.swift` | Contract-test approach: regex-extract every JS bridge call, assert each maps to a registered handler (both directions) | Regexes re-aimed at v2 file layout + `hive.*` dot-methods + envelope |
| `Sources/HiveCore/Browser/SessionFileStore.swift` | Crash-only `session.json` + `session.prev.json` quarantine pattern | Simplified schema: ordered tabs w/ url,title,pinned |
| Honeycomb FTS concept (`Sources/HiveCore/Honeycomb/*`) | Schema *concept*: FTS5 table over captured text with external-content indexing | New small `CaptureStore` — v2 spans model differs (offsets, versions) |

Explicitly NOT salvaged: BrowserState.swift family (333-file target), Swarm/AI cells,
adblock FFI, Sparkle wiring, extensions UI, voice, Polar/Brief surfaces, MLXRuntime
in-process path (replaced by out-of-process server decision, see design Open Questions
resolution in docs/AI-STACK-DECISION.md).
