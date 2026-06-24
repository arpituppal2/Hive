# Hive Xcode Build Fix

## Symptom

Xcode reports cascading errors such as:

- `Unable to resolve module dependency: 'HiveCore'`
- `Unable to resolve module dependency: 'HiveDesignSystem'`
- Missing `.swiftmodule` / `.abi.json` files in DerivedData

## Root cause

These are cascade failures after `HiveCore` fails to compile first.

The real blocker is usually invalid Swift in a **local** file:

`Sources/HiveCore/ReindexEngine.swift` at lines 76–78:

```swift
let phase: ReindexEnginePhase { ... } // invalid: computed properties cannot use `let`
```

Swift requires `var` for computed properties. This file is **not referenced anywhere** in the repo; re-index uses `HiveReindexTrustCoordinator` directly. A broken local copy is enough to block the entire build.

## Fastest fix (Downloads copy)

If `git pull` fails with "local changes would be overwritten", hard-reset first:

```bash
cd /Users/arpituppal/Downloads/Hive
git fetch origin arpituppal2/hive-production-rebuild-82c2
git checkout arpituppal2/hive-production-rebuild-82c2 2>/dev/null || git checkout -B arpituppal2/hive-production-rebuild-82c2 origin/arpituppal2/hive-production-rebuild-82c2
git reset --hard origin/arpituppal2/hive-production-rebuild-82c2
git clean -fd
./scripts/sync-macos-build.sh
open Package.swift
```

Manual cleanup only (if you cannot reset yet):

```bash
cd /Users/arpituppal/Downloads/Hive
rm -f Sources/HiveCore/ReindexEngine.swift
rm -f Sources/HiveMacApp/HiveAppModel.swift Sources/HiveMacApp/HivePrompt10AppKit.swift
rm -f Sources/HiveDesignSystem/AnimationKit.swift
rm -rf ~/Library/Developer/Xcode/DerivedData/Hive-*
open Package.swift
```

In Xcode: **Product → Clean Build Folder**, then build scheme **HiveApp** for macOS.

## Full sync (recommended)

If this folder is a git clone:

```bash
cd /Users/arpituppal/Downloads/Hive
git fetch origin
git checkout arpituppal2/hive-production-rebuild-82c2
git pull origin arpituppal2/hive-production-rebuild-82c2
rm -rf ~/Library/Developer/Xcode/DerivedData/Hive-*
open Package.swift
```

Open `Package.swift` directly. Do **not** open a stale generated `.xcodeproj`.

## Expected result

- `HiveCore` compiles first.
- Dependent modules (`HiveDesignSystem`, `HiveUI`, `HiveMacApp`, etc.) resolve normally.
- mlx-swift C++17 warnings in dependencies are non-blocking.

## Verify from terminal

```bash
cd /Users/arpituppal/Downloads/Hive
xcodebuild -scheme HiveApp -destination 'platform=macOS' build
```

## Local copy drift (many HiveMacApp errors)

If you see errors in `Sources/HiveMacApp/HiveAppModel.swift`, `HivePrompt10AppKit.swift`, or dozens of `Color has no member 'color'` / ambiguous symbol errors, your folder is mixed with local-only files.

Run:

```bash
./scripts/sync-macos-build.sh
```

See `docs/HIVE_LOCAL_COPY_DRIFT.md`.

## SPM / mlx missing products

If Package.swift reports missing products like `mlx-swift-lm_MLXLLM.MLXLLM`:

1. `rm -rf ~/Library/Developer/Xcode/DerivedData/Hive-*`
2. `rm -rf .build`
3. In Xcode: **File → Packages → Reset Package Caches**
4. **File → Packages → Resolve Package Versions**
5. Rebuild

## If errors persist

Share only the **first** compile error under the `HiveCore` or `HiveMacApp` target (ignore downstream cascade errors).
