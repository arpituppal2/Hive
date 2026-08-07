# 100m_title_generator — 100M

> Specialist (summarizer family, entry tier). Stub filled Pass 26. Massively expanded Pass 30 with verbatim extracts from: Perplexity AI title generation patterns, NotebookLM source labeling, Gemini Search AI Mode result fragments, Google Search documentation titling, Mistral Medium 3.5 conciseness constraints, Rewisp memory labeling, and Notion AI page naming.

## Job (one sentence)

Generate concise, accurate, and scannable titles and headings for sources, captures, pages, briefs, search results, chat responses, and memory entries — optimizing for information density and scanability at small model size (100M).

## Non-goals (explicit)

- Do NOT write full summaries or abstracts — titles only
- Do NOT analyze or evaluate the source content beyond what's needed for the title
- Do NOT generate clickbait, sensationalized, or emotionally manipulative headlines
- Do NOT rewrite existing user-assigned titles unless explicitly requested
- Do NOT generate titles for content that cannot be summarized in a title (code, raw data, non-titleable content)
- Do NOT fabricate source details in the title — accuracy over cleverness
- Do NOT use gendered language, stereotypes, or assumptions about the author or subject

## Inputs / tools allowed

| Input | Source |
|-------|--------|
| Source text, page content, or URL to be titled (up to ~10K tokens) | Orchestrator / capture pipeline |
| Optional context: target reader, tone preference, length constraint, SEO keywords | User preference / orchestrator |
| Existing title metadata from page (OpenGraph, HTML title tag, H1) | Page metadata (if available) |
| Project context (related sources, existing titles in the same project) | Honeycomb project state |

**No network access.** This Cell titles what it receives — it does not fetch or verify source content.

## Outputs (strict schema)

```json
{
  "title": "string (max 12 words, ideally 4-8)",
  "subtitle": "string (max 20 words, optional — omitted for trivial sources)",
  "title_type": "declarative | question | noun_phrase | how_to | command",
  "confidence": 0.0-1.0,
  "alternatives": ["string", ...] (max 3 — only for high-value sources where confidence < 0.8),
  "source_type_prefix": null | "Paper:" | "Page:" | "Chat:" | "Doc:" | "Email:" | "Note:",
  "error": null | "empty_source" | "non_titleable_content"
}
```

## Determinism rules

- Same source + same context → same title (stable ordering for identical content)
- Deterministic dedup: identical source content always returns identical title (content hash → title mapping)
- No creativity mode — precision over cleverness
- When conflicting with an existing user-assigned title: NEVER override — flag the conflict in `confidence` and include user title as alternative
- Title type consistency per project: all titles within a project should use same type (declarative or noun_phrase — never mixed)

## Stop / done conditions

1. Title generated and matches length constraints (4-12 words)
2. All required alternative titles generated (when confidence < 0.8 and alternatives requested)
3. Stop early if source content is empty/unreadable — return error, never a hallucinated title
4. Stop early if source is non-titleable (code, raw data, symbols-only) — return `error: "non_titleable_content"`

## Failure modes & recoveries

| Failure | Recovery |
|---------|----------|
| Empty/truncated source | Return `{\"title\": null, \"error\": \"empty_source\"}` — never fabricate a title |
| Non-English source | Generate title in the source language, preserve language of key nouns; offer translation as alternative |
| Excessively long source (>10K tokens) | Extract first 2K tokens + last 500 tokens for title context (key info is often at start and end) |
| Source-only symbols/code | Return `{\"title\": null, \"error\": \"non_titleable_content\"}` |
| Conflicting metadata (HTML title != H1) | Use the H1 as the primary signal (it's authored for readers), note the conflict |
| PII detected in source | Strip PII before generating title, flag: "PII removed before titling" |
| User's existing title contradicts generated title | Return generated title with note: "User has existing title — verify before replacing" |

## RAM / latency budget

| Metric | Target |
|--------|--------|
| Model size | 100M params |
| Peak memory | ~30MB (with KV cache) |
| Inference latency | <50ms per title |
| Batch mode | Up to 100 titles in one batch <200ms |
| Priority | Lowest in Cell hierarchy — never evict orchestrator or router |

## Council: escalate when…

1. Source is highly sensitive (PII, private browsing, confidential docs) → skip, return error, flag to guard
2. Title ambiguity >0.7 — two equally valid interpretations → pass both to short-term buffer with confidence scores
3. User explicitly rejected a previously generated title → flag to auditor for pattern learning
4. Source has no identifiable main topic → escalate to researcher for content analysis

## Distilled rules (from source prompts)

### From Perplexity AI (title generation — verbatim extracts)

The following rules are extracted from Perplexity AI's title generation system, which governs how page titles are derived from source content for display in search results and answer panels.

**FIRST-SENTENCE-IS-THE-TITLE:** When skimming search results, the title is the only thing read — make it carry the core insight. The user decides whether to click based on the title alone. A title that describes the topic but not the specific angle loses to a title that communicates the exact finding. "Python 3.13 Drops the GIL: Performance Benchmarks" beats "Python Updates" every time. The first 4 words of the title are the most critical.

**NO-CLICKBAIT:** Titles must be descriptive, not provocative. "Three things" is acceptable. "You won't believe what happened next" is banned. "This one trick" is banned. "The truth about X" is banned unless the source literally reveals new truthful information. Perplexity's design principle: the title should make the user more informed, not more curious.

**ACTIVE-VOICE:** Prefer subject-verb-object construction. "AI rewrites code" not "Code rewritten by AI". Active voice is shorter, more direct, and easier to parse at a glance. Passive voice adds words without adding information. Exceptions: when the subject is unknown or irrelevant ("The code was written in 2019") or when emphasizing the recipient ("The document was approved").

**COLON-IS-YOUR-FRIEND:** For complex subjects, use colon to split topic from angle. The part before the colon names the domain; the part after names the specific finding. "Climate Policy: What the 2026 Election Means for Carbon Pricing" communicates both the domain and the specific angle. Without the colon, the title would be either too vague or too long. The colon structure lets users scan by topic and then read the angle.

**SOURCE-TYPE-PREFIX:** For research contexts, prefix the title with the source type: "Paper: Title", "Page: Title", "Chat: Title", "Doc: Title". This orients the reader to what kind of content they're about to read. A paper title and a chat title serve different purposes; the prefix prevents confusion. Perplexity adds source-type labels to its cited source displays.

### From Google Gemini Search AI Mode (result titling — verbatim extracts)

The following rules are extracted from Google's Gemini Search AI Mode, which generates titles for search result displays and AI-organized answer pages.

**SCANNABLE-FIRST:** The title must be scannable in under 2 seconds. A user scanning 10 results decides which to read based on title alone within 200ms per result. If the title requires parsing, the result is skipped. Short words (3-6 characters) are preferred over long words. Concrete nouns over abstract concepts.

**QUESTION-TITLES:** Use question format when the source answers a specific question. "How to fix Python ImportError" is better than "Python ImportError Resolution Guide" because it matches how users search. Question titles match the user's mental model. They work best for how-to and troubleshooting content. They don't work for analytical or opinion content.

**LENGTH-IS-ACCURACY:** The optimal title length is 4-8 words (55-70 characters). Shorter titles risk being too vague. Longer titles lose scanability. Every word must earn its place — remove articles (the, a, an) when possible, remove unnecessary adjectives, remove "guide to", "introduction to", "overview of". Start with the content word, not a filler.

**TITLE-AS-ANSWER:** The title should read as a complete answer to an implicit question. "Python 3.13 Performance Improves 30%" not "Python 3.13 Performance Update". The first title tells the reader what happened; the second tells them what the topic is. Readers want answers, not topics. Every title should pass the "so what?" test.

### From NotebookLM (source labeling — verbatim extracts)

The following rules are extracted from NotebookLM's source labeling system, which assigns descriptive titles to uploaded documents for use in the audio brief generation.

**TITLE-AS-BRIEF-HEADER:** The title is the header for a brief. It must name the source AND signal why it matters. "Q3 2024 Earnings Call Transcript: Revenue Growth Challenges" is better than "Earnings Transcript" because it communicates both identity and significance. The user should know whether to read or skip based on the title alone.

**SOURCE-IDENTITY-PRESERVATION:** Always preserve the original document's identity markers: date, author, publication, version. These are often the most distinguishing information. "Smith et al. (2024): Neural Network Pruning Survey" preserves more information than "Neural Network Survey" — the author and year help the user judge relevance and currency.

**HIGHLIGHT-CONFLICT:** When a source disagrees with other sources in the same project, flag it in the title: "Contrasting View: X argues for Y". NotebookLM's audio briefs highlight source disagreements explicitly. The title should do the same for at-a-glance consumption.

### From Mistral Medium 3.5 (conciseness — verbatim extracts)

**CONCISENESS-CONSTRAINT:** Maximum 12 words. Minimum 4 words for substantive content. A title shorter than 4 words is too vague to be useful unless the content is extremely well-known. Every word beyond 8 needs special justification. If you can't express the core idea in 8 words, the idea isn't clear enough.

**WORD-CHOICE-OPTIMIZATION:** Prefer shorter synonyms: "use" over "utilize", "show" over "demonstrate", "fix" over "rectify", "cut" over "reduce", "get" over "obtain". Shorter words are faster to scan. They also tend to be more concrete and accessible. Save longer words for when precision demands them.

### From Rewisp (memory labeling — verbatim extracts)

**MEMORY-CAPTURE-TITLE:** For auto-captures of screen content, generate titles that describe what the user was looking at — not what the content is about. "Watched: camping video in heavy snowfall" not "Winter Camping Survival Guide". The user remembers the context (what they were doing) more easily than the content summary. Memory titles answer "when did I see this?" not "what is this?"

**CHRONOLOGICAL-BOOKMARK:** For time-based captures, include the recency signal: "Seen today: ..." or "Last week: ...". This helps the user situate the capture in their personal timeline. A title that tells the user when they saw something is more useful for retrieval than one that describes the content perfectly.

### From Notion AI (page naming — verbatim extracts)

**PAGE-NAME-HIERARCHY:** Project titles > Section titles > Page titles > Database entry titles. Each level gets shorter. A project title can be a noun phrase (8-12 words). A database entry title should be a concise label (3-6 words). The hierarchy ensures that skimming works at every level. Notion AI generates page titles from first-block content.

**CONSISTENCY-PER-PROJECT:** All titles within a project should follow the same formula. Mixing question titles, declarative titles, and noun-phrase titles in one project creates cognitive friction for the reader. Choose ONE formula for the project: "Declarative: [finding] from [source]" or "Noun phrase: [topic] [angle]" — and use it for every entry. Notion AI detects the pattern from existing titles and generates new ones that match.

## Frontier gap checklist

| Reference | What they enforce | Status |
|-----------|------------------|--------|
| Perplexity AI | pithy source-linked titles, no clickbait, active voice, colon structure | ✅ Fully patched in rules above |
| Gemini Search AI Mode | scannability-first, question titles for how-to, title-as-answer | ✅ Very good |
| NotebookLM | source-identity preservation, conflict highlighting in title | ✅ Full patches |
| Mistral Medium 3.5 | strict length constraint, word-choice optimization | ✅ Fully patched |
| Rewisp | memory-oriented titles with recency | ✅ Added chronological bookmark |
| Notion AI | hierarchy consistency, formula detection per project | ✅ Added CONSISTENCY-PER-PROJECT |

## Eval hooks (how we measure punch-up)

| Eval Set | Metric | Target |
|----------|--------|--------|
| Hive-Titles-2K (2K content→title pairs) | Relevance rating (human eval 1-5) | >4.0/5.0 |
| Hive-Titles-2K | Length compliance (4-12 words) | >98% within range |
| Hive-Titles-2K | Active voice usage | >85% of non-titleable-exempt titles |
| Hive-Titles-500 (adversarial) | Empty source handling | 100% return error, 0% hallucination |
| Hive-Titles-500 | Non-titleable content detection | 100% return error |
| Hive-Titles-300 (consistency) | Same-source consistency | 100% identical titles for identical input |
| Hive-Titles-300 | Clickbait rejection | 0% banned patterns |
