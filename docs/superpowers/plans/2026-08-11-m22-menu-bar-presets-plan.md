# M22 — Menu-Bar Modes & Presets Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M12 Command Center, M13 Projects/Tasks, M16 Worker/Permission Center, M18 Focus Sessions/Awake Leases, M21 Wellness Rhythms, platform signing/distribution decisions.
> **Scope:** an optional macOS menu-bar companion and local contextual presets, with explicit enablement, command-registry authority, lifecycle cleanup, accessibility, and browser-first behavior.

## 1. Goal

M22 gives users who want it a fast, quiet menu-bar entry point into Hive’s already-registered commands and a small set of contextual presets. It must feel like an optional extension of Hive, not a second app, a default status-bar burden, or an unbounded automation daemon.

A user can show or hide the companion, choose whether it launches at login, inspect which preset is active and why, invoke an available command, and remove the companion without losing browser state. Presets are local projections over explicit M12 commands, M18/M21 session state, workspace/profile state, and approved M16 capabilities. They never invent commands, permissions, or authority.

## 2. Non-goals and explicit deferrals

M22 does not ship a generic launcher replacement, arbitrary user scripting, a background automation daemon, privileged root helper, menu-bar item management for other apps, window manipulation without M16 grants, passive screen surveillance, unbounded polling, cloud-synced preset secrets, or a separate user-facing Swarm application.

Deferred:

- a broad third-party extension marketplace;
- menu-bar hiding/reordering of other applications’ items;
- automatic app/window control, Accessibility, Screen Recording, Apple Events, or terminal access merely because a preset exists;
- persistent launch agents or helpers before a measured user journey requires them;
- cross-device preset sync before M6 storage and deletion semantics explicitly cover it;
- arbitrary natural-language commands that bypass the M12 typed registry;
- preset-triggered purchases, messages, account changes, destructive deletes, or external publishes;
- battery/thermal-intensive status polling and always-on context inference.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

M12 defines the typed Command Center authority, local query modes, action panels, receipts, shortcut conflict behavior, and browser-safe degraded paths. M16 defines signed worker admission, capability grants, Permission Center/TCC disclosure, stop/revoke, and privileged action boundaries. M18/M21 define FocusSession/awake-lease authority and optional wellness reminder/smart-pause policy. The app already has command, workspace, profile, settings, and menu infrastructure, and the packaged CEF product has helper processes for browser internals.

No verified Hive menu-bar companion, contextual preset registry, login-item consent flow, stateless status-item recovery, or clean uninstall/unregister path is currently established. Existing CEF helpers are browser implementation helpers, not evidence that a Hive menu-bar worker is safe or shipped.

### 3.2 Authority table

| Concern | Authority | M22 rule |
|---|---|---|
| Command definitions | M12 CommandRegistry | Menu items resolve stable command IDs; no menu-local callbacks become new authority. |
| Availability | M12 predicate + current state snapshot | Unavailable commands are hidden or honestly disabled with a reason. |
| Privileged execution | M16 Worker/Permission Center + policy | Menu invocation requests permission or shows a preview; it never bypasses grants. |
| Preset definition | Local typed PresetStore | Presets contain declarative command IDs, predicates, and presentation metadata—not code. |
| Active context | Explicit local state adapters | Workspace/profile/session/Focus state is scoped and timestamped; unknown is conservative. |
| Wellness filtering | M18/M21 authorities | A preset cannot clear pause, disable, or safety state. |
| Login launch | macOS login-item authority | Registration is explicit, inspectable, reversible, and never silently re-enabled. |
| Status-item lifecycle | MenuBarCoordinator | Strong ownership, idempotent install/remove, rebuild after lifecycle events. |
| Privacy | M1/M6/M16 scope policy | No hidden screen/window/audio/history collection for preset matching. |
| Evidence | EventLedger | Record command/preset/consent/status classes, not raw private context. |
| Browser continuity | Main Hive app | Companion failure never blocks launch, navigation, capture, or ordinary browser use. |

## 4. Product modes and consent

M22 has independent user controls:

```text
browser_only                 // default
menu_bar_enabled             // explicit show/hide consent
login_launch_enabled         // separate explicit consent
contextual_presets_enabled   // separate opt-in; default conservative
privileged_actions_enabled   // M16 grants, never implied by M22
wellness_surface_enabled     // M21 setting; menu bar cannot override it
```

The first enable flow explains:

- what appears in the menu bar;
- whether Hive runs while the main window is closed;
- whether login launch is being requested;
- what context is used for preset matching;
- which commands are available without extra permissions;
- how to hide, disable, unregister, and remove it.

No first-launch browser onboarding asks for menu-bar, login, Accessibility, Screen Recording, Apple Events, microphone, or filesystem permissions. Each is requested only from a user action that needs it.

A user can disable the companion from Hive Settings, the menu-bar menu, or macOS Login Items where applicable. Disable is not a destructive deletion: it hides the item, stops preset evaluation, unregisters an optional login item if authorized, and preserves browser/session data.

## 5. Status-item lifecycle

### 5.1 Ownership and construction

`MenuBarCoordinator` owns exactly one status item per user session. The coordinator is created only when the feature is enabled and retains the status item strongly for its lifetime. Repeated enable/scene/window events are idempotent.

The status item presents a compact menu or bounded popover. It does not host a second browser window by default. The primary action opens the existing Hive window or Command Center; it must not create duplicate browser authorities.

### 5.2 Lifecycle states

```text
hidden
installing
visible
rebuilding
suspended_locked
suspended_user_session
error_unavailable
removing
removed
```

Every transition has a reason and stable idempotency key. On sleep/wake, display changes, fast user switch, app relaunch, or status-item reconstruction, the coordinator rebuilds presentation from the persisted preference and current M12 snapshot. It never treats stale menu contents as current authority.

If the main app is unavailable, the companion may show a bounded “Open Hive” action or an honest unavailable state. It must not silently become a separate automation host.

### 5.3 Popover/menu behavior

The default surface is a short menu with:

- active workspace/profile label;
- one or two user-pinned commands;
- current preset name and reason, if enabled;
- explicit “Open Hive”;
- “Pause/hide presets” when the feature is enabled;
- settings, hide, and quit/remove controls.

Long lists open the existing Command Center rather than turning the status item into a dashboard. Menu content is bounded, deterministic, keyboard accessible, and refreshes from a new state snapshot after invocation.

## 6. Typed contextual preset model

A preset is declarative data, not executable code:

```text
preset_id: stable ID
name: localized user-visible label
icon: allow-listed symbol identifier
enabled: Bool
priority: bounded integer
scope: global | profile | workspace | project | focus-session
match: typed predicates over approved local state
commands: [stable command IDs + typed argument templates]
required_capabilities: typed M16 capability classes
presentation: menu | compact_status | command_center
expiry: none | session | local-time | explicit
provenance: built-in | user-authored | imported
version / created_at / updated_at
```

Allowed match inputs are limited to explicit local state: active workspace/profile, selected project/task, M18 session state, M21 explicit pause/presenting state, browser window presence, network availability class, and user-authored schedule. A preset cannot match on raw page text, screenshots, keystrokes, microphone audio, window titles from other apps, or hidden usage history.

Argument templates may reference stable typed IDs and user-authored values. They cannot contain shell text, AppleScript, arbitrary URLs, secrets, model output, or unrestricted file paths. A template that resolves to a missing or stale ID becomes unavailable and explains why.

## 7. Preset precedence and context evaluation

Context evaluation is deterministic and local:

1. filter disabled, expired, revoked, and out-of-scope presets;
2. apply explicit user pause/disable and M18/M21 safety suppression;
3. resolve current workspace/profile/project/session snapshot;
4. validate command availability and required capabilities through M12/M16;
5. order by scope specificity, explicit priority, stable preset ID;
6. expose at most the bounded number configured by the UI;
7. retain a reason code for each shown, hidden, suppressed, or unavailable preset.

Unknown context is not a match. If two presets conflict, the higher-specificity preset wins only for presentation; it cannot override a command’s policy or permission. A tie is resolved by stable ID and shown in diagnostics. A model cannot select a winning preset or change precedence.

Context evaluation is event-driven from approved local state changes and bounded refreshes, not a tight polling loop. If a state is stale, the menu shows “Context unavailable” rather than pretending the preset is current.

## 8. Command invocation contract

Every menu action resolves through M12:

```text
menu_invocation_id
preset_id: optional
command_id
argument_schema_version
resolved_arguments
context_snapshot_id
required_capabilities
availability_receipt
preview_or_confirmation
approval_scope_key: when required
result_receipt
```

The flow is:

1. resolve the stable command ID;
2. refresh availability against current state;
3. validate typed arguments and scope;
4. ask M16/policy for preview or approval when required;
5. execute through the existing command/worker boundary;
6. verify the result and return a receipt;
7. refresh the status surface from a new snapshot.

No command is considered successful because the menu closed. A failed, denied, stale, or unavailable action reports the reason and preserves the main browser state.

## 9. Privileged and sensitive actions

M22 never elevates a command. If a preset points to a command requiring Accessibility, Screen Recording, Apple Events, terminal, files, network, or connector scope, the menu shows the missing capability and opens the Permission Center/preview path. It does not request broad permission merely because the item is visible.

Destructive or external actions require the same M16/M17 approval binding as the main app. A menu click is intent, not consent to a broad session grant. Preset-defined approval cannot authorize a target or scope not shown in the current preview.

Status-item labels and notifications never include passwords, clipboard contents, raw page text, meeting content, file bodies, or hidden URLs. EventLedger records IDs/status/reason classes and redacts arguments according to M6/M16 policy.

## 10. Login launch and helper boundary

M22 must work with the main app launched normally. Login launch is an independent opt-in and must reflect macOS registration status honestly. If a future signed agent/helper is required, it receives a separate capability manifest, uses a typed IPC protocol, and is governed by M16; it is not silently installed as a generic daemon.

Registration, disable, revocation, helper crash, user removal in System Settings, and app uninstall are explicit lifecycle cases. A disabled or revoked login item cannot re-enable itself. A helper that ignores stop/revoke is terminated according to the bounded M16 policy and cannot retain active grants.

## 11. Privacy, retention, and offline behavior

M22 stores only:

- companion visibility and login-launch preference;
- typed preset definitions and user-pinned command IDs;
- bounded local context snapshot classes and timestamps;
- invocation/availability receipts with redacted arguments;
- capability/permission status classes, never secrets.

It does not create a shadow history of every active app, window, keystroke, screenshot, audio stream, clipboard value, or page. Preset matching works offline from local state. Network absence may hide network-dependent commands but never blocks the browser.

User-authored presets are exportable as inert declarative data with secrets and non-portable permissions removed. Deleting a preset removes its local definition and pending scheduled evaluation; it does not delete the command or browser data it referenced.

## 12. Accessibility and interaction quality

The companion is complete only when the status item, menu/popover, settings, preset editor, unavailable states, and removal paths work with VoiceOver, keyboard navigation, Increase Contrast, Dynamic Type where applicable, Reduce Motion, and reduced transparency.

Requirements:

- status item has a localized label describing Hive and its current state;
- menu items expose command name, availability, shortcut, and permission reason;
- preset match reasons are available as text, not only icon or color;
- keyboard focus enters and returns from the popover predictably;
- Escape closes without invoking an action;
- destructive remove/disable actions are labeled by outcome and confirm when needed;
- longer names, localization, and increased text do not clip menu actions;
- reduced motion removes popover transitions without hiding state changes;
- VoiceOver can reach hide, disable presets, settings, Open Hive, and removal controls;
- status updates do not steal focus or repeatedly announce unchanged state.

## 13. Work packages

### M22-A — Typed preset and command projection

Define the declarative preset schema, approved context adapters, precedence, versioning, export rules, and M12 command-resolution contract. Add deterministic availability/reason receipts.

**Done when:** a preset can only reference typed registered commands and approved local state; invalid, stale, or missing references fail closed.

### M22-B — Optional status-item lifecycle

Implement explicit show/hide consent, strong coordinator ownership, bounded menu/popover, lifecycle states, sleep/wake/session/display rebuild, and browser-first behavior.

**Done when:** enable/disable/relaunch/sleep/fast-user-switch/display changes do not duplicate, orphan, or silently expand the companion.

### M22-C — Preset editor and contextual evaluation

Add user-authored preset creation/edit/delete, scope/priority/expiry controls, deterministic matching, reason display, and M18/M21 suppression integration. Keep secrets and raw content out of presets.

**Done when:** context changes update the projection deterministically, unknown context fails quiet, and wellness/policy suppression cannot be bypassed.

### M22-D — Login launch, permission, and cleanup boundary

Add independent login-item consent/status, optional signed helper decision, M16 capability handling, stop/revoke, crash recovery, disable/unregister, uninstall, and System Settings removal reconciliation.

**Done when:** the companion never re-enables itself, privileged commands cannot bypass Permission Center, and all helper/login states have truthful recovery paths.

### M22-E — Integrated browser-first and accessibility validation

Validate clean-profile progressive disclosure, menu invocation receipts, unavailable/denied commands, localization/long labels, VoiceOver/keyboard, reduced motion, offline use, sleep/session/display changes, privacy inspection, and complete removal.

**Done when:** the companion is optional, quiet, accessible, removable, and incapable of blocking or degrading ordinary browser use.

## 14. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M22-01 | First launch | No status item or login prompt |
| M22-02 | Enable status item | One visible item with explicit receipt |
| M22-03 | Disable status item | Item removed; browser/session data preserved |
| M22-04 | Enable login launch separately | Consent and registration state shown independently |
| M22-05 | Login launch denied | Browser works; no prompt loop or silent retry |
| M22-06 | User disables in System Settings | Hive reconciles disabled state; no re-enable |
| M22-07 | Main app closed | Bounded Open Hive/status state; no separate automation host |
| M22-08 | Main app relaunch | One coordinator/item; no duplicate menu |
| M22-09 | Sleep/wake | State rebuilds; stale menu is not authority |
| M22-10 | Fast user switch | User-scoped state does not bleed across sessions |
| M22-11 | Display/Space change | Invocation anchors to current system surface |
| M22-12 | Status item deallocated/recreated | Idempotent rebuild; no orphan callback |
| M22-13 | Built-in preset | Valid command IDs and deterministic reason |
| M22-14 | User preset create | Declarative schema validates and persists locally |
| M22-15 | Invalid command ID | Preset unavailable; no callback execution |
| M22-16 | Missing project/workspace ID | Preset unavailable with recovery action |
| M22-17 | Expired preset | Hidden/suppressed with expiry reason |
| M22-18 | Disabled preset | No evaluation or menu item |
| M22-19 | Preset scope precedence | Specificity/priority/ID ordering deterministic |
| M22-20 | Preset tie | Stable ID tie-break; diagnostic available |
| M22-21 | Unknown context | No match; quiet unavailable state |
| M22-22 | M21 pause/presenting | Wellness presets suppressed; menu cannot clear state |
| M22-23 | M18 thermal yield | Power-sensitive preset suppressed or unavailable |
| M22-24 | Offline state | Local commands remain; network commands explain unavailable |
| M22-25 | Menu invocation | M12 command receipt and refreshed snapshot |
| M22-26 | Command becomes stale | Preflight revalidation rejects; no false success |
| M22-27 | Typed argument invalid | Validation error; no execution |
| M22-28 | Privileged command | Permission Center/preview path; no bypass |
| M22-29 | Destructive command | Exact current preview/approval required |
| M22-30 | Preset approval scope mismatch | Rejected; no widened authority |
| M22-31 | Worker stop/revoke | In-flight command stops; menu shows revoked state |
| M22-32 | Helper crash | Main browser remains usable; bounded recovery |
| M22-33 | Login helper revoked | No automatic re-registration |
| M22-34 | Uninstall/disable | Item/helper/login state cleaned according to authority |
| M22-35 | Export preset | Inert data only; no secrets/permissions exported |
| M22-36 | Delete preset | Definition/pending evaluation removed; commands unaffected |
| M22-37 | Raw page text in match | Not admitted as context |
| M22-38 | Window-title heuristic | Ignored by default; no passive surveillance |
| M22-39 | Clipboard/secret in preset | Rejected/redacted |
| M22-40 | VoiceOver status item | Label/state/action available |
| M22-41 | Keyboard menu flow | Open, navigate, invoke, dismiss, return focus |
| M22-42 | Long/localized labels | No clipped or unreachable controls |
| M22-43 | Reduce Motion | No essential state depends on transition |
| M22-44 | High contrast | Availability and suppression remain distinguishable |
| M22-45 | No status permission/unsupported OS | Honest unavailable state; browser unaffected |
| M22-46 | Browser-only mode | Full browsing path works with M22 disabled |

## 15. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M22-A | Typed preset schema | Validation, versioning, export/import, invalid-reference fixtures |
| M22-B | M12 authority binding | Every menu action resolves registry ID and receipt |
| M22-C | Explicit opt-in | No default item, login prompt, or background mode |
| M22-D | Lifecycle/recovery | Sleep, wake, display, session, relaunch, crash, disable evidence |
| M22-E | Context truthfulness | Approved local predicates only; unknown context fails quiet |
| M22-F | M16 permission boundary | Privileged actions preview/approve/revoke correctly |
| M22-G | Wellness boundary | M18/M21 suppression cannot be bypassed |
| M22-H | Privacy/offline | No shadow telemetry, secrets, raw content, or network dependency |
| M22-I | Login/helper cleanup | No silent re-enable; bounded signed boundary if needed |
| M22-J | Accessibility | VoiceOver, keyboard, contrast, dynamic sizing, reduced motion |
| M22-K | Browser-first | Companion unavailable/disabled without browser degradation |
| M22-L | Truthful status | No verified menu-bar capability without current runtime evidence |

## 16. Implementation order and handoff

Implement M22-A before installing any status item. Implement the menu-bar surface as a stateless projection over M12 and local adapters. Add login launch only after the visible companion lifecycle is stable and a measured user journey justifies it. Treat helper installation as an M16/M6 boundary decision, not a convenience shortcut.

The next smallest safe implementation slice is **M22-A: typed preset schema, approved local-context adapters, deterministic precedence, and M12 command-resolution fixtures**. No background daemon, privileged automation, model training, or default menu-bar chrome is part of M22.
