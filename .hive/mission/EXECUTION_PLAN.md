# Hive Browser — Buffy Execution Plan
## Agent-Driven Implementation: Phase 1 → Phase 4

**Owner:** Buffy (Freebuff AI Agent)
**Subagents available:** file-picker, code-searcher, basher, researcher-web, researcher-docs, thinker-with-files-gemini, code-reviewer-deepseek
**Start:** 2026-08-07 | **Target:** 2027-01-01

---

## How This Plan Works

Each task is a self-contained execution block. I spawn subagents in parallel where possible, validate output, then proceed. Every task has:
- **Spawn:** Which subagents to spawn and with what prompts/params
- **Validate:** What command to run to verify the change
- **Review:** Whether to spawn code-reviewer-deepseek after

---

## EXECUTION 0: Pre-Flight — Codebase Deep Scan

**Goal:** Understand every file I'll touch before making changes.

### E0.1: Scan BrowserState.swift structure

```
SPAWN: code-searcher
  searchQueries:
    - {pattern: "^    func |^    var |^    let ", flags: "-g BrowserState.swift", maxResults: 100}
    - {pattern: "^// MARK:", flags: "-g BrowserState.swift", maxResults: 30}

SPAWN: file-picker
  prompt: "Find all Swift files that import or reference BrowserState. I need to know the blast radius of any BrowserState changes."
  directories: ["Sources/Hive", "Tests"]

VALIDATE: Count MARK sections and functions to plan decomposition
```

### E0.2: Scan build scripts

```
SPAWN: basher
  command: "wc -l scripts/build-hive-app.sh scripts/preflight-hive-app.sh scripts/smoke-test-hive-app.sh && head -80 scripts/build-hive-app.sh"
  what_to_summarize: "What signing/codesigning steps exist, what entitlements are used, is notarization present"

VALIDATE: Identify exactly where to inject notarization + Sparkle
```

### E0.3: Verify current test baseline

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && swift test 2>&1 | tail -30"
  what_to_summarize: "Total test count, any failures, test duration"
  timeout_seconds: 120

VALIDATE: Confirm 983 tests pass before any changes
```

### E0.4: Read key design files

```
READ: Sources/Hive/Design/HiveDesign.swift
READ: Sources/Hive/HiveApp.swift
READ: Sources/Hive/BrowserState.swift (first 200 lines for structure)
READ: Package.swift
```

---

## EXECUTION 1: Notarization Pipeline (Phase 1 — P1.1)

**Goal:** Add notarization to build-hive-app.sh so the .dmg passes Gatekeeper.

### E1.1: Research Apple notarization requirements

```
SPAWN: researcher-docs
  prompt: "Apple notarization requirements for macOS apps distributed outside the App Store in 2026. What entitlements are required for Hardened Runtime? What's the notarytool command flow? What's the stapling step?"

SPAWN: researcher-web
  prompt: "macOS app notarization script example for a CEF/Chromium-based browser app in 2026. How to notarize CEF helper executables alongside the main app bundle. Example build scripts from open source browsers like Brave or Chromium."

VALIDATE: Collect the exact notarytool commands and entitlement requirements
```

### E1.2: Update Hive.entitlements for Hardened Runtime

```
READ: Sources/Hive/Hive.entitlements

THEN:

SPAWN: str_replace on Sources/Hive/Hive.entitlements
  Add hardened runtime entitlements if missing:
  - com.apple.security.cs.allow-jit (CEF JIT)
  - com.apple.security.cs.allow-unsigned-executable-memory (CEF renderer)
  - com.apple.security.cs.disable-library-validation (CEF helpers)
  - com.apple.security.network.client
  - com.apple.security.device.audio-input (voice dictation)
  - com.apple.security.device.camera (Google Lens)
  - com.apple.security.files.user-selected.read-write (downloads)

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && /usr/libexec/PlistBuddy -c 'Print' Sources/Hive/Hive.entitlements"
```

### E1.3: Inject notarization into build-hive-app.sh

```
READ: scripts/build-hive-app.sh (full file)

THEN:

SPAWN: str_replace on scripts/build-hive-app.sh
  After .dmg creation, add:
  1. notarytool submit --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$TEAM_ID"
  2. notarytool wait with polling
  3. xcrun stapler staple on the .dmg
  4. spctl --assess --verbose to verify Gatekeeper acceptance

SPAWN: code-reviewer-deepseek
  prompt: "Review the notarization additions to build-hive-app.sh. Check: are all error paths handled? Is the keychain access correct? Does it handle notarytool timeout?"

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && bash -n scripts/build-hive-app.sh"
```

### E1.4: Create notarization helper script

```
WRITE: scripts/notarize-hive-app.sh
  Standalone notarization script that:
  - Takes .dmg path as argument
  - Reads APPLE_ID, APPLE_APP_PASSWORD, TEAM_ID from environment or Keychain
  - Runs notarytool submit + wait + staple
  - Reports success/failure with specific error codes

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && bash -n scripts/notarize-hive-app.sh && chmod +x scripts/notarize-hive-app.sh"
```

---

## EXECUTION 2: Sparkle Auto-Update (Phase 1 — P1.2)

**Goal:** Integrate Sparkle 2.x for in-app updates.

### E2.1: Add Sparkle dependency

```
READ: Package.swift

THEN:

SPAWN: str_replace on Package.swift
  Add Sparkle 2.x as a package dependency:
  .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")

  Add to Hive target dependencies:
  .product(name: "Sparkle", package: "Sparkle")

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift package resolve 2>&1 | tail -5"
    timeout_seconds: 60
```

### E2.2: Integrate Sparkle into HiveApp.swift

```
READ: Sources/Hive/HiveApp.swift

THEN:

SPAWN: str_replace on Sources/Hive/HiveApp.swift
  Add:
  import Sparkle

  Add to HiveApp struct:
  private let updaterController: SPUStandardUpdaterController

  Init:
  init() {
      self.updaterController = SPUStandardUpdaterController(
          startingUpdater: true,
          updaterDelegate: nil,
          userDriverDelegate: nil
      )
  }

  Add to .commands:
  CommandGroup(after: .appInfo) {
      Button("Check for Updates...") {
          updaterController.checkForUpdates(nil)
      }
  }

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -20"
    timeout_seconds: 180
```

### E2.3: Configure appcast

```
SPAWN: str_replace on scripts/build-hive-app.sh
  Add Sparkle appcast generation step:
  - Generate appcast.xml using generate_appcast tool
  - Upload .dmg + appcast.xml to hivebrowser.com/downloads/
  - Set SUFeedURL in Info.plist

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && grep -r 'SUFeedURL' Sources/ scripts/ 2>/dev/null"
```

---

## EXECUTION 3: Crash Reporter (Phase 1 — P1.3)

**Goal:** Privacy-preserving crash reporting, opt-in only.

### E3.1: Create CrashReporter.swift

```
WRITE: Sources/Hive/CrashReporter.swift
  - Signal handler for SIGILL, SIGTRAP, SIGABRT, SIGBUS, SIGSEGV, SIGFPE
  - Sanitizer: strips URLs, page titles, form data from crash context
  - Writes sanitized crash log to ~/Library/Logs/Hive/
  - Opt-in flag in UserDefaults: "HiveCrashReportingEnabled"
  - On next launch: detect previous crash, offer to submit
  - Submission: HTTPS POST to crash.hivebrowser.com (only if opted in)
  - Never submits automatically — user must review + approve each report

SPAWN: code-reviewer-deepseek
  prompt: "Review Sources/Hive/CrashReporter.swift. Check: signal safety (no malloc in signal handler), privacy sanitization completeness, opt-in enforcement."

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

### E3.2: Add crash reporting opt-in to SettingsView

```
READ: Sources/Hive/SettingsView.swift

THEN:

SPAWN: str_replace on Sources/Hive/SettingsView.swift
  Add privacy section toggle:
  - "Share anonymized crash reports to help improve Hive"
  - Default: OFF
  - Stores to UserDefaults "HiveCrashReportingEnabled"

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

---

## EXECUTION 4: BrowserState.swift Decomposition (Pre-Phase 2)

**Goal:** Split the 6410-line BrowserState.swift into manageable subsystem extensions.

### E4.1: Map all MARK sections

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && grep -n '// MARK:' Sources/Hive/BrowserState.swift"
  what_to_summarize: "List all MARK sections with line numbers"

VALIDATE: Identify decomposition boundaries
```

### E4.2: Plan extension split

```
SPAWN: thinker-with-files-gemini
  prompt: "BrowserState.swift is 6410 lines. Based on the MARK sections found, propose the optimal decomposition into separate extension files. What goes in BrowserState+Tabs.swift vs BrowserState+AI.swift vs BrowserState+Workspaces.swift vs BrowserState+Chrome.swift vs BrowserState+Persistence.swift? What public API surface must stay on the main class vs move to extensions? What's the minimal set of changes to avoid breaking the 983 tests?"
  filePaths: ["Sources/Hive/BrowserState.swift", "Tests/HiveCoreTests/"]
```

### E4.3: Execute decomposition

```
Based on E4.2 output:

SPAWN: str_replace on Sources/Hive/BrowserState.swift
  Extract each subsystem to a new file:
  - Sources/Hive/BrowserState+Tabs.swift (tab CRUD, pin/essential, MRU, reorder)
  - Sources/Hive/BrowserState+AI.swift (Swarm, context modes, action approval, Studio)
  - Sources/Hive/BrowserState+Workspaces.swift (spaces, profiles, switching)
  - Sources/Hive/BrowserState+Chrome.swift (layout, panels, compact mode, command palette)
  - Sources/Hive/BrowserState+Persistence.swift (session save/load, recovery, Honeycomb)

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift test 2>&1 | tail -10"
    timeout_seconds: 120
    what_to_summarize: "Test pass/fail count, any regressions"
```

---

## EXECUTION 5: CDP DevTools — Production Access (Phase 2 — P2.1 Foundation)

**Goal:** Replace `#if DEBUG` remote debugging with in-process DevTools for agentic browsing.

### E5.1: Research CEF in-process DevTools API

```
SPAWN: researcher-docs
  prompt: "Chromium Embedded Framework (CEF) CefBrowserHost::SendDevToolsMessage API. How to send CDP commands in-process without opening a debugging port. What CDP domains are available in-process? Are there limitations vs remote debugging?"

SPAWN: code-searcher
  searchQueries:
    - {pattern: "sendDevToolsMessage|SendDevToolsMessage|devtools", flags: "-g *.h -g *.swift", maxResults: 20}
    - {pattern: "remoteDebuggingPort|remote_debugging_port", flags: "-g *.swift", maxResults: 10}

VALIDATE: Confirm CefBrowserHost.sendDevToolsMessage exists in vendored CefSwift
```

### E5.2: Build CEFDevToolsClient.swift

```
WRITE: Sources/HiveCore/AI/CEFDevToolsClient.swift
  - Wraps CefBrowserHost.sendDevToolsMessage
  - Manages CDP session (connect, disconnect, send command, receive response)
  - Handles CDP message serialization (JSON → binary → CefBinaryValue)
  - Provides async Swift API: sendCommand(method: String, params: [String: Any]) async throws -> [String: Any]
  - Supported domains: Page, Runtime, DOM, Accessibility, Input, Emulation, Browser

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

### E5.3: Remove #if DEBUG gate for DevTools in production

```
READ: Sources/Hive/HiveApp.swift (lines around 60-66)

THEN:

SPAWN: str_replace on Sources/Hive/HiveApp.swift
  Change:
    #if DEBUG
    config.remoteDebuggingPort = 9223
    #endif
  To:
    // Remote debugging port is ALWAYS available for in-process DevTools
    // but only accessible from within the browser process itself.
    // External connections are firewalled by macOS application sandbox.
    config.remoteDebuggingPort = 9223

  Add comment: In-process CDP via CefBrowserHost.sendDevToolsMessage
  is the primary path for agentic browsing. Remote port 9223 is
  sandboxed — no external access in production.

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

---

## EXECUTION 6: adblock-rust FFI Wrapper (Phase 2 — P2.5 Quick Win)

**Goal:** Integrate Brave's adblock-rust crate as a drop-in replacement for EasyList.

### E6.1: Research adblock-rust FFI surface

```
SPAWN: researcher-web
  prompt: "brave/adblock-rust crate crates.io - what C FFI bindings are available? Can it be used as a cdylib from Swift? What's the minimum API surface needed: engine creation, filter list loading, URL matching, cosmetic filtering?"

SPAWN: code-searcher
  searchQueries:
    - {pattern: "EasyList|easyList|adblock|adBlock|Adblock", flags: "-g *.swift", maxResults: 20}
    - {pattern: "hive-fetch-boundary|hive_fetch_worker", flags: "-g *.swift -g *.toml", maxResults: 20}

VALIDATE: Understand existing adblock code (EasyListBlocklist.swift) and Rust FFI pattern
```

### E6.2: Build Rust FFI crate

```
WRITE: native/adblock-ffi/Cargo.toml
  [package]
  name = "hive-adblock-ffi"
  version = "0.1.0"
  edition = "2021"

  [lib]
  crate-type = ["cdylib", "staticlib"]

  [dependencies]
  adblock = "0.8"
  once_cell = "1"

WRITE: native/adblock-ffi/src/lib.rs
  - C-ABI functions: engine_create, engine_load_filters, engine_check_url, engine_destroy
  - Global engine singleton via OnceCell
  - Returns JSON strings for Swift to parse

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive/native/adblock-ffi && cargo build --release 2>&1 | tail -10"
    timeout_seconds: 180
```

### E6.3: Build Swift wrapper

```
WRITE: Sources/HiveCore/Browser/AdblockEngine.swift
  - Swift wrapper over adblock-rust C FFI
  - Async engine initialization with filter list download
  - checkURL(_ url: URL) -> AdblockResult (blocked/reason/filter)
  - Default filter lists: EasyList, EasyPrivacy, Fanboy's Annoyance
  - Per-site disable toggle (already exists in SafeBrowsingWarning)
  - Falls back to EasyListBlocklist.swift if Rust engine unavailable

SPAWN: code-reviewer-deepseek
  prompt: "Review Sources/HiveCore/Browser/AdblockEngine.swift. Check: FFI safety, error handling, fallback path, thread safety."

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

---

## EXECUTION 7: AI Interaction States (Phase 2 — Design Fix)

**Goal:** Add loading, empty, error, partial, and degraded states to every AI feature.

### E7.1: Define AIResult protocol

```
WRITE: Sources/HiveCore/AI/AIResult.swift
  Protocol defining 5 states every AI feature must implement:

  protocol AIResult {
      associatedtype Value
      case loading(progress: Double)
      case partial(Value, remainingProviders: Int)
      case success(Value)
      case error(AIError, retry: () async -> Void)
      case degraded(Value, explanation: String)
      case empty
  }

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

### E7.2: Create AIStateView.swift

```
WRITE: Sources/Hive/AIStateView.swift
  - Reusable SwiftUI view that renders all 5 AIResult states
  - Loading: shimmer skeleton with progress bar
  - Partial: streaming text with "Waiting for 2 more models..." indicator
  - Success: rendered content
  - Error: error card with message + retry button
  - Degraded: content with yellow banner "Using fewer models than usual"
  - Empty: friendly illustration + "No results yet"

  Uses HiveDesign tokens throughout.

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | tail -10"
    timeout_seconds: 120
```

---

## EXECUTION 8: Landing Page + Waitlist (Phase 1 — P1.4)

**Goal:** Ship hivebrowser.com with download page, feature showcase, and waitlist capture.

### E8.1: Create landing page

```
WRITE: web/index.html
  - Hero: "The browser that thinks with you"
  - Feature grid: AI browsing, On-device AI, Model Council, Deep Research, Workspaces, Privacy
  - Comparison table: Hive vs Dia vs Comet vs Arc vs Zen
  - Download button (macOS .dmg, coming soon for Windows/iOS)
  - Waitlist email capture form
  - Social proof: "Join 20,000+ on the waitlist"

WRITE: web/styles.css
  - Dark theme default (matches Hive brand)
  - Responsive design
  - Subtle animations

WRITE: web/waitlist.js
  - Email capture → POST to waitlist API
  - Referral link generation
  - Count animation for waitlist numbers

VALIDATE:
  SPAWN: browser-use
    prompt: "Open web/index.html and verify: hero renders, download button is visible, waitlist form submits, comparison table is readable, mobile responsive at 375px width"
    params: {url: "file:///Users/arpituppal/Downloads/Hive/web/index.html"}
```

---

## EXECUTION 9: Test Suite Expansion (Phase 1 — P1.9)

**Goal:** Grow from 983 to 1,200+ tests covering new features.

### E9.1: Identify test gaps

```
SPAWN: code-searcher
  searchQueries:
    - {pattern: "@Test func", flags: "-g *.swift -l", maxResults: 5}
    - {pattern: "class.*Tests", flags: "-g *.swift -l", cwd: "Tests", maxResults: 20}

SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && find Tests -name '*.swift' | sort"
  what_to_summarize: "List all existing test files"
```

### E9.2: Write new tests

```
WRITE: Tests/HiveCoreTests/AdblockEngineTests.swift
  - Test filter matching (known blocked domains)
  - Test filter bypass (known clean domains)
  - Test engine initialization failure fallback
  - Test concurrent URL checking

WRITE: Tests/HiveCoreTests/CDPDevToolsClientTests.swift
  - Test CDP message serialization
  - Test command/response round-trip (mock)
  - Test session lifecycle

WRITE: Tests/HiveCoreTests/AIResultStateTests.swift
  - Test all 5 state transitions
  - Test retry mechanism
  - Test degraded state explanation

VALIDATE:
  SPAWN: basher
    command: "cd /Users/arpituppal/Downloads/Hive && swift test 2>&1 | tail -15"
    timeout_seconds: 120
    what_to_summarize: "Total test count, pass/fail, any new test failures"
```

---

## EXECUTION 10: Final Integration & Ship (End of Phase 1)

**Goal:** Build, test, and verify the complete Phase 1 deliverable.

### E10.1: Full build

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1"
  timeout_seconds: 180
  what_to_summarize: "Build success/failure, any warnings or errors"
```

### E10.2: Full test suite

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && swift test 2>&1 | tail -20"
  timeout_seconds: 180
  what_to_summarize: "Total test count, all pass/fail"
```

### E10.3: Build app bundle

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && bash scripts/build-hive-app.sh --allow-adhoc 2>&1 | tail -20"
  timeout_seconds: 300
  what_to_summarize: "Build success, .dmg path, any errors"
```

### E10.4: Preflight check

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && bash scripts/preflight-hive-app.sh --app dist/Hive.app --allow-adhoc 2>&1"
  what_to_summarize: "Preflight pass/fail, helper count, bundle structure"
```

### E10.5: Smoke test

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && HIVE_SMOKE_TIMEOUT_SECONDS=60 bash scripts/smoke-test-hive-app.sh 2>&1"
  timeout_seconds: 90
  what_to_summarize: "Smoke test pass/fail, readiness marker emitted"
```

---

## Phase 2-4 Execution Blocks (Outline)

These will be detailed when Phase 1 completes. High-level spawn patterns:

### Phase 2: AI Supremacy
- `CDPAgentTools.swift`: thinker-with-files-gemini for architecture → write_file → code-reviewer-deepseek → swift test
- `AXTreeContext.swift`: researcher-web for AXTree format → write_file → swift test
- `ModelCouncilV2.swift`: researcher-web for parallel dispatch patterns → write_file → swift test
- `AIURLBar.swift`: researcher-web for Dia UX research → str_replace on FloatingURLBarOverlay → swift build
- `DeepResearchPlanner.swift`: researcher-web for Astro pipeline → write_file → swift test
- `BriefingView.swift`: researcher-web for Calendar API → write_file → swift test

### Phase 3: Cross-Platform
- Windows: researcher-web for WinUI3+CEF patterns → write_file → Windows build verification
- iOS: researcher-docs for WKWebView → write_file → iOS simulator test
- Sync: researcher-web for Brave sync v2 protocol → write_file → swift test

### Phase 4: Growth
- SubscriptionManager: researcher-docs for StoreKit 2 → write_file → swift test
- StripeIntegration: researcher-web for Stripe iOS SDK → write_file → swift test

---

## Validation Gates

After every execution block, run:

```
SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && swift build --product Hive 2>&1 | grep -E 'error:|warning:|Build complete'"
  timeout_seconds: 120

SPAWN: basher
  command: "cd /Users/arpituppal/Downloads/Hive && swift test 2>&1 | grep -E 'passed|failed|Test Suite'"
  timeout_seconds: 180
```

If either fails, fix before proceeding to next execution block.

---

## Agent Usage Patterns

| Agent | When to use |
|-------|------------|
| `code-searcher` | Find existing patterns, imports, MARK sections, API usage |
| `file-picker` | Discover related files when blast radius is uncertain |
| `researcher-web` | Open source projects, competitive research, build patterns |
| `researcher-docs` | Apple docs, CEF API, SwiftUI, StoreKit, Sparkle docs |
| `thinker-with-files-gemini` | Non-trivial architecture decisions, decomposition planning, API design |
| `code-reviewer-deepseek` | After every new file or significant modification |
| `basher` | Build, test, validation, script syntax checks |
| `browser-use` | Verify landing page, web chrome rendering (Chrome required) |

---

**NEXT:** Start Execution 0 — pre-flight codebase scan.
