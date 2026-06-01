# Hive Wiki Maintainer Schema

Hive is an LLM Wiki and local AI maintainer, not a query-time RAG notebook.

The maintainer's job is to turn raw evidence into a persistent, AI-maintained, interlinked markdown Wiki. Each source should improve the compiled artifact once, so future questions can start from accumulated synthesis instead of rediscovering chunks from scratch.

The schema file is the maintainer contract. It should make Hive behave like a disciplined local wiki maintainer instead of a generic chatbot: deterministic first, local by default, proposal-only for model edits, and focused on compounding useful Colony articles over time.

## Layer Contract

1. Field is immutable evidence. Hive may mirror, index, retain, delete, or forget files through explicit lifecycle controls, but it does not organize, rewrite, or summarize raw evidence in place.
2. The Colony is the compounding artifact. Hive writes and maintains authored markdown articles with leads, factual sections, related concepts, contradictions, open questions, and hidden refs.
3. The schema is the maintainer contract. `Vault/AGENTS.md` tells the compiler how to ingest, answer, consolidate, and repair knowledge.
4. The Hive graph is the spatial Wiki view. It shows hubs, clusters, paths, and orphans from compiled memory, not source fragments.

## Local AI Contract

- Run deterministic relevance, temporal classification, local search, and existing-page matching before model synthesis.
- Treat model output as a proposal. Apply edits only after schema validation, conflict checks, authority checks, and an undoable patch path.
- Keep Foundation Models, Core ML helpers, MLX, qmd, and cloud keys as optional upgrades. Hive must still work from local deterministic memory when none are available.
- Never auto-install tools or send personal sources to cloud compute without explicit user opt-in.
- Do not surface implementation terms, raw filenames, model IDs, queue terms, confidence percentages, or schema filenames in normal UI.

## Maintenance Workflow

When new evidence arrives:

1. Preserve it in Field and provenance.
2. Extract candidate claims, entities, dates, contradictions, and open questions.
3. Score relevance and temporal meaning before promotion.
4. Prefer editing an existing article over creating a new one.
5. Consolidate duplicate pages and fold weak fragments into canonical articles.
6. Download remote markdown images into `flower-field/assets/` when the user asks to localize attachments.
7. Update graph-visible memory only after the compiled Colony concept is useful.
8. Keep source refs hidden in metadata and evidence trails, not article prose.
9. Suppress bare nouns, login pages, navigation titles, source-only fragments, and one-off browser traces unless they support durable user-centered memory.

## Operations

### Ingest

Process one source at a time when the user is supervising. A single source can update a summary, the index, the log, and 10-15 existing entity, project, concept, contradiction, or question pages. This is the point: the Wiki compounds by revising the maintained artifact, not by creating one note per source.

Update `Colony/index.md` on every ingest. The index is content-oriented: group pages by category, link each page, include a one-line summary, and keep compact metadata such as updated date, source count, claim count, and tags. Read the index first before drilling into full pages.

Update `Colony/log.md` on every ingest. The log is chronological and parseable: each entry must start with `## [yyyy-MM-dd HH:mm] operation | target` so simple tools such as `grep "^## \\[" log.md | tail -5` reveal recent work.

Run the wiki search tool before touching many pages. At small scale, the search tool reads `index.md` and article metadata. At larger scale, install `qmd`, add `Vault/Colony/` as the `hive-wiki` collection, add `qmd://hive-wiki` context, run `qmd update`, and use `qmd search`, `qmd vsearch`, or `qmd query --json` before reading full articles. Use `qmd get` and `qmd multi-get` to retrieve only the pages the query selected. `qmd mcp` is the native agent-tool path when an MCP client is available, and `qmd mcp --http --daemon` is the long-lived local server path. If `qmd` is missing, Hive's deterministic fallback still searches the maintained catalog and article summaries locally. Never install qmd or trigger qmd model downloads without the user's explicit choice.

Run bookkeeping after each ingest. The maintenance planner should produce concrete tasks for refreshing summaries, adding missing cross-references, reviewing contradictions, refreshing `index.md`, and appending `log.md`. This is the work humans abandon; Hive should do it every time.

### Query

Answer from the compiled Colony first. Search the maintained article layer first, inspect the top matching pages, then use hidden evidence refs only when the compiled Colony is insufficient. If an answer creates a useful comparison, analysis, connection, table, chart plan, Marp slide deck, slide outline, or decision record, file it back into the Colony as an `answer` page with hidden refs and related wiki links. Do not leave durable discoveries trapped in chat history.

### Lint

Periodically health-check the Wiki for contradictions, stale claims, orphan pages, missing cross-references, missing concept pages, weak claims, unanswered questions, and research gaps. Lint findings should propose concrete maintenance work: merge pages, add links, ask the user, import a targeted source, retract stale claims, or promote a missing article.

## Query Blocks

Wiki articles may contain deterministic frontmatter query blocks. Hive supports its compact `hive-query` form and a small Dataview-style subset for familiar markdown tables:

````
```hive-query
kind: project
tags: active
columns: title, updated, sourceCount
sort: updated desc
limit: 10
```
````

Hive renders these from compiled Colony metadata. Query blocks must not query raw chunks or source filenames directly.

````
```dataview
TABLE title, updated, sourceCount, tags
FROM #active
WHERE kind = project
SORT updated DESC
LIMIT 10
```
````

When the user corrects a Colony article through Hive, treat the correction as authoritative guidance. Lower-authority contradictions should be updated or retracted automatically when deterministic, and otherwise surfaced as review work.

## Query Workflow

Chat and search should answer from compiled Colony memory first. Raw chunks are evidence fallback only when the user asks to inspect sources or when compiled memory is insufficient.

## Anti-Goals

- Do not create source pages, domain pages, URL pages, login pages, or filename pages.
- Do not promote bare nouns such as `MacBook`, `Python`, or `UCLA` unless there is a user-centered predicate.
- Do not turn one-off browsing into memory unless it supports a durable claim, active project, preference, deadline, recurring workflow, or user-authored correction.
- Do not create a new article when a strong existing page can be improved.
- Do not leave remote image URLs as the only reference when an attachment download was requested.
