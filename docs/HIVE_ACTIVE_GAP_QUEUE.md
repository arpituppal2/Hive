# HIVE ACTIVE GAP QUEUE

| ID | Priority | Owner | Area | Gap | Evidence | Required Fix | Status |
|---|---|---|---|---|---|---|---|
| GQ-001 | P0 | Human | Apple validation matrix | No macOS/iOS/iPadOS/watchOS runtime acceptance evidence | `docs/HIVE_SPEC_GAP_AUDIT.md` unrun acceptance list; Linux-only execution environment | Execute full matrix from `docs/HIVE_MAC_FINALIZATION_RUNBOOK.md` and fill `docs/HIVE_MAC_ACCEPTANCE_LEDGER_TEMPLATE.md` copy | OPEN |
| GQ-002 | P0 | Human | Icon Composer + assets | App icon/menu bar image set completion not verified in Xcode runtime | `Sources/HiveApp/Resources/AppIcon/ExpectedAssetNames.json`; checklist in `docs/BLOCKER_4_ICON_AND_MENUBAR_MAC_CHECKLIST.md` | Run Icon Composer, populate `Assets.xcassets`, capture screenshots, mark pass/fail | OPEN |
| GQ-003 | P1 | Human | AppKit graph parity validation | AppKit graph path implemented but needs real interaction verification/tuning on macOS | Code: `Sources/HiveMacApp/HiveGraphCanvasView.swift` (draw/hit-test/staged reveal), `Sources/HiveMacApp/HiveAppKitGraphSurface.swift` (cursor-centered magnify), toggle wiring in `HiveMacRootView.swift` + Settings | Run AppKit preview path on macOS and validate cursor zoom/selection/label behavior; tune based on runtime evidence | OPEN |
| GQ-004 | P1 | Human | Menu bar quality validation | Header/footer/live count/capture state implemented but not visually validated in dark menu bar | Code: `Sources/HiveMacApp/HiveMacRootView.swift :: HiveMenuBarPopover/MenuBarHeaderView/MenuBarFooterView` | Perform menu bar visual QA + behavior checks and record artifacts | OPEN |
| GQ-005 | P1 | Closed | Impeccable quality gate | Scoped detector and hook are configured and clean for authored scope | `npm run impeccable:detect` => `[]`; scripts in `package.json`; hook + config committed | Keep as enforced guard during Mac validation loops | CLOSED |
| GQ-006 | P1 | Human | Acceptance suite execution | Prompt acceptance suites remain unrun on Apple targets | `docs/HIVE_SPEC_GAP_AUDIT.md` Section 4 + runbook scripts | Execute suites and record results in acceptance ledger | OPEN |
| GQ-007 | P2 | Human | Final settings visual polish | Remaining settings polish requires runtime visual review | Settings IA/code updated in `Sources/HiveUI/HiveOverlaySurfaces.swift` | Run visual QA at macOS runtime, then tune any discovered issues | OPEN |

## Ownership reclassification notes

- `GQ-003` moved from Mixed to Human because meaningful agent-side code scaffolding is now in place (AppKit drawing + hit-testing + magnification + staged reveal hooks). Remaining work requires live macOS interaction validation and tuning.
