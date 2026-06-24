# BLOCKER 5 — AppKit Graph Migration Plan

Status: planned with scaffolding.

## Current implementation audit

### Current entry points

- `Sources/HiveMacApp/HiveMacRootView.swift` renders graph via `HiveGraphSurface` when `selectedSurface == .graph`.
- `Sources/HiveUI/HiveGraphSurface.swift` is the active graph surface entry point.
- Re-index trigger path:
  - `HiveSettingsSurface.confirmAxesAndReindex()`
  - `HiveAppModel.requestHiveReindex()`
  - `HiveGraphSurface` re-index animation + callback.

### Current data model

- Graph payload type: `HiveGraphSnapshot` (`nodes`, `edges`)
- Node model: `GraphNodeRecord`
- Edge model: `GraphEdgeRecord`
- Layering/semantic data from:
  - `GraphPresentationSemantics`
  - `MemoryNodeLayerClassifier`
  - `GraphEngine`

### Current rendering path

- Main renderer: SwiftUI graph surface (`HiveGraphSurface`)
- Uses `HiveMetalRenderer` and extensive SwiftUI state/gesture composition
- Node visibility/filtering performed in SwiftUI surface before render

### Current zoom/pan/input handling

- `@State` scale + offset (`HiveGraphSurface`)
- Magnify and drag gesture state
- Trackpad pan velocity + inertia state variables in SwiftUI
- Selection and hover handled through SwiftUI gesture hit regions

## Migration target

- `NSScrollView` container for primary pan/zoom behavior
- `HiveGraphCanvasView` (AppKit `NSView`) for node/edge drawing and hit-testing
- Cursor-centered zoom using AppKit magnification + coordinate transform
- Explicit label collision resolver in canvas layout pass
- Staged reveal pipeline in AppKit draw/update loop

## Scaffolding added in this branch

- `Sources/HiveMacApp/HiveGraphCanvasView.swift`
  - AppKit canvas now draws nodes/edges, performs mouse hit-testing, and applies first-pass label collision suppression.
- `Sources/HiveMacApp/HiveAppKitGraphSurface.swift`
  - `NSViewRepresentable` wrapper around `NSScrollView` + `HiveGraphCanvasView`.
- `Sources/HiveMacApp/HiveMacRootView.swift`
  - Graph surface routing now supports AppKit preview path behind `@AppStorage("hive.graph.useAppKitCanvas")`.
- `Sources/HiveUI/HiveOverlaySurfaces.swift`
  - Advanced settings now expose “Use AppKit graph canvas (preview)” toggle for migration validation.

## Future files

- `Sources/HiveMacApp/HiveGraphCanvasLayout.swift` (collision handling, staged reveal)
- `Sources/HiveMacApp/HiveGraphHitTesting.swift` (selection and edge hit map)
- `Sources/HiveMacApp/HiveGraphZoomController.swift` (cursor-centered zoom transforms)

## What gets deleted

- SwiftUI-only gesture + trackpad momentum state in `HiveGraphSurface` once AppKit path is authoritative.
- Duplicate zoom/pan logic branches in SwiftUI graph rendering.

## What gets wrapped

- Existing `HiveGraphSurface` will be wrapped by a feature flag during transition:
  - AppKit path for macOS
  - Existing SwiftUI/Metal fallback until parity checks pass

## Risks

- Interaction parity risk (selection and momentum feel differences)
- Label overlap regressions during scale transitions
- Performance regressions if canvas redraw is not region-clipped
- Accessibility regression risk without explicit NSAccessibility nodes

## Estimated integration order

1. Wire `HiveAppKitGraphSurface` into `HiveMacRootView` behind feature flag. ✅
2. Implement node/edge rendering in `HiveGraphCanvasView`. ✅
3. Add hit-testing and selection routing. ✅
4. Add cursor-centered zoom and inertia behavior.
5. Add label collision + staged reveal (collision first-pass now in place; staged reveal pending).
6. Remove duplicated SwiftUI graph interaction code after parity validation.
