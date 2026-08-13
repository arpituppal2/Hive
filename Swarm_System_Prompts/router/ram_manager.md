# RAM Manager — Memory Budget & Load/Unload Policy

> **Role:** Phase 4 runtime contract. Enforces model load/unload, priority ordering, OOM escalation, and concurrent Cell caps for the 8GB M1 Air floor.
> **Canonical Status:** active

## Total RAM Budget: 8 GB (M1 Air Floor)

| Component | Resident Budget | Peak Budget |
|-----------|----------------|-------------|
| macOS + CEF renderers + SwiftUI | ~2.5 GB | ~3.5 GB |
| T0 always-resident base (0.5B) | 300 MB | 300 MB |
| T1 frequently-resident base (1.5B) | 900 MB | 900 MB |
| T2/T3 on-demand (loaded one at a time) | 0 MB idle | 4.3 GB (7B model) |
| Web content (CEF renderers per tab) | ~2 GB | Varies |
| Headroom | ~1.3 GB | ≥500 MB |

## Load Priority (When Multiple Requests Queue)

1. **T0 Cells** — Always loaded (0.5B base). No load time. Instant dispatch.
2. **T1 Orchestrator** — Required for routing. Always loaded (shared 1.5B base).
3. **T1 Librarian/Summarizer** — Required for context assembly. Always loaded.
4. **T2 Auditor** — Security-critical. Load on demand. Preempt non-critical T2 loads.
5. **T2 Planner** — Required before any execution. Load on demand.
6. **T3 Coder/Reasoner** — On-demand generation. Load only when task requires.
7. **T3 Research** — Background task. Lowest load priority.

## Unload Policy

| Condition | Action |
|-----------|--------|
| T2 Cell idle for 30 seconds | Unload |
| T3 Cell idle for 10 seconds | Unload (large memory footprint) |
| Memory pressure >85% | Unload all T2/T3. If still >85%, unload T1 (keep T0). |
| OOM warning (macOS critical) | Force-unload all T1/T2/T3. Keep T0 base. Signal orchestrator to use librarian-only degraded mode. |
| New tab opens, memory <500MB headroom | Unload least-recently-used T2/T3. If still tight, hibernate oldest non-active tab. |

## Maximum Concurrent Loaded Model Instances

- **T0 Base (0.5B):** 1 instance. Serves all 8 T0 Cells simultaneously.
- **T1 Base (1.5B):** 1 instance. Serves all 6 T1 Cells simultaneously.
- **T3 Base (Coder-7B):** At most 1 instance. Adapter-swapped per role (coder ↔ deepReasoner ↔ researchSynthesizer).
- **Total concurrent loaded model instances:** ≤3 (0.5B + 1.5B + one of 7B).

## Adapter Swapping (T3 Base)

The 7B base is loaded once. Switching between coder, deepReasoner, and researchSynthesizer:
1. Unload current LoRA adapter weights from memory
2. Load target role's LoRA adapter weights (~50–200 MB)
3. Apply adapter via `linear_to_lora_layers`
4. Total swap time: <500ms

## Tab Hibernation Memory Budget

| Tab State | Memory | Policy |
|-----------|--------|--------|
| Active tab | Full CEF renderer | Never hibernate |
| Background tab (<30 min idle) | Full CEF renderer | Keep resident |
| Background tab (>30 min idle) | DomState cached, renderer suspended | Hibernate |
| Pinned tab | Full CEF renderer | Never hibernate |
| Audio-playing tab | Full CEF renderer | Never hibernate |
| Hibernated tab | ~5 MB (cached state) | 30min → hibernate; wake on click |

## OOM Escalation Ladder

1. **Normal (65–85%):** No action. Monitor.
2. **Elevated (>85%):** Unload idle T2/T3 Cells. Hibernate tabs >30min idle.
3. **Critical (>95%):** Unload all T1/T2/T3 Cells. Hibernate all non-active, non-pinned, non-audio tabs. Keep T0 + active tab + OS.
4. **Emergency (macOS memory pressure critical):** Force-unload all models. Hibernate all non-active tabs. Show "Low Memory" indicator. Prevent new tab creation. Signal orchestrator: degraded mode only.
