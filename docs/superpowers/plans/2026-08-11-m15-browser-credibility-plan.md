# M15 — Browser Credibility C1–C3 Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 capture/privacy, M2 import/session bootstrap, M4 provenance, M6 sync/encryption boundary, M10 Sidecar, M11 Studio, M12 Command Center, M13 Projects/Tasks, M14 Sheets.
> **Scope:** browser credibility only. No AI/model training, no new connectors, and no autonomous desktop control.

## 1. Goal

M15 closes three browser-native credibility gaps that users notice immediately:

- **C1 — transient auxiliary windows:** a Little Arc-style quick window for opening, triaging, promoting, and closing a link without polluting the main workspace;
- **C2 — lifecycle-aware tabs:** honest distinction between live, sleeping/hibernated, discarded, archived, restored, and failed-recovery states;
- **C3 — command cleanup:** every visible command has a typed identity, truthful availability, a real action or an intentional removal, and a testable receipt.

The result must feel like a reliable browser before advanced Hive surfaces are considered. A user can open a quick link, decide whether it belongs in the workspace, leave the browser for days, return after memory pressure or a crash, and recover tabs without silent loss or phantom controls.

## 2. Non-goals and explicit deferrals

M15 does not promise full Chrome extension parity, cross-device archive sync, collaborative tab groups, arbitrary external protocol execution, browser automation, download-manager replacement, or a generalized window manager.

Deferred:

- native system-wide URL interception until a signed auxiliary-window policy exists;
- arbitrary floating always-on-top windows and custom window levels;
- automatic archival of private tabs, form-bearing tabs, media/capture tabs, pinned/essential tabs, or active work;
- restoring renderer memory or page session state when only a URL is safely available;
- silent command aliases, command telemetry containing URLs/query text, or model-generated commands;
- treating a comments-only “action exists” closure as a shipped command.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository already contains:

- `HibernationPolicy` and `HibernationAdapter` for pure, testable hibernation decisions;
- protections for pinned/essential/active tabs, audio, downloads, recently audible tabs, media capture, unsaved form entry, internal schemes, and collapsed-group behavior;
- `AutoArchivePolicy`, `ArchivedTab`, and shelf capping/ordering primitives;
- session persistence with schema versioning, clean-exit state, quarantine/recovery outcomes, and `TabOrganizationNormalizer`;
- `CommandRegistry` with typed `BrowserCommand`, definitions, shortcuts, and slash aliases;
- existing peek/mini-player surfaces and archive/hibernation state extensions.

These are code-present primitives, not proof of a complete user journey. In particular, a plan comment, a timer, or a closure in a palette catalog does not prove a working window lifecycle or command action.

### 3.2 Authority table

| Concern | Authority | M15 rule |
|---|---|---|
| Main-window tabs/workspaces | `BrowserState` projection + M0 session store | UI state is not durable until the persistence receipt succeeds. |
| Auxiliary window identity | typed `QuickWindowRecord`/window coordinator contract | Never infer a quick window from a URL or title alone. |
| Tab resource decision | `HibernationPolicy`/`HibernationAdapter` | UI cannot bypass safety blockers. |
| Archive eligibility | `AutoArchivePolicy` | Private and protected work never enters the durable archive shelf. |
| Session normalization | `TabOrganizationNormalizer` and M0 recovery | Restore must repair/report, never silently create an empty session. |
| Commands | M12 typed registry | Closure-based catalogs are migration-only; one command authority. |
| Permission/context scope | M1/M6/M10/M11 contracts | Quick-window content cannot widen model, capture, file, or network scope. |
| Evidence | EventLedger/M0 lifecycle evidence | Record intent and result metadata, not page secrets or raw URLs by default. |

## 4. C1 — Transient auxiliary-window contract

### 4.1 Window identity and states

A quick window is a separate, explicitly identified browser surface. Its record contains:

```text
window_id: stable UUID
kind: quick_lookup | promoted_workspace
source: user_shortcut | approved_external_link | command_center
profile_id / workspace_id: explicit scope
tab_id: stable tab identity
url: validated HTTP(S) or approved internal route
created_at / last_interacted_at
pinned: Bool
lifecycle: opening | visible | backgrounded | promotion_pending | promoted | closing | archived | closed | failed
```

State transitions are explicit and idempotent:

```text
opening → visible → backgrounded
visible/backgrounded → promotion_pending → promoted
visible/backgrounded → closing → closed
backgrounded → archived → closed
opening/visible → failed (with recovery action)
```

A close is not an archive; an archive is not a promotion. The UI must expose the distinction with reversible actions where the underlying page remains recoverable.

### 4.2 Opening and safety

Opening a quick window validates the target before creating the window:

- accept only HTTP(S), approved Hive internal routes, or an explicit user-approved protocol adapter;
- canonicalize and display the final URL after redirects without silently following a dangerous scheme;
- preserve the initiating scope/profile and never inherit private state into a non-private window;
- treat page content as untrusted data; it cannot request promotion, capture, tool access, or permission changes;
- do not automatically capture page text, add history, or attach it to a project unless the user’s existing policy explicitly permits that operation and the action is disclosed.

The quick window must remain useful if the target fails: show the failed URL host, error class, retry, copy-safe link, and close action without presenting a fake loaded page.

### 4.3 Promotion

“Open in Workspace” is an explicit promotion transaction:

1. freeze the target window/tab identity and current URL generation;
2. present destination workspace/profile and private-mode consequences;
3. create or move the durable tab only after the user confirms;
4. persist the main-session mutation;
5. close the auxiliary surface only after durable success;
6. emit one ordered receipt linking source window, destination tab, and persistence result.

If persistence fails, keep the auxiliary window visible and do not claim promotion. If the user cancels, no main-workspace mutation occurs.

### 4.4 Window behavior and accessibility

The auxiliary surface must:

- have a stable restoration identity or an explicit non-restorable declaration;
- never steal focus repeatedly or reopen after the user intentionally closed it;
- keep keyboard focus inside its controls while open, then return focus to the invoking control;
- expose title, URL, loading/error state, pin/promote/close actions, and progress to VoiceOver;
- respect reduced motion, increased contrast, dynamic sizing, and off-screen display recovery;
- remain within the normal application window level unless a later platform decision explicitly permits a utility level.

## 5. C2 — Tab lifecycle, hibernation, and archive

### 5.1 Canonical lifecycle states

M15 distinguishes these states:

| State | Meaning | User-visible behavior |
|---|---|---|
| `live` | Renderer/page is available | Normal interaction. |
| `sleeping` | Resource throttling/freezing is requested while state remains restorable | Tab remains present; wake is transparent or disclosed. |
| `hibernated` | Renderer closed; safe wake URL and metadata persisted | Tab remains in place with a clear wake affordance. |
| `discarded` | Renderer/content evicted by pressure or process loss | Never imply full page state survived; show reload/recovery semantics. |
| `archiveCandidate` | Eligible for auto-archive but not yet committed | No user-visible removal before transaction starts. |
| `archived` | Removed from live strip into durable local shelf | Restorable record with source workspace/group metadata. |
| `restoring` | Archive/session item is being reintroduced | Disable duplicate activation and show progress/failure. |
| `recoveryFailed` | Restore could not safely recreate the page or scope | Preserve record, expose retry/open-copy/delete options. |

`hibernated` and `archived` are not interchangeable: hibernation preserves tab placement; archive removes the live tab from the workspace.

### 5.2 Hibernation transaction

Before teardown, the controller must capture a durable lifecycle snapshot containing tab ID, workspace/profile, safe wake URL, title/favicon metadata, last-access instant, private flag, and generation. It must then:

1. re-evaluate policy against the latest activity snapshot;
2. reject if active, pinned, essential, private, media-capturing, form-bearing, downloading, internal, or otherwise protected;
3. persist the snapshot and verify write success;
4. close the renderer;
5. mark the tab hibernated and emit an evidence record.

A failed write must leave the renderer alive or mark the state as explicitly non-durable; it must not present a hibernated placeholder that cannot be recovered. Wake creates a fresh renderer generation, retains the safe URL, and records whether full interaction state was restored or only navigation was restored.

### 5.3 Auto-archive transaction

Auto-archive is opt-in and runs only after session restore settles. It uses `AutoArchivePolicy` as a pure admission decision, then performs a crash-safe two-phase operation:

1. create an `ArchivedTab` candidate with original workspace/group, URL, title, favicon, timestamps, and privacy classification;
2. persist the candidate/intent before removing the live tab;
3. re-check tab generation and active/protected state;
4. remove the live tab and clean all associated transient UI state;
5. persist the new session projection and archive shelf cap;
6. mark the archive committed and emit one ordered receipt.

If any step after candidate creation fails, recovery must reconcile candidate versus live tab deterministically. It must never produce both an apparently live tab and an apparently committed archive with the same identity without a visible conflict state.

Private tabs are never archived or persisted in the shelf. The shelf is local-only unless a future sync contract explicitly changes that boundary.

### 5.4 Restore and stale records

Restoring an archived tab validates the destination workspace/profile and URL generation. Missing workspaces fall back only with a visible report. Missing/invalid URLs preserve the record for repair rather than opening a blank page. Duplicate tab IDs are resolved by the session normalizer and reported. A restored tab receives a new renderer generation and does not inherit stale loading, permission, download, or media state.

### 5.5 Crash and memory-pressure recovery

At launch or renderer loss:

- quarantine unreadable session data and offer the last known-good recovery;
- never silently start a fresh session over a corrupt one;
- normalize duplicate/dangling scopes deterministically;
- preserve archived records independently from live-tab restoration;
- disclose repaired counts without exposing URLs or private content in diagnostics;
- record whether recovery was full state, safe URL reload, archive restore, or unavailable.

## 6. C3 — Command cleanup contract

### 6.1 One authority

`CommandRegistry` is the authority for command identity, title, category, keywords, shortcut, aliases, availability class, and required action receipt. `PaletteCommand.allCommands` or other closure catalogs may remain only as a migration adapter while every entry is mapped to a registry ID.

A command is not exposed if:

- its action is absent or intentionally unavailable in the current browser state;
- it would perform a no-op while presenting itself as successful;
- it lacks an availability reason or a truthful disabled/degraded state;
- its shortcut conflicts without deterministic precedence and remediation;
- its required permission or scope is denied and no fallback is offered.

### 6.2 Availability and receipts

Every invocation returns one typed result:

```text
executed(command_id, effect_summary, affected_ids, undo_scope)
opened_preview(command_id, preview_id)
denied(command_id, reason, recovery)
unavailable(command_id, reason, recovery)
cancelled(command_id)
failed(command_id, error_class, recovery)
```

A successful receipt requires an observable state change or a clearly defined navigation/focus effect. “Nothing to do” is reported as `unavailable` or `executed` with an explicit no-change reason, never as an unexplained success.

Commands that mutate tabs, workspaces, archive state, files, or external windows reuse M11 approval and M12 action receipts. Commands never receive executable arguments from untrusted page text or model output.

### 6.3 Cleanup inventory

The implementation pass must inventory every registry command and palette entry, map it to a concrete action, add state predicates, and either:

- wire a tested action;
- replace it with a preview/approval action;
- mark it unavailable with a useful recovery path; or
- remove it from the user-facing catalog.

No new command is added until it has an ID, availability contract, keyboard/accessibility label, and fixture.

## 7. Persistence, privacy, and provenance

- Private windows/tabs use an ephemeral lifecycle at every boundary: no archive shelf, no session restore, no ordinary history, no capture, and no model context without a separate explicit contract.
- URLs and titles are user data. Event evidence defaults to stable IDs, scope, result class, and redacted host metadata where sufficient.
- Quick-window pages, archived metadata, and recovery diagnostics cannot widen Sidecar, Studio, Sheets, MCP, or memory scopes.
- Auto-archive is reversible through the shelf until the configured retention limit; permanent removal requires an explicit destructive path and is not confused with close/reopen.
- Sync tombstones for live tabs must not accidentally sync local-only archive contents.

## 8. Work packages

### M15-A — Quick-window identity and lifecycle

Define the auxiliary window record, state machine, safe target validation, profile/private scope, promotion transaction, failure handling, restoration identity, focus/accessibility behavior, and clean-profile path.

**Done when:** a link can open in a transient window, be closed, promoted, or archived with durable and truthful outcomes; failed promotion leaves the source window recoverable.

### M15-B — Hibernation versus discard

Align pure policy, runtime adapter, renderer lifecycle, saved wake URL, generation invalidation, media/form/download protections, internal-scheme exclusions, and user-visible state. Define process-loss recovery separately from intentional hibernation.

**Done when:** live/sleeping/hibernated/discarded states are distinguishable, no protected work is torn down, and wake behavior is verified after restart and renderer loss.

### M15-C — Crash-safe auto-archive and restore

Implement the candidate/commit/reconcile contract around `AutoArchivePolicy`, `ArchivedTab`, session persistence, shelf caps, workspace fallback, privacy filtering, and restore failure actions.

**Done when:** repeated passes are idempotent, interrupted archive operations reconcile without duplicate/lost tabs, private tabs never enter durable archive, and restore preserves provenance/placement where valid.

### M15-D — Typed command cleanup

Inventory registry and palette commands, remove no-op exposure, add availability and typed receipts, resolve shortcuts through M12, and ensure state-mutating commands use existing approval/ledger boundaries.

**Done when:** every visible command has a live tested action or an honest unavailable state; no command silently does nothing.

### M15-E — Integrated browser credibility validation

Run clean-profile manual paths and deterministic tests for auxiliary windows, lifecycle transitions, crash/recovery, privacy, keyboard/focus, command availability, and degraded browser-first behavior.

**Done when:** the M15 exit path works with AI disabled, under reduced motion, with denied permissions, after a simulated crash, and with memory/download/media protections active.

## 9. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M15-01 | Open valid HTTPS quick link | Auxiliary window enters `visible` with explicit scope |
| M15-02 | Open unsupported/dangerous scheme | Rejected before window creation with recovery |
| M15-03 | Quick window from private scope | Remains private; no ordinary persistence |
| M15-04 | Page redirects to final URL | Final URL shown; original target retained as bounded provenance |
| M15-05 | Quick window close | Closes without main-workspace mutation |
| M15-06 | Explicit promotion | Main tab created/moved only after confirmation and durable receipt |
| M15-07 | Promotion persistence failure | Auxiliary window remains; no false success |
| M15-08 | Double promotion request | Idempotent result; no duplicate tab |
| M15-09 | User intentionally closes quick window | It does not reopen on next launch |
| M15-10 | Auxiliary window off-screen after display change | Repositioned into visible bounds |
| M15-11 | VoiceOver quick-window controls | Title, URL, loading/error, pin/promote/close exposed |
| M15-12 | Reduced-motion quick-window transition | No required information depends on motion |
| M15-13 | Active/pinned/essential tab | Never hibernated |
| M15-14 | Private tab | Never hibernated into durable session projection |
| M15-15 | Audio/recently-audible tab | Deferred |
| M15-16 | Active download tab | Deferred until terminal |
| M15-17 | Media capture or unsaved form | Deferred |
| M15-18 | Internal Hive/about/chrome route | Protected from auto-hibernation/archive |
| M15-19 | Blank transient renderer with saved URL | Saved URL is used; blank is never wake target |
| M15-20 | Hibernation write failure | Renderer remains alive or explicit non-durable state shown |
| M15-21 | Hibernated tab wake | Fresh renderer generation; safe URL restored |
| M15-22 | Renderer process loss | Discarded/recovery state disclosed; no fake hibernation claim |
| M15-23 | Crash during hibernation | Reconcile to live or hibernated, never ambiguous silently |
| M15-24 | Cold eligible tab | Archive candidate created before live removal |
| M15-25 | Crash after archive candidate | Reconciliation preserves exactly one authoritative outcome |
| M15-26 | Repeated archive pass | No duplicate shelf records or repeated removal |
| M15-27 | Private tab presented to archive policy | Excluded and not persisted |
| M15-28 | Pinned/essential/active/collapsed tab | Excluded according to policy |
| M15-29 | Archive shelf cap overflow | Oldest records removed according to documented policy |
| M15-30 | Restore valid archived tab | New live tab, shelf record removed, workspace restored |
| M15-31 | Restore missing workspace | Explicit fallback and repair report |
| M15-32 | Restore malformed URL | Record retained; no blank navigation |
| M15-33 | Duplicate archived/live identity | Deterministic conflict and visible repair |
| M15-34 | Corrupt session file | Quarantine and last-known-good recovery offered |
| M15-35 | Duplicate/dangling session scopes | Normalizer repairs and reports counts |
| M15-36 | Command with working action | Typed executed receipt with effect summary |
| M15-37 | Command with no valid action | Removed or truthful unavailable result |
| M15-38 | Command unavailable due to state | Reason and recovery shown |
| M15-39 | Shortcut collision | Deterministic winner/conflict UI; no incidental dispatch |
| M15-40 | Denied required permission | No action; recovery path presented |
| M15-41 | Command invocation cancellation | No partial mutation or false success |
| M15-42 | Page text requests command execution | Treated as untrusted data |
| M15-43 | Model proposes command arguments | Typed policy/approval required |
| M15-44 | Command action after stale tab generation | Rejected or refreshed; no stale mutation |
| M15-45 | AI disabled | Browser paths remain complete |
| M15-46 | Reduced motion/high contrast/dynamic size | Information and controls remain available |
| M15-47 | Event evidence redaction | No raw URL/private content in default receipt |
| M15-48 | Reopen after clean exit | Main tabs, archive shelf, and auxiliary-window policy restore truthfully |

## 10. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M15-A | Auxiliary window lifecycle | Open/close/promote/archive state-machine tests and clean-profile path |
| M15-B | Scope and URL safety | Scheme, redirect, private/profile, and prompt-injection fixtures |
| M15-C | Hibernation/discard truthfulness | Lifecycle matrix, protected-work tests, renderer-loss recovery |
| M15-D | Crash-safe archive | Candidate/commit/reconcile tests and restart evidence |
| M15-E | Restore correctness | Placement, duplicate, malformed URL, and repair-report fixtures |
| M15-F | Private-data boundary | No archive/session/history/model-scope leakage tests |
| M15-G | Command authority | Registry/palette inventory with zero unowned visible commands |
| M15-H | No-op prevention | Every exposed command has effect, preview, unavailable, or removal evidence |
| M15-I | Shortcut/accessibility | Conflict, focus, VoiceOver, reduced-motion, contrast, and dynamic-size evidence |
| M15-J | Persistence/recovery | Clean exit, crash, corruption quarantine, and off-screen window recovery |
| M15-K | Browser-first degraded mode | AI/model/permission failure leaves normal browsing usable |
| M15-L | Truthful status | No `verified` label until build, tests, and runtime paths pass current evidence |

## 11. Implementation order and handoff

Implement M15-A before any auxiliary-window polish. Implement M15-B and M15-C against the existing pure policies, not parallel policy copies. Implement M15-D only after the M12 command authority mapping is complete. M15-E must validate the combined path with AI disabled and permissions denied.

The next smallest safe implementation slice is **M15-A: the typed quick-window lifecycle and promotion contract**, preceded by an exact audit of existing `miniPlayer`/peek behavior and any native window creation seams. No model training or background process is part of M15.
