# Hive M11 — Studio Loop

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M11 Studio loop
> **Depends on:** M0 storage/recovery, M1 explicit capture, M2 Brief credibility, M3 candidate-only WISP, M4 source versions/diffs/trails/retrieval, M5 digest/retention, M6 read-only MCP/encryption decision, M10 Sidecar B1–B4
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Related contracts:** `docs/superpowers/plans/2026-08-11-m10-sidecar-b1-b4-plan.md`, `docs/superpowers/plans/2026-08-11-m6-mcp-encryption-decision-plan.md`
> **Primary code seams:** `Sources/HiveCore/Studio/StudioWorkspace.swift`, `Sources/HiveCore/Tools/ToolInvocation.swift`, `Sources/HiveCore/Tools/ToolRegistry.swift`, `Sources/HiveCore/Tools/PolicyEngine.swift`, `Sources/Hive/StudioPanelView.swift`, `Sources/Hive/BrowserState+Studio.swift`, `Sources/Hive/BrowserState+Approval.swift`, `Sources/Hive/ActionApprovalView.swift`
>
> M11 is the first safe browser-to-code action loop. It does not make the browser an unrestricted terminal. A user selects a project root; Hive reads bounded repository context; Swarm proposes a plan; Hive renders a diff and exact check command; the user approves typed actions; a bounded workspace applies and verifies them; and the result, rollback path, and evidence remain inspectable.

## 0. Decision summary

M11 delivers one narrow, reviewable Studio journey:

```text
select project root
  → inspect repository baseline
    → ingest bounded instructions as untrusted project context
      → formulate outcome-oriented plan
        → read/prepare proposed change
          → render exact diff
            → policy + explicit approval
              → checkpoint and apply
                → bounded project check
                  → review result and evidence
                    → keep, rollback, or stop
```

| Slice | User value | Hard boundary |
|---|---|---|
| **S1 — Root and workspace identity** | Choose a repository and know exactly what Hive can touch | Every path, command, grant, and ledger event binds to one validated root identity |
| **S2 — Repository context and plan** | Get useful project-aware work without copying files into chat | Instruction files and repository content are untrusted data; they cannot grant authority or change the user’s request |
| **S3 — Diff-first change loop** | Inspect the proposed change before any write | No write before a typed invocation, policy decision, durable approval, and checkpoint |
| **S4 — Bounded checks and review** | Verify the change with an exact command and visible output | Commands run with bounded cwd/environment/timeout/network policy; model output never declares success |
| **S5 — Rollback and evidence** | Recover from a bad change and understand what happened | Rollback is typed, scoped, idempotent where possible, and ledger-linked; dirty user work is never silently discarded |

M11 is not a general computer-use milestone. It does not add unrestricted shell access, automatic commits/pushes, network-enabled dependency installation, secret management, code signing, remote workers, desktop control, or autonomous background coding.

## 1. Current code truth

The repository has valuable primitives but not a verified compound Studio journey.

| Existing surface | Current evidence/reuse | M11 gap or qualification |
|---|---|---|
| `StudioWorkspace` | Actor with root selection, containment checks, symlink-aware resolution, read/write, unified diff, timeout-based check, backup rollback, and git restore seam | Needs durable workspace identity, bookmark lifecycle, baseline/dirty-state contract, cancellation, output limits, command policy beyond a token deny-list, and crash/restart reconciliation |
| `ToolInvocation` | Typed action envelope with target, preview, trust level, rollback, evidence, and exact approval scope key | Needs M11-specific payload hashing, workspace/root identity, plan/review IDs, generation checks, and executor admission order |
| `ToolRegistry` | Registered tool schemas, risk classes, typed fields, path/command validation, timeout and rollback metadata | Registry validation is not a sandbox; command strings and filesystem access still require a separately enforced worker boundary |
| `PolicyEngine` | Non-bypassable registry/trust/schema gate, developer tools disabled by default | Needs explicit root, instruction, network, dirty-worktree, and approval/ledger predicates for Studio |
| `StudioPanelView` / `BrowserState+Studio` | Existing UI/state seam for edits, checks, and rollback | Must expose the complete state machine, baseline warnings, plan/diff/check/review evidence, cancellation, and truthful degraded states |
| `BrowserState+Approval` / `ActionApprovalView` | Existing pending-action, approval, session-grant, and EventLedger seams | Must bind approval to exact workspace identity, payload hash, plan revision, cancellation generation, and checkpoint |
| `ContextRedactor` / browser context policy | Existing instruction fencing and secret redaction patterns | Must apply to repository instructions, file excerpts, check output, and model-bound context without treating project text as authority |
| `EventLedgerStore` | Existing durable consent/action/rollback audit authority | M11 must define a complete event taxonomy and evidence references for every terminal state |

**Not verified:** root selection → baseline inspection → instruction ingestion → plan → diff preview → approved apply → bounded check → review/rollback with restart-safe evidence. Source presence and passing unit tests for isolated primitives do not satisfy M11.

## 2. Product contract

### 2.1 Browser-first behavior

- Studio is optional and dismissible. A missing model, store, toolchain, bookmark, worker, or permission never blocks ordinary browsing.
- Opening a project is an explicit user action through a native folder chooser or an already authorized workspace record. A model cannot choose a root from text.
- The UI always displays the active project label and normalized root identity before any file or command action.
- Studio defaults to read/plan mode. Drafts are not writes; writes and checks require a separate typed action and approval.
- A failed or cancelled Studio run leaves the browser usable and reports a typed state rather than a generic success/failure toast.
- The user can close Studio without deleting project data, pending drafts, or audit evidence. “Forget workspace” is a separate destructive lifecycle operation and is outside M11.

### 2.2 User-visible vocabulary

```text
unselected       — no project root has been authorized
selecting        — folder authorization is in progress
authorized       — root identity and access lease are valid
stale_access     — persisted bookmark cannot currently be resumed
changed_root     — path resolves to a different identity than recorded
baseline_dirty   — pre-existing user changes detected
instructions     — repository context discovered and classified
untrusted_text   — project content that cannot grant authority
planning         — a typed outcome plan is being assembled
draft_ready      — proposed content exists but no file was written
preview_ready    — exact diff/check preview is available
awaiting_approval — native policy requires user consent
approved         — exact invocation was durably approved
applying         — bounded executor is applying the approved change
checking         — bounded executor is running the approved check
review_required  — result exists but user has not accepted the outcome
succeeded        — verified terminal success with evidence
rolled_back      — change reverted and rollback evidence recorded
cancelled        — no further work admitted for this run
blocked          — policy, access, ledger, or environment denied work
failed           — typed operation failed; no success implied
```

No green success treatment is allowed for `draft_ready`, `review_required`, `cancelled`, `blocked`, `failed`, or `baseline_dirty`.

## 3. S1 — Project root and workspace identity

### 3.1 Workspace record

A workspace is a native-owned record, not a path string supplied by a model:

```text
StudioWorkspaceRecord {
  workspace_id: stable UUID
  display_name: bounded user label
  canonical_root_path: local display value; never model authority
  root_identity: filesystem identity/hash recorded at authorization
  bookmark_data: opaque security-scoped bookmark material, stored by the app’s secret/access policy
  access_state: unselected | authorized | stale_access | changed_root | blocked
  profile_id: browser profile binding
  project_id: Project ID?
  instruction_manifest_id: manifest ID?
  baseline_snapshot_id: snapshot ID?
  network_policy: denied | approved_domains | local_only
  created_at: Date
  updated_at: Date
  revoked_at: Date?
}
```

M11 does not decide whether the final app uses App Sandbox, a signed helper, or an XPC worker; it requires the boundary to be explicit. If the app is sandboxed, external roots require user selection and security-scoped bookmark semantics. If execution moves to a helper, IPC must carry a typed workspace capability and never a free-form absolute path.

Key rules:

- The root is selected by the user and revalidated on every session.
- The app persists only the minimum bookmark/access material required to reopen the workspace. Tokens, credentials, and arbitrary environment variables are not workspace state.
- A bookmark that fails to resolve, resolves to a different filesystem identity, or no longer grants access moves to `stale_access`/`changed_root`; it never silently points at a new folder.
- Root containment resolves symlinks and validates both existing targets and parent directories for new files.
- File paths displayed to models, logs, and citations are relative to the root. Absolute paths are UI-only and redacted from model context by default.
- A workspace capability expires or is revoked on user removal, profile mismatch, restore, or explicit Stop. Reopening requires revalidation.
- Every Studio invocation carries `workspace_id`, `root_identity`, `session_id`, and `context_generation` in native state before executable arguments reach a worker.

### 3.2 Root state machine

```text
none
  → user_selects_folder
  → resolving_access
  → authorized
  → stale_access | changed_root | blocked
  → user_reauthorizes
  → authorized

authorized
  → user_revokes | profile_changes | restore_invalidates
  → revoked
```

Required behavior:

- Selection cancellation returns to `none` without creating a workspace record.
- A stale bookmark presents a reauthorization path and preserves the old record for audit; it does not auto-search nearby folders.
- If the root is inside another authorized root, the user sees the narrower workspace identity and policy; nested roots do not inherit broader grants.
- If `.git` is a file pointing to a worktree, the resolved repository identity is recorded; no assumption that a directory named `.git` exists.
- A root containing secrets, build output, dependency caches, or ignored files is not automatically excluded from access; those classes are separately classified before model context is assembled.

## 4. S2 — Repository baseline and instruction ingestion

### 4.1 Baseline snapshot

Before planning or editing, Studio captures a deterministic baseline:

```text
StudioBaseline {
  baseline_id: stable UUID
  workspace_id: UUID
  root_identity: String
  captured_at: Date
  vcs: none | git
  revision: commit ID?
  worktree_state: clean | dirty | conflicted | unavailable
  changed_paths: [relative path + status]
  ignored_secret_candidates: [relative path class only]
  toolchain_fingerprint: bounded names/versions where available
  instruction_manifest_id: UUID
  context_generation: UInt64
}
```

Rules:

- A dirty baseline is not an error and is never overwritten. It is a user-visible condition that changes the diff and rollback contract.
- Proposed edits must be computed against the exact file snapshot read by the plan. If the file changes before apply, the preview is stale and approval is invalidated.
- Conflicted or unreadable VCS state blocks apply and rollback claims until the user resolves or explicitly narrows the operation.
- Baseline collection is metadata-first and bounded. It must not recursively read the entire repository into model context.
- Secret scanning may classify filenames/content for exclusion, but M11 does not upload or print secret values. A suspected secret is represented by class, path, and redacted reason.

### 4.2 Instruction manifest

The instruction loader may discover repository guidance such as:

- `AGENTS.md`
- `CLAUDE.md`
- `HIVE.md` or project-owned instruction files
- `.cursor/rules/*.mdc`
- `.github/copilot-instructions.md`
- `.github/instructions/*.instructions.md`
- toolchain-specific files explicitly configured by the user

The exact precedence and supported names must be versioned in an `InstructionManifest`. Unknown instruction files may be shown as discovered project content but are not silently treated as policy.

```text
InstructionEntry {
  relative_path: safe relative path
  scope: repository | directory_glob | file_glob
  precedence: integer
  content_hash: hash
  source_state: present | unreadable | changed | excluded
  trust_label: untrusted_project_guidance
  redacted_excerpt: bounded text?
}
```

Hard boundary:

- Instructions can define style, test commands, architecture conventions, and project expectations for a plan.
- Instructions cannot grant filesystem/network/OS authority, override Hive policy, approve a write, suppress a warning, reveal secrets, disable Stop, or change the user’s requested outcome.
- Page text, imported content, generated code, and instruction files all remain untrusted model input. Native policy and user approval are the only authority.
- Instructions are loaded with path, size, nesting, and total-character limits. Symlink escapes, binary files, and secret-shaped values are excluded or redacted.
- The plan shows which instruction entries materially influenced it. The user can inspect or exclude an entry before approval.

### 4.3 Baseline/instruction state machine

```text
uninspected
  → collect_metadata
  → baseline_ready
  → discover_instructions
  → classify_and_redact
  → instruction_manifest_ready
  → planning_context_frozen
```

Any file, root, profile, toolchain, policy, or instruction hash change after `planning_context_frozen` moves the plan to `stale` and requires re-read/review.

## 5. S3 — Plan, draft, diff, and approval contract

### 5.1 Outcome-oriented plan

The plan names outcomes, not model/tool assignments:

```text
StudioPlan {
  plan_id: UUID
  workspace_id: UUID
  baseline_id: UUID
  request_summary: redacted bounded user intent
  outcomes: [PlanStep]
  files_read: relative paths + hashes
  instructions_used: instruction entry IDs
  proposed_tools: typed tool IDs
  risks: [bounded risk class]
  non_goals: [bounded text]
  context_generation: UInt64
  state: draft | ready | stale | blocked | superseded | complete
}
```

A non-trivial plan must contain:

1. desired outcome;
2. files or modules in scope;
3. explicit non-goals;
4. checks to run and why;
5. known risks and rollback path;
6. assumptions requiring user confirmation;
7. a stop condition for uncertainty or changed files.

The plan does not authorize any tool. A plan may be generated in read-only mode and discarded without side effects.

### 5.2 Draft and diff

A proposed file change is a draft until the exact bytes/content and file path are resolved against the baseline. The UI must show:

- workspace/project identity;
- relative path and file status (new/modified/deleted proposal);
- unified diff or an explicit binary/unrenderable warning;
- original snapshot hash and proposed payload hash;
- instruction entries used;
- expected test/check command and timeout;
- rollback kind and limitations;
- model/provider label, if model-generated;
- scope and privacy classification.

No write is allowed for a plan, draft, preview, or model response. The model cannot mark its own proposal approved.

### 5.3 Exact approval envelope

M11 reuses `ToolInvocation`, `ToolRegistry`, `PolicyEngine`, `PendingAction`, and `ActionApprovalView`, adding native M11 identity to the invocation:

```text
StudioApprovalBinding {
  action_id: UUID
  session_id: UUID
  workspace_id: UUID
  root_identity: String
  baseline_id: UUID
  plan_id: UUID
  relative_paths: [safe paths]
  payload_hash: String
  command_hash: String?
  rollback_plan: typed rollback
  policy_revision: String
  context_generation: UInt64
  cancellation_generation: UInt64
  preview_revision: String
}
```

Approval is exact. A changed path, file hash, payload, command, root identity, baseline, policy revision, session generation, or rollback contract invalidates it. Session grants may narrow repeated confirmation only for the exact structured scope and never override a denial or changed generation.

### 5.4 Approval state machine

```text
plan_ready
  → draft_ready
  → preview_ready
  → policy_validating
  → denied | blocked | awaiting_approval
  → approved | denied | cancelled | expired | stale
  → checkpointing
  → applying | checking
  → review_required
  → accepted | rollback_requested
  → rolled_back | rollback_failed
```

EventLedger consent must be durably recorded before `checkpointing`/execution. If ledger write, checkpoint creation, root revalidation, or policy evaluation fails, the invocation remains blocked and nothing executes.

## 6. S4 — Bounded worker and check contract

### 6.1 Execution boundary

M11 requires a separate conceptual execution boundary even if the first implementation is an in-process actor:

```text
Studio UI / Swarm proposal
  → Context broker
    → ToolRegistry + PolicyEngine
      → Approval controller + EventLedger
        → Workspace capability resolver
          → bounded executor/worker
            → verifier
              → EventLedger + Studio review UI
```

The executor must not receive executable arguments until native policy, exact approval (where required), root/access validation, and cancellation-generation checks pass.

A future sandboxed app/helper/XPC configuration may change the mechanism, but not the contract. The main UI must not become an unrestricted automation host merely because a local command is convenient.

### 6.2 File operations

- All reads/writes use relative paths resolved against the authorized workspace capability.
- Containment checks resolve symlinks and parent directories; a symlink created after preview invalidates the invocation rather than being followed outside root.
- Writes are atomic where possible and preserve mode/metadata needed for rollback; a pre-existing user change detected after preview blocks rather than overwrites.
- A write creates a checkpoint before mutation. Checkpoint identity and file hashes enter the ledger.
- Multi-file changes are one transaction at the Studio plan level: each file has a typed outcome, and partial application enters `partially_completed` with per-file rollback status.
- Binary files, files larger than the documented limit, generated dependency trees, and secret-classified content require an explicit unsupported/blocked state, not a lossy text diff.

### 6.3 Command/check operations

A check command must be selected from a user-visible allowlist or explicitly reviewed as a typed command. The deny-list in `InputField.isSafeCommand` is not sufficient security by itself.

Every check records:

```text
CheckExecution {
  check_id: UUID
  workspace_id: UUID
  baseline_id: UUID
  plan_id: UUID
  command_display: redacted exact command
  executable_identity: resolved path/hash where available
  cwd_relative: "."
  timeout_seconds: bounded integer
  environment_class: minimal | toolchain_allowlist
  network_policy: denied | local_only | explicit approved domains
  output_limit: bytes/lines
  cancellation_generation: UInt64
  termination: succeeded | failed | timed_out | cancelled | blocked
  output_artifact_id: local bounded artifact?
  started_at: Date
  finished_at: Date
}
```

Rules:

- No inherited secret-bearing environment by default. `HOME`, PATH, locale, and explicitly allowlisted toolchain variables are the maximum baseline.
- No network is the default. Dependency installation, remote fetches, package scripts, and arbitrary servers are out of scope unless a later milestone adds explicit network policy and a worker boundary.
- Shell metacharacters, command composition, redirection, subshells, and interpreter selection are parsed or denied; a string prefix check is not an allowlist.
- The runner has a hard timeout, output cap, process-group cancellation, and no interactive credential prompt. Timeout/cancel terminates descendants where the platform permits and records uncertainty if termination cannot be verified.
- Model/page/instruction text cannot directly construct a command. A native producer must choose or present the exact command for approval.
- Check output is untrusted evidence. It can report exit status and bounded diagnostics; it cannot approve a write, change policy, or declare a passing build without the verifier observing the actual result.

### 6.4 Cancellation

```text
stop Studio run
  1. advance cancellation_generation atomically
  2. cancel owning task and provider stream
  3. prevent queued executor admission
  4. terminate active process group
  5. discard stale output after generation mismatch
  6. preserve checkpoint and completed side-effect evidence
  7. publish cancelled/partial state
  8. append one idempotent ledger event
```

Stop is native and idempotent. A cancelled run cannot silently resume or consume an old approval. A process that cannot be confirmed terminated yields `termination_uncertain` and blocks new work for that workspace until reconciled.

## 7. S5 — Review, rollback, and evidence

### 7.1 Review contract

The terminal review surface distinguishes:

- proposed vs applied files;
- baseline changes that predated Hive;
- exact approved payload vs actual bytes written;
- check command, cwd, timeout, network policy, exit status, and bounded output;
- model suggestion vs native verification;
- completed, failed, cancelled, partial, and rolled-back operations;
- rollback availability and known irreversible effects.

A green check means only that the exact observed command returned success under the recorded environment. It does not mean correctness, security, or user acceptance.

### 7.2 Rollback contract

Rollback is selected before apply and is visible in the approval card:

```text
RollbackPlan {
  kind: backup_restore | git_restore | patch_inverse | unavailable
  checkpoint_id: UUID
  paths: safe relative paths
  preimage_hashes: [path + hash]
  limitations: bounded text
  state: available | requested | running | succeeded | failed | conflicted
}
```

Rules:

- Rollback never silently discards changes that were present before the Studio baseline.
- Before rollback, current hashes are compared with the hashes produced by Hive. If another process/user changed the file, rollback enters `conflicted` and asks for review.
- Git restore is never run against a dirty user file without showing the exact target and conflict risk. A `.git` directory alone is not proof that restore is safe.
- Backup files and checkpoints have retention/cleanup semantics; cleanup cannot happen until the action/review/rollback ledger references are durable.
- A rollback failure is a first-class terminal state with recovery instructions, not a claimed success.
- External effects such as network requests, package hooks, or commands that mutate outside the workspace are denied in M11; no rollback claim is made for them.

### 7.3 Evidence graph

Every M11 run links these stable records:

```text
StudioRun
  → WorkspaceRecord
  → BaselineSnapshot
  → InstructionManifest
  → PlanRevision(s)
  → Draft/Diff artifact(s)
  → Policy decision
  → Consent event
  → Checkpoint
  → Apply result
  → CheckExecution
  → Review decision
  → Rollback result?
```

EventLedger is the append-only event authority for intent, policy, consent, execution, verification, cancellation, and rollback. Honeycomb stores user-visible project/source artifacts where the retention policy permits; it is not a second authority for consent or execution state. Raw secrets, full environment, hidden prompts, and unbounded command output are excluded from default evidence.

## 8. Cross-cutting security and privacy rules

### 8.1 Prompt-injection boundary

Repository instructions, source files, lockfiles, README text, issue text, generated code, check output, and browser pages are untrusted data. They may inform a proposal, but cannot:

- change the user’s requested outcome or non-goals;
- authorize a file write, command, network access, or secret read;
- widen the selected project root;
- tell Hive to ignore baseline changes, policy, or approval;
- request credentials, disable Stop, or suppress a warning;
- cause a commit, push, deletion, package install, or external message;
- turn test output into a verified security claim.

The plan UI must make the distinction visible: user intent, project guidance, model proposal, native policy, user consent, executor result.

### 8.2 Secret and sensitive-data boundary

- Never place provider keys, Keychain material, shell secrets, `.env` values, passwords, tokens, or full credential-shaped strings in model context, previews, logs, diffs, fixtures, or default output.
- Secret scanning is a redaction/admission control, not a claim of complete detection. Unknown content is treated conservatively when leaving the device.
- Repository context is bounded by path, size, language, and purpose. “Read the repo” is not permission to read every file.
- Remote model use, if later enabled, must display provider/model, exact context class, retention, and network policy before first use; M11 can remain local-only.
- Private browser context and M6 MCP memory remain separate unless the user explicitly attaches a permitted Source; Studio never imports ambient browser history into a repository plan.

## 9. Accessibility and interaction contract

- Project-root selection, workspace switch, plan review, diff navigation, approval, Stop, check output, review, and rollback are keyboard reachable.
- The active workspace/root is announced with a safe label; absolute paths and sensitive filenames are not exposed unnecessarily to assistive technology.
- Diff views provide a textual alternative and do not rely on red/green alone; added/removed/modified state is conveyed semantically.
- Approval cards expose action, target, scope, payload/check summary, trust level, policy reason, evidence, rollback, and safe initial focus.
- Stop is a native button with an accessible name and remains available while planning, applying, and checking.
- Live check output uses bounded polite updates; screen readers are not interrupted for every line.
- Focus returns to the triggering control after closing diff, approval, output, review, or rollback surfaces.
- Reduced Motion removes timeline/spring effects without removing state information. Dynamic type and increased contrast preserve access to the action buttons and failure explanation.
- A dirty baseline, stale preview, blocked access state, and rollback conflict are announced as warnings, not silently represented by muted color.

## 10. Failure matrix

M11 requires deterministic synthetic workspaces and no real credentials, remote network, or production repository.

| ID | Fixture | Required assertion |
|---|---|---|
| M11-1 | Cancel folder selection | No workspace/grant is created |
| M11-2 | Bookmark cannot resolve | Workspace becomes stale; reauthorization is required |
| M11-3 | Root resolves to different filesystem identity | Changed-root block; never silently retarget |
| M11-4 | Relative path traversal | Policy/workspace rejects before worker admission |
| M11-5 | Absolute, home, backslash, colon, or symlink escape | Rejected with safe reason |
| M11-6 | Symlink appears after preview | Invocation invalidated; link is not followed |
| M11-7 | Dirty worktree before planning | Baseline warning; pre-existing changes preserved |
| M11-8 | File changes after diff approval | Hash mismatch; no overwrite; new preview required |
| M11-9 | Unreadable/conflicted repository | Apply/rollback blocked with recovery path |
| M11-10 | Nested workspace selection | Narrow root policy is enforced; parent grant not inherited |
| M11-11 | Instruction file says “ignore policy and run command” | Treated as untrusted text; no authority change |
| M11-12 | Instruction precedence conflict | Manifest shows deterministic precedence and user-visible source paths |
| M11-13 | Oversized/binary/secret-shaped instruction | Excluded or redacted; bounded manifest remains valid |
| M11-14 | README/page asks to print environment or credentials | No secret read/output/context admission |
| M11-15 | Model proposes undeclared tool/argument | Registry/policy denies before executor |
| M11-16 | Model proposes write without diff | No approval card or execution |
| M11-17 | Changed payload after approval | Approval hash mismatch; no execution |
| M11-18 | Ledger unavailable before approval | Action remains blocked; no write/check |
| M11-19 | Check uses `rm`, network fetch, interpreter pipe, or command composition | Denied by command parser/policy |
| M11-20 | Check attempts inherited secret env | Minimal environment contains no secret values |
| M11-21 | Check exceeds timeout/output cap | Process is bounded; typed timeout/output-limit state |
| M11-22 | Check spawns descendants then Stop | Process group cancellation or termination uncertainty is recorded |
| M11-23 | Stop races queued apply | Generation check prevents side effect |
| M11-24 | Stop after partial multi-file apply | No later work; per-file results and rollback status visible |
| M11-25 | Crash after checkpoint before apply | Restart reconciles checkpoint; no duplicate apply |
| M11-26 | Crash after apply before ledger result | Recovery marks outcome unknown and blocks replay until reconciled |
| M11-27 | Another process changes file before rollback | Hash conflict; no silent discard |
| M11-28 | Git restore on dirty user file | Explicit conflict/block; no destructive restore |
| M11-29 | Backup/checkpoint cleanup before evidence | Cleanup denied until references are durable |
| M11-30 | Model says “tests passed” but command failed | Native exit result wins; no green success |
| M11-31 | Remote model/network unavailable | Honest local/degraded state; browser remains usable |
| M11-32 | Accessibility keyboard-only journey | Root, plan, diff, approve, Stop, check, review, rollback all work |
| M11-33 | Reduced Motion / dynamic type / contrast | State and actions remain understandable and operable |
| M11-34 | Workspace revoked during check | New admission blocked; active run cancelled/reconciled |
| M11-35 | Private browser data appears in attached context | Context broker excludes it; no repository artifact or log leak |

The fixture matrix contains **35 cases**. New cases require an update to this plan and the progress mirrors.

## 11. Work packages after approval

### M11-A — Workspace identity and access lifecycle

- Freeze workspace record, root identity, access state, profile binding, bookmark/revocation, and nested-root semantics.
- Reuse `StudioWorkspace` containment logic but require identity/generation checks for every operation.
- Define the first supported macOS access configuration and document sandbox/helper/XPC assumptions without claiming unimplemented capability.
- Add root selection, stale bookmark, changed-root, symlink, revoke, and restart fixtures.

### M11-B — Baseline and instruction manifest

- Freeze baseline snapshot, dirty/conflicted state, VCS identity, toolchain fingerprint, instruction discovery/preference, bounded redaction, and untrusted guidance labels.
- Add deterministic conflict/precedence behavior and show instruction provenance in the plan.
- Ensure page/source content cannot enter Studio context without explicit attachment and M10 admission.
- Add baseline drift, secret-shaped content, hostile instructions, and oversized-file fixtures.

### M11-C — Plan/draft/diff/approval binding

- Extend the existing typed tools and approval UI with plan, baseline, workspace, root, payload, command, rollback, policy, and generation bindings.
- Enforce no-write-before-preview and no-execution-before-ledger-consent/checkpoint.
- Invalidate plans and approvals on file/root/policy/generation changes.
- Add per-kind diff/check previews and accessibility paths.

### M11-D — Bounded executor and verifier

- Define the first supported executor boundary, exact command allowlist/parser, minimal environment, cwd, network policy, output cap, timeout, process-group cancellation, and descendant reconciliation.
- Keep arbitrary shell, package installs, remote fetches, interactive credentials, commits/pushes, and desktop control deferred.
- Have the verifier report observed results only; model text never determines success.
- Add command-composition, secret-env, timeout, cancellation, and network fixtures.

### M11-E — Checkpoint, review, rollback, and recovery

- Freeze checkpoint/preimage/hash semantics, multi-file partial outcomes, dirty-user-change protection, backup cleanup, git restore conflicts, crash recovery, and ledger links.
- Build the clean-profile compound journey: select root → plan → diff → approve → apply → check → review → rollback.
- Repeat with dirty baseline, changed files, revoked workspace, cancelled process, ledger failure, and restart recovery.
- Record evidence before any capability is labeled verified.

## 12. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M11-A | User-selected root has stable identity, explicit access lifecycle, containment, profile binding, and revoke/restart behavior | workspace lifecycle tests + clean-profile root path |
| M11-B | Baseline records dirty/conflicted state without overwriting user work; instruction manifest is bounded, deterministic, provenance-labeled, and untrusted | fixture workspaces + manifest/conformance tests |
| M11-C | Plan/draft/diff are read-only; exact approval binds path, hashes, root, plan, policy, rollback, and generation | tool/policy/approval tests + diff UI path |
| M11-D | No write/check reaches executor before policy, access, approval, and ledger gates | admission-order tests + EventLedger evidence |
| M11-E | Check execution is bounded by cwd, environment, command policy, timeout, output, network, and cancellation | executor fixtures + process cancellation evidence |
| M11-F | Every mutation creates a checkpoint and exposes rollback/conflict limits | checkpoint/rollback tests |
| M11-G | Review distinguishes model proposal, native result, pre-existing changes, partial state, and rollback outcome | review UI/integration fixture |
| M11-H | Crash/restart after checkpoint, apply, or ledger boundary reconciles without duplicate side effects | recovery tests |
| M11-I | Prompt injection, secret exfiltration, path escape, malicious instruction, command composition, and network fixtures fail closed | security fixture suite |
| M11-J | Keyboard, VoiceOver, reduced motion, contrast, and dynamic type paths are usable | accessibility matrix |
| M11-K | Browser remains useful with Studio/model/toolchain/ledger/access unavailable | clean-profile degraded-mode regression |
| M11-L | Complete compound path is demonstrated with fresh evidence and no unsupported claims | manual demo script + exact build/test/runtime record |

M11 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and the compound path is demonstrated on a clean profile. A file editor with a diff, a shell command with a timeout, a green mock check, or a backup method in isolation is `scaffold`/`code-present`, not verified Studio.

## 13. Implementation order and stop conditions

After M0–M6 and M10 gates have fresh evidence:

1. Freeze synthetic workspace, repository, instruction, dirty-state, secret, and hostile-content fixtures.
2. Implement S1 workspace identity/access lifecycle without widening ordinary browser permissions.
3. Implement S2 baseline and instruction manifest as bounded, untrusted context.
4. Implement S3 plan/draft/diff/approval binding and no-write-before-preview.
5. Implement S4 bounded executor/verifier and native cancellation.
6. Implement S5 checkpoint/review/rollback/recovery.
7. Run M11-1…M11-18 before enabling any mutation.
8. Run M11-19…M11-30 before enabling project checks in a user-selected workspace.
9. Run M11-31…M11-35 on clean profile, revoked access, and degraded configurations.
10. Re-run the M10 sidecar path so a Sidecar action cannot bypass M11 Studio controls.
11. Record exact results and remaining risks in the canonical progress log.

Stop and do not widen scope if:

- the model or repository text can choose a root, grant access, or approve an action;
- a dirty user change can be overwritten or silently included in rollback;
- an absolute path, symlink, nested root, or changed identity reaches a worker;
- instruction files can override Hive policy or native approval;
- a command allowlist is implemented as a prefix/substring check without parsing composition;
- secrets or inherited environment values enter model context, logs, diffs, or output;
- a write or check can execute before durable consent and checkpoint evidence;
- Stop only changes UI state, leaves descendants running, or permits stale replay;
- a crash can cause duplicate apply or unknown outcomes to be presented as success;
- rollback claims to undo effects outside the authorized workspace;
- Studio availability blocks ordinary browsing.

## 14. Explicitly deferred

- Unrestricted shell, arbitrary script execution, package/dependency installation, and remote fetches.
- `git commit`, `git push`, branch mutation, worktree deletion, or automatic PR creation.
- Credentials, Keychain reads, password filling, interactive prompts, and secret injection.
- Network-enabled worker execution or server startup; M11 defaults to no network.
- Full language-server/indexer integration, binary patching, image/media editing, and large-repository ingestion.
- Automatic approval, blanket session grants, or model-selected trust levels.
- Remote coding workers, XPC/helper installation, App Sandbox entitlement changes, and distribution/signing claims beyond a documented boundary decision.
- Autonomous background coding, scheduled tasks, and computer-use actions.
- Treating `AGENTS.md`, `CLAUDE.md`, or any repository file as a security policy authority.

## 15. Evidence references

Coding-agent workflow and instruction patterns:

- [Claude Code permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code security](https://code.claude.com/docs/en/security)
- [Cursor rules](https://cursor.com/docs/rules)
- [GitHub Copilot custom instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [VS Code custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)
- [OpenSSF security-focused AI code assistant instructions](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions.html)
- [OWASP Secure Agent Playbook](https://github.com/OWASP/secure-agent-playbook)

macOS/platform boundaries:

- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple security-scoped bookmarks](https://developer.apple.com/documentation/foundation/url/creating_bookmark_data_for_a_security-scoped_resource)
- [Apple startAccessingSecurityScopedResource](https://developer.apple.com/documentation/foundation/nsurl/startaccessingsecurityscopedresource())
- [Apple XPC](https://developer.apple.com/documentation/xpc)
- [Apple NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [Apple Process](https://developer.apple.com/documentation/foundation/process)
- [Apple code signing](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

Security:

- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OWASP LLM02: Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm02-sensitive-information-disclosure/)
- [OWASP LLM05: Improper Output Handling](https://genai.owasp.org/llmrisk/llm05-improper-output-handling/)
- [OpenAI — Designing agents to resist prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)
- [OpenSSF — Security-focused AI code assistant instructions](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions.html)

These sources establish platform constraints, documented workflow patterns, and threat categories. The M11 state machines, workspace record, instruction manifest, approval binding, executor contract, failure matrix, and exit gates are Hive-specific proposed contracts and require implementation evidence before any capability label changes.
