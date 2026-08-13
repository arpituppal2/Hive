# Action Guard — T0 (Rule-Based)

> **Role:** Gatekeeper of every privileged action in the Hive Swarm runtime.
> **Tier:** T0 rule-based. No model, no weights. Deterministic.
> **Serving Strategy:** `ruleBased` — instant evaluation, always resident.
> **Base Model:** — (no weights)
> **Latency Target:** <1ms
> **RAM Budget:** 0 MB (pure logic, no model)

---

## Job (one sentence)

Evaluate every proposed action against the trust-level ladder and return `allow` / `confirm` / `deny` before the action reaches any tool executor.

---

## Non-goals (explicit)

- Do NOT decide WHAT action to take — only evaluate whether a PROPOSED action is safe.
- Do NOT generate content, plans, or reasoning — this is a binary gate.
- Do NOT call any model for decisions — this is deterministic rules.
- Do NOT log or persist data — the EventLedger handles auditing.
- Do NOT bypass for any role, including the orchestrator — rules are absolute.

---

## Inputs / Tools Allowed

### Input

```json
{
  "action_id": "uuid",
  "kind": "file.write | file.read | terminal.exec | browser.navigate | browser.click | browser.type | os.applescript | os.accessibility | connector.sync | connector.mutate | honeycomb.write | honeycomb.delete | code.test | code.diff | brief.create | task.create | permission.grant",
  "target": {
    "workspace_id": "uuid?",
    "path": "string?",
    "domain": "string?",
    "connector": "string?"
  },
  "trust_level": "t0 | t1 | t2 | t3 | t4 | t5",
  "requires_confirmation": "boolean",
  "preview": {
    "diff": "string?",
    "summary": "string?",
    "affected_files": ["string"]?,
    "is_reversible": "boolean"
  },
  "evidence": ["source:uuid"]?,
  "context": {
    "user_scope": "string",
    "session_type": "normal | private",
    "workspace": "string?"
  },
  "rollback": {
    "kind": "git.restore | file.backup | honeycomb.undo | none",
    "available": "boolean"
  }
}
```

### Tools

- `guard.evaluate(action: ActionProposal) -> GuardVerdict`
- `guard.allowedTrustLevels -> [TrustLevel]` (for UI display)
- `guard.policyExplanation(level: TrustLevel) -> String`

---

## Outputs (Strict Schema)

```json
{
  "verdict": "allow | confirm | deny",
  "reason": "string (human-readable, max 200 chars)",
  "rule_id": "string (stable rule identifier for auditing)",
  "trust_level_required": "t0 | t1 | t2 | t3 | t4 | t5",
  "confirmation_prompt": "string? (only when verdict == confirm — the exact text shown to the user)",
  "deny_explanation": "string? (only when verdict == deny — why this action cannot be performed)",
  "escalation": "none | council | user | system_admin"
}
```

---

## Determinism Rules

1. **Temperature:** N/A (no model)
2. **Output discipline:** Same input MUST produce same verdict every time.
3. **Rule precedence:** More specific rules override general rules.
4. **Default deny:** Any action kind not explicitly allowed by a rule is DENIED.
5. **No time-based decisions:** Rules must not depend on time of day, session age, or request count.
6. **No context window inspection:** Rules only evaluate the structured `ActionProposal`, not raw chat content.

---

## Trust Level Ladder

| Level | Label | Scope | Default Policy | Confirmation |
|-------|-------|-------|----------------|--------------|
| T0 | Observe | Read current tab metadata, local graph query | ALLOW within approved scope | None |
| T1 | Suggest | Draft a brief, propose a task, generate a plan | ALLOW, clearly marked as proposal | None |
| T2 | Assist | Create unsent file draft, local task draft | ALLOW only in user-selected workspace | Implicit (reversible) |
| T3 | Act | Apply file diff, run project test, navigate browser tab | CONFIRM per action or session rule | Explicit per action |
| T4 | Privileged | Send message, modify account, Accessibility control | CONFIRM per action + EventLedger | Explicit + event recorded |
| T5 | Developer | Irreversible delete, system config, destructive cmd | CONFIRM with dedicated dialog | Dedicated, no model self-approval |

---

## Stop / Done Conditions

- **Stop:** Immediately upon producing a verdict. No further evaluation needed.
- **Done:** `verdict` field is populated; `rule_id` references the specific rule that triggered.
- **Timeout:** Not applicable — rule evaluation is <1ms.
- **Error state:** If the action proposal is malformed (missing `kind`, invalid `trust_level`), return `{ "verdict": "deny", "reason": "Malformed action proposal", "rule_id": "GATE-000" }`.

---

## Failure Modes & Recoveries

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Unknown action kind | `kind` not in known list | DENY with rule GATE-001 (unknown action kind). Log to EventLedger. |
| Missing trust_level | `trust_level` is null | DENY with rule GATE-002 (action must declare trust level). |
| Trust level mismatch | `kind` requires T3 but declared T1 | DENY with rule GATE-003 (insufficient trust level declared). |
| Irreversible action without rollback | `rollback.available == false` and `kind` is destructive | CONFIRM with double confirmation prompt, even at T3. |
| Private session write attempt | `session_type == "private"` and action mutates persistent storage | DENY with rule GATE-004 (private sessions must not persist). |
| Out-of-workspace file access | `target.path` outside `target.workspace_id` scope | DENY with rule GATE-005 (workspace boundary violation). |

---

## RAM / Latency Budget

- **RAM:** 0 MB (deterministic logic, no model weights loaded).
- **Latency:** <1ms per evaluation. Must not block the main thread; evaluate on a background queue.
- **Concurrency:** Unlimited — stateless pure function. Can evaluate thousands of proposals simultaneously.
- **Memory pressure behavior:** No effect — zero memory footprint.

---

## Council: Escalate When…

- **Escalate to council:** NEVER. The action guard is the final authority — council votes cannot override a DENY verdict.
- **Escalate to user (CONFIRM):** When confidence in allow/deny is below 0.9 OR the action is T4+.
- **Escalate to system admin:** When a T5 action is attempted (requires out-of-band admin approval).
- **Override by orchestrator:** NOT ALLOWED. The action guard's DENY is absolute. The orchestrator can only re-propose with a different trust level or additional constraints.

---

## Distilled Rules (From Source Prompts)

### T0 Observe — Always Allowed Within Scope

```
Rule GATE-T0-001: Read-only metadata access
  Action kinds: ["honeycomb.read", "browser.metadata", "tab.info"]
  Conditions: within approved scope
  Verdict: ALLOW
  Confirmation: none

Rule GATE-T0-002: Local graph query
  Action kinds: ["honeycomb.query"]
  Conditions: read-only, no mutation
  Verdict: ALLOW
  Confirmation: none
```

### T1 Suggest — Allow, Marked as Proposal

```
Rule GATE-T1-001: Generate draft content
  Action kinds: ["brief.create", "task.create", "code.diff"]
  Conditions: output is marked as proposal, not auto-applied
  Verdict: ALLOW
  Confirmation: none (proposal is advisory only)

Rule GATE-T1-002: Plan generation
  Action kinds: ["plan.create"]
  Conditions: execution NOT included — plan only
  Verdict: ALLOW
  Confirmation: none
```

### T2 Assist — Allow in User Workspace

```
Rule GATE-T2-001: File draft creation
  Action kinds: ["file.write"]
  Conditions: target within user-selected workspace; file does not exist (no overwrite); preview shows full diff
  Verdict: ALLOW
  Confirmation: implicit (file is a draft; user can discard)

Rule GATE-T2-002: Task draft creation
  Action kinds: ["task.create"]
  Conditions: within user workspace
  Verdict: ALLOW
  Confirmation: none (task is editable)
```

### T3 Act — Confirm Per Action

```
Rule GATE-T3-001: File modification
  Action kinds: ["file.write", "file.delete"]
  Conditions: target within workspace; rollback available (git or backup); preview shows full diff
  Verdict: CONFIRM
  Confirmation prompt: "Apply this change to {path}? ({diff_summary})"

Rule GATE-T3-002: Test execution
  Action kinds: ["code.test", "terminal.exec"]
  Conditions: command is bounded (timeout, no network by default); workspace-scoped
  Verdict: CONFIRM
  Confirmation prompt: "Run {command}? Output will be shown."

Rule GATE-T3-003: Browser navigation
  Action kinds: ["browser.navigate"]
  Conditions: URL is valid; domain is not in user's blocklist
  Verdict: ALLOW (navigation is reversible)
  Confirmation: none

Rule GATE-T3-004: Browser interaction (click, type)
  Action kinds: ["browser.click", "browser.type"]
  Conditions: element identified by stable ref; not a form submission with credentials
  Verdict: CONFIRM
  Confirmation prompt: "Click '{element_name}' on {domain}?"

Rule GATE-T3-005: Browser form submission
  Action kinds: ["browser.submit"]
  Conditions: form data preview shown; no password fields populated; user confirmed
  Verdict: CONFIRM with extra warning
  Confirmation prompt: "Submit this form on {domain}? The data will be sent to the website."
```

### T4 Privileged — Confirm + EventLedger

```
Rule GATE-T4-001: Message/email send
  Action kinds: ["connector.send", "email.send"]
  Conditions: preview shown; recipient confirmed; no mass-send; EventLedger records
  Verdict: CONFIRM
  Confirmation prompt: "Send this message to {recipient}? This action cannot be undone."

Rule GATE-T4-002: Account modification
  Action kinds: ["connector.mutate"]
  Conditions: specific change shown; account scoped; EventLedger records
  Verdict: CONFIRM
  Confirmation prompt: "Modify {account} setting: {change}? This will take effect immediately."

Rule GATE-T4-003: Accessibility control
  Action kinds: ["os.accessibility", "os.applescript"]
  Conditions: target app identified; action scoped; not system-level configuration
  Verdict: CONFIRM
  Confirmation prompt: "Control {app} to {action}? Accessibility permission required."

Rule GATE-T4-004: Screen recording
  Action kinds: ["os.screen_capture"]
  Conditions: user explicitly requested; retention policy set (max 5 min); not in private session
  Verdict: CONFIRM with double prompt
  Confirmation prompt: "Capture screen content? Only text will be extracted; screenshots discarded immediately."
```

### T5 Developer — Dedicated Confirmation

```
Rule GATE-T5-001: Irreversible deletion
  Action kinds: ["honeycomb.delete", "file.delete.permanent"]
  Conditions: NOT recoverable from trash; preview of everything to be deleted
  Verdict: CONFIRM with dedicated dialog
  Confirmation prompt: "PERMANENTLY DELETE {count} items? This CANNOT BE UNDONE. Type 'DELETE' to confirm."

Rule GATE-T5-002: System configuration
  Action kinds: ["os.system_config"]
  Conditions: admin password required; change previewed
  Verdict: CONFIRM
  Confirmation prompt: "Modify system setting: {change}? Administrator password will be required."

Rule GATE-T5-003: Destructive command
  Action kinds: ["terminal.exec.destructive"]
  Conditions: command previewed; affects system or outside workspace; no model self-approval
  Verdict: DENY (must be manually run by user)
  Deny explanation: "This command affects system state outside your workspace and cannot be approved automatically."
```

---

## Frontier Gap Checklist

| Frontier Reference | What They Enforce | Hive Action Guard Status |
|--------------------|-------------------|--------------------------|
| Claude Code security model | Read-only exploration treated differently from edits; no silent file writes; explicit confirmation per action class | ✅ T0–T5 ladder with escalating confirmation |
| OpenAI Codex CLI | Approval modes: auto-accept safe operations, ask for edits, deny destructive; run-in-isolation boundary | ✅ Default-deny, T3+ confirmation, workspace boundary enforcement |
| Anthropic computer-use | Confirmation on classifier-detected prompt injection; human-in-the-loop for sensitive actions | ✅ Action guard is pre-model — cannot be socially engineered by model output |
| Anthropic agent security | Constrained tool calls; no unrestricted shell; typed inputs/outputs | ✅ Typed ActionProposal with kind/target/preview/rollback |
| Apple Sandbox | Entitlement-gated; per-capability permissions | ✅ Trust levels map to OS permission model (Accessibility, Screen Recording, etc.) |

### Identified Gaps

1. **Classifier-based injection detection:** Anthropic uses a separate classifier to detect prompt injection in computer-use. Hive's action guard is rule-based, which is stronger (can't be tricked by adversarial inputs), but may miss novel injection patterns that don't match known rules. **Mitigation:** Rule GATE-000 catches malformed proposals; injection attempts that bypass rules would need to produce a well-formed ActionProposal, which is structurally constrained.

2. **Session-scoped T3 allowances:** Claude Code allows session-scoped auto-approval for T3 actions. Hive currently requires per-action confirmation. **Gap:** Planned session-rule feature ("Allow all diffs in this project for 30 min") not yet implemented.

3. **Rollback verification:** No automated verification that rollback actually worked. **Gap:** EventLedger should record rollback result and flag failed rollbacks for human review.

---

## Eval Hooks (How We Measure Punch-Up)

The action guard is rule-based — it doesn't "punch up" against larger models because it isn't a model. Instead, eval measures:

1. **Correctness:** 100% correct verdicts on a test suite of 500 hand-crafted action proposals covering all T0–T5 levels, every action kind, and edge cases (malformed, missing fields, workspace boundary violations, private session mutations).

2. **Latency:** Mean evaluation time <1ms, p99 <5ms on M1 Air 8GB.

3. **False positive rate (over-deny):** <1% of safe T0–T2 actions incorrectly denied. Test: run against 1,000 real user actions from telemetry.

4. **False negative rate (under-deny):** 0% — no T4+ action allowed without confirmation, no T5 action allowed without dedicated dialog. Test: adversarial test suite with 200 T4/T5 proposals designed to trick the guard.

5. **Adversarial resistance:** Run against the prompt-injection test suite from Anthropic's computer-use eval. 0% of injection attempts should bypass DENY for T4+ actions.
