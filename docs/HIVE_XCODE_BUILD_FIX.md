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

Run this in Terminal:

```bash
cd /Users/arpituppal/Downloads/Hive

# Option A — delete the unused broken file (fastest)
rm -f Sources/HiveCore/ReindexEngine.swift

# Option B — replace with the fixed version from the branch
# git fetch origin arpituppal2/hive-production-rebuild-82c2
# git checkout origin/arpituppal2/hive-production-rebuild-82c2 -- Sources/HiveCore/ReindexEngine.swift

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

## If errors persist

Share only the **first** compile error under the `HiveCore` target (ignore downstream "Unable to resolve module dependency" messages).
