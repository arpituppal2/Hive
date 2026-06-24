# HIVE SPEC GAP AUDIT

Branch audited: `arpituppal2/hive-production-rebuild-82c2`  
Audit date: 2026-06-24  
Scope: Requested rebuild prompts in `/home/ubuntu/.cursor/projects/workspace/uploads/I_paid_a_full_stack_for_apple_20k_to_build_Hive_fo__1__42c4.md`

## Section 1 — Non-negotiable honesty rules

1. “Implemented” does not mean “tested.”
2. “Unit tested” does not mean “works in the app.”
3. “Code exists” does not mean “meets the prompt.”
4. “Alternative implementation” must be explicitly labeled if it differs from the requested architecture.
5. “Needs macOS/Xcode” means it is not done yet for shipping purposes.
6. If a prompt asked for a custom icon, AppKit view, menu bar behavior, simulator pass, or Icon Composer pipeline, Linux-only validation is insufficient. [developer.apple](https://developer.apple.com/icon-composer/)
7. Do not infer acceptance from absence of compile errors.
8. Do not mark any UI work DONE unless you specify how it was visually validated.

## Section 2 — Source-of-truth checklist from prompts

| Requirement Area | Requested Outcome | Status | Evidence | Missing Pieces | Exact Next Action |
|---|---|---|---|---|---|
| A. Re-index engine / contamination fix | SQLite audit on every re-index against `flower-field`, stale marking by source hash, modified-source detection | **MISSING** | Code: `Sources/HiveUI/HiveAppModel.swift :: reindexHive(plan:)` only applies graph plan and writes audit event; no file hash audit path. Code-only. Validation: NOT RUN on macOS | No `source_file_hash` audit pass, no stale mark flow in reindex path | Implement reindex pre-pass in `HiveCore` (`Store.swift` + `Ingestion.swift`) to compare source hashes vs current field files and mark stale |
| A. Re-index engine / contamination fix | Per-document claim extraction w/ hard source attribution (`source_file_id` from path+mtime+size), Apple Intelligence extraction rules | **PARTIAL** | Code: `Sources/HiveCore/Ingestion.swift :: processSource` uses deterministic extractor/chunker, stores claims with `sourceRefs`; no explicit `source_file_id` hash schema described by prompt. Code-only. Validation: NOT RUN | No required source ID algorithm, no explicit Apple Intelligence extraction contract enforcement | Add schema columns + extraction metadata in `Store.swift` and extraction pipeline in `Ingestion.swift`/foundation runtime |
| A. Re-index engine / contamination fix | Dedup before graph construction using cosine > 0.91 and supporting source IDs merge | **MISSING** | Code: no cosine threshold dedup flow found in ingestion/reindex paths; `supporting_source_ids` column not evidenced. Validation: NOT RUN | Dedup algorithm + merged source support absent | Add embedding dedup stage in `IngestionCoordinator` before claim insert, plus schema support |
| A. Re-index engine / contamination fix | Topic signal normalization + dominance warning (>15%) in Field UI | **MISSING** | Code: no topic dominance threshold computation path found; no dominance banner symbol in Field surfaces. Validation: NOT RUN | Missing computation, storage, and yellow banner behavior | Implement topic frequency aggregation in `HiveCore`; render per-session dismissible banner in Field view |
| A. Re-index engine / contamination fix | Atomic re-index with rollback + phased progress sheet + log entry format | **PARTIAL** | Code: `Sources/HiveCore/Store.swift :: inTransaction` exists. Code: `Sources/HiveUI/HiveGraphSurface.swift` has reindex overlay/progress visuals. Code: `Sources/HiveUI/HiveAppModel.swift :: reindexHive(plan:)` does not wrap full reindex mutation in transaction, only graph-plan apply. Validation: NOT RUN | End-to-end atomic DB reindex transaction not proven; phase logging format acceptance not executed | Move reindex pipeline to single transactional coordinator in `HiveCore`; append required `Vault/Colony/log.md` entry format on success |
| A. Re-index engine / contamination fix | Remove hardcoded topic injection (`mac studio`, etc.) | **MISSING** | Code: `Sources/HiveCore/MemorySelfHealingEngine.swift` contains canonical hardcoded Mac Studio funding consolidation (`entity-mac-studio-funding-goal`, statements and aliases). Code: `Sources/HiveCore/GraphPresentationSemantics.swift` contains `"mac studio"`. Test fixtures also include repeated hardcoded domain. Code-only. Validation: NOT RUN | Explicitly conflicts with prompt requirement to remove hardcoded topic injection | Delete hardcoded domain logic from self-healing/presentation policy and replace with source-driven general rules |
| A. Re-index engine / contamination fix | Prompt 1 acceptance criteria #1-#6 executed | **MISSING** | Test: none found executing those scenario IDs. Validation: NOT RUN on Apple targets | None of the six acceptance runs were executed and recorded | Create integration tests and manual run logs for criteria 1-6 |
| B. Apple Intelligence / local-first capability architecture | Explicit capability tiers with user-visible degradation matrix | **PARTIAL** | Code: `Sources/HiveCore/CapabilityDetector.swift :: HiveCapabilityTier, detect()`; Code: `Sources/HiveUI/SwarmSurface.swift :: capabilityBanner`; Code+unit coverage not present for matrix branches. Validation: NOT RUN on Apple hardware | Tier behavior not validated on macOS/iOS/watch real runtime; matrix not fully proven | Run device/simulator matrix and capture evidence for each tier path |
| B. Apple Intelligence / local-first capability architecture | No silent cloud fallback; explicit user controls and messaging | **PARTIAL** | Code: `Sources/HiveUI/HiveOverlaySurfaces.swift :: online ask toggles/key`; `Sources/HiveUI/SwarmSurface.swift :: capabilityBanner`; Code-only. Validation: NOT RUN | Runtime behavior under AI-unavailable state not verified; potential silent behavior unproven | Execute no-AI scenarios on devices and verify responses and banners |
| B. Apple Intelligence / local-first capability architecture | watch/iPhone/mac behavior per requested matrix | **PARTIAL** | Code: `Sources/HiveCore/HiveWatchConnectivity.swift`; `Sources/HiveWatchApp/HiveWatchSupport.swift :: HiveWatchAskPage`; `Sources/HiveMobileApp/HiveMobileSupport.swift :: HiveIPhoneRootView composer hooks`; Code-only. Validation: NOT RUN | No paired Watch+iPhone runtime validation; iPad matrix unexecuted | Run watch relay tests on paired simulator/device and capture logs/screens |
| C. Emil-style motion and animation rewrite | App-wide replacement with property-specific animation decisions and review framework | **MISSING** | Code: `Sources/HiveDesignSystem/AnimationKit.swift` added but no app-wide proven migration against requested prompt checklists; many existing `withAnimation(HiveMotion...)` remain. Code-only. Validation: NOT RUN | Review checklist not run app-wide; substitutions not equivalent to requested full pass | Perform file-by-file animation audit and replace non-compliant animations |
| C. Emil-style motion and animation rewrite | Reduced motion compliance | **PARTIAL** | Code: `Sources/HiveDesignSystem/AnimationKit.swift :: reduceMotion/pageTransition`; also existing view-level reduce motion behavior scattered. Validation: NOT RUN | No runtime reduced-motion verification on macOS/iOS/watch | Validate with system reduced motion enabled on Apple platforms |
| D. Impeccable integration | Install/run Impeccable, create specific PRODUCT.md & DESIGN.md, detector clean, hook firing, polish zero items | **MISSING** | Files: no `PRODUCT.md`, no `DESIGN.md` in repo root scan. No evidence of `npx impeccable` runs or hooks. Validation: NOT RUN | Entire required flow absent | Install and run Impeccable on macOS, add required docs, enforce hook, rerun until clean |
| E. App icon / dock icon / menu bar icon / Icon Composer pipeline | Custom app icon designed and all app icon slots filled in Xcode asset catalog | **BLOCKED BY MACOS VALIDATION** | Code: `Sources/HiveCore/HiveIconAssetValidator.swift`; Spec file: `Sources/HiveApp/Resources/AppIcon/IconComposerSpec.json`; script support exists. Validation: NOT RUN in Xcode asset inspector; no macOS Icon Composer execution proof in this branch | Slot completion and runtime icon rendering not verified with Xcode/macOS tooling | Open Xcode on macOS, verify `Assets.xcassets/AppIcon` all slots, run app, capture screenshots |
| E. App icon / dock icon / menu bar icon / Icon Composer pipeline | Icon Composer pipeline executed on macOS | **BLOCKED BY MACOS VALIDATION** | Code/docs reference Icon Composer (`IconComposerSpec.json`, scripts), but no run artifact proof tied to this branch execution. Validation: NOT RUN | Required macOS tool execution unverified | Execute Icon Composer flow on macOS and commit exported artifacts + run log |
| E. App icon / dock icon / menu bar icon / Icon Composer pipeline | Menu bar icon variants and state switching | **PARTIAL** | Code: `Sources/HiveApp/HiveApp.swift :: MenuBarExtra + HiveMenuBarIcon`; no evidence of `MenuBarIconActive/MenuBarIconPaused` asset-state switching implementation requested by prompt | Variant mapping behavior differs from requested explicit three-variant template setup | Implement explicit variant assets and state machine, then validate visually on macOS |
| E. App icon / dock icon / menu bar icon / Icon Composer pipeline | Dock badge, dock menu, Show in Dock + Show menu bar icon settings with constraints | **MISSING** | Code: Settings has menu bar toggles only (`Sources/HiveUI/HiveOverlaySurfaces.swift` lines around Section(\"Menu Bar\")); no Dock toggle section found | Requested dock behavior/settings absent | Add Dock visibility settings and mutual-access safeguards, implement dock menu/badge |
| F. Menu bar redesign | Custom header view, live claim count, footer view, dynamic capture state, dark visual quality | **MISSING** | Code: no `HiveMenuHeaderView`, `HiveMenuFooterView`, `CaptureStatusFormatter` symbols found in `Sources`. Existing `MenuBarExtra` popover is basic action popover | Requested redesign architecture absent | Implement custom NSMenu view hierarchy and live claim count query path |
| G. Settings overhaul | Coherent IA, safe reset/export/integrity flows | **PARTIAL** | Code: `Sources/HiveMacApp/HiveMacRootView.swift :: HiveSettingsSheet` now has Export, Run Integrity Check, Reset with confirmations; `Sources/HiveUI/HiveOverlaySurfaces.swift` expanded settings sections | Not visually validated on macOS for clipping/quality and plugin UX acceptance | Run manual UI validation at multiple window sizes + dynamic type and record evidence |
| G. Settings overhaul | Plugin toggles/bookmarks actually usable end-to-end | **PARTIAL** | Code: `Sources/HiveCore/HiveSourcePluginToggleStore.swift`; `Sources/HiveUI/HiveOverlaySurfaces.swift :: handlePluginToggle`; bookmarks persisted | OAuth flow for Google Drive backend not wired in requested plugin panel behavior; runtime not validated | Implement OAuth entrypoint in plugin flow + run manual tests |
| H. Field / Colony / Hive / Swarm UX | Reindex no longer collapses everything into one obsession | **MISSING** | Code: hardcoded Mac Studio consolidation remains (`MemorySelfHealingEngine.swift`). No acceptance test proving contamination fix run | Explicit contradiction with prompt intent | Remove hardcoded self-healing bundle logic; run prompt acceptance test #1/#2 |
| H. Field / Colony / Hive / Swarm UX | Swarm routing handles local vs online correctly | **PARTIAL** | Code: routing frameworks exist + capability banner; tests exist for router units in `Tests/HiveCoreTests/HiveCoreTests.swift` (generic) | Prompt-specific runtime cases not executed (zero-context, forced mode behavior) | Add integration tests and manual runs for requested Swarm edge cases |
| H. Field / Colony / Hive / Swarm UX | Wiki of You / timeline / insights are real, not placeholders | **PARTIAL** | Code references exist in multiple surfaces; no explicit runtime validation evidence | Could still be placeholder quality; no acceptance logs/screens | Perform runtime walkthrough and attach visual proof per view |
| I. AppKit graph rewrite | `NSScrollView` + custom `HiveGraphCanvasView` architecture per prompt | **MISSING** | Code: `Sources/HiveUI/HiveGraphSurface.swift :: SwiftUI View` remains primary graph implementation; no `HiveGraphCanvasView` symbol found | Required AppKit architecture not implemented | Introduce AppKit canvas layer and integrate with current graph data model |
| J. Cross-platform validation matrix | Actual validation done for macOS/iPhone/iPad/watch/reduced motion/widgets/background/menu bar/icon acceptance | **BLOCKED BY MACOS VALIDATION** | Validation: NOT RUN on Apple toolchain in this environment; previous report also stated Linux-only limitations | No simulator/device run evidence, no Xcode test matrix evidence | Execute full matrix in Xcode/simulators/devices and log pass/fail per test ID |

## Section 3 — Evidence format commitments

Evidence cells above use this format and classification:
- `Code: <path> :: <symbol/function>`
- `Test: <path> :: <test case>` (when present)
- `Validation: NOT RUN on macOS` (or equivalent runtime statement)

No requirement was marked **DONE** without runtime evidence. Items with only code-level evidence are **PARTIAL**, **MISSING**, or **BLOCKED BY MACOS VALIDATION**.

## Section 4 — Unrun Acceptance Tests

| Test ID | What It Proves | Current Status | Why Not Run | Exact Command / Manual Path |
|---|---|---|---|---|
| P1-AC-1 | Fresh source “Arpit Uppal is learning Rust…” affects limited colony pages with source attribution | UNRUN | No Apple runtime validation executed | Manual: add file to `Vault/flower-field`, trigger Re-Index Hive in macOS app, inspect Colony + DB |
| P1-AC-2 | Topic dominance banner appears at >=15% | UNRUN | Feature itself currently missing/incomplete | Manual: add 50 same-topic sentences, run Re-Index, verify Field banner |
| P1-AC-3 | Mid-reindex failure yields full DB rollback | UNRUN | Full transactional reindex pipeline not implemented end-to-end | Manual + DB: interrupt extraction, inspect `Hive.sqlite` pre/post |
| P1-AC-4 | Re-index thrash protection (duplicate triggers ignored) | UNRUN | No executed concurrency acceptance run | Manual: trigger reindex 3x rapidly in UI, inspect DB integrity |
| P1-AC-5 | `Vault/Colony/log.md` has timestamped entry per successful reindex | UNRUN | No run evidence in this branch | Manual: run reindex, inspect log format |
| P1b-AC-1 | Graph coordinates classified by semantic axes | UNRUN | AppKit graph rewrite not implemented | Manual + DB inspection on macOS |
| P1b-AC-2 | Overlap resolution pairwise >= 0.005 via debug command | UNRUN | Required debug pathway not verified | Manual: inject duplicate coordinates, run Help debug action |
| P1b-AC-3 | Cursor-centered zoom behavior | UNRUN | Required AppKit implementation absent | Manual trackpad zoom test in AppKit canvas |
| P1b-AC-4 | Ordered staggered reveal timings | UNRUN | Animation architecture differs from prompt | Manual timing validation with screen recording |
| Emergency-Onboarding-1 | Onboarding appears 0/5 launches after completion | UNRUN | Linux environment cannot run app UI | Manual macOS repeated launches |
| Emergency-Settings-2 | Source Plugins settings scrolls with pinned paste bar at 600pt | UNRUN | No visual validation performed | Manual resize in macOS settings window |
| Emergency-Plugins-3 | Google OAuth toggle behavior and persistence | UNRUN | OAuth flow not fully wired/validated | Manual ASWebAuthenticationSession flow + restart validation |
| Emergency-Plugins-4 | URL capture to Field processing within 15s | UNRUN | No runtime plugin capture validation | Manual paste wikipedia URL and track source status |
| Emergency-Plugins-5 | Downloads watcher banner appears in 3s | UNRUN | DispatchSource workflow unverified in app runtime | Manual drop file into Downloads on macOS |
| FINAL-I-1 | Cold-start lifecycle from empty vault to populated answers | UNRUN | Entire final integration suite not executed | Manual scenario run in macOS app + DB checks |
| FINAL-I-2 | Concurrent stress without DB corruption | UNRUN | Not executed with instrumentation | Manual stress sequence + `PRAGMA integrity_check` |
| FINAL-I-3 | Apple Intelligence unavailability mid-operation handling | UNRUN | Requires Apple platform controls | Manual toggle AI availability during ingest |
| FINAL-I-4 | Dominance warning lifecycle across session/relaunch | UNRUN | Dominance feature missing | Manual after feature completion |
| FINAL-I-5 | Colony cross-reference consistency with source delete | UNRUN | Not executed | Manual source add/delete and DB+vault verification |
| FINAL-I-6 | Save Swarm session to Colony with disable-state behavior | UNRUN | Not executed | Manual multi-question session + save flow verification |
| FINAL-E-1..E-8 | Edge-case resilience suite (empty claims, 50MB PDF, external edits, locked DB, empty vault reindex, etc.) | UNRUN | Not executed on Apple runtime | Manual/automated integration runs in Xcode environment |
| Icon-AC | Icon Composer output quality and all AppIcon slots filled | UNRUN | Requires macOS Icon Composer + Xcode asset inspector | Run Icon Composer + verify `Assets.xcassets` in Xcode |
| MenuBar-AC | Redesigned header/footer/live claim count quality in dark menu bar | UNRUN | Redesign not implemented + no macOS visual run | Manual macOS menu bar inspection with capture states |

## Section 5 — Claims Previously Overstated

1. **“Hive Production Rebuild — Complete”**  
   Why overstated: Major requirements are MISSING (AppKit graph rewrite, Impeccable flow, menu bar redesign, hardcoded topic injection removal) and acceptance suites are unrun.

2. **“All plan phases are implemented”**  
   Why overstated: Plan phase labels were closed, but multiple phase-critical acceptance criteria were never executed and some architecture requirements were substituted or skipped.

3. **“Implemented across all phases: ... multi-platform support”**  
   Why overstated: Cross-platform matrix was not run in Xcode/simulators/devices; watch/iPhone relay is code-only without runtime proof.

4. **“Core P0 wiring ... in place” (implied near-completion)**  
   Why overstated: P0 prompt required specific plugin backend behaviors and real OAuth/capture/download workflows; these are partial/unverified.

5. **“Production readiness report” framing**  
   Why overstated: A report existed, but it did not enforce adversarial requirement-by-requirement acceptance evidence and could imply progress inflation.

## Section 6 — Ship/no-ship verdict

### Shipping Verdict
`NO-SHIP`

### Why
Critical spec requirements are either missing or unverified, including AppKit graph rewrite compliance, full re-index contamination fix acceptance, Impeccable integration, menu bar redesign, and Apple-platform acceptance matrix execution. Linux-only code edits are insufficient for claimed completion.

### Blocking Items
- AppKit graph architecture requirement (`NSScrollView` + `HiveGraphCanvasView`) is not implemented.
- Hardcoded topic injection (Mac Studio funding canonicalization) remains in production code.
- Prompt acceptance suites (Prompt 1, 1b, Emergency, FINAL I-1..I-6 / E-1..E-8) are unrun.
- Impeccable integration requirements (installation, docs, detector/hook/polish clean) are missing.
- Icon Composer + Xcode asset slot validation and menu bar/dock behavior validation are unexecuted.

### Fastest Path to Real Completion
1. Remove hardcoded self-healing topic injection and implement true source-driven re-index pipeline with transactional rollback and dominance checks.
2. Implement the requested AppKit graph canvas architecture and replace non-compliant graph interactions.
3. Complete Impeccable workflow (`PRODUCT.md`, `DESIGN.md`, detector + hooks + clean polish run).
4. Execute Icon Composer on macOS and verify all AppIcon slots + menu bar icon state variants in Xcode.
5. Run and document full Apple-platform acceptance matrix (macOS/iPhone/iPad/watch, reduced motion, widgets, onboarding repeats, menu bar/dock behavior) and only then reassess verdict.
