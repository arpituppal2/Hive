# HIVE MAC FINALIZATION RUNBOOK

## Xcode setup

1. Open repository:
   - `cd /path/to/Hive`
   - `open Package.swift`
2. Confirm schemes:
   - Hive macOS app target
   - Hive iPhone target
   - Hive iPad target
   - Hive Watch target
3. Build settings checks:
   - Deployment target values aligned with project requirements
   - App Sandbox/entitlements for file access and required capabilities
   - Widget target configured and embedded correctly

## Icon Composer flow

Required asset names:
- `AppIcon.appiconset`
- `MenuBarActive.imageset`
- `MenuBarPaused.imageset`
- `DockBadgeTemplate.imageset`

Reference locations:
- `Sources/HiveApp/Resources/AppIcon/Hive.icon/icon.json`
- `Sources/HiveApp/Resources/AppIcon/IconComposerSpec.json`
- `Sources/HiveApp/Resources/AppIcon/ExpectedAssetNames.json`

Execution:
1. Run `scripts/export_icon_composer_assets.sh`.
2. Open app `Assets.xcassets` in Xcode.
3. Import/verify all generated icon sizes in `AppIcon.appiconset`.
4. Create/import menu bar and dock template image sets with exact names above.
5. Build and run macOS target.

Screenshot checklist:
- Asset catalog showing all required sets and populated slots
- Dock icon visible in running app
- Menu bar active icon
- Menu bar paused icon

Pass:
- No missing slots in Xcode AppIcon set
- Menu bar icon state changes at runtime

Fail:
- Any missing icon slot, fallback icon, or wrong menu bar icon state

## Simulator/device matrix

Run all rows and capture proof:

| Platform | Scenario | Required Evidence |
|---|---|---|
| macOS | cold start, onboarding, menu bar, dock, settings, graph | screenshots + short screen recording |
| iPhone | ask flow, source ingest, degraded capability messaging | screenshots + logs |
| iPad | layout integrity (portrait/landscape), settings overflow | screenshots |
| Watch | watch query relay to iPhone and response path | paired simulator recording |
| macOS+iOS | reduced motion enabled behavior | before/after captures |
| low capability | capability tier degradation messaging | screenshots + logs |

## Manual acceptance scripts

### Onboarding
1. Fresh launch.
2. Complete onboarding.
3. Relaunch 5 times.
Pass: onboarding does not reappear after completion.

### Re-index contamination
1. Add mixed-topic sources to Field.
2. Trigger re-index.
3. Verify no forced single-topic canonicalization.
Pass: no privileged topic injection; evidence remains source-driven.

### Dominance warning
1. Add repeated same-topic sources.
2. Trigger re-index.
3. Open Field and verify dominance warning.
Pass: warning appears and can be dismissed for session.

### Plugin toggles
1. Toggle each plugin on/off.
2. Restart app.
3. Verify persistence and bookmark behavior.
Pass: states persist; no broken/unsafe toggle paths.

### OAuth
1. Enable Google Drive flow.
2. Complete auth.
3. Restart and validate persisted session or explicit sign-out behavior.
Pass: deterministic authenticated/unauthenticated state.

### Menu bar states
1. Observe menu bar icon with quick capture enabled.
2. Disable quick capture in settings.
3. Verify paused icon state and menu header/footer info.
Pass: icon and popover state update immediately.

### Dock states
1. Toggle Show in Dock and Show in menu bar combinations.
2. Verify mutual guardrail (cannot disable both).
3. Right-click dock menu actions.
Pass: guardrail enforced; dock menu routes correctly.

### Graph interaction
1. Enable AppKit graph preview toggle.
2. Select nodes via mouse.
3. Zoom/pan and inspect label overlap behavior.
Pass: selection works; graph remains readable.

### Widget refresh
1. Ingest new source/claims.
2. Wait for widget snapshot update.
Pass: widget reflects live snapshot.

### Save-to-Colony / wiki flows
1. Ask in Swarm.
2. Save answer to Colony.
3. Open updated page and verify claim links.
Pass: saved content appears with correct references.

## Evidence capture requirements

For each script above:
- Capture: screenshot/video + relevant logs
- Store in a dated folder (example: `artifacts/mac-finalization-YYYYMMDD/`)
- Record Pass/Fail and notes in a markdown ledger copied from:
  - `docs/HIVE_MAC_ACCEPTANCE_LEDGER_TEMPLATE.md`

Pass criteria:
- Behavior exactly matches script expectation

Fail criteria:
- Any mismatch, crash, missing state transition, or unclear UX behavior
