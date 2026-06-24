# HIVE REMAINING EXECUTION PLAN

## 1) Must do on Linux now

1. **Objective:** Continue AppKit graph parity implementation where possible without Apple runtime.
   **Files to edit:**
   - `Sources/HiveMacApp/HiveGraphCanvasView.swift`
   - `Sources/HiveMacApp/HiveAppKitGraphSurface.swift`
   - `Sources/HiveMacApp/HiveMacRootView.swift`
   **Exact command to run:**
   - `rg "HiveGraphCanvasView|HiveAppKitGraphSurface|hive.graph.useAppKitCanvas" /workspace/Sources`
   **Acceptance evidence required:**
   - AppKit path handles selection, zoom interaction hooks, and collision-ready layout scaffolding

2. **Objective:** Keep truth docs synchronized with live state and priority queue.
   **Files to edit:**
   - `docs/HIVE_ACTIVE_GAP_QUEUE.md`
   - `docs/HIVE_SPEC_GAP_AUDIT.md`
   - `docs/BLOCKER_4_ICON_AND_MENUBAR_MAC_CHECKLIST.md`
   - `docs/BLOCKER_5_APPKIT_GRAPH_MIGRATION_PLAN.md`
   **Exact command to run:**
   - `rg "P0|P1|OPEN|IN_PROGRESS|BLOCKED" /workspace/docs/HIVE_ACTIVE_GAP_QUEUE.md`
   **Acceptance evidence required:**
   - No stale “missing” claims for already-implemented code

## 2) Must do on your Mac in Xcode

1. **Objective:** Finalize AppKit graph migration parity.
   **Files to edit:**
   - `Sources/HiveMacApp/HiveGraphCanvasView.swift`
   - `Sources/HiveMacApp/HiveAppKitGraphSurface.swift`
   - `Sources/HiveMacApp/HiveMacRootView.swift`
   **Exact command to run:**
   - `open Package.swift`
   **Acceptance evidence required:**
   - Cursor-centered zoom
   - Selection/hit-testing
   - Label collision mitigation
   - Staged reveal behavior

2. **Objective:** Execute Icon Composer flow and populate Xcode asset catalog.
   **Files to edit:**
   - `HiveApp/Assets.xcassets/*`
   - `Sources/HiveApp/Resources/AppIcon/*` (if spec updates are needed)
   **Exact command to run:**
   - `scripts/export_icon_composer_assets.sh`
   **Acceptance evidence required:**
   - `AppIcon.appiconset` complete
   - `MenuBarActive.imageset`, `MenuBarPaused.imageset`, `DockBadgeTemplate.imageset` populated

3. **Objective:** Validate menu bar/dock behavior quality in runtime.
   **Files to edit:**
   - `Sources/HiveMacApp/HiveMacRootView.swift`
   - `Sources/HiveApp/HiveApp.swift`
   **Exact command to run:**
   - Build and run in Xcode
   **Acceptance evidence required:**
   - Header/footer visuals pass dark-mode quality checks
   - Dock menu actions route correctly
   - Dock/menu mutual accessibility constraint always enforced

4. **Objective:** Finish Impeccable quality gate.
   **Files to edit:**
   - `PRODUCT.md`
   - `DESIGN.md`
   - `.impeccable/config.json`
   **Exact command to run:**
   - `npx impeccable detect . --json`
   **Acceptance evidence required:**
   - Detector clean, or explicitly justified ignores committed

## 3) Must do in simulators/devices

1. **Objective:** Run platform matrix.
   **Targets:** macOS, iPhone, iPad, Watch, reduced motion, low-capability path.
   **Exact command / manual path:**
   - Xcode schemes for each platform target.
   **Acceptance evidence required:**
   - Pass/fail record for each matrix row with artifacts.

2. **Objective:** Run acceptance suites and close failures.
   **Suites:** Prompt AC sets, Emergency set, FINAL-I, FINAL-E.
   **Exact command / manual path:**
   - `xcodebuild -scheme Hive -destination 'platform=macOS' test`
   - Manual scripts for platform-specific interactions.
   **Acceptance evidence required:**
   - Every suite row marked pass/fail with logs/screenshots.

## 4) Final proof before merge

1. **Objective:** Produce Mac finalization evidence package.
   **Files to edit:**
   - `docs/HIVE_MAC_FINALIZATION_RUNBOOK.md`
   - `docs/HIVE_SPEC_GAP_AUDIT.md`
   - `docs/HIVE_ACTIVE_GAP_QUEUE.md`
   **Exact command to run:**
   - `rg "UNRUN|NOT RUN|OPEN" /workspace/docs`
   **Acceptance evidence required:**
   - P0/P1 queue closed or explicitly Mac-blocked with executable steps.
