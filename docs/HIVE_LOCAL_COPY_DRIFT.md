# Hive Local Copy Drift

## What happened

If Xcode shows dozens of errors like:

- `Cannot find type 'ReindexEngine' in scope` in `Sources/HiveMacApp/HiveAppModel.swift`
- `Ambiguous use of 'HiveStartupSourcePluginCatalog'`
- `Value of type 'Color' has no member 'color'`
- `Cannot convert HiveMacApp.SourcePresentation to HiveCore.SourcePresentation`
- `Missing package product 'mlx-swift-lm_MLXLLM.MLXLLM'`

your folder is a **mixed local copy**, not the canonical branch tree.

## Canonical module layout

`HiveAppModel` lives in `Sources/HiveUI/HiveAppModel.swift`, not in `HiveMacApp`.

`HiveMacApp` should contain only:

- `HiveMacRootView.swift`
- `HiveGraphCanvasView.swift`
- `HiveAppKitGraphSurface.swift`
- `HiveMacWindowPresenter.swift`

Local-only files that must be deleted:

- `Sources/HiveMacApp/HiveAppModel.swift`
- `Sources/HiveMacApp/HivePrompt10AppKit.swift`

## Fix

`Package.swift` now lists an explicit `sources` allowlist for `HiveMacApp`, so stray files like `HiveAppModel.swift` are ignored even if they remain on disk. You still need the canonical `HiveMacRootView.swift` from git — run the sync script if that file was edited locally.

From the repo root:

```bash
git pull origin arpituppal2/hive-production-rebuild-82c2
./scripts/sync-macos-build.sh
open Package.swift
```

In Xcode:

1. **File → Packages → Reset Package Caches**
2. **File → Packages → Resolve Package Versions**
3. **Product → Clean Build Folder**
4. Build scheme **HiveApp** for macOS

## If Downloads is not a git clone

Do not keep building from `/Users/arpituppal/Downloads/Hive`. Clone fresh:

```bash
git clone https://github.com/arpituppal2/Hive.git ~/Developer/Hive
cd ~/Developer/Hive
git checkout arpituppal2/hive-production-rebuild-82c2
./scripts/sync-macos-build.sh
open Package.swift
```
