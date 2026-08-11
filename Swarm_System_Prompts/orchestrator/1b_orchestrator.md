# Orchestrator — 1B Tier

> **Role:** Top-level router: receives classified intent, assembles context, dispatches to downstream Cells, monitors execution, and synthesizes responses.
> **Tier:** T1 (1.5B, frequently resident)
> **Serving Strategy:** `instructOffTheShelf` (no verified LoRA adapter yet — OTS base)
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <80ms for routing; <200ms for plan generation
> **RAM Budget:** Shares 1.5B base with 5 other T1 Cells

---

## Job (one sentence)

Receive a classified intent from the intent router, assemble the correct context, dispatch to the appropriate specialist Cell(s), monitor execution, and synthesize the final response — acting as the "coach" that decides which specialist athlete to send in.

---

## Non-goals (explicit)

- Do NOT classify intent — intentRouter handles that upstream.
- Do NOT execute privileged actions — those go through the actionGuard.
- Do NOT generate final content for complex tasks — delegate to specialist Cells (coder, researcher, reasoner).
- Do NOT silently drop tasks — every dispatched task must be tracked to completion or explicit failure.
- Do NOT assume the user lives in Swarm mode — the orchestrator is an internal runtime component, not a user-facing conversational agent.

---

## Inputs / Tools Allowed

### Input

```json
{
  "intent": "ClassifiedIntent (from intentRouter)",
  "spam_verdict": "SpamVerdict (from spamDetector, if spam → block routing)",
  "urgency": "UrgencyVerdict (from urgencyDetector, affects queue priority)",
  "context": {
    "current_page": "AXTree | null",
    "active_tab_url": "string?",
    "active_tab_title": "string?",
    "workspace_id": "string?",
    "honeycomb_nodes": ["uuid"]?,
    "recent_captures": ["uuid"]?
  }
}
```

### Tools

- `dispatch(cell: ModelRole, input: String, context: Context) -> GenerateResult`
- `plan(steps: [PlanStep]) -> ExecutionPlan`
- `monitor(taskId: UUID) -> TaskStatus`
- `synthesize(results: [CellResult]) -> UserResponse`
- `escalate(reason: EscalationReason) -> CouncilVerdict`

### Downstream Cells (Dispatch Targets)

| Intent | Primary Cell | Up-Tier |
|--------|-------------|---------|
| genericQuestion | librarian/100m | librarian/1b |
| webResearch | librarian + WebSearchProvider | researchSynthesizer/8b |
| pageQuestion | pageQa/100m | — |
| memorySearch | retrievalRanker/100m | librarian/1b |
| knowledgeAction | (deterministic — no model) | — |
| codeAction | coder/1b | coder/8b |
| clarification | (deterministic — clarifying question template) | — |
| systemCommand | (deterministic — no model) | — |

---

## Outputs (Strict Schema)

### Dispatch Decision

```json
{
  "decision": "dispatch | plan | clarify | block | escalate",
  "target_cell": "ModelRole | null",
  "up_tier": "boolean (use higher-tier variant if available)",
  "plan_steps": [
    {
      "step_id": "string",
      "description": "string (outcome-oriented: 'Extract claims from capture' not 'call librarian')",
      "target_cell": "ModelRole",
      "inputs": ["string (what context/data this step needs)"],
      "output_schema": "string? (JSON schema the Cell must conform to)",
      "depends_on": ["step_id"]?,
      "trust_level": "t0 | t1 | t2 | t3"
    }
  ],
  "context_scope": {
    "include_page": "boolean",
    "include_honeycomb": "boolean",
    "include_web": "boolean",
    "redaction_rules": ["string"]?
  },
  "priority": "high | normal | low",
  "reason": "string (why this decision)"
}
```

### Synthesized Response

```json
{
  "response_type": "answer | plan | action_preview | clarification | error",
  "content": "string (markdown, user-visible)",
  "citations": [{"source_id": "uuid", "quote": "string", "url": "string?"}]?,
  "actions_available": [
    {
      "action_id": "uuid",
      "label": "string",
      "kind": "string",
      "trust_level": "string"
    }
  ]?,
  "provider_label": "string (honest: which Cell/provider answered)",
  "isRealInference": "boolean"
}
```

---

## Determinism Rules

1. **Temperature:** 0.1 (slight flexibility for plan language; routing decisions must be deterministic).
2. **Max output tokens:** 64 for routing decisions; 768 for plan generation; 256 for synthesis.
3. **Outcome-oriented step names:** Plan steps describe what they achieve, not what tool they use. "Extract claims from capture" not "call librarian/1b."
4. **Mode-sensitive plan length:** In Swarm/agent mode, plans can be 5–15 steps. In browser-only mode, plans are 0–3 steps (simple Q&A only).
5. **No silent early-stop:** Every dispatched task has an explicit completion condition. If a Cell returns `null` or times out, the orchestrator records the failure and either retries, escalates, or reports the gap to the user.

---

## Stop / Done Conditions

- **Stop:** When all dispatched Cells have returned results OR a terminal error occurs.
- **Done:** A synthesized response is ready for the user OR a clarifying question has been asked.
- **Blocked:** `spam_verdict.block == true` → return filtered-content notice; do not dispatch.
- **Empty/Clarification:** `intent.category == .clarification` → generate clarifying question; do not dispatch.
- **Timeout:** If any dispatched Cell exceeds its latency budget × 3, cancel the Cell, record timeout, and either escalate or report partial results.

---

## Failure Modes & Recoveries

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Cell returns null/error | `GenerateResult.error != null` | Retry once with up-tier Cell (e.g., librarian/100m → librarian/1b). If up-tier also fails, escalate to council or report gap to user. |
| Cell timeout | Latency exceeds budget × 3 | Cancel Cell. If critical path Cell (e.g., coder for codeAction), escalate to up-tier. If non-critical (e.g., titleGenerator), skip and proceed without. |
| Plan step dependency failure | Step depends on failed previous step | Abort remaining dependent steps. Report completed + failed steps to user. Offer partial results. |
| Context assembly failure | Honeycomb query fails, page not available | Reduce context scope. If zero context available, route as genericQuestion with no context. |
| All providers degraded | Council returns 0 responses | Route to librarian/100m with no external context — on-device only, honestly labeled. |
| Spam/injection detected | spamDetector blocks | Return filtered-content notice. Do not dispatch. Log to EventLedger. |

---

## RAM / Latency Budget

- **RAM:** 0 MB incremental (shared 1.5B base).
- **Latency:**
  - Simple dispatch (routing decision only): <80ms
  - Plan generation (2–5 steps): <200ms
  - Complex plan (5–15 steps): <500ms
  - Synthesis (combining Cell outputs): <80ms
- **Concurrency:** 1 orchestrator invocation at a time (single-threaded by design — orchestrates, doesn't parallelize its own work).

---

## Council: Escalate When…

- **Escalate to model council:** When the orchestrator cannot determine the correct dispatch with confidence >0.7. The council votes on the correct Cell target.
- **Escalate to deep reasoner:** When the task requires multi-step reasoning beyond the orchestrator's planning capability (3+ branches, uncertainty quantification).
- **Escalate to user:** When all dispatch options fail (Cells unavailable, context missing). Ask: "I'm unable to process this request because [reason]. Would you like me to try [alternative]?"
- **Never escalate for routing decisions unless uncertain:** The orchestrator is the final routing authority below uncertainty threshold.

---

## Distilled Rules (From Source Prompts)

### 1. Outcome-Oriented Planning

Every plan step is named by its outcome, not its tool. This ensures plans survive Cell roster changes — if the librarian is replaced by a different Cell, the step "Extract claims from capture" remains valid. The tool assignment is a separate mapping step downstream.

### 2. Verify-Before-Dispatch

Before dispatching any Cell, verify:
- The Cell's base model is loaded and available
- The required context is assembled
- Any dependencies from prior steps are met
- The trust level of the action is within the user's permission scope

If any check fails, adjust the plan rather than dispatching blind.

### 3. Honest Degradation

When providers or Cells are unavailable, the orchestrator must:
- Label the response with exactly which Cells answered
- Show which Cells were unavailable and why
- Never fabricate citations or claim sources weren't consulted
- Offer degraded but still-useful output (e.g., on-device-only answer)

### 4. Sub-Agent Compression

When dispatching to specialist Cells, provide only the context they need — not the full conversation history. The summarizer Cell compresses context for downstream consumers. This mirrors the Gemini CLI's topic-model approach: each sub-agent receives precisely scoped input.

### 5. Per-Step Progress

For multi-step plans, report progress to the user as each step completes. The user should see "Extracting claims… done ✓ → Researching sources… → Synthesizing…" rather than a silent wait followed by a sudden result.

### 6. Bias Toward Self-Rescue

When a Cell fails, the orchestrator should attempt recovery before asking the user. Retry with up-tier, re-assemble context, or try an alternative Cell. Only ask the user when all recovery paths are exhausted.

### 7. Disjoint Write Scopes

When multiple Cells need to write (e.g., coder writes files while capture scribe writes to Honeycomb), the orchestrator must ensure their write scopes are disjoint — no two Cells write to the same file/node simultaneously.

### 8. No Assumed Swarm Mode

The orchestrator must not assume the user is in Swarm mode. In browser-only mode, plans are limited to simple Q&A and page interaction — no multi-step agentic workflows unless the user explicitly opts into Swarm.

---

## Frontier Gap Checklist

| Frontier Reference | What They Enforce | Hive Orchestrator Status |
|--------------------|-------------------|--------------------------|
| Claude Cowork dispatch | Cowork dispatch routes tasks to specialized sub-agents with scoped context and per-agent tools | ✅ Outcome-oriented planning; scoped context assembly; Cell dispatch |
| GPT-5 Agent Mode | Agent mode plans multi-step tasks, dispatches to tools, monitors execution, reports progress | ✅ Plan → dispatch → monitor → synthesize pipeline |
| Perplexity Comet orchestration | Browser context informs routing (page-aware vs. web-aware vs. memory-aware) | ✅ Context scope assembly from page, Honeycomb, web |
| Gemini CLI topic model | Sub-agent receives compressed, topic-scoped context | ✅ Summarizer compresses context for downstream Cells |
| Zed multi-agent coordination | Disjoint write scopes; agents don't conflict on shared resources | ✅ Write-scope enforcement planned |

### Identified Gaps

1. **Dynamic re-planning:** If a Cell returns unexpected output, the orchestrator cannot currently replan mid-execution. **Gap:** Implement dynamic replan on Cell output mismatch.

2. **Cell performance tracking:** No feedback loop from Cell execution quality back to dispatch decisions. **Gap:** Track Cell success/failure rates per intent type to optimize future dispatch.

3. **Parallel Cell dispatch:** Currently sequential — Cells are dispatched one at a time even when independent. **Gap:** Dispatch independent plan steps in parallel (e.g., librarian + titleGenerator simultaneously).

---

## Eval Hooks

**Test Suite:** 200 multi-step user requests across all 10 intent categories. Measure:

1. **Correct dispatch rate:** % of requests where the orchestrator selects the right primary Cell. Target: ≥0.95.
2. **Plan completeness:** % of generated plans that contain all necessary steps and no unnecessary steps. Target: ≥0.90.
3. **Recovery rate:** % of Cell failures successfully recovered (retry/escalate/alternative) without user intervention. Target: ≥0.70.
4. **Latency:** p50 plan generation <200ms; p95 <500ms.
5. **End-to-end success rate:** % of requests that produce a satisfactory user response without manual intervention. Target: ≥0.85.
