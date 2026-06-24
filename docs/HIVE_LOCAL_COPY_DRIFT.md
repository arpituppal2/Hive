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

`Package.swift` lists an explicit `sources` allowlist for `HiveMacApp`, so stray files like `HiveAppModel.swift` are ignored after sync. You still need the canonical branch tree — local edits in Downloads will block `git pull`.

### If git says "local changes would be overwritten"

Your Downloads copy has drifted. Discard it and match the branch exactly:

```bash
cd /Users/arpituppal/Downloads/Hive
git fetch origin arpituppal2/hive-production-rebuild-82c2
git checkout arpituppal2/hive-production-rebuild-82c2 || git checkout -B arpituppal2/hive-production-rebuild-82c2 origin/arpituppal2/hive-production-rebuild-82c2
git reset --hard origin/arpituppal2/hive-production-rebuild-82c2
git clean -fd
./scripts/sync-macos-build.sh
open Package.swift
```

Or as a one-liner after `cd` into the repo:

```bash
git fetch origin arpituppal2/hive-production-rebuild-82c2 && git checkout arpituppal2/hive-production-rebuild-82c2 2>/dev/null || git checkout -B arpituppal2/hive-production-rebuild-82c2 origin/arpituppal2/hive-production-rebuild-82c2; git reset --hard origin/arpituppal2/hive-production-rebuild-82c2 && git clean -fd && ./scripts/sync-macos-build.sh && open Package.swift
```

To keep a backup of local edits first:

```bash
HIVE_KEEP_LOCAL_CHANGES=1 ./scripts/sync-macos-build.sh
git stash list
```

### Normal sync (already on branch, clean tree)

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
