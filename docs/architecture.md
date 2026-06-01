# Hive Architecture

## Principles

- Local-first by default.
- Exactly four primary app views: Field, The Colony, The Hive, and Swarm.
- Hive is not RAG with a graph. Field sources are indexed for evidence, but the product value is the persistent compiled Colony that accumulates synthesis over time.
- The four product layers are Field sources, compiled Colony, schema, and Hive graph.
- Swarm is the AI conversation and action surface over those layers; it routes notes, captures, searches, source approvals, and questions into the same backend flows instead of maintaining separate memory.
- Every derived claim keeps source provenance.
- Unpinned Field source copies expire after 14 days unless pinned.
- Full forget cascades through raw blobs, artifacts, chunks, claims, graph edges, and caches.
- Background work yields to foreground activity, thermal pressure, and Low Power Mode.

## Runtime

`HiveApp` owns the interactive UI. `HiveDaemon` owns scheduled maintenance and can be installed through a LaunchAgent during packaging. Shared logic lives in `HiveCore`.

The daemon cycle is:

1. Read current hardware/runtime profile.
2. Apply `RuntimePolicy`.
3. Purge expired unpinned Field source copies.
4. Process queued extraction jobs.
5. Rebuild relationships, graph, and Wiki.
6. Append audit events.

The packaged app places `HiveDaemon` at `Hive.app/Contents/Library/Helpers/HiveDaemon`. `scripts/install_launch_agent.sh` writes a per-user LaunchAgent for 12:00 AM local-time maintenance after validating the helper and generated plist; `scripts/uninstall_launch_agent.sh` removes that registration without touching Hive data.

The app reads the per-user LaunchAgent plist and daemon logs for visible worker status in Settings and the menu-bar extra. Manual maintenance runs the bundled helper directly and records the result in the local audit log; installing launchd still remains an explicit script/user action.

## Storage

`HiveStore` uses SQLite WAL mode and JSON payloads with indexed lifecycle columns. This keeps migrations light during early product development while preserving queryable status, retention, and deletion fields.

Core tables:

- `sources`
- `raw_blobs`
- `extraction_jobs`
- `artifacts`
- `chunks`
- `claims`
- `entities`
- `relationships`
- `wiki_pages`
- `feedback`
- `audit_log`
- `chunk_fts`

SQLite is canonical. Hive also maintains a readable vault mirror at `~/Library/Application Support/Hive/Vault/` with `AGENTS.md`, `flower-field/`, `flower-field/assets/`, `Colony/index.md`, `Colony/log.md`, and generated markdown pages. `AGENTS.md` is the schema layer: it tells the maintainer how to ingest sources, update articles, answer questions, run frontmatter queries, consolidate duplicates, download attachments, and preserve the memory boundary. User corrections made through Hive are accepted as authoritative guidance and can retract or update lower-authority derived memory.

`Vault/` is initialized as a local git repository. Hive commits maintained markdown, schema, and local assets after vault writes when git is available, while `flower-field/` source files stay ignored to avoid accidentally versioning bulky or sensitive original evidence.

## Ingestion

Manual ingestion copies files into a content-addressed raw store, writes source/blob/job records, performs deterministic extraction, chunks text, extracts initial claims/entities, and updates the audit log.

Current deterministic extraction:

- Text-like files: local text decoding.
- PDFs: local `PDFKit` selectable text extraction.
- Images/video/audio: metadata records plus `needsReview` state for local OCR/vision/transcription model packs.

## Knowledge

`KnowledgeLoop` derives relationships, applies self-healing and relevance gates, compiles The Colony, writes the vault mirror, and returns a graph snapshot. `WikiCompiler` maintains article pages, review/control pages, synthesis, internal index, and log. It does not create visible source pages; raw source names, domains, URLs, and snippets remain in evidence trails and inspectors. `WikiVaultManager` writes markdown atomically, mirrors raw sources, keeps file paths on wiki records, and removes stale generated files. Before graph rebuild, canonical same-statement claims and same-name entities are merged with combined source references so repeated extraction does not create parallel visual nodes. Relationship discovery uses source/entity/claim overlap plus Markov transition scoring, bounded simple-cycle detection for three-to-six node recurrent loops, and Hamiltonian or near-Hamiltonian paths over scoped components. Markov candidates are blocked through shared sources, shared terms, and nearby timestamps before scoring, so the app does not run naive all-pairs checks on every idle pass. Hamiltonian fallback paths are only persisted when every adjacent pair has a real transition in at least one direction. Large visible graph sets switch to a bounded edge-spring/honeycomb layout path rather than quadratic repulsion. Vector-neighbor cross-checking can be added behind the same relationship table without changing the UI contract.

The Colony is a compounding artifact, not a query-time answer cache. When a new source arrives, Hive should update existing entity/project/topic pages first, revise article sections, fold duplicates, flag contradictions, and only create a new page when no existing article clears the merge threshold. Chat and search should answer from this compiled layer first, using raw chunks only as evidence fallback when the user explicitly asks for source detail.

Hive's primary operations are encoded in the maintainer schema. Ingest preserves raw evidence, extracts claims/entities/dates, updates every relevant article, refreshes index/log, and allows one source to touch many pages. `index.md` is content-oriented: articles grouped by category with links, one-line summaries, updated dates, source counts, claim counts, and tags. Local query fallback uses `WikiSearchEngine` and `WikiIndexNavigator` to consult that catalog before drilling into page bodies. For larger vaults, `QMDWikiSearchTool` provides the command plan for `qmd collection add`, `qmd context add`, `qmd update`, `qmd embed`, `qmd search`, `qmd vsearch`, `qmd query`, `qmd get`, `qmd multi-get`, `qmd status`, and `qmd mcp`; when qmd is not installed, the same call path falls back to deterministic local metadata search. `log.md` is chronological and parseable: entries use `## [yyyy-MM-dd HH:mm] operation | target`, so `grep "^## \\[" log.md | tail -5` returns recent work. Query answers can be filed back into `answer` pages through `WikiOperationEngine`, keeping useful comparisons and analyses in the versioned Wiki instead of losing them in chat. Marp decks can be generated as local markdown slide files from selected Colony pages. `WikiMaintenancePlanner` turns touched pages, lint findings, and contradictions into concrete bookkeeping tasks for refreshing summaries, adding cross-references, updating `index.md`, appending `log.md`, and reviewing conflicts. Lint produces the `Wiki Health` page and now checks contradictions, stale claims, orphan pages, missing cross-references, missing concept pages, weak claims, unanswered questions, and source/research gaps.

Hive supports Dataview-style frontmatter queries through fenced `hive-query` and `dataview` blocks. These queries filter compiled Colony pages by `kind`, `tags`, frontmatter keys, source/claim counts, and update dates, then render deterministic markdown tables inside the article body. The query layer operates on compiled Colony metadata, not raw source chunks.

Markdown image links can be localized into `Vault/flower-field/assets/`. The attachment downloader fetches remote image URLs, writes them to the fixed asset directory, and rewrites article markdown to local paths so the maintainer can read text first and inspect referenced images separately.

The Hive graph is the spatial view of the compiled Colony. Nodes represent useful user-centered memories, projects, traits, constraints, and article concepts. The graph should reveal hubs, clusters, selected paths, and orphans from The Colony; it should not show bare source fragments or act as a browser-history visualization.

Browser history is stored as one sanitized Field item per entry. Each row gets its own source record, raw capsule, artifact, chunk, claim, retention state, and provenance trail. Legacy grouped profile capsules are retired on the next import so the Field page stays inspectable at the same granularity as the user's actual history items. Quick notes, menu-bar current-page screenshot captures, dropped text, dropped images, screenshots, and normal file/folder imports all enter through the same ingestion path. Manual file ingestion also mirrors the raw source into `Vault/flower-field/`; raw delete, retention expiry, and full forget remove that mirror.

`ReviewQueueBuilder` turns trust signals into a small, ranked Needs Confirmation queue for the Wiki. It is claim-only: raw sources are never approval targets. Hive asks for confirmation only when understood claim/wiki content has effective certainty below 70%. Contradictions, suspect status, missing provenance, and incidental browser signals reduce that effective certainty instead of creating separate process rows. User-deferred claim actions such as merge, split, or ask-later can still share the same row. User-marked incidental claims are treated as resolved and removed from the queue. Retracted claims are excluded, and queue entries keep the original claim and source references so clicking the row opens the existing provenance/correction controls instead of creating a separate workflow.

`GraphPrivacyFilter` keeps the default Hive web durable-first by removing low-confidence browser/incidental nodes and their edges. The UI can opt back into those nodes with the low-confidence toggle so browser history remains auditable without dominating the knowledge web. Graph search expands title matches to one-hop neighbors so results keep source and relationship context.

The graph view applies the same timestamp bounds to global search and topic webs. The UI exposes this as a compact time-window scrubber (`All`, `7d`, `30d`, `90d`, `1y`), while the graph engine enforces the actual source/claim/entity date filtering before edge inclusion.

The graph inspector is also a control surface. Claim nodes can be approved, denied, marked incidental, marked important, deferred, queued for merge/split review, or deleted from the graph; source nodes can be pinned, raw-deleted, or fully forgotten with confirmation; non-claim graph nodes persist feedback records so ranking and future review queues can learn from graph-level user intent.

`GraphEvidenceFilter` is applied before the Hive canvas is shown. It removes internal process/path edges, auto-generated insight nodes, weak single-source extracted topics, and self-edges so the default graph reads as a personal evidence map instead of an algorithm trace. The raw relationship records still remain in the local store for future offline audits and stronger model review, but the primary UI only shows relationships that a user can understand without implementation vocabulary.

## Safety

- `URLSafetyPolicy` blocks non-HTTP(S), localhost, local/private/link-local/multicast, and metadata IP targets.
- `URLSafetyPolicy` also blocks common private-address disguises such as integer/hex IPv4, IPv4-mapped IPv6, and private `nip.io`/`sslip.io` aliases.
- `BrowserSnapshotService` creates copy-only SQLite snapshots through SQLite backup before reading browser databases.
- `BrowserEngagementScorer` treats passive browser appearances as incidental unless there are stronger signals like saves, downloads, shares, repeats, or long engaged sessions.
- Browser database snapshots are transient and deleted immediately after sanitized capsule extraction.
- Browser profile consent IDs are path-hashed; unconsented History database paths are not persisted in audit or consent records.
- Browser-history sources can be forgotten as a grouped cascade through the same full-forget path used by individual sources.
- Raw delete removes original blobs and scrubs extracted artifact text, chunk text, embedding references, and FTS rows into provenance capsules.
- Full forget scrubs source metadata, claim statements, wiki pages, feedback, and audit rows that reference the forgotten source, then checkpoints and vacuums the local SQLite store.
- Local export serializes Markdown and structured JSON while excluding raw blobs, copied browser snapshots, secrets, security bookmarks, fully forgotten sources, and retracted claims.
