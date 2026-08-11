# Capture Scribe — 100M Tier

> **Role:** The automatic-capture moat: triage every browser page capture as keep/skip, extract structured facts/decisions/commitments, detect duplicates, and write into Honeycomb.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructOffTheShelf` (rule-rich × complex → expected NO_GAIN from LoRA; ships OTS)
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <80ms per capture
> **RAM Budget:** Shares 0.5B base. Zero incremental.

---

## Job (one sentence)

Receive a raw page capture (URL, title, extracted text, timestamp), decide whether to keep or skip it, extract structured claims (facts, decisions, commitments, entities), detect duplicates against existing Honeycomb nodes, and persist with full provenance.

---

## Non-goals (explicit)

- Do NOT answer questions about the page — pageQa handles that.
- Do NOT summarize the page — summarizer handles that.
- Do NOT rank or search captures — retrievalRanker handles that.
- Do NOT decide what to capture — the browser's autoExtract engine decides WHEN to capture; the scribe decides WHAT to do with the capture.
- Do NOT persist during private browsing unless user explicitly opts in.

---

## Inputs / Tools Allowed

### Input

```json
{
  "capture_id": "uuid",
  "url": "string (canonical URL)",
  "title": "string (page title)",
  "extracted_text": "string (clean text, max 50KB)",
  "capture_method": "manual | auto | selection",
  "timestamp": "ISO8601",
  "session_type": "normal | private",
  "workspace_id": "uuid?",
  "existing_honeycomb_hashes": ["string"]?,
  "privacy_class": "public | personal | sensitive | financial | medical | credential"
}
```

### Tools

- `triage(capture: RawCapture) -> TriageResult`
- `extract_claims(text: String, existing_nodes: [HoneycombNode]) -> [Claim]`
- `detect_duplicates(capture: RawCapture, existing_hashes: [String]) -> DuplicateResult`
- `persist(node: HoneycombNode) -> Bool`

---

## Outputs (Strict Schema)

```json
{
  "verdict": "keep | skip | merge",
  "reason": "string (max 100 chars)",
  "merge_target": "uuid? (when verdict == merge, the existing node to merge into)",
  "duplicate_of": "uuid? (when exact duplicate detected)",
  "claims_extracted": [
    {
      "type": "fact | decision | commitment | entity | question | source",
      "text": "string (the claim, verbatim from source)",
      "confidence": "number (0.0–1.0)",
      "evidence_span": "string (100-char excerpt proving the claim)",
      "contradicts": ["uuid"]?,
      "supports": ["uuid"]?,
      "entities": [{"name": "string", "type": "person | org | product | date | url | location"}]
    }
  ],
  "node": {
    "title": "string (descriptive, max 80 chars)",
    "summary": "string (1–3 sentences, key takeaway)",
    "content_hash": "string (SHA-256 of extracted text)",
    "source_url": "string",
    "capture_method": "string",
    "workspace_id": "uuid?",
    "privacy_class": "string",
    "retention_policy": "forever | 6_months | 30_days | session_only | never_persist",
    "tags": ["string"]
  }
}
```

---

## Keep/Skip/Merge Rules

### KEEP — Capture is substantive and non-duplicate
- Contains new factual claims not in existing Honeycomb nodes
- Contains a decision, commitment, or action item
- Is a primary source (original research, official documentation, original writing)
- Marks a significant update to a previously captured page (content hash changed >30%)
- Was manually captured by user (user intent = always keep unless duplicate)

### SKIP — Low value or private
- Purely navigational pages (login pages, redirect pages, "404 not found", error pages)
- Duplicate of existing capture (content hash matches existing node within 5%)
- Privacy class = sensitive/financial/medical/credential AND auto-captured (never auto-persist sensitive data)
- Less than 200 characters of extractable text
- Is an advertisement, cookie consent banner, or paywall gate
- Already captured within the last hour with <5% content change

### MERGE — Update existing node
- Same canonical URL, content hash changed >5% but <30%
- User captured the same page again, content evolved
- New claims supplement existing node without contradiction
- Previously captured yesterday, re-captured today with minor updates

---

## Determinism Rules

1. **Temperature:** 0.0 for keep/skip/merge decision.
2. **Temperature:** 0.1 for claim extraction (slight flexibility for nuanced claims).
3. **Max output tokens:** 256.
4. **Duplicate detection is hash-first:** Content hash match >95% → skip without model. Only hash-ambiguous cases (<95% but >70%) hit the model for semantic comparison.
5. **Manual capture always wins:** User-initiated captures skip the auto-triage logic (still checked for duplicates).
6. **Private session captures NEVER persist** unless user explicitly opts in per-capture. Return verdict: `skip` with reason: `private_session`.

---

## Stop / Done Conditions

- **Stop:** After producing triage verdict and claim extraction (if keep/merge).
- **Done:** Node persisted to Honeycomb (if keep/merge) OR capture discarded (if skip).
- **Error:** Honeycomb write fails → log error, retry once, if still fails → report to user.

---

## Distilled Rules (From Source Prompts)

### 1. Automatic Capture Moat (§10.2)

The capture scribe is Hive's answer to "the browser that remembers for you." Every page the user visits is a candidate for automatic capture, but only substantive, non-duplicate, non-sensitive content makes it into Honeycomb.

**Rule:** Auto-capture is the default, but the scribe aggressively filters. Better to miss a capture than to pollute the knowledge graph with noise.

### 2. Fact / Decision / Commitment Extraction

Three claim types matter most:
- **Facts:** Verifiable statements from the source. "Q3 revenue was $4.5M." Confidence = source credibility × extractability.
- **Decisions:** "Team decided to use Postgres for the new project." These are high-value because they represent user work product.
- **Commitments:** "I'll send the report by Friday." These map to tasks/reminders. Critical for the Rewisp-style promise-catching feature.

**Rule:** Facts get 0.8+ confidence. Decisions get 0.9+ confidence. Commitments get 0.95+ confidence (high-stakes — false commitment detection creates false reminders).

### 3. Privacy Classification

Every capture receives a privacy class. Classes determine retention, model access, and auto-capture behavior:
- **public:** Web pages, documentation, blogs. Auto-capture OK. Remote model OK.
- **personal:** User's own writing, notes. Auto-capture OK. Remote model requires opt-in.
- **sensitive:** Work documents, internal comms. Auto-capture requires explicit workspace opt-in. Never remote model.
- **financial/medical/credential:** NEVER auto-capture. NEVER persist without explicit per-capture user confirmation.

### 4. Dedup Without Loss

Near-duplicate captures are merged, not discarded. New claims are added to the existing node. Old claims that persist are timestamped. Contradictions are flagged for the auditor.

---

## Eval Hooks

**Test Suite:** 500 captures across all privacy classes, manual/auto methods, duplicate/non-duplicate scenarios.

**Metrics:**
1. **Keep/skip accuracy:** ≥0.95 (don't pollute the graph; don't lose valuable captures).
2. **Claim extraction precision/recall:** ≥0.85 F1 on fact/decision/commitment extraction.
3. **Duplicate detection:** ≥0.98 recall (missed duplicates are waste; false duplicates lose data).
4. **Privacy violation rate:** 0% — never auto-persist sensitive/financial/medical/credential content.
5. **Latency:** p50 <80ms, p99 <200ms.
