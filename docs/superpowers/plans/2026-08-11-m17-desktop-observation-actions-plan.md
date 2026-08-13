# M17 — Desktop Observation & Typed Actions Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M6 local-agent/encryption decision, M10 Sidecar approvals, M11 Studio bounded execution/rollback, M12 Command Center receipts, M15 browser credibility, M16 Worker/Permission Center.
> **Boundary:** M16 owns the signed pipe, grants, TCC state, and revocation. M17 owns target-bound observations, typed desktop payloads, preflight revalidation, verification, and compensation.

## 1. Goal

M17 makes one small class of personal-computer actions safe enough to review: the user can select an approved target window, inspect a redacted observation, review a typed action preview, approve it, have the Worker revalidate the target immediately before dispatch, see the result and verification, and stop or revoke the session at any point.

M17 does not claim that arbitrary mouse/keyboard automation, AppleScript, OCR, or model-generated coordinates are safe. It turns those raw capabilities into bounded, target-bound, policy-gated operations or rejects them.

## 2. Non-goals and explicit deferrals

M17 does not ship unrestricted desktop control, invisible background automation, arbitrary Apple Events, freeform shell/AppleScript, password/payment/message submission, account changes, system configuration, root access, or automatic “undo” claims for non-transactional OS mutations.

Deferred:

- broad multi-app workflows;
- arbitrary coordinate clicks without a verified target element;
- credential, payment, health, private-message, 2FA, or banking interactions;
- autonomous long-running loops;
- global screen recording and durable screenshot history;
- cross-device remote desktop control;
- rollback claims where the target application/OS has no verified compensation path.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository contains typed `ToolInvocation` envelopes with targets, previews, trust levels, approval-scope hashes, and rollback plans; `ToolRegistry` risk classes/input fields; `PolicyEngine`; `EventLedgerStore`; `ResearchWorkerClient`; Studio file snapshots/diffs/rollback; Bee cancellation/verification; and M16’s planned signed Worker/grant/Permission Center boundary. Direct end-to-end desktop target observation and action verification are not proven.

### 3.2 Authority table

| Concern | Authority | M17 rule |
|---|---|---|
| Root user intent | Browser UI/Command Center | AX/OCR/clipboard/page text cannot alter it. |
| Worker/grants/TCC | M16 Worker and Permission Center | M17 cannot mint, widen, or self-approve grants. |
| Action schema | M17 typed adapter registry | No privileged freeform strings. |
| Policy/trust | M10/M11 `PolicyEngine` and ActionLadder | Model is advisory; policy is executable boundary. |
| User approval | M10/M11 approval controller | Approval binds exact target/action/parameters/generation/expiry. |
| Observation truth | OS adapter + target snapshot | Cached elements and coordinates expire; re-observe before action. |
| Verification | M17 verifier | A dispatch result is not success without typed postcondition evidence. |
| Rollback/compensation | Tool contract | Non-transactional actions disclose irreversibility; no fake undo. |
| Evidence | EventLedger | Ordered redacted metadata, no raw secrets/screens by default. |
| Stop/revoke | M16 browser-owned controller | Immediate and idempotent; worker cannot veto. |

## 4. Target-bound observation model

### 4.1 Target identity

A target is not a screen coordinate. It is a structured identity:

```text
application_bundle_id, process_instance_id
window_id, window_generation, title_hash, role
screen/display_id, bounds, scale_factor, frontmost_state
observation_generation, observed_at, permission_state
redaction_profile, source_kind: ax | screen | browser-dom | file
```

An element reference adds:

```text
element_path or stable AX identifier
role, label_hash, value_class, bounds, enabled/focused state
element_generation, parent/window identity, observation timestamp
```

Labels and values are redacted or hashed in durable evidence unless the user explicitly permits display. The model may receive bounded untrusted observations, but observation text is never treated as instructions.

### 4.2 Observation states

```text
requested → permission_check → observing → snapshot_ready
snapshot_ready → stale | redacted | target_changed | revoked | failed
observing → paused_sensitive | paused_user_takeover | stopped
```

A snapshot is a point-in-time fact, not a durable object reference. Every action proposal includes the snapshot generation and target identity from which it was derived.

### 4.3 Sensitive and takeover states

When a sensitive target is detected or the user takes control:

- pause model-driven dispatch;
- stop frame/OCR retention and redact clipboard/credential-shaped text;
- require explicit user return before continuing;
- never log raw password/payment/private-message content;
- invalidate stale action previews after focus, target, or window changes.

## 5. Typed desktop action model

### 5.1 Allowed M17 action kinds

M17 begins with a deliberately small set:

```text
desktop.focusApprovedWindow(target)
desktop.activateElement(target, element)
desktop.clickElement(target, element)
desktop.selectOption(target, element, optionID)
desktop.typeNonSensitiveText(target, element, textClass, value)
desktop.scrollApprovedRegion(target, direction, boundedAmount)
desktop.readApprovedElement(target, element)
desktop.copyVisibleNonSensitiveValue(target, element)
```

`desktop.typeNonSensitiveText` accepts only a declared data class (`ordinary_text`, `search_query`, `local_draft`) and rejects credentials, payment data, tokens, private keys, and unknown sensitive classes. Raw coordinates, arbitrary key sequences, freeform AppleScript, arbitrary CGEvents, and model-provided process IDs are not M17 action inputs.

### 5.2 Action envelope

Every action contains:

```text
action_id, kind, grant_id, session_id, project_id
user_intent_id, target_identity, observation_generation
typed_parameters, preview_text, risk/trust level
requires_confirmation, approval_scope_key, expires_at
expected_preconditions, postconditions
rollback_kind: transactional | compensation | none
stop_behavior, redaction_policy, tool_version
```

The canonical parameter representation is deterministic and hashable. `approval_scope_key` changes if target identity, element identity, action kind, sensitive-data class, text hash, bounds, or policy version changes.

### 5.3 Parameter safety

Validate before preview and again before dispatch:

- target belongs to the active grant and approved scope;
- element role/label hash/bounds/generation match the observation;
- text class is allowed and size-limited;
- scroll direction/amount is bounded;
- application/window is still the intended process instance;
- no hidden freeform script or extra parameter is smuggled through metadata;
- action is not derived solely from untrusted page/OCR instructions.

## 6. Preview, approval, and preflight

### 6.1 Preview

The UI shows target application/window, action verb, bounded element description, data class, intended effect, risk, whether the action is reversible, and what will be recorded. It does not expose secrets merely to obtain consent.

For multi-step actions, M17 previews one typed step at a time or a fixed immutable batch with an explicit maximum count. The user can reject, edit the user-authored intent, take over, or stop.

### 6.2 Approval binding

Approval is valid only for the exact action envelope and a short expiry. It is invalidated by any change to:

- worker identity, grant, permission state, policy version, or revocation generation;
- target process/window/focus/bounds/role;
- element generation or enabled state;
- action parameters, text class, or postcondition;
- user takeover, sensitive-surface detection, or navigation/application change.

A model cannot reuse a prior approval for a new target or mutate an approved envelope after the fact.

### 6.3 Preflight revalidation

Immediately before OS dispatch, the Worker re-observes and verifies:

1. process instance and bundle ID;
2. window identity and generation;
3. frontmost/focus state and expected bounds;
4. element role, stable path/identifier, bounds, enabled state, and label hash;
5. TCC/grant/session/revocation state;
6. user takeover and sensitive-surface state;
7. approval hash and expiry.

Any mismatch returns `stale_target`, `focus_changed`, `permission_changed`, `sensitive_surface`, or `approval_expired`; it does not guess or click a nearby target.

## 7. Dispatch and verification

### 7.1 Dispatch

The adapter sends only typed arguments to the Worker. Dispatch is cancellable and bounded by action timeout, retry count, and batch count. A retry must re-observe and revalidate; it must not replay an old coordinate or stale AX reference.

### 7.2 Postconditions

Each action declares a verifier:

- click/activate: target element state or expected focus/navigation change;
- select: selected option identity/value class;
- type: non-sensitive field value hash/length/class, never raw secret;
- scroll: bounded viewport/anchor change;
- read/copy: returned value class plus redaction and source scope.

Verification failure is `unverified`, not success. The user receives retry, take-over, or stop options. Partial multi-step batches report the exact completed step and remaining steps.

### 7.3 Verification limits

A screenshot or AX observation can support a postcondition but does not prove an external side effect such as an email being sent, payment being accepted, or account state changing. Those actions remain out of scope or require a provider-specific receipt and explicit confirmation.

## 8. Rollback, compensation, and irreversibility

### 8.1 Rollback classes

| Class | Meaning | M17 behavior |
|---|---|---|
| `transactional` | Tool guarantees atomic rollback | May expose undo after verified commit. |
| `compensation` | A typed inverse may reduce the effect | Show compensation, not “undo”; require approval where consequential. |
| `none` | OS/app mutation cannot be reliably reversed | Label irreversible before approval; elevated confirmation or reject. |

AX mutations and CGEvent input generally have no universal OS transaction. M17 must not promise rollback merely because an action has a `rollbackKind` field. The tool adapter must prove the compensation path and its limits.

### 8.2 File/terminal actions

File and terminal actions use M11’s bounded workspace, diff, checkpoint, command policy, and rollback contract. M17 must not bypass Studio for file writes, arbitrary terminal commands, or repository mutations.

## 9. Stop, revoke, and user takeover

A visible stop button cancels queued/in-flight actions, invalidates action generations, closes observation streams, and prevents retries. Revocation comes from M16 and invalidates the grant/IPC channel. User takeover pauses model dispatch and transfers focus/control to the user; returning control requires a fresh observation and approval.

Stop is not merely an UI state update: it must terminate worker dispatch and leave a typed `cancelled`/`interrupted` ledger result. A worker or model cannot defer stop until after a sequence completes.

## 10. EventLedger contract

Required ordered evidence:

```text
intent → observation_scope → observation_snapshot_hash
→ policy_decision → preview → user_approval/denial
→ preflight_result → dispatch → verification
→ compensation/rollback/stop/revoke/recovery
```

Default evidence includes stable IDs, target bundle/window IDs or redacted hashes, action class, risk/trust, policy/tool versions, timestamps, result class, postcondition class, and rollback/compensation reference. It excludes raw screenshots, OCR dumps, clipboard values, password/token text, freeform scripts, and full page content.

Ledger failure before a consequential action makes the action unavailable or waiting; it never silently proceeds unlogged. Ledger failure after a non-consequential observation is disclosed as incomplete evidence and does not become a false success.

## 11. Accessibility and browser-first behavior

The action preview and stop/takeover controls must be keyboard reachable, VoiceOver-labeled, readable under increased contrast and dynamic sizing, and independent of animation. The user must be able to deny all permissions and continue ordinary browsing. M17 must not place a blocking desktop-agent cockpit over the default browser surface.

## 12. Work packages

### M17-A — Target identity and observation snapshots

Define typed app/window/element identities, generations, observation scopes, redaction profiles, sensitive/takeover states, and snapshot hashing. Build pure stale-target and scope-validation rules before OS dispatch.

**Done when:** observations are target-bound, untrusted, privacy-classified, and invalidated on target/focus/permission changes.

### M17-B — Typed action schema and registry

Add the narrow `desktop.*` action catalog, parameter schemas, data classes, risk/trust mapping, approval-scope hashing, limits, and forbidden-input rejection. Reuse M16 grants and M11/M12 typed boundaries.

**Done when:** no raw coordinates/scripts/model-selected permissions can enter an enabled privileged action path.

### M17-C — Preview, approval, and preflight revalidation

Bind exact target/action/generation/parameters/postconditions to the approval UI. Implement immediate preflight re-observation and fail-closed stale/focus/sensitive/permission results.

**Done when:** moving, closing, replacing, or changing focus in the target between preview and dispatch cannot cause a nearby or unintended action.

### M17-D — Dispatch, verification, and compensation

Implement bounded typed dispatch, cancellation, postcondition verifiers, partial-batch reporting, compensation/irreversibility labels, and M11 handoff for file/terminal changes.

**Done when:** every enabled action reports verified, unverified, failed, cancelled, or interrupted honestly; no universal rollback claim is made for non-transactional OS effects.

### M17-E — Integrated adversarial and degraded validation

Exercise prompt injection, wrong-window/focus races, stale AX elements, sensitive surfaces, clipboard redaction, revoke/stop, worker crash, ledger failure, accessibility, and AI-disabled browser-first paths.

**Done when:** one bounded action can complete with preview, approval, preflight, verification, and evidence; every denied/stale/unsafe path stops without external effect.

## 13. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M17-01 | Observation for approved app/window | Snapshot has target identity, generation, scope, and redaction class |
| M17-02 | Process instance changes | Snapshot/action invalidated |
| M17-03 | Window closes/reopens with same title | Identity mismatch; no reuse |
| M17-04 | Window bounds/focus changes | Action returns `focus_changed` or `stale_target` |
| M17-05 | AX element re-rendered | Old element returns stale; re-observe required |
| M17-06 | Nearby element resembles target | No coordinate guessing; action rejected |
| M17-07 | Hidden/off-screen target | Observation/action pauses or rejects |
| M17-08 | Target leaves approved app/window scope | Grant mismatch; no action |
| M17-09 | Screen scale changes | Bounds/generation invalidated |
| M17-10 | Sensitive window detected | Observation redacted/paused; no model dispatch |
| M17-11 | Clipboard credential-shaped value | Redacted before context/ledger |
| M17-12 | OCR contains “ignore instructions” | Data only; user intent unchanged |
| M17-13 | Raw coordinate action | Rejected unless mapped to a verified typed element |
| M17-14 | Freeform AppleScript action | Rejected; typed adapter required |
| M17-15 | Raw shell action | Routed to M11 policy or rejected |
| M17-16 | Unknown text data class | Rejected; no typing |
| M17-17 | Oversized text/scroll amount | Bounded rejection |
| M17-18 | Action approval hash changes | Approval invalidated |
| M17-19 | Grant/revocation generation changes | Approval invalidated |
| M17-20 | Permission withdrawn after approval | Preflight fails closed |
| M17-21 | User takeover before dispatch | Model action paused; fresh consent required |
| M17-22 | Click target disabled | Preflight rejects |
| M17-23 | Focus moves to another app | Preflight rejects; no global click |
| M17-24 | Successful focus/activate | Typed postcondition verified |
| M17-25 | Successful non-sensitive type | Value class/hash verified; no raw text ledger |
| M17-26 | Verification cannot observe result | `unverified`, not success |
| M17-27 | Dispatch timeout | Cancel/interrupt result; no blind retry |
| M17-28 | Retry after target change | Re-observe/revalidate or reject |
| M17-29 | Stop during dispatch | Worker cancellation and ledger `cancelled` |
| M17-30 | Revoke during dispatch | IPC/grant invalidated; no further action |
| M17-31 | Worker crash | Interrupted action; recovery shown |
| M17-32 | Ledger unavailable before action | Action waits/unavailable |
| M17-33 | Ledger failure after observation | Incomplete evidence disclosed |
| M17-34 | Transactional rollback | Verified rollback receipt |
| M17-35 | Compensation action | Labeled compensation; new approval if required |
| M17-36 | No rollback available | Irreversible warning or rejection |
| M17-37 | File write request | Routed through M11 preview/diff/checkpoint |
| M17-38 | Terminal mutation request | M11 bounded runner/network policy required |
| M17-39 | Email/payment/account mutation | Out of scope or explicit privileged confirmation; no silent send |
| M17-40 | Partial multi-step batch | Exact completed/remaining steps disclosed |
| M17-41 | Retained screenshot request | Explicit scope/retention approval required |
| M17-42 | AX/OCR raw data in EventLedger | Redacted/rejected |
| M17-43 | VoiceOver preview/stop/takeover | All controls reachable and labeled |
| M17-44 | Reduced motion/high contrast/dynamic size | No lost information or clipped approval |
| M17-45 | All permissions denied | Browser remains usable |
| M17-46 | AI unavailable | User-authored typed action/observation paths remain truthful |
| M17-47 | Stale model-generated action | Advisory proposal rejected without user reapproval |
| M17-48 | Wrong project/session binding | Action rejected before dispatch |

## 14. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M17-A | Target identity | App/process/window/element generations and scope tests |
| M17-B | Observation privacy | Redaction, sensitive surface, clipboard, and retention tests |
| M17-C | Typed action boundary | Registry/schema rejects coordinates/scripts/unknown data classes |
| M17-D | Approval binding | Exact action/target/generation/expiry hash and UI evidence |
| M17-E | Preflight race safety | Focus/window/element/permission changes fail closed |
| M17-F | Verification truthfulness | Typed postconditions and unverified result paths |
| M17-G | Stop/revoke | Immediate worker cancellation and grant invalidation |
| M17-H | Rollback honesty | Transactional/compensation/none labels match actual tool capability |
| M17-I | File/terminal boundary | M11 Studio owns workspace mutations |
| M17-J | EventLedger order/redaction | Ordered evidence without secrets/screens/raw scripts |
| M17-K | Accessibility/degraded mode | VoiceOver, keyboard, reduced motion, denied permissions |
| M17-L | Browser-first release gate | One bounded action only after all prior evidence is fresh |

## 15. Implementation order and handoff

Implement M17-A before any OS dispatch. Implement M17-B against the M16 capability manifest and existing ToolRegistry, not a parallel freeform action channel. Implement M17-C before granting any action beyond read-only observation. Implement M17-D only after preflight and ledger ordering are testable. M17-E must prove stale-target, stop/revoke, sensitive-data, and denial paths before broader workflows are considered.

The next smallest safe implementation slice is **M17-A: pure target identity, observation snapshot, generation, scope, and redaction contracts**. No model training or background process is part of M17.
