# Hive Apple HIG Remediation Ledger - 2026-05-29

This file maps the three-pass audit findings to the surrounding Apple guidance used for the fix pass. It is intentionally implementation-facing: the normal app UI should not expose this level of implementation detail.

## Structural Shell, Toolbar, Settings, and Menus

| Audit IDs | Apple source | Applied fix |
| --- | --- | --- |
| HIG-001, HIG-002, HIG-003, HIG-007, HIG-008, HIG-024, HIG-034, HIG-071, HIG-073, HIG-075 | `APPLE DESIGN DOC.pdf` pp. 1-5, 121-123; `APPLE COMPONENTS DOC.pdf` pp. 37, 48, 53-59, 83, 160-162; `APPLE INPUT DOC.pdf` p. 30 | Replaced the custom shell with native `NavigationSplitView`, restored the native sidebar behavior, moved preferences into the macOS `Settings` scene, and put primary actions in a real toolbar item group with visible labels and accessibility labels. |
| HIG-035, HIG-036, HIG-037, HIG-038, HIG-081, HIG-082, HIG-083 | `APPLE COMPONENTS DOC.pdf` pp. 83, 96-98, 124-126; `APPLE EFFICIENCY DOC.pdf` pp. 1-6 | Routed menu commands, toolbar actions, command palette actions, and App Intents through shared request handling; kept the menu bar icon policy-controlled and added explicit menu bar recovery/toggle routing. |

Touched files:

- `Sources/HiveApp/HiveApp.swift`
- `Sources/HiveMacApp/HiveMacRootView.swift`
- `Sources/HiveDesignSystem/HiveAppleNative.swift`
- `Sources/HiveCore/HiveAppIntents.swift`
- `Sources/HiveUI/HiveOverlaySurfaces.swift`

## Liquid Glass, Color, Contrast, and Typography

| Audit IDs | Apple source | Applied fix |
| --- | --- | --- |
| HIG-004, HIG-005, HIG-006, HIG-020, HIG-021, HIG-022, HIG-023, HIG-068, HIG-084 | `APPLE DESIGN DOC.pdf` pp. 10-20, 45-46, 150-155, 240-254; `APPLE COMPONENTS DOC.pdf` pp. 53-59, 96-98 | Re-scoped Liquid Glass to chrome and control surfaces, added solid button styling for content rows/prose, moved the menu bar icon through `HiveLiquidGlassSurface`, and kept content surfaces opaque/readable. |
| HIG-016, HIG-017, HIG-018, HIG-019, HIG-061, HIG-062, HIG-063, HIG-074 | `APPLE DESIGN DOC.pdf` pp. 10, 121-123, 240-254; `APPLE COMPONENTS DOC.pdf` pp. 124-126 | Raised minimum production text sizes, removed global uppercasing from scaffolding/action labels, retained system typography for controls, and kept authored memory text in the separate readable register. |

Touched files:

- `Sources/HiveDesignSystem/HiveDesignSystem.swift`
- `Sources/HiveDesignSystem/HiveAppleNative.swift`
- `Sources/HiveUI/WikiSurface.swift`
- `Sources/HiveUI/RawInputsSurface.swift`
- `Sources/HiveUI/HiveOverlaySurfaces.swift`
- `Tests/HiveRebuildTests/HiveRebuildTests.swift`

## Hive Graph Interaction and Performance

| Audit IDs | Apple source | Applied fix |
| --- | --- | --- |
| HIG-009, HIG-010, HIG-011, HIG-012, HIG-013, HIG-057, HIG-058, HIG-059, HIG-060, HIG-072, HIG-085 | `APPLE DESIGN DOC.pdf` pp. 14-20, 121-123; `APPLE INPUT DOC.pdf` pp. 8, 30; `APPLE PATTERNS DOC.pdf` pp. 14-15 | Added accessibility labels/values/hints to graph nodes and scrubber, removed unimplemented radial actions, added a focus path action that performs work, made max zoom content-bounds-aware, doubled node scale, and preserved performance-oriented renderer boundaries. |

Touched files:

- `Sources/HiveUI/HiveGraphSurface.swift`
- `Tests/HiveRebuildTests/HiveRebuildTests.swift`

## Platform Reach: App Intents, Watch, Widgets, and Voice

| Audit IDs | Apple source | Applied fix |
| --- | --- | --- |
| HIG-026, HIG-027, HIG-028, HIG-029, HIG-030, HIG-031, HIG-032, HIG-033, HIG-076, HIG-080 | `APPLE DESIGN DOC.pdf` pp. 7-8; `APPLE INPUT DOC.pdf` p. 22; `APPLE EFFICIENCY DOC.pdf` pp. 1-6, 22, 59, 104, 113-118 | Converted App Intent `perform()` methods into request enqueueing, added `AppShortcutsProvider`, added WidgetKit timeline scaffolding, made watch capture/ask controls route to real app requests, and used the shared Hive symbol wrapper for watch controls. |

Touched files:

- `Sources/HiveCore/HiveAppIntents.swift`
- `Sources/HiveWatchApp/HiveWatchSupport.swift`
- `Sources/HiveWidgets/HiveWidgetSupport.swift`
- `Sources/HiveMacApp/HiveMacRootView.swift`

## AI, Search, Privacy, and Local-First Tooling

| Audit IDs | Apple source | Applied fix |
| --- | --- | --- |
| HIG-039, HIG-040, HIG-045, HIG-046, HIG-047, HIG-048, HIG-049, HIG-050, HIG-051, HIG-055, HIG-056, HIG-078 | Generative AI guidance in `APPLE DESIGN DOC.pdf`; Machine Learning guidance in `APPLE DESIGN DOC.pdf`; `APPLE EFFICIENCY DOC.pdf` pp. 1-6, 104, 113-118 | Added a native SQLite FTS5/BM25 wiki index, stopped qmd search from doing setup/update work implicitly, removed fake Core ML score manipulation, made cloud key storage fail closed when Keychain is unavailable, and added a pre-send review gate for online Ask. |

Touched files:

- `Sources/HiveCore/WikiSearchTool.swift`
- `Sources/HiveCore/MemoryCompilerModelRuntime.swift`
- `Sources/HiveUI/HiveAppModel.swift`
- `Sources/HiveUI/HiveOverlaySurfaces.swift`

## Colony, Field, Onboarding, and Content Surfaces

| Audit IDs | Apple source | Applied fix |
| --- | --- | --- |
| HIG-014, HIG-015, HIG-052, HIG-053, HIG-054, HIG-064, HIG-065, HIG-077 | `APPLE PATTERNS DOC.pdf` pp. 14-15, 29, 84-86; `APPLE COMPONENTS DOC.pdf` pp. 37, 53-59; `APPLE INPUT DOC.pdf` pp. 48-49 | Kept content rows and article prose solid, rendered article markdown through `AttributedString(markdown:)`, preserved article relation rendering separately from control markdown, and left implementation-specific setup details out of normal surfaces. |

Touched files:

- `Sources/HiveUI/WikiSurface.swift`
- `Sources/HiveUI/RawInputsSurface.swift`
- `Sources/HiveUI/HiveOverlaySurfaces.swift`
- `Sources/HiveCore/WikiVault.swift`

## Deferred Platform Work Still Tracked

Some audit items are larger than a SwiftPM source pass and remain tracked for the Xcode/project packaging phase rather than being claimed as complete runtime fixes:

- HIG-025, HIG-066, HIG-067, HIG-070: real iOS/iPadOS/watchOS project packaging, schemes, provisioning, app groups, Sign in with Apple entitlements, iCloud containers, and simulator/device validation.
- HIG-041, HIG-042, HIG-043, HIG-044, HIG-079: full iCloud document sync, conflict resolution, delete propagation, credential-state refresh, and account revocation flows.
- HIG-068, HIG-069, HIG-085: rendered UI snapshot/contrast/performance gates. Source-level policy and unit tests now pass, but rendered frame-time and contrast automation still need app-hosted measurement.

The production build and test suite verify the implemented code-level fixes from this pass. The deferred items need project-level signing/provisioning or device/simulator infrastructure before they can be honestly closed.
