# M18 — Focus Sessions, Awake Leases & Wellness Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy, M13 Projects/Tasks, M15 browser lifecycle, M16 Worker/Permission Center, M17 desktop observation/actions.
> **Scope:** local focus sessions, bounded OS awake leases, power/thermal policy, humane reminders, and browser-first degraded behavior.

## 1. Goal

M18 lets a user start an intentional, bounded work session tied to a Hive project or task. Hive may request a visible, time-limited awake lease, show local progress, pause intelligently when the user is locked, presenting, in a meeting, or under power/thermal pressure, and offer gentle break reminders that are easy to snooze or disable.

The product promise is a **lease**, not a system takeover: Hive never silently keeps a Mac awake indefinitely, never overrides the user’s battery/thermal policy, and never turns wellness into surveillance or coercion.

## 2. Non-goals and explicit deferrals

M18 does not ship a medical device, health diagnosis, biometric monitoring, screen-content cloud analytics, punitive focus blocking, forced breaks, hidden timers, or a replacement for macOS Focus/Do Not Disturb. It does not infer wellness from screenshots or keystrokes by default.

Deferred:

- HealthKit, heart-rate, posture, eye-tracking, webcam, microphone, and biometric data;
- automatic calendar/email/meeting connector access before M19/M23 contracts;
- app blocking, website blocking, parental controls, or irreversible “lock me out” modes;
- cross-device wellness sync and cloud analytics;
- background power assertions outside an active user-visible lease;
- AI-generated health recommendations or model-dependent timing decisions.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository has tab focus navigation, hibernation/idle policies, download notifications, project/task stores, EventLedger, local persistence/recovery contracts, and M16/M17 worker/OS boundaries. No explicit IOPM power assertion wrapper, battery/thermal observer, lock/presence observer, or general wellness reminder scheduler was found. Existing download notifications do not constitute a focus/wellness scheduler.

### 3.2 Authority table

| Concern | Authority | M18 rule |
|---|---|---|
| User intent/session start | Browser UI/Command Center | Explicit start; no ambient focus session. |
| Project/task relation | M13 Project/Task authority | Session references stable IDs; missing targets degrade cleanly. |
| Session state | Local FocusSession store/state machine | Persist before acquiring an OS lease. |
| Awake lease | OS adapter owned by session coordinator | One bounded assertion per session; always expires/releases. |
| Battery/thermal policy | Local policy engine + system signals | Policy may revoke/yield; user cannot force unsafe lease through default flow. |
| Presence/context | Public system signals and explicit user controls | “Unknown” pauses or avoids interruption; never treats missing data as permission. |
| Notifications | UserNotifications + local scheduler | Authorization is optional; in-app/menu-bar fallback remains. |
| Wellness content | Deterministic local templates | No model required; no health claims. |
| Privacy | Local-only store and retention policy | No screen/OCR/keystroke telemetry for wellness by default. |
| Audit | EventLedger | Record session/lease state and policy classes, not private activity content. |

## 4. Focus session model

### 4.1 Session record

```text
session_id: stable UUID
project_id: optional Project ID
task_id: optional Task ID
intent: user-authored short label
started_at / updated_at / planned_end_at
state: proposed | active | paused | yielding | completed | cancelled | revoked | recovery_required
pause_reason: user | screen_locked | screen_sleeping | meeting_or_presentation | battery | thermal | permission | system_unknown
elapsed_active / elapsed_paused
awake_lease_id: optional
settings_snapshot: duration, break policy, notification policy
created_by: user
privacy_class: local-only
```

A session is not inferred from app usage. It begins only after a user action that discloses duration, project/task scope, awake behavior, reminders, and pause rules.

### 4.2 State machine

```text
proposed → active
active → paused | yielding | completed | cancelled | revoked | recovery_required
paused → active | completed | cancelled | revoked
yielding → paused | completed | cancelled | revoked
recovery_required → active | paused | completed | cancelled
```

Every transition has a reason, timestamp, prior state, and idempotency key. A stale UI cannot resume a revoked or completed session. “Paused” means elapsed active time stops; “yielding” means the OS lease is being released while the user may continue the session without keep-awake behavior.

### 4.3 Persistence and crash recovery

1. Validate project/task references and settings.
2. Persist `proposed` session.
3. Persist `active` session and planned expiry.
4. Acquire the OS lease.
5. Persist lease-active evidence.

If lease acquisition fails, the session may remain active with `awakeLeaseUnavailable` disclosed, or become paused according to user policy; it must not claim the Mac is being kept awake. On restart, expired sessions become completed/paused by deterministic wall-clock rules, and any orphaned lease is released/reconciled before a new session starts.

## 5. Awake lease contract

### 5.1 Lease fields

```text
lease_id, session_id, assertion_kind
issued_at, expires_at, max_duration
requested_reason, effective_reason
battery_policy, thermal_policy, lid/display policy
os_assertion_identifier, status: requested | active | yielded | released | expired | failed
```

M18 allows only an explicit user-visible maximum duration. The default lease is bounded; a session may end earlier, but cannot silently extend itself. Renewal requires a new disclosure and user decision, not a background timer.

### 5.2 Acquisition and release

The coordinator must write session state before calling the OS adapter. It must release the assertion on normal completion, cancel, pause, revoke, lock/sleep policy, battery/thermal threshold, process termination, and worker/browser shutdown. Release is idempotent and observable.

If the OS API returns an unknown assertion ID or release failure, M18 marks the lease `recovery_required`, reports the issue, and attempts bounded reconciliation. It must never represent an unverified assertion as active.

### 5.3 Power policy

The user chooses a policy at session start:

- **Never keep awake:** no assertion;
- **Keep awake until session end:** bounded by session maximum and system safety policy;
- **Keep awake while charging:** yield on battery;
- **Keep awake only for presentation/build/export:** requires a declared task reason and ends on completion/expiry.

The policy must disclose that macOS/system conditions can supersede the request. Hive does not defeat lid-close, thermal emergency, low-power, admin, or OS safety behavior.

## 6. Battery, thermal, lock, and context smart pause

### 6.1 Battery and thermal

Use system signals rather than high-frequency polling. Define thresholds in policy:

- nominal/fair thermal state: session may continue;
- serious thermal state: release/yield the awake lease and pause heavy local work;
- critical thermal state: revoke lease, pause session, and show a non-alarming explanation;
- low battery or user-selected battery threshold: yield or pause according to policy;
- charging transition: may resume lease only when the user policy allows and the session is still active.

Unknown or unavailable readings must not be interpreted as safe permission for indefinite assertions.

### 6.2 Lock, sleep, and user presence

Screen lock, display sleep, fast-user-switching/session resignation, and system sleep pause or yield the session according to the chosen policy. Wake does not silently resume an expired or revoked session. If the user returns after a long gap, show the session state and offer resume rather than assuming intent.

### 6.3 Meetings, presenting, recording, and takeover

M18 should avoid intrusive reminders when a presentation/call/screen-share state is explicitly known or manually declared. Because M18 does not yet own calendar/meeting connectors, unknown context must prefer a quiet in-app/menu-bar cue rather than a blocking overlay. The user gets one-tap “presenting” and “do not remind during this” controls; no screenshot surveillance is required.

A user can pause for today, snooze, disable reminders, or end the session immediately. No shame copy, streak loss, or penalty state is allowed.

## 7. Wellness reminder contract

### 7.1 Reminder classes

M18 supports local, configurable suggestions:

- micro-break cue after a user-selected active interval;
- posture/eye-rest language only as a general suggestion, never a diagnosis;
- longer break suggestion after repeated intervals;
- session completion/review cue tied to the project/task.

Reminders are suggestions, not locks. Every reminder has `scheduled`, `shown`, `snoozed`, `dismissed`, `disabled`, or `suppressed` state and a reason when suppressed.

### 7.2 Interruption policy

Default presentation is a quiet menu-bar/status cue or non-modal notification. A blocking overlay is not the default and is never mandatory. The system applies a cooldown after dismissal/snooze, caps reminder frequency, honors notification authorization, and suppresses reminders while locked, sleeping, presenting, in full-screen media, or during an explicitly declared meeting.

If local notification permission is denied, Hive provides an in-app/status surface and does not repeatedly prompt. Notification content contains no page text, private task details, or screen-derived content unless the user explicitly chooses it.

### 7.3 Accessibility

Every state and action is available via keyboard, VoiceOver, dynamic sizing, increased contrast, and reduced motion. A reminder must expose its reason, duration, snooze choices, disable path, and current session state. It must never rely on color, sound, animation, or a countdown alone.

## 8. Privacy and data lifecycle

All session and reminder state is local by default. M18 stores only the minimum required: user-authored session intent, project/task IDs, durations, policy decisions, lease states, reminder outcomes, and coarse system-state classes. It does not store screenshots, keystroke timing, window titles, OCR, clipboard values, audio, webcam data, or a detailed app-usage timeline for wellness.

Wellness records have a user-visible retention setting and a “forget session history” path. Forgetting removes local session/reminder records and corresponding non-secret evidence according to M0/EventLedger deletion policy; it does not claim to erase OS notification-center history outside Hive’s control.

## 9. Work packages

### M18-A — Focus session authority and recovery

Define the local FocusSession schema/state machine, project/task references, explicit start/end/pause/resume, settings snapshot, idempotent transitions, persistence-before-lease ordering, restart reconciliation, and deletion/forget semantics.

**Done when:** a user can start, pause, resume, complete, cancel, and recover a task-linked session without timers or UI state becoming the authority.

### M18-B — Bounded awake lease adapter

Define the OS power assertion adapter, lease IDs, maximum duration, acquisition/release/reconciliation, charging/battery policies, process termination cleanup, and truthful unavailable states.

**Done when:** every successful lease has a verified bounded release path; no orphan assertion or indefinite background keep-awake path remains after expiry, pause, crash, or revoke.

### M18-C — Battery/thermal/presence policy

Add local system-signal adapters for thermal, battery/power source, display sleep/wake, lock/session state, and user-declared presentation/meeting mode. Define yielding, pausing, resuming, and unknown-state behavior.

**Done when:** serious/critical thermal, low battery, lock/sleep, and session resignation release or pause according to policy without data loss or unsafe retry loops.

### M18-D — Humane reminders and wellness controls

Add deterministic local reminder scheduling, suppression/cooldown, snooze/disable/today controls, notification authorization/degraded paths, accessible status UI, and local retention/forget controls.

**Done when:** reminders are optional, quiet, non-modal by default, never shame the user, and remain useful when UserNotifications is denied.

### M18-E — Integrated browser-first validation

Validate task-linked start, lease acquisition/release, restart/crash recovery, thermal/battery yielding, lock/presence pauses, presentation suppression, notification denial, accessibility, reduced motion, and AI/Worker-disabled operation.

**Done when:** ordinary browsing remains unchanged without a Focus Session, every lease and reminder is inspectable, and all privileged/notification failures degrade truthfully.

## 10. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M18-01 | Start session without project/task | Allowed only if user selects standalone scope; scope disclosed |
| M18-02 | Start task-linked session | Stable project/task IDs persisted |
| M18-03 | Duplicate start request | One session; idempotent result |
| M18-04 | Persist active state fails | No OS lease acquired or session marked explicitly non-active |
| M18-05 | Lease acquisition unavailable | Session discloses no keep-awake guarantee |
| M18-06 | Lease expires | Assertion released; session completes/pauses by policy |
| M18-07 | User ends session | Lease released and receipt recorded |
| M18-08 | User pauses session | Lease yielded/released; active elapsed time stops |
| M18-09 | User resumes paused session | New bounded lease only if policy permits |
| M18-10 | Renewal at expiry | Requires fresh disclosure/decision; no silent extension |
| M18-11 | Release called twice | Idempotent; no false failure |
| M18-12 | Release returns OS error | Recovery-required state and bounded reconciliation |
| M18-13 | App terminates during lease | Reconciliation path; no orphan assertion claim |
| M18-14 | Browser crash with active session | Restart reconciles state and lease before resume |
| M18-15 | Thermal nominal | Session continues under policy |
| M18-16 | Thermal serious | Lease yielded/released; heavy work pauses |
| M18-17 | Thermal critical | Session paused/revoked; no retry loop |
| M18-18 | Low battery threshold | Yield/pause according to chosen policy |
| M18-19 | Charger connected | Resume lease only if user policy allows |
| M18-20 | Battery state unavailable | No indefinite lease assumption |
| M18-21 | Display sleep/lock | Session pauses/yields; no intrusive reminder |
| M18-22 | Session resigns/fast-user-switch | Lease released; state recorded |
| M18-23 | Wake after expiry | No silent resume |
| M18-24 | User declares presentation | Blocking reminders suppressed |
| M18-25 | Meeting context unknown | Quiet cue only; no forced overlay |
| M18-26 | Screen-share/full-screen state known | Reminder suppressed/deferred |
| M18-27 | User pauses for today | All reminders suppressed through chosen boundary |
| M18-28 | User snoozes reminder | Cooldown honored; no penalty |
| M18-29 | User disables wellness | No further reminders; session can continue |
| M18-30 | Notification permission denied | In-app/menu-bar fallback; no prompt loop |
| M18-31 | Notification content scope | No page/OCR/private screen text in notification |
| M18-32 | Reminder frequency cap | No notification spam across repeated sessions |
| M18-33 | Dismissal cooldown | Next reminder delayed deterministically |
| M18-34 | Forget session history | Local records removed within stated scope |
| M18-35 | EventLedger evidence | IDs/policy classes only; no screen/keystroke content |
| M18-36 | User starts ordinary browsing | No focus/wellness state created |
| M18-37 | AI unavailable | Deterministic session/reminder controls remain usable |
| M18-38 | Worker unavailable | Focus session does not require desktop worker |
| M18-39 | VoiceOver session controls | Start/pause/resume/end/snooze/disable exposed |
| M18-40 | Reduced motion/high contrast/dynamic size | No information lost or clipped |
| M18-41 | User changes system sleep policy | Hive discloses OS policy may supersede lease |
| M18-42 | Multiple sessions requested | Policy allows one active lease per user/session scope or explicit conflict UI |
| M18-43 | Stale task/project reference | Session remains recoverable with missing-link state |
| M18-44 | Clock moves backward/forward | Monotonic elapsed accounting plus wall-clock expiry disclosure |
| M18-45 | Sleep spans planned expiry | Session does not overrun; reconciles on wake |
| M18-46 | Uninstall/disable wellness | Lease released and reminder scheduler stopped |

## 11. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M18-A | Focus session authority | State-machine, persistence, idempotency, and task-link tests |
| M18-B | Lease safety | Bounded acquire/release/expiry/reconciliation evidence |
| M18-C | Battery/thermal policy | Serious/critical/low-battery yield and no-retry tests |
| M18-D | Lock/presence handling | Sleep/wake/session resignation and expiry tests |
| M18-E | Humane interruption | Suppression, cooldown, snooze, disable, no-shame UX evidence |
| M18-F | Notification degradation | Denied authorization leaves local fallback and no prompt loop |
| M18-G | Privacy/local-only | No screenshots, OCR, keystrokes, audio, webcam, or cloud wellness data |
| M18-H | Retention/forget | User-visible session-history deletion within stated scope |
| M18-I | Ledger truthfulness | Lease/session/reminder evidence is minimal, ordered, and redacted |
| M18-J | Accessibility | Keyboard, VoiceOver, contrast, reduced motion, dynamic size |
| M18-K | Browser-first behavior | No session means ordinary browsing is unaffected |
| M18-L | Truthful status | No verified claim without current build/tests/runtime evidence |

## 12. Implementation order and handoff

Implement M18-A before any OS power assertion. Implement M18-B with a fake clock and fake OS adapter before integrating IOPM. Implement M18-C using event-driven system signals and conservative unknown-state behavior. Implement M18-D only after session/pause semantics are stable. M18-E must validate expiry, crash, battery/thermal, lock, notification denial, and forget paths.

The next smallest safe implementation slice is **M18-A: local FocusSession state machine, persistence-before-lease ordering, and restart reconciliation**. No model training or background process is part of M18.
