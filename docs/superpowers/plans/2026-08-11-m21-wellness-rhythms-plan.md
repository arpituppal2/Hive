# M21 — Wellness Rhythms Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M5 reminder/proposal lifecycle, M12 Command Center, M13 Projects/Tasks, M16 Worker/Permission Center, M18 Focus Sessions/Awake Leases.
> **Scope:** optional local wellness rhythms, gentle break suggestions, explicit smart-pause controls, notification truthfulness, and browser-first degraded behavior.

## 1. Goal

M21 makes Hive’s wellness behavior humane and context-aware without turning it into surveillance, a medical product, or a productivity enforcement system. A user can opt into lightweight break rhythms during an explicit Focus Session, pause or snooze them, declare that they are presenting or in a meeting, and understand why a reminder was shown or suppressed.

M18 owns the hard lifecycle: FocusSession state, awake leases, battery/thermal yielding, lock/sleep handling, and lease recovery. M21 owns the soft layer: reminder cadence, suppression, explicit context controls, notification presentation, and local retention. M21 may suggest a break; it never locks the user out, penalizes them, or claims to know more context than the platform exposes.

## 2. Non-goals and explicit deferrals

M21 does not ship medical advice, diagnosis, biometric monitoring, posture/eye tracking, webcam or microphone surveillance, keystroke analysis, screen-content analysis, app-usage scoring, parental controls, forced breaks, app/site blocking, or a replacement for macOS Focus/Do Not Disturb.

Deferred or explicitly opt-in:

- passive meeting detection from window titles, process names, audio devices, screenshots, or screen-sharing streams;
- global dictation detection or microphone monitoring outside Hive-owned audio sessions;
- reading or toggling another app’s Focus state without an available sanctioned API and explicit user authorization;
- calendar/email-derived meeting context until the relevant connector/module contract is approved;
- cloud wellness analytics, cross-device wellness sync, and model-generated health recommendations;
- time-sensitive or critical notification privileges;
- automatic changes to system Focus, notification settings, sleep policy, or power policy.

When context is unknown, M21 suppresses or uses a quiet in-app/status cue. Unknown is never permission to interrupt.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

M18 defines local FocusSession state, bounded awake leases, battery/thermal/lock/presence yielding, optional reminders, notification-denied behavior, local retention, and browser-first degradation. M5 defines proposal lifecycle concepts such as approve, deny, snooze, expire, and forget. The repository has general toasts/download notifications and session/task persistence, but no proven M21 reminder scheduler, wellness context bus, or end-to-end smart-pause surface.

These are planning primitives, not a verified wellness product. No source claim may be upgraded to `verified` until a current build, tests, and a clean-profile runtime path pass.

### 3.2 Signal reliability policy

| Signal/context | M21 treatment | Authority/limit |
|---|---|---|
| User starts/pauses/ends Focus Session | Reliable intent | M18 FocusSession authority |
| User chooses “Presenting,” “In a meeting,” or “Do not remind” | Reliable explicit override | Local user preference; expires or remains until changed per disclosure |
| Screen locked/sleeping/session inactive | Reliable suppression trigger | M18/OS lifecycle signals |
| Notification authorization/status | Reliable delivery constraint | UserNotifications; may change outside Hive |
| Battery/thermal yield | Reliable safety constraint | M18 power policy |
| Hive-owned audio/dictation state | Reliable only for Hive-owned session | App-scoped permission and lifecycle |
| Another app’s meeting/dictation state | Unknown by default | No passive capture or inference |
| System Focus mode | Treat conservatively unless supported by an approved, documented API path | Do not claim granular mode identity or toggle system state |
| Window title/process/screenshot heuristic | Never an automatic authority | Optional future experiment requires separate permission, disclosure, and evaluation |

M21 may combine signals only through a deterministic local policy. A model cannot decide whether to interrupt, infer a meeting, or override a suppression state.

## 4. Local state and lifecycle

### 4.1 Rhythm profile

A user profile is explicit, versioned, and local:

```text
profile_id: stable ID
enabled: Bool
eligible_session_kinds: task-linked | presentation-prep | user-selected
micro_break_interval: bounded duration or off
long_break_after_intervals: bounded integer or off
quiet_hours: local schedule or off
notification_mode: in-app | passive notification | off
default_snooze: 15m | 1h | today | custom bounded duration
respect_explicit_presenting: Bool
retention_policy: local duration / forget-on-end
updated_at / settings_version
```

Defaults are conservative: disabled until opt-in, no health claims, no modal interruptions, no time-sensitive notifications, and no reminders outside an explicit eligible session unless the user separately enables that behavior.

### 4.2 Reminder lifecycle

Every reminder has durable minimum state and an idempotency key:

```text
reminder_id, session_id, profile_id
kind: micro_break | longer_break | resume_hint
scheduled_at, eligible_at, shown_at, resolved_at
state: scheduled | suppressed | shown | snoozed | dismissed | completed | expired | cancelled
suppression_reason: locked | sleeping | quiet_hours | presenting | meeting_declared | notification_denied | thermal | battery | no_session | user_disabled | unknown_context
source: deterministic_local_policy
```

A crash or restart must not replay a burst of missed reminders. On recovery, stale reminders expire or coalesce into one quiet status item according to a deterministic wall-clock rule. No missed-reminder guilt copy, streak loss, or penalty state is allowed.

### 4.3 M18 bridge

M21 observes M18 session transitions; it does not mutate lease state or acquire power assertions. If M18 yields or ends a session, M21 suppresses or reschedules reminders according to the user profile. If M18 is unavailable, M21 cannot create an implicit session and remains disabled or offers manual local reminders only.

## 5. Smart-pause contract

### 5.1 Explicit controls first

The primary smart-pause controls are visible, keyboard-accessible, and one action away:

- **Presenting:** suppress reminders until the user ends presentation mode or a disclosed expiry occurs;
- **In a meeting:** suppress reminders until the user ends the declaration or a disclosed expiry occurs;
- **Dictating/recording:** suppress reminders for the chosen bounded duration;
- **Pause for today:** suppress all M21 reminders through the user’s local-day boundary;
- **Snooze:** suppress the current reminder for a selected duration;
- **Disable wellness:** stop future M21 scheduling while leaving M18 sessions and ordinary browsing intact.

These states are not claims about what another app is doing. They are user-authored context and must be labeled accordingly.

### 5.2 Reliable automatic suppression

M21 automatically suppresses reminders for reliable states already owned by the platform/session boundary:

- screen locked, sleeping, fast user switch, or inactive user session;
- M18 battery/thermal safety yield;
- notification authorization denied or notification delivery unavailable;
- no eligible Focus Session;
- the user’s configured quiet hours.

Automatic suppression must show a reason in the status inspector when the user asks. It must not create a notification merely to announce that a notification was suppressed.

### 5.3 Unknown and conflicting states

If one signal says eligible and another is unknown, prefer no interruption. Explicit user declaration wins over heuristic suggestions. A later automatic signal cannot silently clear a user’s “presenting,” “meeting,” or “pause today” state. Expiry and clearing behavior is visible at the point of declaration.

## 6. Reminder and notification UX

A reminder is a suggestion with a useful action, not an alarm. The default surface is a quiet in-app cue, menu-bar/status item, or passive local notification depending on authorization and the user profile. A modal overlay is never the default.

Every shown reminder exposes:

- why it appeared and which session it belongs to;
- the suggested duration or action;
- Snooze, Dismiss, and Disable/Adjust Rhythm actions;
- a “Presenting/Meeting/Do not remind” quick control;
- current suppression and notification state when relevant.

Notification delivery uses the system authorization/status boundary and does not attempt to bypass macOS Focus or Do Not Disturb. M21 does not request time-sensitive/critical interruption privileges by default. If authorization is denied, the app remains quiet and offers an in-app setting path; it does not repeatedly ask.

The UI must remain understandable without color, sound, animation, countdowns, or hover. Any modal-like custom surface follows the product’s accessibility/focus rules and always has an Escape/Cancel path.

## 7. Privacy and retention

M21 stores only the minimum local state needed to honor the user’s chosen rhythm:

- profile and explicit control settings;
- eligible session IDs and coarse durations;
- reminder schedule/outcome/suppression class;
- coarse battery/thermal/lock/session classes when needed for reconciliation;
- local retention and deletion metadata.

M21 does not store screenshots, OCR, page bodies, window titles, process histories, keystroke timing, clipboard values, microphone audio, webcam frames, detailed app usage, meeting content, or raw Focus configuration. It does not send wellness state, context signals, or reminder history to remote models or services.

The user can disable M21, pause it for the day, forget wellness history, and inspect the retained record class. Forgetting removes Hive-owned local records according to M0/EventLedger policy but does not claim to erase OS Notification Center history outside Hive’s control.

## 8. Accessibility and humane interaction

M21 is complete only when all settings, status, reminders, and recovery paths work with keyboard navigation, VoiceOver, Dynamic Type, Increase Contrast, Reduce Motion, and reduced transparency.

Requirements:

- status announces enabled/disabled, current session, next eligible reminder, and suppression reason;
- buttons have outcome-specific labels: “Snooze for 15 minutes,” not “Snooze” alone;
- presenting/meeting/dictation declarations expose their expiry and clearing action;
- focus returns to the prior control after a reminder is dismissed or a settings sheet closes;
- larger text does not clip reminder actions, settings controls, or privacy explanations;
- reduced motion removes entrance/bounce effects without hiding the state transition;
- no reminder relies on color, sound, animation, or a countdown alone;
- the user can reach Disable, Pause for today, and Forget history without a mouse.

## 9. Work packages

### M21-A — Local rhythm profile and lifecycle

Define the local profile, explicit enablement, eligible-session relation, schedule, retention, reminder state machine, deterministic IDs, crash recovery, and M18 bridge. Add no heuristics initially.

**Done when:** a user can enable, pause, snooze, disable, and forget M21 state; restart does not replay stale reminders or create an implicit session.

### M21-B — Explicit smart-pause controls

Add presenting, meeting, dictating/recording, pause-for-today, snooze, and quiet-hours controls with expiry, local persistence, accessibility, and visible status reasons.

**Done when:** explicit declarations suppress reminders deterministically, survive restart as disclosed, expire correctly, and never claim that Hive detected another app’s context.

### M21-C — Reliable suppression and notification boundary

Integrate M18 lock/sleep/session/power signals and UserNotifications authorization/status. Add coalescing, cooldown, notification-denied behavior, and no-burst crash recovery.

**Done when:** no reminder appears during reliable suppression states, denied notification permission produces no prompt loop, and all deliveries are honest about the available channel.

### M21-D — Optional signal evaluation, not authority

Document and evaluate any future sanctioned Focus or platform signal path. Keep meeting/window/audio/screen-share heuristics disabled by default; if an experiment is later admitted, isolate it behind explicit permission, a visible toggle, local-only processing, false-positive/negative metrics, and a manual override.

**Done when:** no automatic context detector can become an interruption authority without a separately approved contract and adversarial evaluation.

### M21-E — Integrated humane/browser-first validation

Validate clean-profile onboarding, explicit opt-in, reminders, suppression, snooze/disable/forget, notification denial, lock/sleep/thermal states, restart recovery, accessibility, reduced motion, privacy inspection, and ordinary browsing with M21 disabled.

**Done when:** wellness is optional and quiet, browser behavior is unchanged when disabled, and no health/surveillance claim is made.

## 10. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M21-01 | First launch | No wellness prompt or session created |
| M21-02 | User enables profile | Explicit settings snapshot stored locally |
| M21-03 | No eligible Focus Session | No reminder scheduled |
| M21-04 | M18 session starts | Eligible schedule created according to profile |
| M21-05 | Session ends | Pending reminders cancel/expire; no guilt notification |
| M21-06 | Pause for today | All reminders suppressed through local-day boundary |
| M21-07 | Snooze 15m | Current reminder delayed exactly; no duplicate |
| M21-08 | Disable wellness | Future M21 scheduling stops; M18/browser continue |
| M21-09 | Forget history | Hive-owned wellness records removed; OS history caveat shown |
| M21-10 | Presenting declared | Reminders suppressed until disclosed expiry/clear |
| M21-11 | Meeting declared | Reminders suppressed; no claim of automatic detection |
| M21-12 | Dictating declared | Reminders suppressed for bounded duration |
| M21-13 | Explicit state expires | Normal eligibility resumes only if session/profile allow |
| M21-14 | Conflicting explicit states | Deterministic precedence and visible resolution |
| M21-15 | Screen locked | Reminder suppressed; no lock-screen sensitive content |
| M21-16 | User session inactive | Reminder suppressed; no replay burst on return |
| M21-17 | Sleeping/wake | Missed reminders coalesce or expire deterministically |
| M21-18 | Thermal yield | M18 safety state suppresses M21 reminder |
| M21-19 | Low battery policy | No reminder that conflicts with M18 power policy |
| M21-20 | Notification authorization denied | In-app setting path; no repeated system prompt |
| M21-21 | Notification authorization changes externally | Status reconciles before next schedule |
| M21-22 | Quiet hours | No delivery; next eligible time disclosed locally |
| M21-23 | Notification delivery failure | In-app/status fallback; no false “shown” receipt |
| M21-24 | Crash with pending reminders | No stale burst; state reconciles by wall-clock rule |
| M21-25 | Duplicate scheduler request | Idempotent reminder IDs; one effective schedule |
| M21-26 | Stale UI action | Rejected or reconciled; cannot clear newer pause |
| M21-27 | Unknown meeting state | Suppress or quiet cue; never infer permission to interrupt |
| M21-28 | Window-title heuristic present | Ignored by default; no automatic suppression authority |
| M21-29 | Screen-share permission absent | No prompt solely for wellness; manual Presenting control remains |
| M21-30 | Dictation from another app | Unknown; no microphone surveillance or false claim |
| M21-31 | System Focus state unavailable | Use notification boundary/manual controls; no fabricated mode |
| M21-32 | User changes system Focus | Hive does not toggle system state; delivery remains OS-governed |
| M21-33 | Reminder content privacy | No page/app/meeting content in notification text |
| M21-34 | Local-only inspection | No network/model call for profile or reminder policy |
| M21-35 | VoiceOver reminder | Reason, session, action, snooze, disable all announced |
| M21-36 | Dynamic Type | Controls and privacy copy remain reachable |
| M21-37 | Reduce Motion | No essential state hidden by animation |
| M21-38 | Increased contrast | Status and suppression reasons remain distinct |
| M21-39 | Keyboard-only flow | Enable/pause/snooze/disable/forget complete without mouse |
| M21-40 | M21 disabled | Ordinary browsing and M18 session path unaffected |
| M21-41 | Health/biometric request | Rejected as out of scope; no data capture |
| M21-42 | Remote model request | Denied by default; no wellness context leaves device |
| M21-43 | Uninstall/permission removal | Scheduling stops; no claimed OS-history deletion |
| M21-44 | M18 unavailable | No implicit focus session; quiet disabled/manual state |
| M21-45 | Repeated dismissals | Cooldown/quiet behavior; no escalating nag |
| M21-46 | Explicit user asks for frequent reminders | Bounded cadence and clear override/disable remain |

## 11. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M21-A | Explicit opt-in/profile | Clean-profile enable/disable/pause/forget evidence |
| M21-B | Reminder lifecycle | Deterministic schedule, coalescing, snooze, expiry, crash recovery |
| M21-C | M18 boundary | M21 observes session/power state; never owns leases or creates sessions implicitly |
| M21-D | Smart-pause truthfulness | Explicit declarations work; unknown heuristics cannot interrupt |
| M21-E | Notification honesty | Authorization/status/failure states and no prompt loop |
| M21-F | Privacy/local-only | No screenshots, audio, window history, health data, cloud analytics, or remote wellness context |
| M21-G | Humane controls | No forced breaks, shame copy, streak penalties, or lockouts |
| M21-H | Accessibility | Keyboard, VoiceOver, dynamic sizing, contrast, reduced motion |
| M21-I | Power/safety interaction | Battery/thermal/lock/sleep suppression honors M18 |
| M21-J | Browser-first degraded path | Browsing works fully with M21 disabled/unavailable |
| M21-K | Signal admission | Any future detector requires separate permission, toggle, metrics, and contract |
| M21-L | Truthful status | No verified wellness claim without current runtime evidence |

## 12. Implementation order and handoff

Implement M21-A before any context heuristics. Implement explicit smart-pause controls before investigating platform signals. Integrate only reliable M18/session/notification boundaries in M21-C. Treat Focus, meeting, screen-share, and dictation detection as separate experiments that cannot become authority by implication.

The next smallest safe implementation slice is **M21-A: local rhythm profile, reminder state machine, explicit opt-in, and M18 observation boundary**. No model training, screen/audio surveillance, background workload, or automatic meeting detector is part of M21.
