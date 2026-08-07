# model_council — control doc

> **Council-family control doc (runtime contract).** Specifies when to convene a council vote, how ties are broken, the tiny-cell-enough threshold, and the composition rules per question type. Referenced by `council/1b_council_chair.md`, `orchestrator/1b_orchestrator.md`, and every Cell's `Council: escalate when…` section.

## Purpose

The model council is the system's confidence-threshold gate. It exists to answer one question: "Is the current Cell + tier sufficient, or do we need a bigger tier / a different specialist / the cloud?" It is convened by the orchestrator when a Cell's confidence drops below 0.7, or when routing is genuinely ambiguous, or when an expensive resource (8B, BYOK) is requested. **The council never overrides the guard.**

## Contract

### 1. When to Convene (Orchestrator Triggers)

The council is convened automatically (by the orchestrator, without user intervention) when:

| Trigger | Signal | Action |
|---------|--------|--------|
| **Low confidence** | A Cell returns `confidence < 0.7` | Convene the relevant panel; vote on escalate vs retry-smaller. |
| **Routing ambiguity** | `intent_router.ambiguous_pairs` is non-empty | Convene routing panel; vote on the most likely route. |
| **8B load requested** | Any Cell returns `escalate:"8b_*"` | Convene size-selection panel; gate the 8B load. |
| **BYOK/cloud requested** | Any Cell returns `escalate:"byok_frontier"` | Convene BYOK panel + require USER opt-in. Single border crossing. |
| **Persistent tie (council itself)** | `council_chair` returns `blocked` after 2+ tie-break rounds | Escalate to `reasoner/8b_deep_reasoner` for advisory vote; chair still decides. If still unresolved → `ask_user`. |

The council is NOT convened when:
- A `100m` Cell returns `confidence ≥ 0.9` — the "tiny Cell is enough" rule: proceed immediately.
- The question is trivial (one-shot factual answer, single bounded edit, simple navigation).
- The user has explicitly bypassed the council (rare, logged).

### 2. Panel Composition by Question Type

| Question type | Voting panel (Cell filenames) | Chair | Notes |
|---------------|-------------------------------|-------|-------|
| **Routing ambiguity** | `router/100m_intent_router` (advisory), `planner/1b_planner`, `council/1b_council_chair` | `1b_council_chair` | The router gets an advisory vote but doesn't dominate — it already flagged the ambiguity. |
| `memory_honeycomb_integrity` | `auditor/1b_auditor`, `auditor/8b_auditor` (if loaded), `council/1b_council_chair` | `1b_council_chair` | The 8B auditor votes if it's already loaded (don't load it just for the council). |
| `action_safety` | `guard/rule_action_guard` (ABSOLUTE VETO), `council/1b_council_chair` | `1b_council_chair` | The guard is NOT a voting member — its veto is absolute and preempts any vote. The council ratifies or rejects PERMITTED actions only. |
| `size_effort_selection` | `council/1b_council_chair`, `planner/1b_planner`, `ram_manager` (headroom query, not a vote) | `1b_council_chair` | The ram_manager provides current headroom as a fact; the planner and chair vote on which tier. |
| `byok_frontier_escalation` | `council/1b_council_chair`, `auditor/1b_auditor` (provenance gate), `orchestrator/1b_orchestrator` | `1b_council_chair` | **USER opt-in required** before any data leaves the device. This is the single border crossing; it is logged in EventLedger. |

### 3. Voting Protocol

1. **Chair convenes the panel** — each panelist receives the question + the relevant evidence.
2. **Each panelist votes** — `{verdict, confidence, rationale}`.
3. **Chair tallies** — the consensus threshold scales with the decision's trust level (AGENTS.md §9.3): T0/T1 decisions → simple majority (≥50% + 1 of non-abstaining voters); T2/T3 decisions → supermajority (≥66%); T4 decisions → unanimity; T5 decisions → always blocked unless the user explicitly overrides. The chair enforces the tier-appropriate threshold.
4. **Tie** → second round with narrowed options. If still tied after 2 rounds → chair decides.
5. **Persistent tie (chair can't decide)** → escalate to `reasoner/8b_deep_reasoner` for a single advisory vote. Chair still owns the final decision.
6. **Verdict is binding on the orchestrator** — but NOT on the guard. The guard's veto is absolute and preempts any council verdict.

> **Tally rule note:** confidence-weighted-sum and expertise-matrix voting (research extracts in `1b_council_chair.md` / pass docs) are NOT adopted as the tally rule. Votes are counted per panelist at the tier-appropriate threshold; confidence informs rationale strength and tie-break criteria only.

### 4. Tie-Break Rules

- **Round 1:** standard vote. If tie, proceed to Round 2.
- **Round 2:** narrowed options (chair eliminates the least-plausible options, presents 2 choices). If still tied, chair decides.
- **Chair decision criteria:** (1) stronger rationale wins, (2) safety-preserving option wins over convenience, (3) cheaper tier wins over expensive tier when rationales are equally strong, (4) on-device wins over cloud.
- **2+ round tie (chair can't decide):** `escalate:"8b_deep_reasoner"` for advisory vote. If the reasoner's vote is clear, chair adopts it. If even the reasoner is uncertain → `action:"ask_user"`.

### 5. Tiny-Cell-Enough Threshold

The "tiny Cell is enough" rule is the council's most important function: **NOT convening.**

- If a `100m` Cell returns `confidence ≥ 0.9` → **no council.** Proceed immediately. This is the common path.
- If a `100m` Cell returns `confidence ≥ 0.7` but < 0.9 → orchestrator weighs: is the task trivial enough that 0.7 confidence is fine? If yes, proceed. If no (the task is safety-relevant or user-facing), convene.
- If a `1b` Cell returns `confidence ≥ 0.7` → **no council for tier escalation.** The 1B is sufficient. Only convene if the 1B explicitly requests escalation or returns `blocked`.
- **The common path should NEVER see the council.** The council is an exception handler, not a workflow step.

### 6. BYOK/Cloud Border Crossing (Single Path)

The cloud border is crossed through exactly ONE path:
1. A Cell returns `escalate:"byok_frontier"`.
2. The council convenes the BYOK panel.
3. The council votes: is this genuinely beyond on-device capability? If no → `action:"retry_smaller"`. If yes → `action:"ask_user"`.
4. **The user is prompted (in chat, the only valid approval channel):** "This task requires a cloud model. [model name, provider, data scope, retention policy]. Send data off-device? [Yes/No]"
5. User confirms → orchestrator dispatches to BYOK runtime. User denies → orchestrator retries at best on-device tier.
6. **Every border crossing is logged in EventLedger:** what data left the device, to which provider, for what purpose, with what user approval.
7. **No silent cloud usage ever.** The user must opt in for every crossing.

### 7. Council Audit Trail

Every council session logs to EventLedger:
- `council_id`, question, question_type, panel composition.
- Each panelist's vote (verdict + confidence + rationale).
- Tie-break rounds (if any).
- Final verdict + action.
- Whether user opt-in was required and whether it was given.

### 8. Cross-References

- `00_INDEX.md` — Council composition rules (the source of truth for panel composition).
- `council/1b_council_chair.md` — The chair Cell that executes this contract.
- `orchestrator/1b_orchestrator.md` — The orchestrator that convenes the council per these triggers.
- `guard/rule_action_guard.md` — The guard, whose veto is absolute and preempts any council verdict.
- `reasoner/8b_deep_reasoner.md` — The reasoner, invoked as a tie-break escalation.
- `router/ram_manager.md` — The ram_manager, consulted for headroom in size-selection votes.

### 9. Invariants (testable)

1. **Council never overrides the guard** — if the guard denies an action, the council's verdict on that action is void.
2. **Council never convenes for `100m` + `confidence ≥ 0.9`** — the tiny-Cell-enough rule is absolute.
3. **Cloud border crossing always requires user opt-in** — zero silent cloud dispatches.
4. **Council verdict is binding on the orchestrator** — the orchestrator may not re-route around a council decision without re-convening.
5. **Council quorum met for every vote** — no panelist missing without a logged reason (Cell unavailable, RAM cap, etc.).
6. **Every council session is logged** — EventLedger audit trail.
7. **Thresholds scale with risk** — T4 votes require unanimity; T5 requires explicit user override; the guard's veto preempts all of them.

### Pass 34 expansion — Additional council protocols from frontier prompts

#### From Claude Cowork Dispatch (multi-agent arbitration — verbatim extracts)

1. **ARBITRATION OVER CONSENSUS:** "When the council votes on a matter where speed matters more than thoroughness (near-term deadline, user waiting for decision, hot-patch needed), the chair may bypass the full voting panel and decide with a reduced panel: chair + the Cell most directly affected by the decision. This arbitration mode requires: (1) a clear time constraint that full deliberation would miss, (2) the explicit justification logged in EventLedger, (3) a mandatory post-hoc audit by the full panel within 1 hour. Arbitration is the exception, not the rule." (Claude Cowork Dispatch, §Expedited Decision-Making)

2. **ESCALATION ESCALATION PREVENTION:** "If the council votes to escalate to BYOK, and the user denies cloud access, the council must not re-vote on the same escalation within the same session. A denied escalation is final for that session. The only exception is if new evidence emerges that was not available during the first vote. This prevents the council from 'nagging' the user about cloud access." (Claude Cowork Dispatch, §Escalation Finality)

#### From Apple Intelligence (on-device deliberation — verbatim extracts)

3. **LOCAL-ONLY DECISION LOGGING:** "All council deliberations, votes, tie-break rounds, and final verdicts must be logged locally. No deliberation content leaves the device. The EventLedger stores: (1) question and options, (2) anonymized vote tallies (no Cell identities in logs that could leave device), (3) final verdict with rationale. Full deliberation logs are local-only." (Apple Intelligence, §Privacy)

4. **TIER GATE CROSS-REFERENCE:** "Before the council votes to escalate tiers, the ram_manager must confirm available headroom. If ram_manager predicts the target tier would fail to load, the council must not vote to escalate — it defaults to the current tier or a smaller one. The ram_manager's headroom projection is binding: the council cannot vote to load a tier that the ram_manager says won't fit." (Apple Intelligence, §Tier Gating)

#### From GPT-5.5 Instant (voting theory — verbatim extracts)

5. **CONFIDENCE-CALIBRATED VOTE WEIGHTING:** "When tallying votes, weight each vote by the panelist's confidence score AND the panelist's relevant expertise for the question type. A planner's vote on a planning question gets weight 1.0; the same planner's vote on a safety question gets weight 0.5 (because safety is the guard's domain). The chair maintains a 'expertise matrix' per Cell for each question type." (GPT-5.5 Instant, §Expertise-Weighted Voting)

6. **MINORITY REPORT PRESERVATION:** "Every dissenting vote must be preserved in the council record with: (1) the dissenter's identity, (2) the specific point of disagreement, (3) the evidence or reasoning the majority didn't adopt. A dissenter that is later proven correct should trigger a review of the council's decision-making process. Minority reports are audit data, not noise." (GPT-5.5 Instant, §Dissent Preservation)


## Open questions
_(none yet — filled in Phase 4 as implementation begins)_
