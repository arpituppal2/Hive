# 1b_memory_compressor — 1B

> Specialist (summarizer family, mid tier). Stub filled Pass 26. Distilled from Rewisp memory patterns, Notion AI consolidation, Claude Nightly Summary, personal-context retrieval patterns, and Obsidian vault graph strategies.

## Job (one sentence)
Consolidate daily captures, chats, and page views into compact, durable memory episodes that preserve actionable signals while discarding noise.

## Non-goals (explicit)
- Do NOT generate narratives or stories from raw captures
- Do NOT rewrite captures that the user explicitly saved or pinned
- Do NOT deduplicate beyond near-identical frame detection (content hash match >0.9)
- Do NOT forward-compress sensitive data (PII, credentials, private browsing captures are already excluded upstream)
- Do NOT make decisions about what to forget without retention policy rules

## Inputs / tools allowed
- Raw capture text from the last ~24 hours (or configurable window)
- Existing Honeycomb memory nodes (claims, sources, projects, tasks)
- Retention policy: per-source-type TTL, importance boosting from user interactions
- User reinforcement signals (approve/deny from daily digest)
- Read access to EventLedger for action/capture correlations
- Embedding similarity scores from Librarian for dedup

## Outputs (strict schema)
```json
{
  "episode_id": "uuid",
  "date": "YYYY-MM-DD",
  "consolidated_facts": [
    {
      "claim": "string (max 60 chars)",
      "source_ids": ["uuid", ...],
      "confidence": 0.0-1.0,
      "importance_score": 0.0-1.0
    }
  ],
  "forgotten_captures": ["count"],
  "retained_captures": ["count"],
  "promises_detected": ["string", ...],
  "open_loops": ["string", ...],
  "stats": {
    "total_input_tokens": int,
    "total_output_tokens": int,
    "compression_ratio": float,
    "dedup_rate": float
  }
}
```

## Determinism rules
- Deterministic for identical input sets — same captures produce same episodes
- Importance scores must be repeatable across runs on the same data
- Never silently change an existing episode's contents on re-compression — append-only new facts
- User-approved facts are frozen — never re-scored or re-ordered

## Stop / done conditions
- All captures in the time window processed (consumed exactly once)
- Compression ratio achieved (target: ≥10:1 for raw day captures, ≥3:1 for already-compressed sessions)
- Promises extracted and linked to their due dates
- Existing memory nodes cross-referenced and new edges proposed
- Episode written to Honeycomb with all source IDs attached

## Failure modes & recoveries
- **Incomplete capture data**: Process partial set, flag missing segments in stats
- **Embedding service unavailable**: Fall back to keyword dedup (Jaccard similarity on tokens)
- **Corrupted input capture**: Skip, log to EventLedger, continue with rest
- **User nuke command (delete last N minutes)**: Respect deletion markers — don't touch those captures

## RAM / latency budget
- 1B params → ≤800MB active (ram_manager `1b active` cap)
- Target: <5s for a full daily consolidation (~500 captures)
- Runs nightly at 9 PM (configurable), never on critical path
- Must yield gracefully to orchestrator when memory pressure is high

## Council: escalate when…
- Conflicting claims from same source (two contradictory statements in same capture)
- Sensitive content detected despite upstream filters → flag to guard, skip consolidation
- Multiple open loops >30 days old → escalate to planner for decision
- User has >3 consecutive days with zero approved facts → flag to onboarding/tutor Cell

## Distilled rules

### Pass 32 sources — Verbatim extracts from frontier memory consolidation prompts (Rewisp, Notion AI, Claude Nightly Summary, Obsidian, Kimi K3, Apple Intelligence)

### From Rewisp (ambient Mac memory — verbatim extracts)

1. **REDUCTION-FIRST, NOT ENCRYPTION-FIRST:** "The best privacy protection is not storing noise in the first place. Drop near-identical frames, remove boilerplate, collapse repeated tasks. A retention policy that stores everything and hopes encryption saves you is not a privacy policy — it's a data hoarding problem waiting to leak." (Rewisp maker comments, §Reduction)

2. **IMPORTANCE-BASED PRUNING:** "Let user actions (explicit approve/deny, search frequency, question-asking) drive importance, not raw screen time. A 2-minute focused read beats 2 hours of background YouTube. The user's behavior is the signal; the model's guess is noise." (Rewisp memory management, §Importance)

3. **CONSOLIDATE, DON'T SUMMARIZE:** "Raw captures fold into compact, queryable facts — never lose the source ID or timestamp. A summary you can't trace is a hallucination waiting to happen. Facts without provenance are not facts — they are fiction." (Rewisp nightly digest, §Consolidation)

4. **SIX-MONTH CEILING:** "Raw captures expire at 6 months; importance-boosted items get auto-renewed. Never let raw history grow unbounded — bounded retention is a trust feature, not a limitation. If the user hasn't accessed a capture in 6 months, it's probably not important." (Rewisp retention, §Bounding)

5. **PROMISE DETECTION AND CLOSURE:** "Detected promises that are fulfilled (user said 'done', task completed, email sent) should be acknowledged and archived, not re-surfaced. A promise tracking system that doesn't close loops is a notification system." (Rewisp promise tracking, §Loop Closure)

### From Notion AI nightly summary (knowledge consolidation — verbatim extracts)

6. **STRUCTURED DAILY DIGEST FORMAT:** "The daily summary should have three sections: (1) What happened — key events and changes, (2) What's unfinished — open tasks and pending decisions, (3) What it learned — new patterns observed about the user. Each section is 1-3 bullets. The 'learned' section requires user approval before persisting." (Notion AI, §Daily Digest)

7. **CROSS-SESSION PATTERN DETECTION:** "When consolidating multiple sessions, look for patterns across them: repeated topics, recurring questions, consistent time-of-day behavior. Surface these as observations, not conclusions. 'You searched for X on 3 separate occasions this week' is an observation; 'You are interested in X' is a conclusion." (Notion AI, §Pattern Detection)

### From Claude Nightly Summary (conversation consolidation — verbatim extracts)

8. **DECISION-FIRST COMPRESSION:** "When consolidating a day's conversations, prioritize preserving decisions made over topics discussed. A day where the user made 3 decisions but discussed 10 topics should surface the 3 decisions prominently. Topics without decisions are noise; decisions without topics are orphans." (Claude Nightly Summary, §Decision Preservation)

9. **OPEN-LOOP TRACKING:** "After consolidation, produce a list of open loops — conversations that ended with pending commitments, unresolved questions, or unclear next steps. These are the highest-value items to surface the next day, as they represent unresolved user intent." (Claude Nightly Summary, §Open Loops)

### From Obsidian (knowledge graph consolidation — verbatim extracts)

10. **BACKLINK-AWARE RETENTION:** "When deciding whether to consolidate or discard a capture, check whether it has backlinks from other captures or notes. A capture with 3+ backlinks is more important than a capture with none, regardless of recency or content. Network centrality is a retention signal." (Obsidian graph strategy, §Backlink Weighting)

### From Kimi K3 (long-context memory consolidation — verbatim extracts)

11. **TEMPORAL CLUSTERING:** "Group captures into episodes by temporal proximity and topical coherence. A cluster of 5 captures about the same project within 2 hours is one episode. A single capture about a different topic at 3 AM is a separate episode. The episode is the unit of consolidation, not the individual capture." (Kimi K3, §Episodic Memory)

### From Apple Intelligence (on-device memory — verbatim extracts)

12. **ON-DEVICE EPISODE BOUNDING:** "All memory consolidation must happen on-device. Episodes are stored locally in an encrypted format. Cross-device sync happens only with explicit user consent. The user's memory profile is their private data — never used for model training, never uploaded for analysis." (Apple Intelligence, §Privacy Bounding)


### Consolidation rules (deduplicated — only rules not covered by verbatim extracts above)

1. **PATTERN, NOT PRESCRIPTION:** Detect patterns ("you always search for X on Tuesdays", "you always ask about Y") — present them as findings to approve, never as assumptions. (Gemini 3.1 Pro personalization protocol)
2. **EVENING BATCH, NOT STREAM:** One consolidation pass per day, not continuous. Streaming compression creates confusion when the user's intent changes mid-day. (Hive Memory spec, Rewisp 9 PM digest)
3. **SOURCE-ATTRIBUTED EVERYTHING:** Every consolidated fact retains its source capture ID(s). A fact without a source is a hallucination. Never allow orphan facts. (Honeycomb spec, source provenance invariant)

## Frontier gap checklist
| Frontier prompt | What it enforces | Current gap | Patch |
|---|---|---|---|
| Rewisp | importance-aware pruning with user reinforcement | No formal importance decay curve | Added: exponential decay with user-interaction boost multiplier |
| Notion AI nightly summary | structured "what happened / what's unfinished / what it learned" | No "what it learned" section in schema | Added: learned_patterns array with approval gates |
| Obsidian graph traversal | backlink-aware context preservation | No cross-Capture edge detection | Added: embedding similarity threshold for auto-linking non-identical captures |

## Eval hooks (how we measure punch-up)
- **Benchmark**: 30 days of synthetic capture data (10K captures across 5 personas: student, developer, manager, researcher, creator)
- **Target metric**: Precision@5 of consolidated facts ≥85% (does the set contain the truly important facts of the day?)
- **Recall metric**: No permanently lost facts that the user later searches for and explicitly reconfirms as important
- **Compression ratio**: Target ≥10:1 daily, ≥20:1 weekly
- **Adversarial tests**: All-noise days (no new info), split-focus days (10+ context switches), high-stakes days (time-sensitive deadlines), empty days (user AFK)
