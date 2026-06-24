# Hive Xcode Build Fix

## Symptom

Xcode reports cascading errors such as:

- `Unable to resolve module dependency: 'HiveCore'`
- `Unable to resolve module dependency: 'HiveDesignSystem'`
- Missing `.swiftmodule` / `.abi.json` files in DerivedData

## Root cause

These are usually cascade failures after `HiveCore` fails to compile first.

A common concrete blocker is invalid Swift in `Sources/HiveCore/ReindexEngine.swift`, for example:

```swift
let phase: ReindexEnginePhase { ... } // invalid: computed properties cannot use `let`
```

## Fix

1. Pull latest branch containing the corrected `Sources/HiveCore/ReindexEngine.swift`.
2. Open the package directly:
   - `open Package.swift`
3. Do **not** open a stale generated `.xcodeproj` unless it is regenerated from the package.
4. Clean build folder in Xcode (`Product > Clean Build Folder`).
5. Delete stale DerivedData if needed:
   - `rm -rf ~/Library/Developer/Xcode/DerivedData/Hive-*`
6. Build scheme `HiveApp` for macOS.

## Expected result

- `HiveCore` compiles first.
- Dependent modules (`HiveDesignSystem`, `HiveUI`, `HiveMacApp`, etc.) resolve normally.
- Remaining mlx-swift C++17 warnings in dependencies are non-blocking.

## Verify from terminal

```bash
cd /path/to/Hive
xcodebuild -scheme HiveApp -destination 'platform=macOS' build
```
