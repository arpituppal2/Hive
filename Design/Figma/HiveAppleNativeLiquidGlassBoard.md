# Hive Honey Obsidian Figma Board

This board is the design QA source for the Hive preview-language pass. It should be recreated in Figma from Apple Design Resources and compared against the app after every visual QA pass.

The app icon artwork is authored Figma-first at `Design/Figma/HiveGlassStackLogo/HiveGlassStackLogo.figma-source.svg`. Import that source into an open Figma file, keep the 13 construction layers editable, then export the three centered foreground hex assets listed in `Design/Figma/HiveGlassStackLogo/IconComposerLayerMap.json`.

## HIG Contract

- Hierarchy: controls and navigation sit on solid warm surfaces; Field, Colony prose, and the graph canvas stay readable and calm.
- Harmony: use SF Symbols, system spacing, adaptive light/dark appearances, and platform-native control behavior before custom ornament.
- Consistency: every icon-only action routes through the `HiveSymbol` wrappers, the HiveLiquidGlassSurface compatibility wrapper renders solid surfaces, and every motion path has a reduced-motion fallback.
- Accessibility: controls need labels, explicit hints, keyboard reachability, sufficient contrast, minimum target sizes, and non-color state signals.
- Material restraint: Solid honey and obsidian surfaces replace translucent app chrome.

## Imported Kits

- Apple Design Resources: macOS 26 Figma kit.
- Apple Design Resources: iOS and iPadOS 26 Figma kit.
- Apple app icon template for default, dark, clear, and tinted appearances.
- SF Symbols 7 reference for approved Hive chrome symbols.

## Frames

- `00 Principles`: HIG hierarchy, harmony, consistency, accessibility, platform convention, and material restraint.
- `01 Icon Composer Layers`: `Hive Glass Stack` layer stack: 13 Figma construction layers for honey depth, one centered point-up glass hex repeated at 100%, 75%, and 50%, edge refraction, and reflection glints; three Icon Composer foreground groups own translucency only for final packaging.
- `02 Shell`: sidebar, toolbar group, command entry, chat sheet, settings inspector, all with solid preview-style surfaces.
- `03 Raw Inputs`: evidence list, import/search/action chrome, and compose areas use the same solid surface stack.
- `04 Wiki`: editable article view and inspector actions share the solid honey and obsidian language.
- `05 Hive Graph`: custom graph canvas with graph-only hex nodes; graph controls use solid wrapper surfaces.
- `06 Motion`: SF Symbol effects for import, synthesis, confirm, conflict, navigation replace, and reduced-motion fallbacks.
- `07 Accessibility`: reduce transparency, reduce motion, increased contrast, keyboard focus, and VoiceOver overlays.

## Acceptance Notes

- No content row, Colony prose block, Field card, or graph canvas background uses translucent material.
- All icon-only controls use the `HiveSymbol` wrapper and have labels.
- App icon previews must remain recognizable at 1024, 512, 128, 64, and 32 px in all six appearances.
