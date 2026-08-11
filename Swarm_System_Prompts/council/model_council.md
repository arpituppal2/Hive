# Model Council — Voting & Tie-Breaking Contract

> **Role:** Phase 4 runtime contract defining when to convene the model council, how to vote, how to break ties, and when a single tiny Cell is sufficient.
> **Canonical Status:** active

## When to Convene the Council

| Condition | Convene Council? | Rationale |
|-----------|-----------------|-----------|
| Multiple providers available (MLX + Tavily + BYOK) | Yes | Multi-source improves answer quality |
| Only MLX local available | No | Single provider — librarian is sufficient |
| Research task with ≥3 sources | Yes | Multi-source synthesis benefits from parallel provider views |
| Simple factual question ("What is 2+2?") | No | Wasteful — librarian handles instantly |
| Security-critical audit | Yes (local-only providers) | Never send security audit to remote providers |
| User explicitly requests council | Yes | Honor user intent |
| Degraded environment (only mock available) | No | Council with mock-only is theater |

## Council Composition

### Default Panel (when available)
1. **MLX Local** (on-device, private, fast) — always included
2. **Tavily Cloud** (web search API, broader knowledge) — included for research/current-events
3. **BYOK Remote** (user's frontier model) — included when configured

### Local-Only Panel (security-critical)
1. MLX Local only
2. If MLX unavailable → librarian (100M) with no-external-context

## Voting Protocol

### Confidence-Weighted Voting (from GPT-5.5 Instant)
Each panelist's vote is weighted by their confidence score. A vote at 0.9 confidence counts 3× more than a vote at 0.3 confidence. The weighted sum determines the decision.

### Majority with Explicit Dissent (from GPT-5.5 Instant)
The verdict must include the dissenting view when it exists. A 2–1 vote with strong dissent is more informative than a 3–0 vote with weak agreement.

### Quorum Rules
- **Minimum 2 providers** must respond for a valid council verdict
- **Single provider scenario:** When only one provider responds, the verdict carries `isDegraded: true` with `activeProviders: [theResponder]`
- **All providers timeout/error:** Council fails. Fall back to librarian (100M) on-device-only.

## Tie-Breaking

When providers disagree and the weighted vote is ≤0.55 in either direction:
1. Escalate to the 8B deep reasoner with both positions + evidence
2. The reasoner produces a tie-breaking analysis
3. If the reasoner also can't decide, present both views to the user with "The council is split on this question."

## When a Tiny Cell is Enough (No Council Required)

| Scenario | Sufficient Cell | Why |
|----------|----------------|------|
| "What does this page say?" | pageQa (100M) | Grounded, single-source, no synthesis |
| "Close this tab" | None (system command) | Deterministic, no model |
| "Search for X" | librarian (100M) + WebSearchProvider | Web search gate, not reasoning |
| "Save as brief" | None (knowledge action) | File operation |
| "Fix typo in auth.swift" | coder/1b | Scoped, single-file, low risk |
| "Summarize this page" | summarizer (1B) | Single-source compression |
| "Research competitive landscape" | Council → researchSynthesizer/8b | Multi-source, high-stakes |
| "Audit these claims" | auditor/1b (or 8b) | Security-critical, local-only |

## Honest Degradation

When not all providers are available:
- The verdict carries `isDegraded: true`
- The UI shows exactly which providers answered and which were unavailable
- Never fabricate council participation

## Latency Budget

| Operation | Target |
|-----------|--------|
| Single council round-trip | <5s |
| Tie-breaking escalation (reasoner) | +4s |
| Timeout per provider | 30s |
| Total council maximum | 35s |
