# ram_manager — control doc

> **Router-family control doc (runtime contract).** Specifies the load/unload, priority, OOM policy, and concurrent-Cell caps for the 8GB M1 floor. This is a deterministic engine, not a model. It gates EVERY Cell load and unload. It is referenced by `orchestrator/1b_orchestrator.md`, `council/1b_council_chair.md`, and every Cell's `RAM / latency budget` section.

## Purpose

The ram_manager is the system's memory gatekeeper. It enforces the invariant that the AI subsystem never exceeds 4000MB on an 8GB M1 (system reserve: 1500MB). It decides: can this Cell load right now? If not, what gets evicted? If OOM is imminent, how do we degrade gracefully?

## Contract

### 1. Memory Budget (hard invariant)

| Resource | Budget | Notes |
|----------|--------|-------|
| Total AI ceiling | 4000MB | Hard cap; never breached. |
| System reserve | 1500MB | For macOS + browser renderer + non-AI processes. |
| `rule` tier | ~0MB | guard + ram_manager engine are code, not weights. Always resident. |
| `100m` cohort | ≤300MB | All 100m Cells share a common base model (per `ModelManifest.sharedRepo`). Always resident. |
| `1b` active | ≤800MB | One working specialist + the warm orchestrator at a time. |
| `8b` active | ≤2000MB | Strictly ONE at a time; evicts the active 1B specialist (orchestrator's route state retained). |
| `byok` | 0MB local | Remote only; never loaded locally. |

### 2. Concurrent Loaded Cells by Tier (invariant)

**Tier-Normal (common path, >90% of interactions):**
- `rule` set: guard + ram_manager — always loaded.
- `100m` cohort: intent_router, spam_detector, urgency_detector, dom_scout, librarian-100m — always loaded, share one weight slot.
- `1b`: the warm orchestrator + exactly ONE working specialist (e.g., 1b_coder, 1b_planner, 1b_librarian, 1b_auditor, 1b_compressor, 1b_council_chair, 1b_action_planner, 1b_link_scorer).
- **Total memory: ~300MB (100m cohort) + ~800MB (orchestrator + 1 specialist) = ≤1100MB.** Well within the 4000MB ceiling.

**Tier-Escalation (rare path, <10% of interactions):**
- `rule` + `100m` cohort: unchanged.
- `1b` warm orchestrator: route state retained.
- `8b`: one 8B Cell loaded (coder-8b, planner-8b, nav_reasoner-8b, auditor-8b, deep_reasoner, research_synthesizer).
- The working `1b` specialist is EVICTED before the `8b` loads.
- **Total memory: ~300MB + ≤800MB (orchestrator) + ≤2000MB (one 8B) = ≤3100MB.** Under the 4000MB ceiling.

**Invariant enforcement:** the ram_manager checks before EVERY load. If a load would breach the ceiling:
1. Evict in priority order (see §4).
2. If eviction doesn't free enough: REFUSE the load. Return `load_denied:ram_cap` to the orchestrator.
3. The orchestrator retries at a SMALLER tier (8b→1b, 1b→100m). System degrades to smaller-and-honest, never to silent-failure.

### 3. Load Protocol

When the orchestrator requests a Cell load:

```json
{ "request": "load",
  "cell": "<filename>",
  "tier": "<100m|1b|8b>",
  "requested_by": "orchestrator",
  "purpose": "<1-line reason>" }
```

Response:
```json
{ "verdict": "load_granted" | "load_denied",
  "deny_reason": "ram_cap" | "tier_conflict" | "cell_not_found" | null,
  "evicted": ["<cell filenames evicted to make room>"],
  "current_usage_mb": <int>,
  "remaining_headroom_mb": <int>,
  "recommended_tier_downgrade": "<100m|1b|8b>" | null }
```

**Cohort sharing:** if the requested Cell shares a base model with an already-loaded Cell (per `ModelManifest.sharedRepo`), the load cost is zero — the weights are already in memory. The ram_manager tracks this.

### 4. Eviction Policy (LRU + Safety)

When memory is needed, evict in this order:

1. **Idle `8b`** — if an 8B hasn't been used in >30s, evict it. This is the cheapest eviction (frees 2000MB).
2. **Least-recently-used working `1b` specialist** — the working specialist (NOT the orchestrator) with the oldest last-use timestamp.
3. **NEVER evict the orchestrator** — the orchestrator's route state is the system's spine. Evicting it loses the current goal + plan.
4. **NEVER evict the `100m` cohort** — these are always-resident. The cost to reload them on every interaction outweighs the memory savings.
5. **NEVER evict `guard`** — the guard is the safety backstop. Evicting it leaves the system without a safety gate.
6. **Pinned Cells** — if a Cell is mid-write (auditor writing findings, librarian writing claims), it is PINNED until commit. Do not evict a pinned Cell.

### 5. OOM / Hard Limit Policy

If a load request would breach the 4000MB ceiling even after eviction:

1. **Refuse the load.** Return `load_denied:ram_cap` with `recommended_tier_downgrade`.
2. **The orchestrator retries at the recommended smaller tier.** For example: an 8b_coder load was denied → retry with 1b_coder.
3. **If the smallest tier for the job is still denied** (e.g., even a 1B can't load) → the system is in a critical memory state. The orchestrator surfaces to the user: "Memory is full. Close unused tabs or wait for background work to finish."
4. **Graceful degradation path:** the system works at whatever tier it can load. Better a 100m agent that's honest about its limits than an 8B that can't load.

### 6. Unload Protocol

Cells are unloaded:
- **Proactively:** by the ram_manager when idle (LRU eviction, per §4).
- **On request:** by the orchestrator when a task completes (`request:"unload", cell:"<filename>"`).
- **On error:** if a Cell crashes or returns a fatal error, the ram_manager evicts it and logs the crash.

### 7. Monitoring + Telemetry

The ram_manager tracks (locally, never network-exported):
- Current memory usage per Cell.
- Load/eviction count per Cell (to identify thrashing).
- Denied-load count (to identify systematic RAM pressure).
- Peak memory usage over the last N interactions.
- Cohort-sharing hit rate (how often a Cell shares weights with an already-loaded Cell).

### 8. Cross-References

- `00_INDEX.md` — RAM budget rules (the source of truth for the budget table).
- `ModelManifest` (in `Sources/HiveCore/AI/ModelManifest.swift`) — `sharedRepo` groups for cohort sharing.
- `orchestrator/1b_orchestrator.md` — the orchestrator's RAM-aware dispatch logic.
- `council/1b_council_chair.md` — the council consults ram_manager headroom for size-selection votes.
- Every Cell's `RAM / latency budget` section — references this contract.

### 9. Invariants (testable)

1. **Total AI memory ≤ 4000MB** at all times (enforced before every load).
2. **At most one 8B** loaded at any time.
3. **At most one working 1B specialist** loaded (the orchestrator is warm, not counted as the working specialist for this invariant).
4. **100m cohort never evicted** — always resident.
5. **Guard never evicted** — always resident.
6. **Orchestrator never evicted** — always resident (route state may be swapped to disk on extreme pressure, but the orchestrator process stays).
7. **No load bypassing the ram_manager** — every Cell load goes through this contract.

## Open questions
_(none yet — filled in Phase 4 as implementation begins)_
