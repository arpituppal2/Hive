# BLOCKER 4 — Icon and Menu Bar Mac Checklist (Prepared)

This blocker is **prepared**. Visual asset generation still requires macOS + Xcode + Icon Composer.

## Code paths implemented in this branch

- Dock/menu bar visibility guardrail:
  - `Sources/HiveUI/HiveOverlaySurfaces.swift` (`HiveSettingsSurface` menu section)
  - `Sources/HiveApp/HiveApp.swift` (`HiveAppPreferences.setShowInDock`)
- Dock visibility policy:
  - `Sources/HiveApp/HiveApp.swift` (`applyDockVisibility(showInDock:)`)
- Dock badge count:
  - `Sources/HiveApp/HiveApp.swift` (`onChange(of: model.claims.count)`)
- Dock menu:
  - `Sources/HiveApp/HiveApp.swift` (`HiveAppLifecycleDelegate.applicationDockMenu`)
- Menu bar icon state switching:
  - `Sources/HiveDesignSystem/HiveAppleNative.swift` (`HiveMenuBarIconState`, `HiveMenuBarIcon`)
  - `Sources/HiveApp/HiveApp.swift` (menu bar label uses active vs paused icon state)
- Menu bar redesign scaffolding:
  - `Sources/HiveMacApp/HiveMacRootView.swift` (`HiveMenuBarPopover` now includes `MenuBarHeaderView` + `MenuBarFooterView` + live claim/source count + capture state label)

## Exact asset names

- `AppIcon.appiconset`
- `MenuBarActive.imageset`
- `MenuBarPaused.imageset`
- `DockBadgeTemplate.imageset`

Reference manifest:
- `Sources/HiveApp/Resources/AppIcon/ExpectedAssetNames.json`

## Exact asset locations

- Existing icon composer spec location:
  - `Sources/HiveApp/Resources/AppIcon/Hive.icon/icon.json`
  - `Sources/HiveApp/Resources/AppIcon/IconComposerSpec.json`
- Xcode asset catalog target location to create/verify:
  - `HiveApp/Assets.xcassets/AppIcon.appiconset`
  - `HiveApp/Assets.xcassets/MenuBarActive.imageset`
  - `HiveApp/Assets.xcassets/MenuBarPaused.imageset`
  - `HiveApp/Assets.xcassets/DockBadgeTemplate.imageset`

## Exact Xcode steps

1. Open project in Xcode.
2. Open app target asset catalog (`Assets.xcassets`).
3. Run Icon Composer flow for app icon and export to `AppIcon.appiconset`.
4. Create `MenuBarActive.imageset` and `MenuBarPaused.imageset`.
5. Add template-style monochrome menu bar glyphs for active/paused states.
6. Create `DockBadgeTemplate.imageset` for dock badge styling fallback.
7. Build and run macOS app target.
8. Verify settings toggles:
   - Toggle “Show Hive in Dock”
   - Toggle “Show Hive in the menu bar”
   - Confirm guardrail prevents both from being off simultaneously.

## Screenshots to capture

1. Xcode asset catalog with all required asset names visible.
2. App in Dock with badge visible (claim count > 0).
3. Menu bar icon active state (quick capture enabled).
4. Menu bar icon paused state (quick capture disabled).
5. Settings screen showing Dock/menu bar toggles and guardrail behavior.
6. Dock right-click menu showing:
   - Open Hive
   - Open Field
   - Open Swarm
   - Settings…

## Pass/fail criteria

- **Pass** if all required asset names exist, load at runtime, and states switch correctly.
- **Fail** if any asset name is missing, icon fallback occurs, or both Dock/menu bar can be disabled at once.
- **Fail** if dock menu items do not route to intended surfaces.
