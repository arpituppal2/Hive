# Hive Apple HIG Three-Pass Audit - 2026-05-29

## Scope

This audit covers the five Apple documents supplied for the review:

| Document | Extracted pages | Extracted text |
| --- | ---: | ---: |
| APPLE DESIGN DOC.pdf | 300 | 210,918 chars |
| APPLE EFFICIENCY DOC.pdf | 122 | 124,371 chars |
| APPLE COMPONENTS DOC.pdf | 225 | 274,316 chars |
| APPLE INPUT DOC.pdf | 79 | 106,508 chars |
| APPLE PATTERNS DOC.pdf | 93 | 159,274 chars |
| Total supplied/extracted | 819 | 875,387 chars |

The prompt described 918 pages. The supplied files extract to 819 pages. This audit uses the complete extractable text from those files, plus source inspection of the current Hive codebase.

## Method

I normalized the extracted Apple guidance into 1,280 actionable checklist statements. Visual examples and image-only callouts are not counted as separate text statements, but their surrounding page guidance was used when it was extractable.

I then ran three independent passes:

1. Document pass: page-by-page checklist against source-level app structure.
2. Surface pass: user-visible screens and components against Apple component, input, typography, contrast, and material guidance.
3. Platform pass: macOS, iOS, iPadOS, watchOS, widgets, App Intents, iCloud, Sign in with Apple, speech input, and AI integration against Apple platform guidance.

The `Caught` column is the number of passes that found the same issue. The maximum is 3.

## Apple Guidance Anchors

| Area | Source anchor |
| --- | --- |
| Platform structure | Design pp. 1-8, 121-123 |
| Liquid Glass/materials | Design pp. 45-46, 121, 150-155 |
| App icons | Design pp. 26, 36 |
| Contrast/readability/accessibility | Design pp. 10-20, 240-254 |
| Buttons/tooltips/menus | Components pp. 48, 53-59, 83, 96-98 |
| Search/popovers/input | Components pp. 124-126, 160-162, 213; Input pp. 30, 48-49 |
| Drag and drop/loading/onboarding/settings | Patterns pp. 14-15, 29, 84-86 |
| App Shortcuts/widgets/Live Activities | Efficiency pp. 1-6, 22, 59, 104, 113-118 |

## Consolidated Issues

| ID | Issue | Source anchor | Hive evidence | Passes | Caught |
| --- | --- | --- | --- | --- | ---: |
| HIG-001 | Hive uses a custom macOS shell instead of a native split-view/window structure, so sidebar, toolbar, titlebar, resizing, and platform affordances are reimplemented inconsistently. | Design pp. 1-5, 121-123; Components p. 37 | `Sources/HiveApp/HiveApp.swift:82-88`, `Sources/HiveMacApp/HiveMacRootView.swift` | 1,2,3 | 3 |
| HIG-002 | The native sidebar toggle is explicitly removed and replaced by custom controls, which recreates the "mystery sidebar button" problem instead of following macOS sidebar conventions. | Components p. 37; Input p. 30 | `Sources/HiveMacApp/HiveMacRootView.swift:171` | 1,2,3 | 3 |
| HIG-003 | Settings is presented as in-window content rather than a proper macOS Settings surface, making the app mode switch confusing and less native. | Patterns pp. 85-86; Design pp. 3-5 | `Sources/HiveMacApp/HiveMacRootView.swift:200`, `Sources/HiveApp/HiveApp.swift:98-100` | 1,2,3 | 3 |
| HIG-004 | Liquid Glass is not limited to navigation/control layers; content rows and article actions still use glass button styling, reducing hierarchy and readability. | Design pp. 150-155 | `Sources/HiveUI/WikiSurface.swift:519`, `Sources/HiveUI/RawInputsSurface.swift:209`, `Sources/HiveUI/HiveOverlaySurfaces.swift:397` | 1,2,3 | 3 |
| HIG-005 | Liquid Glass color/tint is treated as brand paint in several places instead of sparse semantic material; Apple guidance says glass should primarily pick up surrounding content and use color sparingly. | Design pp. 45-46, 150-155 | `Sources/HiveDesignSystem/HiveDesignSystem.swift`, `Sources/HiveDesignSystem/HiveAppleNative.swift:896-1056` | 1,2,3 | 3 |
| HIG-006 | The menu bar icon uses raw `.regularMaterial` instead of the central glass policy, so reduce transparency/contrast behavior is not guaranteed. | Design pp. 150-155; Components pp. 96-98 | `Sources/HiveDesignSystem/HiveAppleNative.swift:480` | 1,2,3 | 3 |
| HIG-007 | Toolbar controls are custom HStacks instead of native toolbar item groups/search placement, so layout, labels, focus, and overflow behavior diverge from Apple controls. | Components pp. 53-59, 124-126 | `Sources/HiveMacApp/HiveMacRootView.swift:506-525` | 1,2 | 2 |
| HIG-008 | Several top-right icon controls depend on tooltips instead of visible labels or obvious placement, making first-use navigation unclear. | Components p. 48; Design pp. 15-20 | `Sources/HiveMacApp/HiveMacRootView.swift:506-525` | 2,3 | 2 |
| HIG-009 | Accessibility labels and hints are often generic activation text instead of task-specific consequences. | Design pp. 14-20; Components p. 48 | `HiveSymbolButton` and button wrappers in `Sources/HiveDesignSystem/HiveAppleNative.swift` | 1,2,3 | 3 |
| HIG-010 | The graph hit overlay is hidden from accessibility, so the visual honeycomb graph is not equivalently operable with VoiceOver or keyboard navigation. | Design pp. 14-20; Input p. 30 | `Sources/HiveUI/HiveGraphSurface.swift:411` | 1,2,3 | 3 |
| HIG-011 | Hover is required for graph discovery, but there is no complete keyboard/touch equivalent for hover plaques. | Input pp. 8, 30; Design pp. 14-20 | `Sources/HiveUI/HiveGraphSurface.swift:1545` | 1,2,3 | 3 |
| HIG-012 | The graph time scrubber is small, custom, unlabeled, and below recommended hit target expectations. | Design p. 18; Input p. 30 | `Sources/HiveUI/HiveGraphSurface.swift:575-593` | 1,2,3 | 3 |
| HIG-013 | The graph radial menu contains actions that are visible but not implemented, violating direct manipulation and feedback expectations. | Components pp. 53-59; Patterns pp. 14-15 | `Sources/HiveUI/HiveGraphSurface.swift:594-610` | 1,2,3 | 3 |
| HIG-014 | Daily tips appear as a blocking overlay instead of contextual, dismissible guidance that lets the app launch into usable content. | Patterns p. 29; Efficiency pp. 1-6 | `Sources/HiveMacApp/HiveMacRootView.swift`, `Sources/HiveUI/HiveOverlaySurfaces.swift` | 1,2,3 | 3 |
| HIG-015 | Onboarding and tips are text-heavy and explain implementation concepts rather than quickly demonstrating the first useful task. | Patterns p. 29; Design pp. 121-123 | `Sources/HiveUI/HiveOverlaySurfaces.swift` | 1,2 | 2 |
| HIG-016 | Typography uses many fixed custom sizes and font families instead of one adaptive type system that supports Dynamic Type and platform defaults. | Design pp. 10, 240-254 | `Sources/HiveDesignSystem/HiveDesignSystem.swift` | 1,2,3 | 3 |
| HIG-017 | 12 pt and smaller supporting text appears across important controls and states, which is too small for the current density and multi-device target. | Design pp. 10, 240-254; Efficiency p. 104 | `HiveTypography` and settings/graph text styles | 1,2 | 2 |
| HIG-018 | Global uppercase treatment for labels and actions harms readability, localization, and platform tone. | Design pp. 240-254 | `HiveText` transformations in `Sources/HiveDesignSystem/HiveDesignSystem.swift` | 1,2 | 2 |
| HIG-019 | There is no evidence of localization, RTL, long-label, or text-expansion verification despite many long custom button labels. | Design pp. 121-123, 240-254 | Custom labels in toolbar, graph, onboarding, settings | 1,2,3 | 3 |
| HIG-020 | Base color tokens have strong contrast, but opacity/material overlays are not proven against AA/AAA and can visually reduce readability. | Design pp. 11-12, 150-155 | 237 `color.opacity(` uses across `Sources` | 1,2,3 | 3 |
| HIG-021 | Relationship strength in the graph is encoded primarily with opacity, which is not enough for accessibility when color/opacity perception differs. | Design pp. 14-15; Input p. 30 | `Sources/HiveUI/HiveGraphSurface.swift` graph edge opacity behavior | 1,2 | 2 |
| HIG-022 | Icon-in-button nesting creates button-within-button visual noise and does not match system button hierarchy. | Components pp. 53-59 | `HiveGlassButtonStyle`, `HiveSymbolButton`, graph radial controls | 2,3 | 2 |
| HIG-023 | Corner radii are inconsistent across controls, cards, sheets, and sidebar rows, producing mixed visual language. | Components pp. 53-59, 160-162 | `HiveRadii`, ad hoc capsules, graph controls, settings rows | 1,2 | 2 |
| HIG-024 | The app minimum window is fixed at 1120x720, which blocks natural resizing and does not translate to iPad compact/regular layouts. | Design pp. 3-5, 121-123 | `Sources/HiveDesignSystem/HiveDesignSystem.swift` layout metrics | 1,2,3 | 3 |
| HIG-025 | iOS/iPadOS support is not implemented as real app surfaces; the mobile target is primarily policy/data definitions. | Design pp. 1-3, 121-123 | `Sources/HiveMobileApp/HiveMobileSupport.swift` | 1,2,3 | 3 |
| HIG-026 | watchOS actions are stubs, so the Watch app cannot perform its core glanceable tasks. | Design pp. 7-8; Input p. 22 | `Sources/HiveWatchApp/HiveWatchSupport.swift:541-542`, `:622` | 1,2,3 | 3 |
| HIG-027 | Custom watch voice capture is not wired through dictation, Speech, or iPhone companion recognition. | Design pp. 7-8; Input p. 22 | `Sources/HiveWatchApp/HiveWatchSupport.swift`, `Sources/HiveDesignSystem/HiveSpeechInputController.swift` | 1,2,3 | 3 |
| HIG-028 | Digital Crown navigation is not the primary organizing model for the entire watch experience. | Design pp. 7-8; Input p. 22 | Crown support appears only in selected watch inspection contexts | 1,3 | 2 |
| HIG-029 | Widgets are policy/snapshot structs, not real WidgetKit entries, timelines, or widget families. | Efficiency pp. 104, 113-118 | `Sources/HiveWidgets/HiveWidgetSupport.swift` | 1,2,3 | 3 |
| HIG-030 | Complications are described but not implemented as watchOS complication timeline providers. | Design pp. 7-8; Efficiency p. 22 | `Sources/HiveWidgets/HiveWidgetSupport.swift`, `Sources/HiveWatchApp/HiveWatchSupport.swift` | 1,2,3 | 3 |
| HIG-031 | Live Activities are policy-only and not implemented with ActivityKit for bounded import/synthesis sessions. | Efficiency p. 59 | `Sources/HiveWidgets/HiveWidgetSupport.swift` | 1,3 | 2 |
| HIG-032 | App Intents exist but `perform()` methods return `.result()` without routing to real app actions. | Efficiency pp. 1-6 | `Sources/HiveCore/HiveAppIntents.swift:244-424` | 1,2,3 | 3 |
| HIG-033 | No `AppShortcutsProvider` was found, so shortcuts are not surfaced as system-discoverable phrases. | Efficiency pp. 1-6 | `Sources/HiveCore/HiveAppIntents.swift` | 1,2,3 | 3 |
| HIG-034 | Menu commands and toolbar buttons do not consistently share the same command routing or App Intent execution path. | Components p. 83; Efficiency pp. 1-6 | `Sources/HiveApp/HiveApp.swift`, `Sources/HiveMacApp/HiveMacRootView.swift` | 2,3 | 2 |
| HIG-035 | Custom keyboard shortcut editing does not show robust conflict validation, unavailable states, or system-reserved shortcut handling. | Components p. 83; Input pp. 48-49 | `Sources/HiveUI/HiveOverlaySurfaces.swift` | 1,2,3 | 3 |
| HIG-036 | Menu bar extra behaves like a custom popover/control panel; Apple guidance says menu extras should display a menu unless the function clearly requires richer UI. | Components pp. 96-98 | `Sources/HiveApp/HiveApp.swift:209-218` | 1,2,3 | 3 |
| HIG-037 | The menu bar icon is small/custom and not fully aligned with menu bar status-item conventions. | Components pp. 96-98 | `Sources/HiveDesignSystem/HiveAppleNative.swift:480` | 2,3 | 2 |
| HIG-038 | Menu bar hide/show is reversible, but recovery is not discoverable from system Help or a stable menu item when the extra is gone. | Components pp. 96-98; Patterns pp. 85-86 | `Sources/HiveApp/HiveApp.swift:41-57`, settings text | 3 | 1 |
| HIG-039 | Cloud API keys fall back to `UserDefaults` when Keychain is unavailable, which is not appropriate for sensitive credentials. | Design privacy guidance; Generative AI privacy guidance | `Sources/HiveCore/MemoryCompilerModelRuntime.swift:199-202` | 1,2,3 | 3 |
| HIG-040 | Online Ask can send local memory context to a configured endpoint without a user-facing pre-send review of exactly what leaves the device. | Generative AI privacy/transparency guidance | `Sources/HiveCore/CloudChatAnswerEngine.swift` | 1,2,3 | 3 |
| HIG-041 | iCloud sync is not offered as a first-run all-or-nothing choice with a clear benefit statement. | iCloud guidance; Patterns pp. 29, 85-86 | `Sources/HiveCore/HiveCloudSync.swift`, onboarding/settings | 1,2 | 2 |
| HIG-042 | iCloud vault sync is not actually implemented for Field, Colony, and Hive files; only state/status helpers are present. | iCloud guidance | `Sources/HiveCore/HiveCloudSync.swift:230-240` | 1,2,3 | 3 |
| HIG-043 | iCloud delete warnings and conflict resolution are described in policy but not implemented as concrete flows. | iCloud guidance | `Sources/HiveCore/HiveCloudSync.swift` | 1,3 | 2 |
| HIG-044 | Sign in with Apple appears as account state policy, but credential-state refresh, revocation, and platform-native button usage are incomplete. | Sign in with Apple guidance | `Sources/HiveUI/HiveAppleAccountSurface.swift`, `Sources/HiveCore/HiveCloudSync.swift` | 1,3 | 2 |
| HIG-045 | Foundation Models integration prompts for JSON text instead of using true guided generation/schema APIs where available. | Foundation Models guidance; Generative AI outputs guidance | `Sources/HiveCore/FoundationModelMemoryRuntime.swift` | 1,2,3 | 3 |
| HIG-046 | The tiny Core ML task model tier is not implemented; availability is represented as routing metadata rather than an actual model path. | Machine Learning guidance; Core ML guidance | `Sources/HiveCore/MemoryCompilerModelRuntime.swift` | 1,2,3 | 3 |
| HIG-047 | MLX appears as a Mac model manager path, but the teacher/synthesis maintenance workflow is not fully wired into the product. | Machine Learning guidance | `Sources/HiveCore/LocalInference.swift`, `Sources/HiveCore/MemoryCompilerModelRuntime.swift` | 1,3 | 2 |
| HIG-048 | AI hardware eligibility is too coarse and does not clearly enforce the requested support ladder across iPhone 12, M-series devices, A-series iPads, Apple Intelligence, and cloud opt-in. | Machine Learning guidance; Generative AI privacy guidance | `Sources/HiveCore/MemoryCompilerModelRuntime.swift`, `Sources/HiveCore/RuntimePolicy.swift` | 1,3 | 2 |
| HIG-049 | Native Wiki search is not SQLite FTS5/BM25 despite the product plan requiring a native local index before optional qmd. | Search/tooling plan; Machine Learning guidance | `Sources/HiveCore/WikiSearchTool.swift` | 1,3 | 2 |
| HIG-050 | Core ML semantic rerank is a score bump, not a real model-backed reranking pass. | Machine Learning confidence/results guidance | `Sources/HiveCore/WikiSearchTool.swift:544` | 1,3 | 2 |
| HIG-051 | qmd command planning can run collection setup/update around searches, which risks latency/power surprises for a local-first Mac app. | Efficiency and power guidance | `Sources/HiveCore/WikiSearchTool.swift:148-154`, `:277-324` | 1,3 | 2 |
| HIG-052 | The Colony article view uses a custom line parser instead of a robust Markdown renderer/editor, limiting readability, links, tables, and accessibility. | Design typography/accessibility; Components text guidance | `Sources/HiveUI/WikiSurface.swift` | 1,2 | 2 |
| HIG-053 | Article consolidation uses custom per-row buttons instead of standard multi-selection and contextual actions. | Components pp. 37, 53-59; Input pp. 48-49 | `Sources/HiveUI/WikiSurface.swift:536` | 1,2 | 2 |
| HIG-054 | The Colony rows use glass/control styling for content, making selectable content look like floating controls. | Design pp. 150-155 | `Sources/HiveUI/WikiSurface.swift:519` | 1,2,3 | 3 |
| HIG-055 | Field ingest progress has progress text but no complete cancel/retry/undo model for long-running imports. | Patterns pp. 14-15; Generative AI loading guidance | `Sources/HiveUI/RawInputsSurface.swift` | 1,2 | 2 |
| HIG-056 | Drag and drop has visual pulse feedback but lacks full system-level confirmation/undo semantics for irreversible source intake. | Patterns pp. 14-15; Input pp. 48-49 | `Sources/HiveUI/RawInputsSurface.swift` | 1,2 | 2 |
| HIG-057 | Hive graph search opens an answer-oriented control without a clear results list, scope, or selection step. | Components pp. 124-126; Search guidance | `Sources/HiveUI/HiveGraphSurface.swift` | 2,3 | 2 |
| HIG-058 | Maximum out-zoom is not truly content-bounds-aware; the scale function returns a constant floor. | Input zoom/direct manipulation guidance | `Sources/HiveUI/HiveGraphSurface.swift:1316-1324` | 2,3 | 2 |
| HIG-059 | Graph culling can hide nodes/edges without a clear user-visible indication of what is hidden or why. | Design pp. 121-123; Accessibility guidance | `Sources/HiveUI/HiveGraphSurface.swift` | 1,2 | 2 |
| HIG-060 | Canvas graph has no equivalent alternate table/list/summary view for assistive technologies. | Design pp. 14-20; Input p. 30 | `Sources/HiveUI/HiveGraphSurface.swift` | 1,2,3 | 3 |
| HIG-061 | Some Hive/Colony/Field wording is hard-coded product copy, while the product requirement says no generic hard-coded text inside Hive/Wiki experiences. | Design tone/localization guidance | `Sources/HiveUI`, `Sources/HiveCore/WikiVault.swift` | 2 | 1 |
| HIG-062 | Several command labels are product metaphors without enough plain-language consequence, which raises first-use cognitive load. | Design clarity guidance; Components p. 48 | Command palette, sidebar labels, graph radial labels | 1,2 | 2 |
| HIG-063 | Empty and failure states are not consistently written as plain next actions; some still expose app-state language instead of task help. | Patterns loading/errors guidance | `Sources/HiveUI/HiveOverlaySurfaces.swift`, `Sources/HiveCore` status labels | 1,2 | 2 |
| HIG-064 | Settings is dense and mixes normal behavior settings with advanced implementation/tooling details. | Patterns pp. 85-86 | `Sources/HiveUI/HiveOverlaySurfaces.swift:876-952` | 1,2 | 2 |
| HIG-065 | Seeded personal-looking sample data is bundled as app resources, which can confuse privacy expectations and demo truth. | Privacy/trust guidance | `Sources/HiveApp/Resources/Seeds/HiveMemorySeed.json` | 1,2,3 | 3 |
| HIG-066 | Packaging is a manual SwiftPM macOS app build; there is no verified Xcode multi-platform app package for iOS, iPadOS, watchOS, widgets, and App Store distribution. | Platform design and distribution expectations | `Package.swift`, `scripts/build_app.sh` | 1,2,3 | 3 |
| HIG-067 | Entitlements use default/local identifiers and are not proven against real team, iCloud container, Sign in with Apple, and app group provisioning. | iCloud and Sign in with Apple guidance | `scripts/build_app.sh`, generated entitlements | 1,3 | 2 |
| HIG-068 | No automated UI/snapshot/contrast verification exists for light, dark, increased contrast, reduce transparency, reduce motion, Dynamic Type, or platform sizes. | Design pp. 10-20, 121-123 | `Tests/` source-policy tests, no UI snapshot harness found | 1,2,3 | 3 |
| HIG-069 | Several tests assert compliance flags or strings rather than exercising actual UI behavior. | Quality/feedback guidance | `Tests/HiveRebuildTests` | 1,3 | 2 |
| HIG-070 | No real simulator/device validation is present for watchOS, iOS, or iPadOS. | Design pp. 1-8, 121-123 | No Xcode scheme/device test evidence in repo | 1,2,3 | 3 |
| HIG-071 | Popover/modal behavior is not consistently designed around transient dismissal, saving state on close, or detachment when useful. | Components pp. 160-162 | Command palette, ask panels, graph overlays | 2 | 1 |
| HIG-072 | Tooltips and accessibility hints are not specific enough to explain unfamiliar symbols, especially in toolbar and graph controls. | Components p. 48 | `HiveSymbolButton` wrappers and graph controls | 1,2,3 | 3 |
| HIG-073 | Full Keyboard Access focus order is not explicitly handled for custom sidebar, graph, radial menu, and overlay controls. | Input p. 30 | Custom Canvas/overlay controls in `HiveGraphSurface` and root shell | 1,2,3 | 3 |
| HIG-074 | Placeholder text is sometimes long instructional copy instead of concise examples that set scope. | Components search/input guidance; Generative AI inputs guidance | Ask boxes, onboarding/tips, graph search | 1,2 | 2 |
| HIG-075 | Long labels still risk wrapping and crowding inside glass buttons, especially in toolbar, settings, and graph controls. | Design pp. 121-123, 240-254 | Toolbar labels and `HiveGlassButtonStyle` | 2,3 | 2 |
| HIG-076 | File import is macOS-centric and does not provide equivalent Files, Photos, share sheet, and drag/drop paths for iOS/iPadOS. | Design pp. 1-3; Patterns p. 84; Input pp. 48-49 | `RawInputsSurface`, build targets | 1,2,3 | 3 |
| HIG-077 | Startup plugin access for browser history, links, downloads, Google Drive, and disk access is represented by request UI but not proven as real permissioned connectors. | Privacy and permission guidance | `Sources/HiveUI/HiveOverlaySurfaces.swift` plugin setup UI | 1,3 | 2 |
| HIG-078 | Chat/AI answers lack a lightweight explicit feedback control to help correct model mistakes and improve future suggestions. | Machine Learning explicit feedback guidance | Chat and ask surfaces | 1,3 | 2 |
| HIG-079 | Destructive or hard-to-undo cloud/account operations are described in policy but do not have complete confirmation and recovery flows. | iCloud deletion/conflict guidance; Sign in with Apple revocation guidance | `HiveCloudSync`, account/settings surfaces | 1,3 | 2 |
| HIG-080 | Voice input exists on macOS/iOS code paths, but UI permission states and unavailable-language/offline explanations are incomplete. | Speech/input guidance; Generative AI limitations guidance | `HiveSpeechInputController`, `HiveVoiceNoteRecorder`, ask surfaces | 1,2 | 2 |
| HIG-081 | Menu bar contrast remains vulnerable because the extra blends brand color, translucency, and small text in a constrained system area. | Components pp. 96-98; Design pp. 11-12, 150-155 | `HiveMenuBarPanel`, `HiveMenuBarIcon` | 1,2,3 | 3 |
| HIG-082 | The command palette exposes commands that do not all have enabled/disabled preconditions tied to the current selection. | Components pp. 53-59, 83 | `HiveOverlaySurfaces` command palette | 1,2,3 | 3 |
| HIG-083 | Search, command palette, and Ask are separate surfaces without one coherent user mental model for "find, ask, act." | Design pp. 121-123; Components pp. 124-126 | Root toolbar, graph search, ask panels, command palette | 2,3 | 2 |
| HIG-084 | The app still relies on visual polish policy structs that declare intended behavior instead of hard implementation boundaries. | Design/material/accessibility guidance | `HiveDesignSystem`, `HiveInteractionPolicy`, policy tests | 1,3 | 2 |
| HIG-085 | The current app does not yet meet the user's stated 60/120 fps target with measured proof; performance policy exists, but no frame-time instrumentation or regression gate was found. | Efficiency/performance guidance | Graph culling/policy code without automated frame metrics | 1,2,3 | 3 |

## Reconciliation

| Caught count | Number of issues | Meaning |
| --- | ---: | --- |
| 3 | 42 | Found by document, surface, and platform passes. These are structural, not cosmetic. |
| 2 | 40 | Found by two passes. These are likely real product defects, but some need visual/device confirmation before implementation priority. |
| 1 | 3 | Found by one pass. These are still actionable, but should be validated while fixing adjacent issues. |
| Total | 85 | Consolidated noncompliance findings. |

## Highest Priority Fix Order

1. Replace the custom macOS shell with a native split-view/window/settings architecture and stop removing the standard sidebar toggle.
2. Re-scope Liquid Glass: navigation, toolbar, sidebar/control clusters, popovers, command palette, menu bar, and ask sheets only. Remove glass from content rows and prose.
3. Build a real accessibility path for the Hive graph: keyboard focus, hover equivalents, table/list fallback, labeled axes, and non-opacity-only relationship cues.
4. Convert App Intents, shortcuts, widgets, watch actions, and iCloud sync from descriptors/policies into working platform integrations.
5. Rebuild the type system around platform-scaled typography and remove global uppercase treatments.
6. Add automated visual/accessibility checks for light/dark, contrast, reduce transparency, reduce motion, Dynamic Type, and platform sizes.

## Notes

- This audit intentionally does not count "policy says it should work" as compliance. A feature counts only when the product surface or runtime path enforces it.
- Raw token contrast is not the same as rendered contrast through glass, opacity, gradients, and blurred material. Hive needs rendered contrast tests.
- The watch, widget, App Intent, iCloud, and iOS/iPadOS findings are not small polish gaps. They are missing-platform gaps relative to the requested Apple-wide product target.
