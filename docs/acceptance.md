# Acceptance Criteria

## First Five Minutes

- App opens to the three-view shell without requiring network access.
- User can import a file or folder into Field.
- Browser history imports create one Field row per sanitized history entry, not one grouped profile blob.
- The Field dropzone accepts files, folders, text drops, image drops, and screenshots.
- The menu bar exposes quick capture actions for a Quick Note and a screenshot; both enter the same Field ingestion/provenance path.
- The menu bar can capture the current foreground page/window screenshot with a user command and feed the markdown context plus local image into Field.
- Imported text/PDF sources create source, raw blob, artifact, chunk, claim, entity, audit, Wiki, and graph records.
- Hive creates `Vault/AGENTS.md`, `Vault/flower-field/`, `Vault/flower-field/assets/`, `Vault/Colony/index.md`, and `Vault/Colony/log.md`.
- Hive initializes `Vault/` as a local git repository for markdown/schema/assets when git is available.
- Imported manual files are mirrored into `Vault/flower-field/`, and compiled article/synthesis/health markdown pages are written under `Vault/Colony/`.
- The generated `Vault/AGENTS.md` describes Hive's four-layer contract: Field sources, compiled Colony, schema, and Hive graph.
- The Colony is a persistent compiled artifact; chat/search answer from the compiled Colony before falling back to raw chunks.
- The Wiki displays claims with confidence and uncertainty.
- The Wiki exposes an index/category rail over maintained markdown pages, not just a single overview dump.
- The Wiki supports selecting multiple articles and consolidating them into one canonical article.
- The Wiki supports `hive-query` and Dataview-style frontmatter blocks that generate deterministic dynamic tables/lists from compiled article metadata.
- `Colony/index.md` is a content catalog grouped by page kind with link, summary, updated date, source count, claim count, and tags.
- `Colony/log.md` uses chronological grep-friendly headings shaped like `## [yyyy-MM-dd HH:mm] operation | target`.
- Hive exposes a local wiki search tool that plans current qmd collection/context/update/embed/search/vsearch/query/get/multi-get/status/MCP commands and falls back to deterministic index/summary search when qmd is unavailable.
- Hive produces bookkeeping tasks for index refresh, log append, summary refresh, cross-reference repair, contradiction review, and research gaps after wiki maintenance.
- `Command-Shift-D` downloads remote images for the selected Wiki article into `Vault/flower-field/assets/` and rewrites image links to local paths.
- Chat answers can be saved back into the Wiki as cited answer pages.
- The Colony can generate a local Marp markdown slide deck from selected article content.
- The command palette and chat sheet expose filing the latest answer as a Wiki artifact so query work compounds.
- The Wiki Health page reports contradictions, stale claims, orphan pages, missing cross-references, missing concept pages, unanswered questions, and research gaps.
- User corrections made through Hive become authoritative guidance and trigger contradiction cleanup.
- Selecting a Wiki claim opens source trail, evidence spans when available, correction, and feedback controls.
- The Wiki exposes compact Needs Confirmation rows only for understood claim/wiki content whose effective certainty is below 70%, plus user-deferred claim actions.
- Selecting a Needs Confirmation claim opens the same source trail, evidence, correction, and feedback controls as the normal claim list.
- The Wiki Overview summarizes the review queue count without dumping incidental browser items into the reading surface.
- The Wiki Overview does not expose graph-health counters or internal algorithm names.
- Needs Confirmation rows expose compact non-destructive triage actions for confirm, this matters, and this was incidental.
- Claims the user has already approved, marked important, or marked incidental are treated as resolved and removed from Needs Confirmation.
- The Hive view displays useful claim, topic, project, and user-memory nodes with straight memory edges; raw source nodes stay out of the default graph.
- The default Hive graph hides low-confidence browser/incidental nodes until the low-confidence toggle is enabled.
- The default Hive graph hides algorithm/path edges, auto insight nodes, weak single-source auto topics, and self-edges from the primary canvas.
- The Hive graph inspector uses human relationship labels such as `From source`, `Mentions`, and `Supports`, not internal predicate names.
- Sidebar status and runtime/process counters are not shown in the primary navigation.
- Graph search keeps one-hop context around matches instead of isolating matching nodes.
- Topic webs expand through local relationship context rather than behaving like a text-only graph search.
- Topic webs can be saved and deleted without deleting underlying sources, claims, or graph data.
- Markov graph analysis detects multi-step local loops, not only direct or triangular relationships.
- Hamiltonian/near-Hamiltonian path edges are never created for disconnected adjacent node pairs.
- Same-statement claims and same-title canonical entities merge into one graph node with combined provenance instead of duplicating visual nodes.
- Canvas labels are collision-aware; hidden labels do not make nodes unclickable.
- Global graph rendering uses visible-node budgets so normal search/filter changes do not lay out the full vault.
- Large graph rendering uses a bounded fast layout path so visible sets with hundreds or low thousands of nodes do not trigger quadratic force work.
- Graph date filters apply to timestamped source, claim, and entity nodes.
- Topic webs respect the selected graph time window instead of pulling stale nodes back into scope.
- Hive exposes a compact time-window scrubber for All, 7d, 30d, 90d, and 1y scopes.
- Markov relationship scoring uses bounded source/token/time candidate blocks instead of unbounded all-pairs scans.
- Canvas graph nodes have an accessibility representation and list alternative.
- Every visible graph node can be selected without selecting empty space.
- Empty canvas clicks clear stale followed paths so the graph does not remain dimmed without an inspector.
- Followed graph paths are visibly highlighted, direction markers follow the user's traversal direction, and paths can be continued from connected edges.
- Selected claim nodes expose approve, deny, incidental, matters, ask-later, merge-review, split-review, and delete controls in the graph inspector.
- Selected source nodes expose pin, raw delete, and full forget controls in the graph inspector with confirmation.
- Selected topic/project/insight nodes can persist matters/incidental/ask-later feedback for future ranking.
- `Command-1/2/3/4` switches the four primary views.
- `Command-K` opens one deterministic command/search overlay without adding another primary view or racing the chat sheet.

## Retention And Deletion

- Unpinned Field source copies expire after 14 days.
- Pinned Field source copies survive retention expiry.
- Raw delete removes the original blob, scrubs extracted text/chunks/FTS, and keeps derived claims with minimal provenance.
- Full forget retracts claims and removes raw blobs, artifacts, chunks, pending jobs, and FTS entries.
- Full forget scrubs source metadata, claim text, wiki pages, feedback notes, old audit rows, and local SQLite free pages for forgotten content.
- Full forget also removes the raw-source vault mirror and regenerated markdown references to the forgotten content.
- Browser history can be fully forgotten as a grouped local deletion path after confirmation.

## Trust

- Browser passive history is incidental by default.
- Browser profile IDs stored before consent do not contain local History database paths.
- Browser SQLite snapshots are transient and deleted after import.
- Browser snapshot fallback fails closed when WAL sidecars exist and SQLite backup cannot be used.
- Private/local URLs are blocked from online retrieval.
- Machine learning features are complementary to the local Wiki, graph, and deterministic rules; Hive remains useful when synthesis is unavailable.
- Proactive suggestions require factual attribution, visible correction actions, and a confidence threshold before they appear in primary surfaces.
- Confidence appears as plain language, never as raw percentages, unless the user is looking at an explicitly statistical/debug context.
- Explicit feedback uses direct consequences such as `This is right`, `This is wrong`, `This was incidental`, and `Ask me later`, and Hive persists the result immediately.
- Hive explains limitations in user terms and offers next actions such as adding evidence, correcting The Colony, or asking a narrower question.
- Model output is proposal-only: it cannot delete, rewrite, or promote memory without schema validation and a reversible user-visible path.
- Claims can be approved, denied, marked incidental, marked important, deferred, or deleted.
- Claims can be corrected through replacement records that preserve lineage and source spans.
- Retracted claims do not appear in Needs Confirmation.
- Local export writes Markdown and JSON without raw blobs, browser snapshots, secrets, or security bookmarks.
- Local export excludes fully forgotten sources and retracted claims.
- Every claim shown in Wiki has source references or a visible uncertainty label.

## Runtime

- Heavy background work is paused while the user is active unless manually requested.
- Low Power Mode pauses background inference-class work.
- Serious or critical thermal pressure blocks non-interactive work.
- Maximum compute mode is explicit and selects stronger local model candidates while still respecting critical thermal safety.
- Dropping a compatible local model file or folder into the Models directory updates local availability without downloading or starting the model.
- The LaunchAgent installer validates its generated plist and the uninstaller reverses launchd registration without deleting user data.
- Settings and the menu bar expose background-worker status without installing the LaunchAgent automatically.
- Manual maintenance can run the bundled daemon from the app when the helper exists.

## Verification

Run:

```bash
scripts/acceptance.sh
```
