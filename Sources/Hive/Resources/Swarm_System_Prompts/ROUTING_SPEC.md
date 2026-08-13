# ROUTING_SPEC — Hive/Swarm Routing & Escalation Canon

> **Canonical status:** active
> **Created:** 2026-08-11
> **Supersedes:** any ad-hoc routing notes in PITCH/ or docs/
> **Read this before:** touching `ModelManifest.swift`, `Dispatcher.swift`, `ModelStore.swift`, `ram_manager.md`, `orchestrator/Cell_orchestrator.md`, or any Cell's tier selection
> **Companion to:** `MODEL_SPEC.md` (training), `MEMORY_ARCHITECTURE_SPEC.md` (conversation + life memory), `00_INDEX.md` (roster + RAM budget)

## 0. The Thesis

**Deterministic-first, tiny-first, escalate only on evidence.** Hive is a browser that happens to have AI; every request must be answerable by the *smallest, fastest, most honest* Cell that clears the quality bar. The model of record is Apple's tiered escalation: ~85% of intents answered on-device by a small model, ~12% by a heavier tier, ~3% by an external model — with zero fake theater about which tier ran.

The invariant, enforced in code and by `ram_manager.md`:

> **The smallest Cell that clears its confidence threshold IS the answer. Escalation is an evidence-driven exception path, never the default.**

## 1. The Escalation Ladder (7 tiers)

Every request enters at the lowest possible tier and moves up **only** when a trigger in §2 fires. The ladder maps 1:1 onto `ModelManifest.swift` tiers (T0–T3 + rule/fmf/byok) and the `Dispatcher` fallback order (MLX → Apple FMF for narrow roles → honest Mock).

| Tier | Runtime | Footprint (8GB) | TTFT target | Decode target | Example roles |
|---|---|---|---|---|---|
| **T-1 Rule** | Deterministic code (regex/hash/heuristics), zero model | 0 | <1ms | n/a | spam gates, link-score basics, action guard, PII strip, dedupe hashing |
| **T0 100M** | 4-bit distilled classifier | ~0.4–0.6 GB | **<100ms** | 80–120 tok/s | intent router, urgency detector, spam detector, link scorer, retrieval ranker, 100M librarian |
| **T1 1B** | 4-bit distilled instruct | ~1.8–2.2 GB | **150–300ms** | 45–75 tok/s | orchestrator, action planner, summarizer, 1B coder, 1B planner, council chair, 1B librarian |
| **T2 8B** | 4-bit instruct (MoE where available) | ~4.8–5.5 GB | 600ms–1.5s | 15–25 tok/s | deep reasoner, 8B coder, nav reasoner, research synthesizer, 8B auditor/planner |
| **T3 FMF** | Apple Foundation Models | native (ANE) | <500ms | hardware | only the six narrow low-risk roles in `ProviderPolicy`; FORBIDDEN for orchestrator/auditor/planner/coder/research |
| **T4 BYOK** | Remote frontier (opt-in) | 0 loaded | network-bound 50–500ms + TTFT | provider | `byokFrontier` — user-configured, Keychain-gated, council-voted, never load-bearing |

### 1.1 Cohort sharing (the 8GB contract)

Per `ModelManifest.sharedRepo` and `ram_manager.md`: Cells sharing a base model share **one load slot** (all 100M classifiers on one 0.6B-class weight set; summarizer/planner 1B cohort on one 1.7B set). Loading a second cohort unloads the first when RAM pressure requires. Never load two 8B cohorts concurrently on the 8GB floor — the second waits in queue or the request escalates to T3/T4 with the user informed.

### 1.2 Honest unavailability

If a tier's weights are absent (no MLX deps, no FMF capability), the request falls through the `Dispatcher` chain to the honest Mock with `provider == .mock` and `isRealInference == false`. A Mock result is **never** presented as real inference — it carries a visible label (AGENTS.md §4: no false theater).

## 2. Escalation Triggers (evidence-based, exhaustive)

Escalate one tier when ANY fires. The orchestrator logs the trigger in the EventLedger (`route_escalated` event with `from_tier`, `to_tier`, `trigger`).

| # | Trigger | Evidence | Default action |
|---|---|---|---|
| E1 | **Low confidence** | Cell returns `confidence < 0.7` (per `ai-architecture.md`) | Council → next tier |
| E2 | **Ambiguity** | Two intents within δ (route is genuinely ambiguous) | Council vote → next tier |
| E3 | **Complexity** | Input context exceeds the Cell's context budget (§4 of MODEL_SPEC), multi-step plan required, or cross-domain synthesis | Up one tier |
| E4 | **Capability gap** | Manifest declares the role needs a tier (e.g., research synthesizer is T2) | Load that tier directly |
| E5 | **Resource pressure** | RAM < floor, thermal/battery threshold, or UI stall risk (per ram_manager) | Downshift to lighter tier OR defer with explicit queue notice — never degrade silently |
| E6 | **User request** | Explicit "think harder / use the big model / go online" | Honor intent, show what was used |
| E7 | **Verification failure** | Auditor flags the T1 output as unverifiable or contradictory | Re-run at T2 before presenting |

**Anti-escalation rules:**
- A `100m` Cell returning `confidence ≥ 0.9` ends the path. **No council, no escalation** (INDEX §council).
- Do NOT escalate to mask a slow prefill. Stream, show progress, keep the tier.
- Do NOT escalate because a user "sounds smart." Escalation is about the *job*, not the prose.
- The council is an exception path. The common path is the smallest Cell that clears threshold.

## 3. Latency Budgets (per-role SLA)

Measured from request receipt to first streamed token (TTFT) and total completion where noted. These are **acceptance criteria** — the `eval/punch_up_tests.md` suite must assert them on the M1 8GB floor.

| Path | Tier | TTFT SLA | Total SLA | Notes |
|---|---|---|---|---|
| Spam/urgency gate (every request) | T-1/T0 | <100ms | <150ms | The gate short-circuits before any other Cell |
| Intent routing | T0 | <150ms | <200ms | Fires on omnibar submit and page actions |
| Link scoring | T0 | <100ms | <200ms | Batch of ≤10 candidates |
| Orchestration (dispatch a task) | T1 | <300ms | <600ms | Includes plan-map resolution |
| Summarize a page/turn | T1 | <400ms | <2s | Streaming starts by 400ms |
| Action planning (browser) | T1 | <600ms | <3s | DOM context pre-tokenized; prefix cache warm |
| 8B reasoning (deep question) | T2 | <1.5s | streamed | 15–25 tok/s on 4-bit 8B; show progress |
| Research synthesis (full brief) | T2 | 1–2.5s | 2.5–5s | Perplexity-class bar: parallel search first, then synthesize |
| Studio code step | T1/T2 | 200–800ms | 1.5–4s per step | Cursor-class bar; prefix cache on repo context |
| FMF narrow role | T3 | <500ms | streamed | ANE-accelerated |
| BYOK remote | T4 | 50–500ms + provider TTFT | provider | Network-bound; stream everything |

### 3.1 The latency levers (in priority order)

1. **Prefix caching / KV reuse** — system prompts, tool schemas, repo context, and the conversation fresh-tail are cached so TTFT drops 80–90% on repeat paths. This is the single biggest lever on 8GB.
2. **Tier correctness** — routing a 1B job to an 8B model multiplies latency 3–5× for nothing. The router must be *right*, not clever.
3. **Streaming first token** — every T1+ path streams; the UI shows partial structured output (schema-guided JSON per §5) so the first visible token lands inside the SLA even when generation continues.
4. **Batch & parallelize** — link scoring and search-fetch fan out in parallel (Perplexity-class: parallel search before synthesis).
5. **Zero-footprint result cache** — repeat page summaries / quick definitions served from a bounded LRU (encrypted, local) — no re-inference.

## 4. Conversation Routing (how chats route)

A user turn is classified into one of four **scopes** by the intent router. Scope determines context assembly (see `MEMORY_ARCHITECTURE_SPEC.md` for the memory mechanics):

| Scope | Context assembled | Tier floor | Typical latency |
|---|---|---|---|
| **Single-shot** ("what is the capital of…") | Current prompt only | T0/T1 | <300ms |
| **Session** ("continue the summary…") | Fresh-tail (last N turns verbatim) + compacted summary of older turns | T1 | <600ms |
| **Project** ("where were we on the brief…") | Project memory graph (sources, claims, tasks, decisions) + fresh tail | T1/T2 | <1.5s |
| **Life** ("what did I promise last week…") | Hybrid retrieval over Honeycomb (BM25 + embeddings + recency) | T2 | streamed, 2–5s |

Rules:
- Never assemble more context than the Cell's budget (MODEL_SPEC §1.3). Truncate with provenance, not silently.
- Never send raw page text to a remote model because a tab is open — scope must be explicit and user-visible (AGENTS.md §7.2).
- The user can pin a scope (`@tabs`, `@project X`, `@memory`) — pinning overrides the router and is shown as a scope chip (Comet-class scope preview).

## 5. Tool Gating (when tools are allowed)

Tools are typed registry entries (`tool registry` per AGENTS.md §7.4), never parsed from model prose. A request may invoke tools only when ALL hold:

1. The **trust level** (T0–T5) for the action is within the user's current grant (action ladder; §9.3 of AGENTS.md).
2. The **policy engine** evaluates the typed arguments (never the natural-language wrapper).
3. The **approval controller** renders a preview and collects consent for T3+ actions.
4. The **EventLedger** records intent → policy → approval → action → result → rollback.

Routing interacts with tools as follows:
- T0/T1 Cells **may propose** tools (planner proposes the plan); execution always goes through the ladder.
- The **orchestrator** maps steps to Cells AND to tool capabilities; a step names an outcome, not a tool (Claude Cowork lesson: outcome-oriented steps survive roster changes).
- No Cell may grant itself permissions. The rule-actor (`guard/rule_action_guard`) is T-1 deterministic and short-circuits anything outside the grant.

## 6. Streaming & No-Theater Rules

1. **Honest labels:** the response footer (or hover) shows provider + model + `isRealInference`. Mock results are labeled mock. FMF is labeled FMF. BYOK is labeled BYOK.
2. **No fake progress:** no spinner theater for a <100ms T0 path. No "thinking…" animation when the tier is T-1 rule.
3. **Visible escalation:** when a request escalates tiers, the UI shows a one-line reason ("deeper reasoning — using 8B reasoner") with a cancel affordance.
4. **Structured streaming:** T1+ paths stream schema-validated partials (JSON mode) so the UI renders progressively without layout shift.
5. **Cancel everywhere:** every tier, every path, cancellation is honored ≤100ms after the user gesture, and the ledger records it.

## 7. Measurement & Eval Hooks

Every routing decision emits a ledger event with: request_id, scope, route path (tier chain), trigger (if escalated), confidence, TTFT, total latency, token counts, provider labels. The `eval/punch_up_tests.md` suite asserts:

- **Correctness:** per-Cell eval pass rates at each tier (punch-up targets from MODEL_SPEC §0).
- **Latency SLOs:** §3 table, measured on M1 8GB with cold and warm prefix cache.
- **Escalation discipline:** synthetic corpus of easy/hard/ambiguous requests; assert easy ones never escalate (95%+ stay at first-tier-clear) and hard ones always do.
- **Honesty invariant:** `isRealInference` agrees with provider in 100% of cases (already locked by `honestyInvariantHoldsAcrossAllRoles`).
- **RAM invariant:** concurrent loaded params never exceed the ram_manager cap; cohort sharing verified by load-slot accounting.

## 8. What This Means for the User

The user never picks a model. They ask; the router picks the smallest honest answer; if it needs more, they see a one-line reason and a cancel button. The Apple lesson in one sentence: **~85% of life is a small fast answer, ~12% deserves deeper work, ~3% is worth going external — and the user should never have to guess which is happening.**
