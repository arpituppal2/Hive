# HIVE ACTIVE GAP QUEUE

| ID | Priority | Area | Gap | Evidence | Required Fix | Status |
|---|---|---|---|---|---|---|
| GQ-001 | P0 | Apple validation matrix | No macOS/iOS/iPadOS/watchOS runtime acceptance evidence yet | `docs/HIVE_SPEC_GAP_AUDIT.md` unrun ledger; Linux-only execution | Execute full Apple matrix and capture artifacts using runbook | OPEN |
| GQ-002 | P0 | Icon Composer + assets | App icon/menu bar asset slot completion still unverified in Xcode | `Sources/HiveApp/Resources/AppIcon/*`, checklist only | Run Icon Composer + fill `Assets.xcassets` slots + screenshot proof | OPEN |
| GQ-003 | P1 | AppKit graph migration | AppKit graph now renders nodes/edges and supports selection, but parity not complete | `Sources/HiveMacApp/HiveGraphCanvasView.swift`, `HiveAppKitGraphSurface.swift`, `HiveMacRootView.swift` | Finish cursor-centered zoom, staged reveal, and default-path switchover after runtime validation | IN_PROGRESS |
| GQ-004 | P1 | Menu bar quality | Header/footer/live state added but visual QA on macOS not yet proven | `Sources/HiveMacApp/HiveMacRootView.swift :: HiveMenuBarPopover` | Validate dark menu bar quality and interaction behavior on macOS | OPEN |
| GQ-005 | P1 | Impeccable quality gate | Scoped detector for authored files is clean | `package.json` scripts + `docs/BLOCKER_3_IMPECCABLE_STATUS.md` | Keep hook and scripts enforced during Mac finalization | CLOSED |
| GQ-006 | P1 | Acceptance suite debt | I-1..I-6 / E-1..E-8 and prompt suites not executed on Apple targets | Audit unrun ledger | Run, record, and fix failures until pass | OPEN |
| GQ-007 | P2 | Settings IA polish | Settings now broad but needs final visual/rhythm cleanup under real macOS rendering | `Sources/HiveUI/HiveOverlaySurfaces.swift` | Final typography/spacing/content polish after simulator/device QA | OPEN |
