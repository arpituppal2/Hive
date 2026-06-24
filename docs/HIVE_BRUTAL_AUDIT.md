# Hive — Brutally Honest Architecture & Quality Audit

_Generated from a full static audit of `Sources/` (91 Swift files, ~54k LOC across 10 modules). No Swift toolchain is available in this environment, so findings are from static analysis, not runtime profiling. Every claim below has a `file:line` anchor so it can be verified directly._

## Executive verdict

The "crashes everywhere / nothing works" framing is **not** what the code actually shows. The codebase is structurally more disciplined than the symptoms suggest:

- **0** `fatalError` / `preconditionFailure` / `as!` in production paths.
- **1** genuine launch-crash bomb (a double-fault `try!`) — now fixed.
- A **real design-token system** exists and the primary macOS surfaces honor it.
- The core engines the spec demands (re-index trust coordinator, dedup, topic-dominance warning, Colony compiler, contradiction detection, routing classifier, capability detection) **already exist**.

The real problems are **architectural debt**, not random breakage:

1. `HiveAppModel` is a 3,899-line god object (58 `@Published` properties) doing DB + AI + navigation + auth + swarm + legacy chat.
2. **Two parallel settings UIs** (`HiveSettingsSurface` vs `HiveSettingsSheet`) and a `@AppStorage`/typed-store/`HiveAppPreferences` soup.
3. **Two AI conversation systems** (ephemeral `chatEntries` vs persisted Swarm) with menu/dock routing that conflates them.
4. **Three graph render pipelines** (SwiftUI `GraphNodeHex`, AppKit `HiveGraphCanvasView`, Metal `LivingGraphRender`).
5. **~20 GCD background→main hops** inside a `@MainActor` model — works today, not Swift 6-clean.
6. Mobile/watch targets are **not real clients** of the architecture (no `HiveAppModel`, no `HiveStore`).

None of these cause "everything is broken"; they cause drift, inconsistency, and fragility. The honest path is **consolidation before new features**.

---

## Phase 1 — Inventory

**Entry point:** single `@main struct HiveExecutable: App` (`Sources/HiveApp/HiveApp.swift:1069`). Scenes: `WindowGroup`, `MenuBarExtra`, `Settings`. `HiveDaemon/main.swift` is a separate CLI process with its own `HiveStore`.

**Surfaces** (`HiveMacRootView.mainSurface`, `Sources/HiveMacApp/HiveMacRootView.swift:510`): `.rawInputs` (Field), `.wiki` (Colony), `.graph` (Hive), `.swarm`. Navigation is a custom `HStack` shell, **not** `NavigationSplitView`/`NSSplitView`; sidebar width hardcoded to 180pt.

**Database:** single SQLite connection per `HiveStore` (`Sources/HiveCore/Store.swift:33`), `NSRecursiveLock` + `SQLITE_OPEN_FULLMUTEX` + WAL, `BEGIN IMMEDIATE` transactions. Clean layering. Dead alternate persistence (`SQLiteHiveDataStore`/`SwiftDataHiveDataStore` in `HiveDataStore.swift`) is **test-only** — recommend deleting from the app target or clearly fencing it.

**Singletons:** `CapabilityStore.shared`, `HiveWatchConnectivityHandler.shared`. No global `HiveStore.shared` (good — store is instance-owned).

---

## Phase 2 — Crash audit

| Pattern | Count | Verdict |
|---|---|---|
| `try!` | 1 → **fixed** | was CRITICAL |
| `fatalError`/`precondition`/`assertion` | 0 | clean |
| `as!` | 0 | clean |
| Force unwraps | 6 | 1 meaningful (fixed) + 5 low |
| IUO properties | 0 | clean |
| `.sync` deadlock risk | 0 | clean |
| MainActor/GCD hops | ~20 | systemic, deferred |

**Fixed in this pass:**
- `Sources/HiveUI/HiveAppModel.swift:544` — `try! HiveStore(...)` double-fault → safe in-memory fallback.
- `Sources/HiveCore/WikiArticleConsolidator.swift:30` — `.first!` → `guard let`.
- `Sources/HiveCore/GraphEngine.swift:205` — `loop.nodeIDs[0]` → `guard let firstNodeID`.
- `Sources/HiveCore/WikiMarpDeckExporter.swift:47` — `fileURL!` → bound local.
- `Sources/HiveCore/HiveFoundationModelsOrchestrator.swift:1222` — `userPrompt!` → nil-coalesced local.

**Deferred (HIGH, needs compiler to verify safely):** the ~20 `DispatchQueue.global → DispatchQueue.main.async { self... }` hops in `HiveAppModel` (e.g. `:806`, `:1513`, `:1851`, `:1875`, `:2066`, `:2134`). They work under current build settings but fight the `@MainActor` annotation and are not Swift 6 strict-concurrency clean. Recommended: migrate to `Task { @MainActor in ... }` with `nonisolated` snapshot handoffs — but only with a working toolchain to verify.

**Deferred (MEDIUM):** `HiveGraphSurface.swift:1720` orchestrates reindex from a `Task.detached` capturing View `@State` (`reindexRequestID`) — stale-instance risk; should move to the model.

---

## Phase 3 — State management

**Duplicate sources of truth (worst → least):**
1. **Settings** — `HiveSettingsSurface` (Settings window) AND `HiveSettingsSheet` (`model.settingsVisible`) are two different UIs with overlapping sections and no parity; plus `@AppStorage` keys + typed stores + `HiveAppPreferences`. `HiveAppPreferences.sidebarVisible` and `@AppStorage("hive.sidebarVisible")` are two reactive owners of the **same** key.
2. **AI conversation** — legacy `chatEntries`/`chatVisible` (in-memory) vs persisted `swarmThreads`. Dock "Open Swarm" sets `chatVisible = true` (`HiveApp.swift:1114`) instead of `selectedSurface = .swarm`.
3. **Navigation** — `HiveAppModel.selectedSurface` + `HiveCloudAppStateSync` mirror + `HiveMobileNavigationState` + watch local `@State`.
4. **Capture** — `HiveShiftCaptureHotKeyController.phase` + model ingestion + mobile `pendingCaptures` (no store path).
5. **Graph search** — `model.graphSearchVisible/Text` + view `searchDraft` + `instrumentSearchVisible`.

**Recommended SSOT:** navigation → `HiveAppModel` (extract `HiveNavigationState`); selected source/node → already model-owned (keep); AI → Swarm threads only, deprecate `chatEntries`; settings → one typed store + one UI; capture → a single capture-session enum on the model; domain data → `HiveStore` (already authoritative; UI arrays are derived snapshots — keep that direction, never write UI state back to the store).

**Circular-update risk:** `refreshFromStore` auto-selects a wiki page (`HiveAppModel.swift:1997`) which triggers `didSet` → cloud publish and UI jumps. Worth guarding.

---

## Phase 4 — UX (per-surface, scored /10)

Honest scores from static review of the SwiftUI surfaces (Clarity / Hierarchy / Learnability / Consistency):

| Surface | Clarity | Hierarchy | Learnability | Consistency | Note |
|---|---|---|---|---|---|
| Field (`RawInputsSurface`) | 6 | 6 | 6 | 7 | Three-pane intent present; processing-state language is good. |
| Colony (`WikiSurface`) | 7 | 7 | 7 | 7 | Strongest surface; article model is coherent. |
| Hive graph (`HiveGraphSurface`) | 5 | 5 | 4 | 5 | Powerful but 3,958 LOC; three renderers; discoverability low. |
| Swarm (`SwarmSurface`) | 6 | 6 | 6 | 6 | Sessions persist; routing invisible (good) but two chat systems confuse. |
| Settings | 3 | 4 | 3 | 3 | Two UIs, two entry paths — the weakest area. |

**Empty states:** real empty states exist (`SwarmEmptyState`, `RawSourcesEmptyState`) but some copy reads like errors ("No insights or open loops yet"). Recommend imperative, action-first copy.

---

## Phase 5 — Visual system

A genuine token layer exists in `Sources/HiveDesignSystem/HiveDesignSystem.swift` (~1,188 LOC): `HiveColorToken` (16 semantic colors, light/dark), `HiveTypography`, `HiveSpacing` (4/8/12/16/24/32/48), `HiveRadius` + `HiveLayoutMetrics`, `HiveMotion`, `HiveInterfaceScale`.

**Token-honoring:** macOS primary surfaces (root, overlays, Swarm, Wiki, Field).

**Token bypass zones (fix targets):** AppKit `HiveGraphCanvasView` (raw `NSColor(calibratedWhite:)`, `NSFont.systemFont`), Metal `LivingGraphRender` (SIMD palette), and all satellite platforms (watchOS/iOS/widgets use `.font(.title2)` etc.). These are isolated and safe to migrate incrementally.

---

## Phase 6 — Layout

macOS is fixed-column, design-token-driven — not adaptive split panes. Sidebar 180pt, no user resize. iPad uses `NavigationSplitView(.balanced)`. `GeometryReader` usage is mostly appropriate; the graph surface is the layout-complexity hotspot. Hardcoded widths that bypass tokens: Swarm columns 292/288 (`SwarmSurface.swift:49`), live overlay 560, command palette 720, AppKit canvas 2800×1800.

**"Awkward element near traffic lights":** the app uses a hidden title bar with a custom `HStack` shell; the most likely culprit is the sidebar top region / window chrome offset in `HiveMacRootView` `nativeShell` (`:225`). Needs a runtime screenshot on macOS to pin exactly — cannot be confirmed statically.

---

## Phase 7 — Components

Strong primitives in `HiveDesignSystem` (`HiveSymbol`, button styles, glass surfaces, `HiveText`, `HexagonShape`). **Competing variants to consolidate:**
- Settings: `HiveSettingsSurface` vs `HiveSettingsSheet`.
- Toolbar buttons: `HiveToolbarIconButton` vs `GraphToolbarIconButton` vs `GraphInstrumentButton`.
- Action buttons: `HiveActionButton` vs `SwarmActionButton` vs `ChatStarterButton`.
- Rows: `HiveSidebarRow`/`MenuBarActionRow`/`SwarmThreadRow`/`SourceRow`/`CommandPaletteRow` (same anatomy ~5×).
- Graph nodes: `GraphNodeHex` vs `HiveGraphCanvasView` vs `LivingGraphRender`.

---

## Phase 8 — Performance (static estimate)

Cannot run Instruments here. Static risks: `HiveAppModel` god object causes broad `@Published` invalidations (any refresh can re-render unrelated surfaces); `refreshFromStore` rebuilds many derived arrays at once; the graph surface recomputes layout/separation in-view. Recommended once a toolchain is available: profile launch, graph render, and `refreshFromStore`; split `HiveAppModel` so a source-list change doesn't invalidate the graph.

---

## Spec-compliance snapshot

| Area | Status | Evidence |
|---|---|---|
| Re-index audit + dedup + topic-dominance + log | PARTIAL→mostly PRESENT | `HiveReindexTrustCoordinator.swift` (audit `:111`, dedup `:144`, dominance `:185`, log `:89`); anti-thrash via `trustedReindexInProgress` (`HiveAppModel.swift:2266`). Gap: extraction runs outside the txn (split transactions). |
| No hardcoded "mac studio" injection | PRESENT (clean) | 0 matches in prompts. (User-specific terms still live in classifier signal lists + bundled seed JSON — acceptable as data, not prompt injection.) |
| Forbidden "Online source needed" | **FIXED** | removed in this pass; grep-confirmed 0 matches. |
| Swarm auto-routing (no manual mode) | PRESENT | `SwarmRequestRouter.decide()` (`SwarmRequestRouter.swift:57`). (Not labeled A–E, but functionally equivalent.) |
| Colony schema/cross-ref/contradiction/lint/index | PRESENT | `WikiEngine.swift` (contradictions `:124`, lint `:254`, index `:996`). Gap: cross-ref is lint-only (no auto-insert). |
| Graph semantic coords + overlap resolution | PARTIAL | unit space + deconfliction exist (`GraphPresentationSemantics.swift`); stored as scaled `x/y`, not `coord_x/coord_y` in `[-1,1]`. |
| Capability detection | PRESENT | `CapabilityDetector.swift:49`. |
| Background capture engine / `screen_captures` | ABSENT | not implemented (on-demand capture only). |

---

## Prioritized roadmap (build-safe ordering)

**Done in this pass (P0, surgical, no compiler needed):** launch-crash fix, forbidden-string removal, force-unwrap hardening.

**Next (P1 — requires a Swift toolchain to verify each step):**
1. Collapse the two settings UIs into one; unify `sidebarVisible` ownership.
2. Merge legacy `chatEntries` into Swarm; fix dock/menu "Open Swarm" to route to `.swarm`.
3. Migrate `HiveAppModel` GCD hops to structured concurrency (Swift 6 clean).
4. Pick ONE graph renderer as canonical; delete or fence the other two.

**Then (P2):**
5. Extract `HiveNavigationState` / `HiveCaptureSession` / settings store out of the god object.
6. Bring AppKit canvas, Metal palette, and satellite platforms inside the design-token fence.
7. Wire mobile/watch to a shared store reader instead of parallel state.
8. Close re-index atomicity gap (single end-to-end transaction or compensating rollback for the extraction step).

**Why P1/P2 were not auto-applied:** these are multi-hundred-line refactors across a 54k-LOC codebase. Without a Swift compiler in this environment, blind edits of that scale would very likely reintroduce the build failures that were just resolved. They should be done on a Mac with Xcode, one verifiable step at a time.
