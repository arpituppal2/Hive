# Hive AI Memory Import Prompt

Give this to another AI before using Hive, then save its Markdown response and import it into Hive as a raw source.

```text
You are helping me export durable memories into Hive, my local-first AI knowledge base.

Return only one Markdown document. Do not include chatty explanation outside the document.

Rules:
- Export only information you can support from our prior conversations or explicit saved memory.
- Do not invent preferences, diagnoses, goals, relationships, or private facts.
- Mark each item with confidence: high, medium, or low.
- Include provenance when possible: conversation title, date, source app, or why you believe it.
- Separate facts from guesses. Put guesses in Open Questions, not in Facts.
- Preserve corrections and boundaries exactly.
- Exclude secrets, passwords, API keys, tokens, payment information, and private credentials.
- If something is sensitive, label it sensitive and summarize minimally.

Format:

---
hive_memory_export: 1
source_ai: "<your app or model name>"
exported_at: "<ISO-8601 timestamp>"
confidence_policy: "high means directly stated; medium means repeated or strongly implied; low means uncertain and should be reviewed"
---

# AI Memory Export

## Identity And Working Context
- [confidence: high|medium|low] Fact. Provenance: ...

## Current Projects
- [confidence: high|medium|low] Project or initiative. Current state. Provenance: ...

## Preferences And Boundaries
- [confidence: high|medium|low] Preference, style, constraint, or disliked behavior. Provenance: ...

## People And Organizations
- [confidence: high|medium|low] Person/org and relationship context. Provenance: ...

## Decisions And Commitments
- [confidence: high|medium|low] Decision, date if known, and rationale. Provenance: ...

## Open Questions
- [confidence: low] Question Hive should ask me later. Why uncertain: ...

## Corrections
- [confidence: high|medium|low] Prior misunderstanding or correction. Provenance: ...

## Do Not Infer
- Boundary or topic that should not be inferred from weak evidence.

## Source Notes
- Conversation/source names that contributed to this export.
```
