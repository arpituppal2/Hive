# HIVE REMAINING EXECUTION PLAN

## 1) Must do on Linux now

1. **Objective:** Remove hardcoded topic injection and contamination-specific domain bundling.  
   **Files to edit:**  
   - `Sources/HiveCore/MemorySelfHealingEngine.swift`  
   - `Sources/HiveCore/GraphPresentationSemantics.swift`  
   - `Sources/HiveCore/PresentationAdapters.swift`  
   **Exact command to run:**  
   - `rg "mac studio|funding|entity-mac-studio-funding-goal|claim-mac-studio-funding-goal" /workspace/Sources`  
   **Acceptance evidence required:**  
   - No hardcoded prompt-banned domain terms in production logic (tests may still contain fixtures if clearly isolated)
   - Self-healing logic generalized to source-driven patterns only

2. **Objective:** Implement prompt-required re-index transactional pipeline (audit -> extract -> dedupe -> rebuild) with rollback and structured logs.  
   **Files to edit:**  
   - `Sources/HiveCore/Store.swift`  
   - `Sources/HiveCore/Ingestion.swift`  
   - `Sources/HiveCore/WikiEngine.swift`  
   - `Sources/HiveUI/HiveAppModel.swift`  
   **Exact command to run:**  
   - `rg "reindex|BEGIN IMMEDIATE TRANSACTION|ROLLBACK|log.md|is_stale|source_file_hash" /workspace/Sources`  
   **Acceptance evidence required:**  
   - Single transaction wrapper around re-index state mutation
   - Explicit rollback path exercised by test
   - Structured `Vault/Colony/log.md` append format in code

3. **Objective:** Add missing integration tests for acceptance scenarios executable in CI-like environments.  
   **Files to edit:**  
   - `Tests/HiveCoreTests/HiveCoreTests.swift`  
   - `Tests/HiveRebuildTests/HiveRebuildTests.swift`  
   **Exact command to run:**  
   - `swift test` (on machine with Swift toolchain)  
   **Acceptance evidence required:**  
   - New tests for topic dominance logic, re-index concurrent trigger handling, and rollback behavior

4. **Objective:** Add missing Impeccable scaffolding files so macOS run is actionable.  
   **Files to edit:**  
   - `PRODUCT.md`  
   - `DESIGN.md`  
   - `.impeccable/config.json` (if required by tool)  
   **Exact command to run:**  
   - `rg "impeccable|PRODUCT.md|DESIGN.md" /workspace`  
   **Acceptance evidence required:**  
   - Files exist with Hive-specific, non-placeholder content

## 2) Must do on your Mac in Xcode

1. **Objective:** Implement/verify AppKit graph rewrite per prompt (`NSScrollView` + `HiveGraphCanvasView`).  
   **Files to edit:**  
   - `Sources/HiveUI/HiveGraphSurface.swift` (or split into AppKit adapter files)  
   - `Sources/HiveMacApp/HiveMacRootView.swift`  
   **Exact command to run:**  
   - `open Package.swift`  
   **Acceptance evidence required:**  
   - Concrete `HiveGraphCanvasView` symbol and `NSScrollView` document-view wiring
   - Cursor-centered zoom behavior in runtime

2. **Objective:** Execute Icon Composer pipeline and verify AppIcon slot completion in Xcode.  
   **Files to edit:**  
   - `Sources/HiveApp/Resources/AppIcon/*`  
   - Xcode `Assets.xcassets/AppIcon` (project-side)  
   **Exact command to run:**  
   - `scripts/export_icon_composer_assets.sh`  
   **Acceptance evidence required:**  
   - Icon Composer exports generated on macOS
   - No missing AppIcon slots in Xcode asset catalog
   - Dock icon visibly custom at runtime

3. **Objective:** Complete menu bar redesign requirement (header/footer/live claim count/state variants).  
   **Files to edit:**  
   - `Sources/HiveApp/HiveApp.swift`  
   - `Sources/HiveUI/HiveOverlaySurfaces.swift`  
   - Add dedicated menu view classes if needed  
   **Exact command to run:**  
   - Build/run from Xcode on macOS  
   **Acceptance evidence required:**  
   - Header + footer custom views present
   - Live claim count updates
   - Capture state icon variants visible

4. **Objective:** Run Impeccable tooling and hook integration on Mac.  
   **Files to edit:**  
   - `PRODUCT.md`, `DESIGN.md`, `.impeccable/*`  
   **Exact command to run:**  
   - `npx impeccable detect . --json`  
   - `/impeccable polish`  
   **Acceptance evidence required:**  
   - Zero unresolved findings or justified ignores
   - Hook demonstrates regression catch on intentional violation

## 3) Must do in simulators/devices

1. **Objective:** Execute cross-platform matrix (macOS, iPhone portrait/landscape, iPad portrait/landscape, Watch relay).  
   **Files to edit:**  
   - Runtime-only validation (no file edit required unless failures found)  
   **Exact command / manual path:**  
   - Xcode schemes: Hive macOS / Hive iPhone / Hive iPad / Hive Watch  
   **Acceptance evidence required:**  
   - Pass/fail log per platform and orientation
   - Watch dictation relay response path verified

2. **Objective:** Run onboarding, settings, plugin, widget, and menu/dock acceptance checks.  
   **Files to edit:**  
   - Runtime validation first; patch failing files afterward  
   **Exact manual path:**  
   - Launch app repeatedly, resize settings window, toggle plugins, test Downloads watcher, verify widget refresh  
   **Acceptance evidence required:**  
   - Evidence table entries for each emergency acceptance criterion

3. **Objective:** Run final integration suite I-1..I-6 and edge suite E-1..E-8.  
   **Files to edit:**  
   - Runtime validation + test harness updates as needed  
   **Exact command / manual path:**  
   - `xcodebuild -scheme Hive -destination 'platform=macOS' test`  
   - Manual scenario execution per FINAL PROMPT test IDs  
   **Acceptance evidence required:**  
   - Recorded outcomes for every test ID, with failures fixed and re-run

## 4) Final proof before merge

1. **Objective:** Produce evidence-complete closeout report with only DONE/PARTIAL/MISSING/BLOCKED statuses and no optimistic language.  
   **Files to edit:**  
   - `docs/HIVE_SPEC_GAP_AUDIT.md` (update with runtime evidence)  
   **Exact command to run:**  
   - `rg "Validation: NOT RUN" docs/HIVE_SPEC_GAP_AUDIT.md`  
   **Acceptance evidence required:**  
   - Remaining NOT RUN entries reduced to zero for ship-critical requirements

2. **Objective:** Ensure no regressions and reproducible build/test flow.  
   **Files to edit:**  
   - As needed from discovered regressions  
   **Exact command to run:**  
   - `swift test`  
   - `scripts/acceptance.sh`  
   - `xcodebuild -scheme Hive -destination 'platform=macOS' test`  
   **Acceptance evidence required:**  
   - All test suites pass
   - No critical acceptance criteria left unverified

3. **Objective:** Gate merge by strict verdict upgrade logic.  
   **Files to edit:**  
   - `docs/HIVE_SPEC_GAP_AUDIT.md` verdict section  
   **Exact command to run:**  
   - Manual review checklist signoff  
   **Acceptance evidence required:**  
   - Verdict can only move above `SHIP ONLY FOR INTERNAL MAC VALIDATION` once icon pipeline + AppKit graph rewrite + platform acceptance matrix are complete
