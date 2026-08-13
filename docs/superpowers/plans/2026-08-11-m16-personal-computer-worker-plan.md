# M16 — Personal Computer Worker & Permission Center Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M6 local-agent/encryption decision, M10 Sidecar scope/approval, M11 Studio bounded execution, M12 Command Center receipts, M15 browser credibility.
> **Scope:** privilege boundary, capability grants, permission UX, worker lifecycle, and safe observation/action contracts. Desktop action coverage is deliberately narrow and staged.

## 1. Goal

M16 gives Hive a trustworthy path to optional personal-computer capabilities without turning the browser process into an unbounded automation host. A user can inspect what the Worker is, which capabilities it has, why a capability is requested, what scope it covers, how to deny/revoke it, and whether a worker session is stopped. The system remains useful when every privileged permission is denied.

M16 is a security and trust milestone first. It does not claim full computer-use parity merely because `ComputerUse`, AppleScript, Accessibility, ScreenCaptureKit, or a helper process exists in source.

## 2. Non-goals and explicit deferrals

M16 does not ship unrestricted desktop control, arbitrary AppleScript, root privileges, silent screen recording, broad OCR history, background surveillance, password-manager control, payment/send/publish actions, or permission bypasses. It does not make the Worker a model authority.

Deferred to later, separately gated work:

- broad desktop observation and multi-app navigation;
- arbitrary click/type/screenshot loops;
- autonomous email, messaging, purchase, account, or financial actions;
- password, card, banking, health, private-message, and authentication surfaces;
- LaunchDaemon/root helper, kernel extensions, input injection beyond approved Accessibility primitives;
- cloud-hosted computer use or remote screen streaming;
- connector mutation and enterprise fleet policy beyond documented TCC behavior.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository contains a signed `ResearchWorkerClient` with process spawning, protocol/version handshakes, code-signature checks, timeout handling, capped pipe draining, and reaping. It contains typed `ToolRegistry`, `ToolInvocation`, `PolicyEngine`, trust levels, browser/site permission policies, `EventLedgerStore`, cancellation/generation tokens, and file/terminal abstractions. Direct native AXUIElement, ScreenCaptureKit, and Apple Events bridges are not proven as an end-to-end personal-computer capability.

### 3.2 Required privilege boundary

```text
Hive Browser.app
  Browser UI, context broker, Permission Center, approval controller
  No unrestricted shell, Accessibility driver, screen stream, or Apple Events authority

Hive Worker
  Optional signed helper or XPC service
  Typed capability adapters, bounded sessions, no model-selected permissions

EventLedger
  Durable intent, grant, policy, approval, action, result, stop, revoke, and recovery evidence
```

The worker is not trusted because a model asked for it. It is trusted only for the narrowly granted capability, target scope, generation, and lifetime represented by a signed/validated grant.

### 3.3 Authority table

| Concern | Authority | M16 rule |
|---|---|---|
| User intent | Browser UI/Command Center | Page/OCR/model content cannot rewrite it. |
| Capability policy | PolicyEngine/ActionLadder | Worker never self-approves or escalates. |
| OS permission state | Permission Center querying system APIs | Explain denied/unknown separately; never infer granted from a prior grant. |
| Worker identity | Signed bundle, protocol handshake, version/capability manifest | Reject unexpected path, signature, protocol, or manifest. |
| File scope | M11 workspace/security-scoped bookmark | No path outside selected scope; resolve symlinks and enforce containment. |
| Screen scope | explicit display/window/app target | No global capture by default; no screenshot retention by default. |
| Apple Events scope | explicit target application + typed event | No freeform script text from a model/page. |
| Action approval | M10/M11 controller | Approval binds exact action, target, generation, preview, and expiry. |
| Evidence | EventLedger | Store IDs, classes, hashes, summaries, and redacted metadata—not secrets/screens by default. |
| Stop/revoke | Browser-owned controller | Revocation is immediate, idempotent, and cannot be vetoed by a worker. |

## 4. Capability and grant model

### 4.1 Capability classes

M16 recognizes separate grants:

```text
worker.connect
file.read(scope)
file.write(scope)
terminal.execute(scope, commandPolicy)
accessibility.observe(targetApp/window)
accessibility.act(targetApp/window, actionSet)
screen.observe(targetDisplay/window/app, retentionPolicy)
appleEvents.send(targetApp, eventSet)
network.connect(domainSet, purpose)
clipboard.read/write(scope)
```

Each grant has:

```text
grant_id, capability, target_scope, data_scope, purpose
issued_at, expires_at, session_id, project_id
worker_identity_hash, protocol_version, policy_version
user_consent, approval_receipt, revocation_generation
retention_class, redaction_policy, status
```

No grant is wildcard by default. `screen.observe` is not `accessibility.observe`; `file.read` is not `file.write`; observing an app is not acting in it; and browser page access is not OS-app access.

### 4.2 Grant lifecycle

```text
requested → disclosed → user_approved → active
requested → denied
active → expired | revoked | worker_disconnected | policy_invalidated
```

A grant is valid only when the system permission, worker identity, scope, policy version, session, and revocation generation all match. A stale approval must be rejected after a target, action, scope, worker, or policy change.

### 4.3 Permission Center

The Permission Center must show, per capability:

- plain-language purpose;
- system permission state and how macOS controls it;
- requested Hive scope and target app/window/display;
- data captured, retention, and remote-model eligibility;
- current sessions and expiry;
- last use/result class;
- deny, revoke, pause, and “open System Settings” paths;
- degraded behavior when denied.

The UI must never imply that clicking a Hive button can grant Accessibility, Screen Recording, Automation, or file access. It can check state, explain the next step, and deep-link to an appropriate System Settings pane where supported.

## 5. Worker identity, installation, and IPC

### 5.1 Install/admission

Before connection:

1. locate the worker only within the signed app/resource bundle or explicitly approved installation path;
2. verify code signature/designated requirement and executable identity hash;
3. verify protocol version and capability manifest;
4. reject unexpected extra capabilities or downgrade attempts;
5. establish a per-session nonce and revocation generation;
6. record install/connection result without raw environment secrets.

The Worker must not start merely because a page asks for it. Installation is separate from first use; each capability is separately consented.

### 5.2 Typed IPC

IPC messages are versioned, length-bounded, schema-validated, and typed. A request includes grant ID, session ID, action ID, target scope, input hash/summary, timeout, and cancellation generation. A response includes result class, output schema, redaction status, verification, and ledger correlation.

Reject:

- arbitrary executable strings where a typed operation exists;
- paths outside the selected root/bookmark scope;
- target app/window IDs not in the grant;
- stale or reused action IDs;
- oversized payloads, malformed frames, protocol downgrade, and unknown action kinds;
- worker claims of approval or permission state.

### 5.3 Process lifecycle

The browser owns connect, pause, stop, revoke, timeout, crash, and restart. On stop/revoke it closes the IPC channel, cancels in-flight work, invalidates grants, releases security-scoped resources, and terminates/reaps the helper according to a bounded graceful-then-force policy. A worker that ignores stop cannot retain an active grant.

## 6. Observation contract

### 6.1 Accessibility observation

Observation is limited to an approved target application/window and an allowlisted attribute set. AX trees are untrusted input and may contain prompt injection, secrets, or stale UI. The adapter must include target identity, observation generation, timestamp, permission state, and redaction result. It must not silently widen from one window to an entire desktop.

### 6.2 Screen observation

ScreenCaptureKit use is opt-in and target-scoped. Prefer one approved window/app/display over global capture. Frames are transient evidence by default: process in memory, redact/drop sensitive surfaces, and retain only typed text/facts or a user-approved artifact. If the target changes, capture pauses and asks again. Permission denial yields a normal degraded mode.

### 6.3 Sensitive surfaces

The default deny list includes password managers, banking/payment, health, authentication/2FA, private messaging, private browser windows, and any user-added bundle/domain/window. “Not on the deny list” is not proof that a surface is safe; explicit target scope and user consent remain required.

Sensitive input takeover pauses observation and model context. Passwords, payment cards, access tokens, private keys, and credential-shaped strings are never stored in the default ledger or prompt context.

## 7. Action contract and trust ladder

M16 establishes the boundary; later milestones may add narrow actions. The only allowed action classes are typed and policy-gated:

| Trust | Examples | M16 behavior |
|---|---|---|
| T0 Observe | query approved AX metadata, inspect worker status | Allowed within active grant. |
| T1 Suggest | propose a click target or file read | No external effect. |
| T2 Assist | prepare an unsent local draft or preview | User-selected scope; reversible. |
| T3 Act | approved file write, approved navigation, bounded terminal check | Per-action preview/approval and ledger record. |
| T4 Privileged | Accessibility act, Apple Event, external app mutation | Disabled by default; explicit per-action consent. |
| T5 Developer | destructive delete, arbitrary script, system configuration | Not enabled by M16. |

No freeform AppleScript, shell, keystroke sequence, or model-generated coordinate list crosses the boundary. Typed adapters may internally use platform APIs, but the model receives/produces only structured action schemas.

Each action preview binds:

```text
action_id, grant_id, session_id, target identity, action kind/parameters
before-state summary, intended effect, risk class, expiry, rollback/stop behavior
```

Execution revalidates the binding immediately before the worker receives executable arguments. A target change, screen change, focus change, stale generation, or policy change invalidates the preview.

## 8. EventLedger and privacy contract

Required ordered evidence:

```text
intent → scope_requested → permission_state_checked → policy_decision
→ user_consent/denial → worker_dispatch → result/verification
→ stop/revoke/rollback/recovery
```

The ledger records stable IDs, timestamps, actor/session/project, capability/risk class, policy version, result class, hashes, and redacted summaries. It does not store screenshots, OCR dumps, raw AppleScript, secrets, full clipboard values, or unconstrained page text by default.

Ledger failure must not silently convert a privileged action into an unlogged action. The policy determines whether an action waits, becomes unavailable, or can complete only as a clearly disclosed non-consequential operation.

## 9. File and terminal boundaries

File access uses a user-selected project root or security-scoped bookmark, canonical path containment, symlink escape checks, file-size/type limits, and read/write separation. Bookmark access is balanced for every use. Terminal execution reuses M11’s bounded runner: explicit command policy, working directory, environment allowlist, timeout, output cap, network default-deny, cancellation, and checkpoint/rollback where mutation occurs.

The Worker must not receive the user’s entire home directory, environment, Keychain, browser profile, or clipboard by implication.

## 10. Stop, revoke, and recovery

### 10.1 Stop

A visible stop control must be available during every active worker session. Stop is local, immediate, idempotent, and does not require model cooperation. It cancels queued and in-flight operations, closes streams, pauses observation, invalidates action generations, and leaves the user at a stable browser state.

### 10.2 Revoke

Revocation invalidates all grants for the selected capability/session/project according to the user’s chosen scope. It disconnects the worker, removes active security-scoped access, stops screen streams, invalidates AX/Apple Event adapters, and prevents automatic regrant. Re-enabling requires fresh disclosure and consent.

### 10.3 Failure recovery

If the worker crashes, the browser marks active operations interrupted, revokes their grants, and shows retry/restart—not success. If the browser crashes, the next launch treats grants as expired unless a durable session contract explicitly says otherwise. If a permission is later withdrawn, all dependent actions become unavailable and no repeated prompt loop occurs.

## 11. Work packages

### M16-A — Worker identity and capability manifest

Define signed worker admission, protocol/version handshake, capability manifest, per-session nonce, grant IDs, revocation generations, bounded IPC, and process lifecycle. Reuse `ResearchWorkerClient` hardening where applicable without assuming research-worker semantics are sufficient for OS control.

**Done when:** an unexpected/unsigned/mismatched worker cannot connect, capabilities cannot be added by the worker, and stop/revoke reliably closes the channel and reaps the process.

### M16-B — Permission Center and TCC state disclosure

Define capability cards, system-state checks, just-in-time request UX, denial/degraded states, System Settings guidance, expiry/revoke controls, and privacy/data-retention explanations for Accessibility, Screen Recording, Automation, files, terminal, clipboard, and network.

**Done when:** every privileged capability has a user-readable request, deny, revoke, and degraded path; the UI never claims to grant TCC permission itself.

### M16-C — Scope-bound observation adapters

Add only approved-window/app/display observation contracts, sensitive-surface deny/redaction, transient frame handling, AX generation checks, and target-change pause behavior. Keep screen text and screenshots out of durable storage by default.

**Done when:** observation cannot widen scope, capture denied/private surfaces, or continue after target/permission/revocation changes.

### M16-D — Typed action ladder and approval binding

Map typed file/terminal/browser/Accessibility/Apple Event actions to M10/M11 policy and approvals. Add exact target/generation binding, preflight revalidation, stop behavior, rollback/irreversibility disclosure, and EventLedger ordering.

**Done when:** no model/page/OCR content can issue freeform privileged execution and every enabled T3/T4 action has preview, consent, result, and recovery evidence.

### M16-E — Integrated Permission Center/Worker validation

Run clean-profile, permission-denied, worker-crash, revoke-during-action, target-change, sensitive-surface, cancellation, and browser-first degraded-mode paths. Validate signing, IPC, ledger redaction, no-secret handling, accessibility, reduced motion, and dynamic sizing.

**Done when:** a user can install/connect, grant one scoped capability, observe or perform one bounded approved action, stop/revoke it, inspect evidence, and continue browsing with all privileged capabilities denied.

## 12. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M16-01 | Worker missing | Connection unavailable; browser remains usable |
| M16-02 | Worker wrong path | Rejected before launch |
| M16-03 | Invalid signature/designated requirement | Rejected and logged as admission failure |
| M16-04 | Protocol mismatch | Rejected without capability use |
| M16-05 | Manifest advertises undeclared capability | Reject manifest; no implicit grant |
| M16-06 | Capability downgrade/upgrade attempt | Session invalidated |
| M16-07 | Malformed/oversized IPC frame | Bounded rejection; worker remains untrusted |
| M16-08 | Reused/stale action ID | Rejected idempotently |
| M16-09 | Accessibility permission unknown | Explain/check path; no observation |
| M16-10 | Accessibility denied | Degraded state; no retry loop |
| M16-11 | Screen Recording denied | No frame/OCR; normal browsing continues |
| M16-12 | Automation denied | No Apple Event; typed recovery shown |
| M16-13 | File scope not granted | No read/write; user-select path shown |
| M16-14 | Security-scoped bookmark stale | Reauthorization path; no guessed path |
| M16-15 | Terminal network denied | Command unavailable or bounded failure |
| M16-16 | Global home-directory request | Rejected as overbroad |
| M16-17 | Accessibility target changes | Observation pauses and requires revalidation |
| M16-18 | Screen target changes | Stream pauses; no silent global capture |
| M16-19 | Password-manager/banking window | Capture/OCR dropped and action paused |
| M16-20 | Private browser window | No default observation, capture, or durable context |
| M16-21 | Credential-shaped OCR text | Redacted before prompt/ledger/storage |
| M16-22 | Hidden prompt injection in OCR/web text | Classified as untrusted data; no action change |
| M16-23 | Model proposes freeform AppleScript | Rejected; typed adapter required |
| M16-24 | Model proposes shell command | Routed through M11 bounded policy or rejected |
| M16-25 | T3 file write | Exact preview, approval, scope, diff, and ledger required |
| M16-26 | T4 external-app action | Disabled by default; explicit per-action consent |
| M16-27 | Target focus changes before action | Approval invalidated |
| M16-28 | Grant expires before dispatch | Rejected; fresh grant required |
| M16-29 | Revoke during observation | Stream stops and grant invalidates |
| M16-30 | Stop during action | Cancellation/termination path; no false success |
| M16-31 | Worker crash during action | Interrupted result; retry/recovery shown |
| M16-32 | Browser crash with active grants | Grants expire on restart unless explicitly reconsented |
| M16-33 | XPC invalidation | Operations stop; resources released |
| M16-34 | Helper ignores graceful stop | Bounded force termination and ledger result |
| M16-35 | Ledger unavailable before privileged action | Action waits/unavailable; no unlogged mutation |
| M16-36 | Ledger write failure after non-consequential read | Disclosed degraded evidence state |
| M16-37 | Screenshot retention request | Requires explicit retention/target consent |
| M16-38 | Clipboard read request | Separate grant; sensitive-value redaction |
| M16-39 | Network domain outside grant | Egress rejected |
| M16-40 | Symlink escapes project root | File action rejected |
| M16-41 | Action rollback unavailable | Preview labels irreversible; elevated confirmation or reject |
| M16-42 | Worker reconnect after revoke | Rejected until fresh consent |
| M16-43 | Permission Center VoiceOver path | State, purpose, scope, deny/revoke controls exposed |
| M16-44 | Reduced motion/high contrast/dynamic size | No information depends on animation or clipped cards |
| M16-45 | AI/model unavailable | Permission and browser controls remain complete |
| M16-46 | All TCC permissions denied | Ordinary browsing and local read-only features remain usable |

## 13. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M16-A | Worker admission | Signature, path, protocol, manifest, nonce, and version tests |
| M16-B | Capability grants | Typed scope, expiry, session, and revocation-generation fixtures |
| M16-C | Permission Center truthfulness | Granted/denied/unknown/degraded UX and System Settings guidance |
| M16-D | OS boundary isolation | No main-process unbounded AX/screen/Apple Events/shell path |
| M16-E | Observation minimization | Target-scoped capture, sensitive filtering, transient retention tests |
| M16-F | Typed actions | No freeform privileged scripts or model-selected permissions |
| M16-G | Approval binding | Exact target/action/generation/preview/expiry revalidation |
| M16-H | Stop/revoke | Immediate, idempotent cancellation and worker teardown |
| M16-I | EventLedger ordering | Intent→grant→policy→consent→dispatch→result→revoke evidence |
| M16-J | Failure recovery | Worker/browser crash, permission withdrawal, stale bookmark, and retry paths |
| M16-K | Accessibility | VoiceOver, focus, keyboard, contrast, reduced motion, dynamic size |
| M16-L | Browser-first degraded mode | Clean profile remains useful with worker and permissions denied |

## 14. Implementation order and handoff

Implement M16-A before any OS observation or action. Implement M16-B before prompting for TCC permissions. Implement M16-C only for narrow target-scoped observation. Implement M16-D only after grant/approval/ledger ordering is testable. M16-E must prove denial and stop paths before any broader desktop capability is considered.

The next smallest safe implementation slice is **M16-A: signed worker admission and typed capability manifest**, reusing the existing `ResearchWorkerClient` hardening while keeping research-fetch privileges separate from OS-control privileges. No model training or background process is part of M16.
