# Urgency Detector — 100M Tier

> **Role:** Score every incoming user request for urgency to enable attention scheduling and priority routing.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructLoRA` (LoRA adapter available: `urgency_detector`)
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared with T0 cohort)
> **Latency Target:** <50ms
> **RAM Budget:** Shares 0.5B base. Zero incremental.
> **Held-out Verdict:** base 0.33 → +LoRA 0.75 → vs gen14 0.75 → **MATCH** (3-way classification; LoRA adds reliable attention-priority triage)

---

## Job (one sentence)

Assign every user input an urgency level (`now`, `soon`, `whenever`) to enable the orchestrator to schedule attention and prioritize resource allocation.

---

## Non-goals (explicit)

- Do NOT classify intent (intentRouter does that).
- Do NOT detect spam/injection (spamDetector does that).
- Do NOT execute anything — just label urgency.
- Do NOT make moral judgments about priority — urgency is about time-sensitivity, not importance.
- Do NOT exceed 8 output tokens.

---

## Inputs / Tools Allowed

### Input

```
Raw user input string.
Optional: context_urgency_hints (is the user mid-task? Is a deadline mentioned? Has the user been waiting?).
```

### Tools

- `assess(input: String, hints: UrgencyHints?) -> UrgencyVerdict`
- No external tools.

---

## Outputs (Strict Schema)

```json
{
  "level": "now | soon | whenever",
  "confidence": "number (0.0–1.0)",
  "reason": "string (max 30 chars, stable reason code)",
  "time_sensitivity": "immediate | hours | days | none | unknown"
}
```

---

## Urgency Levels

### now
Immediate attention required. Time-sensitive, blocking, or critical.
**Triggers:** "urgent", "ASAP", "right now", "emergency", "critical", "broken", "crashed", "deadline in [minutes/hours]", "live", "customer waiting", "production down", active time pressure phrases.
**Resource:** Route immediately; preempt lower-priority tasks if needed.
**Confidence:** 0.8+ for explicit urgency language.

### soon
Should be addressed within this session, but not blocking.
**Triggers:** "today", "by end of day", "this afternoon", "when you get a chance", active task language without time pressure, multi-step requests that require follow-up.
**Resource:** Schedule in current session queue; don't preempt.
**Confidence:** 0.7+ for time-bounded but not immediate language.

### whenever
No time sensitivity. Can be queued, batched, or deferred.
**Triggers:** "someday", "whenever", "no rush", "just curious", casual conversation, exploratory questions, "what is X" without time context, "tell me about", "how does Y work."
**Resource:** Queue at lowest priority; batch with similar requests.
**Confidence:** 0.9+ for explicit no-rush language.

---

## Determinism Rules

1. **Temperature:** 0.0
2. **Top-p:** 1.0
3. **Max output tokens:** 8
4. **Time-pressure phrases → now:** Always classify explicit deadline/immediacy language as `now`.
5. **Casual/no-pressure phrases → whenever:** Always classify explicit deferral language as `whenever`.
6. **Default → soon:** When no urgency signals detected, default to `soon` (middle priority).
7. **No multi-turn state:** Each input is independently classified.

---

## Stop / Done Conditions

- **Stop:** Immediately after producing the urgency verdict.
- **Done:** `level`, `confidence`, `reason`, `time_sensitivity` all populated.

---

## Failure Modes & Recoveries

| Failure | Detection | Recovery |
|---------|-----------|----------|
| False urgency (whenever → now) | User task jumps to top of queue unnecessarily | Cost is low — preempting one task is recoverable. Track false-urgent rate for tuning. |
| Missed urgency (now → whenever) | Time-sensitive task delayed | Higher cost — user frustration. LoRA fine-tune with missed-urgency examples. |
| LoRA unavailable | MLX load fails | Fall back to base model (0.33 accuracy → still functional for triage) |

---

## RAM / Latency Budget

- **RAM:** 0 MB incremental.
- **Latency:** <50ms.
- **Concurrency:** Up to 4 concurrent assessments.

---

## Council: Escalate When…
- Escalate to orchestrator (consumer of urgency signal).
- Never escalate to council — urgency is a routing signal, not a model decision.

---

## Distilled Rules (From Source Prompts)

### Time-Pressure Lexicon

**Immediate:**
- "urgent", "ASAP", "right now", "immediately", "emergency"
- "critical", "broken", "crashed", "down", "failing"
- "deadline" + time-unit (minutes, hours, "by 3pm")
- "live", "production", "customer waiting", "on call"
- "lost" + data/files/work

**Today/Soon:**
- "today", "this afternoon", "by tonight", "EOD"
- "before you go", "when you get a chance"
- "working on", "in the middle of"

**Whenever:**
- "someday", "whenever", "no rush", "not urgent"
- "just curious", "just wondering", "quick question" (casual)
- "tell me about", "what is", "how does" (exploratory)

---

## Frontier Gap Checklist

| Frontier Reference | What They Enforce | Status |
|--------------------|-------------------|--------|
| Apple Intelligence priority | On-device triage before cloud escalation; urgency informs which model tier to use | ✅ T0 urgency → orchestrator routing priority |
| Slack/Figma notification triage | Attention scheduling based on message content and sender context | ✅ urgency level maps to queue priority |

---

## Eval Hooks

**Test Suite:** 600 labeled inputs (200 per urgency level). Disjoint held-out.

**Metrics:**
1. **3-way accuracy:** Target 0.75 (held-out MATCH verdict).
2. **now recall:** ≥0.95 (must not miss time-sensitive requests).
3. **Latency:** p50 <30ms, p99 <50ms.
