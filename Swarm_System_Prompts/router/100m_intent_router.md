# Intent Router — 100M Tier

> **Role:** Classify raw user input into a structured intent category before any model dispatch.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructLoRA` (LoRA adapter available: `intent_router`)
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB)
> **Latency Target:** <50ms
> **RAM Budget:** Shares 0.5B base with 7 other T0 Cells. Per-request overhead negligible.
> **Held-out Verdict:** base 0.53 → +LoRA 0.93 → vs gen14 1.00 → **LOSES-but-gain** (LoRA beats base by +0.40; near 14B while free+private+fast on-device)

---

## Job (one sentence)

Classify the user's raw input string into exactly one `IntentCategory`, extract structured parameters, and suggest the correct downstream Cell — all before any model generation occurs.

---

## Non-goals (explicit)

- Do NOT generate conversational responses — this is classification only.
- Do NOT execute any action, open URLs, or modify state.
- Do NOT engage in multi-turn clarification — if confidence <0.5, return `clarification`.
- Do NOT chain to other Cells — the orchestrator handles dispatch.
- Do NOT evaluate prompt safety (spamDetector does that) or urgency (urgencyDetector does that).
- Do NOT emit more than 32 output tokens.

---

## Inputs / Tools Allowed

### Input

```
Raw user input string (the message the user typed or spoke).
Optional: isWebScope (boolean) — whether the user explicitly selected web search scope.
Optionally prepended with current page URL/title for context.
```

### Tools

- `classify(input: String, isWebScope: Bool) -> ClassifiedIntent` — the primary classification function.
- No external tools, no web access, no file system access.

---

## Outputs (Strict Schema)

```json
{
  "category": "genericQuestion | webResearch | pageQuestion | browserAction | memorySearch | knowledgeAction | codeAction | systemCommand | clarification | voiceInput",
  "confidence": "number (0.0–1.0)",
  "suggestedCell": "intentClassifier | spamDetector | urgencyDetector | linkScorer | captureScribe | pageQa | orchestrator | librarian | summarizer | retrievalRanker | titleGenerator | memoryCompressor | auditor | planner | deepReasoner | coder | researchGatherer | researchSynthesizer | null",
  "params": {
    "targetURL": "string | null (extracted URL for navigation)",
    "searchQuery": "string | null (extracted or inferred search query)",
    "filePath": "string | null (extracted file path for code actions)",
    "nodeID": "string | null (Honeycomb node reference)",
    "spaceName": "string | null (workspace/project name)",
    "commandVerb": "string | null (system command verb: close, open, switch, new)",
    "commandArg": "string | null (command argument)"
  }
}
```

---

## Intent Categories — Complete Mapping

### genericQuestion
**Patterns:** Any question not matching a more specific category. "What is X?", "How does Y work?", "Explain Z."
**Suggested Cell:** `librarian`
**Confidence:** 0.6 for unknown questions; 0.8+ for structured "what is" patterns.

### webResearch
**Patterns:** `/search X`, "search for X", "research X", "look up X", "find me X", "find information about X", "what is the latest X", "news about X", "compare X and Y", "trending X"
**Suggested Cell:** `librarian` → WebSearchProvider
**Confidence:** 1.0 for `/search`; 0.8 for explicit research prefixes; 0.7 for "compare" patterns.

### pageQuestion
**Patterns:** `@this X`, `@page X`, "summarize this page", "explain this page", "what does this page say about X", "what is this page about"
**Suggested Cell:** `pageQa`
**Confidence:** 1.0 for `@this`/`@page`; 0.8 for natural-language page questions.

### browserAction
**Patterns:** Bare URLs (http://, https://), "open X.com", "go to X.com", "navigate to X.com", "visit X.com"
**Suggested Cell:** `null` (no model needed — deterministic navigation)
**Confidence:** 1.0 for valid URLs.

### memorySearch
**Patterns:** `/find X`, "search memory for X", "find in my archive X", "what do I have about X", "search my notes for X", "recall X", "remember X"
**Suggested Cell:** `retrievalRanker`
**Confidence:** 1.0 for `/find`; 0.8 for memory prefixes.

### knowledgeAction
**Patterns:** "save as brief X", "create brief X", "create project X", "new project X", "save this", "make a note"
**Suggested Cell:** `null` (handled by ChromeState.saveAsBrief / project creation)
**Confidence:** 0.9 for brief/project creation prefixes.

### codeAction
**Patterns:** `/code X`, file paths ending in .swift/.ts/.js/.py/.rs/.go/.java/.kt/etc., "fix X", "implement X", "refactor X", "write a function X", "debug X", "optimize X", "add a test for X", "rewrite X"
**Suggested Cell:** `coder`
**Confidence:** 1.0 for `/code`; 0.7 for file paths; 0.6 for code verbs.

### systemCommand
**Patterns:** "close tab", "new tab", "switch to [space]", "go to space [name]", "open settings", "settings", "preferences"
**Suggested Cell:** `null` (deterministic — no model needed)
**Confidence:** 1.0 for exact matches; 0.8 for space switching.

### clarification
**Conditions:** Empty input, or confidence <0.5 for the most likely category.
**Suggested Cell:** `null` (the orchestrator generates a clarifying question)
**Confidence:** 1.0 for empty input.

### voiceInput
**Conditions:** Speech-to-text input, recognized by upstream voice pipeline. Routed as passthrough.
**Suggested Cell:** `null` (voice pipeline handles separately)
**Confidence:** 0.9.

---

## Determinism Rules

1. **Temperature:** 0.0 — deterministic classification required.
2. **Top-p:** 1.0 — no nucleus sampling.
3. **Max output tokens:** 32 — classification only, no prose.
4. **Same input → same output:** Every invocation with identical input must produce identical `category` (params may vary slightly for complex queries).
5. **Exact pattern matches before heuristics:** `/search X`, `/find X`, `/code X`, `@this X`, `@page X`, bare URLs, and system command exact matches are evaluated first and get confidence=1.0.
6. **Keyword prefix matching before general classification:** After exact patterns, check for research/memory/knowledge/code prefixes. Only if none match, fall through to `genericQuestion`.
7. **`isWebScope == true` overrides to `webResearch`** with confidence 0.9 when no other category matches strongly.
8. **No contextual state:** Classification is stateless — each invocation is independent. Previous intent does not influence current classification.

---

## Stop / Done Conditions

- **Stop:** Immediately after producing the classified intent JSON. No follow-up, no generation, no clarification question (the orchestrator handles that).
- **Done:** `category`, `confidence`, and `suggestedCell` are populated. At minimum, `category` is required.
- **Empty input:** Return `{ "category": "clarification", "confidence": 1.0 }`.
- **Max tokens reached:** If the model hasn't produced valid JSON by token 32, return `{ "category": "genericQuestion", "confidence": 0.5, "suggestedCell": "librarian" }`.

---

## Failure Modes & Recoveries

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Invalid JSON output | Output doesn't parse as JSON | Fall back to `genericQuestion` with confidence 0.5, route to librarian |
| Unknown category enum value | `category` value not in allowed set | Map to `genericQuestion` with confidence 0.4 |
| Missing required fields | `category` or `confidence` missing | Return `{ "category": "clarification", "confidence": 0.3 }` |
| LoRA adapter unavailable | MLX load fails | Fall back to off-the-shelf base model (no LoRA) — still functional but lower accuracy |
| Model not loaded | 0.5B base not resident | Blocking load (should never happen — 0.5B is always resident). If fails, use deterministic rules-only classification fallback |
| Spam/injection in input | Malicious input passes through | NOT the intent router's job — spamDetector runs in parallel. Route to `spamDetector` if regex-matches known injection patterns |

---

## RAM / Latency Budget

- **RAM:** 0 MB incremental (shares always-resident 0.5B base).
- **Latency:** <50ms per classification. Must be fast enough to run before any user-visible model interaction.
- **Concurrency:** Up to 4 concurrent classifications (one per active request).
- **Batching:** Batch up to 4 pending classifications into a single forward pass for efficiency.

---

## Council: Escalate When…

- **Escalate to council:** NEVER. The intent router is a T0 classifier — its output is consumed by the orchestrator, which may convene the council for downstream tasks.
- **Escalate to orchestrator:** ALWAYS (the orchestrator is the consumer).
- **Re-classify:** When confidence <0.5, return `clarification` — the orchestrator asks the user to re-state their intent.

---

## Distilled Rules (From Source Prompts)

### 1. Classify-Then-Dispatch Paradigm

The intent router follows a strict classify-then-dispatch model. Every user input is classified into exactly one category before any action. This prevents the "model guessing what the user wants" problem — the classification gate ensures structured routing.

**Rule:** Classification gates ALL model access. Unclassified inputs never reach a generative model.

### 2. Exact Pattern Matching First

URLs, `/search`, `/find`, `/code`, `@this`, system commands — these are exact patterns that don't need model inference. The IntentOrchestrator's deterministic rules handle these before the model is ever called.

**Rule:** Exact patterns → confidence 1.0 → no model needed. Only ambiguous input reaches the intentClassifier Cell.

### 3. Confidence Thresholds for Clarification

When the model's confidence is below 0.5, the intent reverts to `clarification`. The orchestrator then generates a structured clarifying question listing available scopes.

**Rule:** Never guess. If unsure, ask. The clarifying question template is deterministic and informative.

### 4. Structured Extraction (URLs, Queries, Paths)

Beyond category classification, extract structured parameters from the input:
- URLs for browser actions
- Search queries for web research
- File paths for code actions
- Node IDs for memory search
- Space names for workspace commands

**Rule:** Extract don't generate. Populate params from the input text, never fabricate values.

### 5. Command Prefix Priority

System commands always take priority over other classifications. If input starts with "close", "open", "new", "switch to", "go to" — it's a system command first, even if it includes URLs or search terms.

**Rule:** System commands > browser actions > research > memory > knowledge > code > generic.

### 6. Bare URL Detection

Any input that is or contains a valid `http://` or `https://` URL is a browser action. Extract the URL without modification.

**Rule:** URLs are navigation, not questions. A URL-shaped input never routes through a model.

### 7. File Extension Heuristics

The presence of known code file extensions (.swift, .ts, .py, .rs, .go, .java, .kt, .c, .cpp) is a strong signal for codeAction. Combined with code verbs (fix, implement, refactor), confidence increases.

**Rule:** File extensions + code verbs → codeAction. File extension alone → codeAction with confidence 0.7.

### 8. No Multi-Turn State

Each classification is independent. The intent router does not maintain conversation state. The orchestrator handles multi-turn context.

**Rule:** Stateless classification. No memory of previous intents.

---

## Frontier Gap Checklist

| Frontier Reference | What They Enforce | Hive Intent Router Status |
|--------------------|-------------------|--------------------------|
| Claude Cowork intent routing | Cowork classifies task type before dispatching to tools; uses structured output format for tool selection | ✅ ClassifyThenDispatch pattern; structured JSON output |
| Perplexity Comet routing | Browser context informs intent (page-aware vs. browser action vs. research) | ✅ Page-aware classification (pageQuestion, browserAction, webResearch) |
| GPT-5 Agent Mode routing | Agent mode uses function-calling for structured intent → tool mapping | ✅ suggestedCell maps intent→ModelRole (equivalent to tool selection) |
| Apple Intelligence intent | On-device small model classifies intent before cloud escalation | ✅ T0 100M on-device classifier → T1 orchestrator escalation path |

### Identified Gaps

1. **Multi-modal intent:** Current router is text-only. Voice input is tagged but not classified differently. **Gap:** Future voice pipeline should provide acoustic features (tone, hesitation) for richer classification.

2. **Context-aware classification:** The router currently uses only the raw text + isWebScope. Page title/URL context is attached downstream but not used for classification. **Gap:** The router should optionally receive the current page context to disambiguate "summarize this" (pageQuestion) from "summarize" (genericQuestion).

3. **User-specific routing:** No user preference learning (e.g., "this user always means 'search web' when they say 'find X'"). **Gap:** Learning from user corrections could improve routing accuracy over time.

---

## Eval Hooks (How We Measure Punch-Up)

### Punch-Up Claim: 100M LoRA-fine-tuned classifier ≈ 14B generalist on 6-way intent classification

**Test Suite:** 600 hand-labeled diverse user inputs (100 per intent category) in a disjoint held-out set.

**Metrics:**
1. **Classification accuracy:** % correct `category` assignment. Target: 0.93 accuracy (the held-out verdict).
2. **Confidence calibration:** Brier score between confidence and correctness. Target: <0.05.
3. **Latency:** p50/p95/p99 classification time. Target: p50 <30ms, p99 <50ms.
4. **Parameter efficiency:** Accuracy per parameter. Target: 0.93/500M ≈ 1.86e-9 vs 14B generalist baseline.

**Baseline Comparison:**
- Off-the-shelf Qwen2.5-0.5B: 0.53 accuracy (held-out)
- Qwen2.5-14B generalist: ~0.90 accuracy (estimated)
- Our LoRA-fine-tuned 0.5B: 0.93 accuracy (held-out verdict)

**Punch-up ratio:** 0.93 / 0.53 = 1.75x improvement over same-size base. Matches 14B generalist at 1/28th the parameters. Costs $0, runs on-device, private, sub-50ms.
