# M20 — Sheets UI Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M4 Honeycomb provenance, M10 Sidecar scope, M11 Studio approvals, M12 Command Center, M13 Projects/Tasks, M14 Sheets v1 data contract, M19 Connectors v1.
> **Scope:** a browser-native, Honeycomb-backed Sheets UI: accessible grid editing, saved views, deterministic formula presentation, safe CSV flows, source provenance, basic charts with accessible fallbacks, and reviewable agent proposals.

## 1. Goal

M20 makes the existing M14 sheet contract usable as a real browser-native workspace. A user can open a small source-backed table from a project, inspect and edit typed cells, filter/sort/group rows, understand formula results and errors, trace values to sources, import/export with explicit safety warnings, save a reproducible view, and render a basic chart without losing the underlying table.

The UI is a projection and command surface over Honeycomb-backed sheet artifacts. It is not a second database, a generic dashboard, an Excel compatibility promise, or an AI-generated spreadsheet theater surface.

## 2. Non-goals and explicit deferrals

M20 does not add macros, VBA, scripting, arbitrary formulas, external refresh, network functions, workbook compatibility, real-time collaboration, pivot-table parity, slicers, rich conditional formatting, formula autofill heuristics, autonomous data mutation, or chart images without retained data.

Deferred:

- multi-user collaboration and cloud conflict resolution beyond M6 storage policy;
- spreadsheet plugins, custom functions, JavaScript/Python execution, and external workbook links;
- scheduled connector refresh and automatic chart refresh from external systems;
- advanced pivot tables, dashboards, presentations, geographic maps, and animation-heavy data graphics;
- automatic type changes based only on model suggestions;
- model-generated formulas or transforms that bypass M11 approval;
- a UI-only cache that can become authoritative when Honeycomb is unavailable.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository contains `HiveSheet`, typed columns/rows/cells, `SheetStore` CRUD, formula-version metadata, CSV import/export, a deterministic `SheetFormula` evaluator, source IDs on rows, `SheetsPanel`, and a split `SheetEditorView` with basic editing, filter, sort, row/column actions, formula-bar behavior, and CSV actions. M14 defines the stronger canonical schema, provenance, query, chart, accessibility, CSV, and agent boundaries.

These are code-present primitives, not verified M20 behavior. Current model limitations—including minimal column kinds, incomplete formula semantics, basic CSV parsing, absent durable saved-query/chart objects, and partial provenance display—must not be described as complete M20 capability.

### 3.2 Authority table

| Concern | Authority | M20 rule |
|---|---|---|
| Durable sheet state | Honeycomb `SheetStore` / artifact node | UI never persists an alternate canonical copy. |
| Revision/conflict | Honeycomb revision and M14 snapshot contract | Stale edits/proposals fail closed; no invisible merge. |
| Cell identity | Stable row/column IDs | Array position is presentation only. |
| Formula result | Versioned deterministic evaluator | UI displays typed result/error; it never executes formula text. |
| Saved view/query | Versioned query object tied to sheet revision | A view is pure and cannot mutate sheet state. |
| Chart | Derived chart object tied to saved query/input revision | Stale inputs are disclosed, never silently refreshed into a new meaning. |
| Source lineage | Honeycomb source/claim edges and row/cell lineage | Sorting/filtering never severs provenance. |
| Agent proposal | M11 approval/EventLedger | Model output is an inert patch until approved and revalidated. |
| Export/delete | M0/M4 lifecycle and recovery authority | Scope, warnings, manifest, and deletion effect are previewed. |
| Accessibility | SwiftUI/AppKit accessibility tree plus textual fallbacks | Charts never become the only representation of data. |

## 4. Information architecture and progressive disclosure

Sheets appears from a project, source-backed brief, Command Center, or an explicit user command. It must not become a first-launch dashboard or request connector permissions merely because the user opens the browser.

The surface has five bounded regions:

1. **Sheet navigator:** searchable list of sheets with project, row/column count, provenance class, last-updated time, and unavailable/stale status.
2. **Editor toolbar:** title, save/revision status, undo/redo if backed by the current revision contract, import/export, view/query, chart, provenance, and delete actions.
3. **Formula/value bar:** selected cell identity, raw value/formula, typed result/error, source indicator, and edit/commit state.
4. **Grid:** headers, typed cells, row identity, selection, inline editing, filter/sort/group projection, and stable source markers.
5. **Inspector/secondary surfaces:** source lineage, query definition, chart configuration, warnings/loss report, and proposal diff. These are explicit panels or popovers, not hidden hover-only information.

When a capability is unavailable, the UI states why and preserves the table path. AI, charts, connectors, and remote models may be unavailable without blocking browsing or direct local sheet edits.

## 5. Grid interaction contract

### 5.1 Selection and editing

The grid uses a single authoritative editing controller. Selection is identified by stable `(sheetID, revision, rowID, columnID)` plus a presentation coordinate. Inline edit buffers are not durable until an explicit commit.

Required behaviors:

- click selects; direct typing enters edit mode without losing the selected cell;
- Enter commits and moves according to the documented keyboard policy;
- Tab and Shift-Tab move across visible columns; arrows move within the current view;
- Escape cancels the edit buffer and restores the last committed value;
- formula-bar and inline editing share one buffer and one commit path;
- invalid typed values remain visible as an explicit invalid state with a recovery action;
- edits commit against the revision that was rendered; stale revisions reopen with a conflict explanation;
- deleting a row/column requires a preview of affected formulas, queries, charts, and provenance;
- private or redacted source-backed values never become visible through selection, copy, tooltips, or accessibility labels without scope permission.

### 5.2 View projection

Filter, sort, and group operate over a snapshot and return stable row IDs. A filtered or sorted index is never used as the mutation target. Hidden rows are not deleted and cannot be confused with missing rows. Empty results explain whether the view is empty, the filter excludes all rows, or the source is unavailable.

Grouping is a presentation projection in M20. It does not create a second row hierarchy or mutate source row identity. If grouping is unsupported for a type, the control is unavailable with an explanation rather than silently coercing values.

### 5.3 Performance bounds

M20 targets small local sheets, not unbounded workbooks. The UI must declare practical limits for rendered rows, columns, cell text length, formula range size, and chart points. Large sheets use bounded paging/virtualization or an honest read-only/deferred state. A slow query or render is cancellable and cannot block the browser shell.

## 6. Typed columns and cell presentation

The UI renders the M14 type contract without inventing implicit coercions. Text, number, boolean, date/datetime, URL, enum, formula, null, invalid, unresolved, and redacted states have distinct but compact presentations.

Type changes are schema mutations, not formatting changes. Before applying one, the UI previews values that would become invalid or unresolved and names affected formulas/views/charts. Locale-specific display formatting never changes stored values. Dates show the chosen timezone/parse policy when ambiguity matters.

Formula cells display both the expression and the evaluated state. A cached value is marked stale whenever the input revision, dependency hash, schema, or formula-engine version no longer matches.

## 7. Formula UI and deterministic errors

M20 consumes M14's evaluator; it does not broaden its grammar in the UI. Formula text is parsed by the deterministic engine and never passed to JavaScript, shell, a model, or an embedded browser.

The UI must:

- show the evaluator version for formula cells when a user inspects details;
- distinguish parse, unknown reference, type, divide-by-zero, cycle, and limit errors;
- show a bounded dependency summary and a stable cycle path where available;
- preserve unsupported formulas as inert text instead of attempting a best-effort execution;
- disclose when a formula result is unavailable because a source/input is redacted, missing, stale, or unresolved;
- prevent a formula commit when validation fails, while preserving the user's draft for correction;
- avoid displaying an error as a plausible numeric value;
- allow an explanation request to produce advisory text without changing the formula.

A formula proposal from an agent is rendered as a patch: target cell/range, old value, proposed formula, expected result/error, dependency set, evaluator version, privacy class, and target revision. Applying it requires M11 approval and fresh revision validation.

## 8. Filters, sorts, groups, and saved queries

A saved query is a pure, versioned description:

```text
query_id: stable ID
sheet_id: stable ID
input_revision: exact source sheet revision
selected_columns: stable column IDs
filters: typed predicates
sort_keys: stable column IDs + direction + null policy
group_keys: stable column IDs
aggregates: allow-listed functions and aliases
row_limit: bounded integer
query_version: evaluator/query semantics version
created_by / created_at / updated_at
```

Query execution is deterministic for a pinned input revision. Null ordering, invalid-value handling, text comparison, date timezone, and tie-breaking are explicit. The result includes the input revision, row IDs, warnings, and a stable ordering key.

Changing a sheet does not silently rewrite a saved query. The view becomes stale or offers an explicit “rebase to current revision” preview. Rebase is a new version and reports changed filters, columns, row counts, and chart inputs.

## 9. Charts and accessible fallbacks

M20 supports only bounded basic charts backed by saved queries: bar, line, and scatter where the query result satisfies the chart's typed input contract. A chart stores its query ID, input revision, selected series, axis semantics, null policy, aggregation, and accessibility description.

Every chart has:

- a concise title and plain-language summary;
- explicit x/y/series labels and units when known;
- a visible stale/filtered/aggregated/null-data disclosure;
- keyboard-reachable focus for data points or a table view;
- a companion accessible data table containing the exact plotted values;
- a text summary that does not depend on hover or color alone;
- high-contrast-safe encodings using labels, patterns, shapes, or line styles where applicable;
- reduced-motion behavior that disables animated transitions without hiding state;
- a truthful unavailable state when data types, limits, or query errors prevent rendering.

Charts never fabricate data, interpolate missing values without disclosure, or accept arbitrary HTML/script/remote image configuration. If the chart renderer fails, the query result and accessible table remain available.

## 10. CSV import/export UI

M20 exposes M14's safe CSV contract through an explicit preview flow rather than a one-click destructive import.

### 10.1 Import preview

Before persistence, show file name, bounded size, encoding/BOM, delimiter, row/column estimate, inferred types, formula-like cells, malformed rows, ambiguous dates, and expected warnings. The user chooses a new sheet or an explicit replacement target; replacement always previews affected revision/provenance and requires confirmation.

Imported formula-looking cells are inert text unless the user explicitly creates a local formula through the supported formula editor. The importer must not silently interpret `=`, `+`, `-`, `@`, tabs, or control characters as executable formulas.

Partial import is either atomic failure or an explicitly reviewable result with exact coordinates and counts. No malformed row disappears silently.

### 10.2 Export

Export presents format, delimiter, encoding, newline, formula mode, null policy, and consumer-safety profile. The manifest records sheet ID, revision, query/view if filtered, evaluator version, provenance policy, warnings, and any loss/escaping transformations.

Offer separate **Human View / spreadsheet-safe** and **Raw Interchange / contract-preserving** profiles. Formula-triggering text is escaped according to the selected profile, with a warning when the representation changes. Formulas may export as inert expressions or calculated values only when explicitly selected.

Export never places sensitive source content on the clipboard automatically. Clipboard copy has a scope-aware confirmation or is unavailable for redacted values.

## 11. Provenance and source inspection

Every source-backed row exposes a compact source marker and an inspector path. The inspector shows source identity, version, retrieval time, capture/connector class, evidence span where available, transform name/version, and provenance quality.

Provenance must survive:

- sort/filter/group projections;
- direct edits and user corrections;
- deterministic transforms and formula derivations;
- CSV manifests and re-import where the contract supports stable IDs;
- chart/query selection;
- source deletion or connector revocation.

When a source is deleted or revoked, visible derived values may remain only under M4/M19 lifecycle rules and must be marked provenance-degraded. Revoked source content is excluded from retrieval immediately even if physical index cleanup is pending.

Cell text, imported instructions, connector content, and model output are untrusted data. A source inspector must never offer a direct “run instruction” action from content.

## 12. Agent proposal and approval UX

Agents can propose column mappings, formulas, deterministic transforms, anomaly explanations, query definitions, or chart configurations. They cannot mutate the live sheet by returning JSON, markdown, or formula text.

Every proposal includes:

```text
proposal_id
sheet_id + target_revision
selected_scope (cells/ranges/columns)
old_snapshot / proposed_patch
expected row/cell counts
formula/transform/query/chart version
provenance impact
privacy and remote-model status
validation result and warnings
approval_scope_key
```

The UI renders a before/after diff, not only a natural-language summary. Approval is single-use or explicitly bounded, expires, and is rejected if the sheet revision, selected scope, or policy changes. EventLedger records proposal, preview, approval/denial, stale rejection, application, verification, and rollback/compensation result without raw secrets or unnecessary cell bodies.

Prompt injection in a cell, source, imported file, or connector record cannot alter the proposal's scope, authority, permission, or approval state.

## 13. Persistence, deletion, and recovery

Direct edits, imports, query saves, chart saves, proposal applications, exports, and deletes have typed lifecycle receipts. A crash during an import or edit leaves either the prior canonical revision or a recoverable, explicitly quarantined operation—not a half-visible sheet.

Sheet deletion is scoped and previewed. It reports affected queries, charts, source edges, project references, FTS/vector entries, exports, and pending proposals. User-derived tasks/briefs are not silently deleted when a source sheet is removed; their provenance state is updated according to M4/M13 rules.

Restore creates a new current revision where the retained snapshot permits it. It does not silently resurrect revoked connector data or deleted source content.

## 14. Accessibility and native interaction

M20 is complete only when the grid and its alternatives work with keyboard navigation, VoiceOver, Dynamic Type, Increase Contrast, Reduce Motion, and reduced transparency settings supported by the product.

Requirements:

- every cell announces sheet, column header, row identity/position, type, value state, and editability;
- headers expose sort direction and filter state;
- filtered/grouped views disclose visible/total counts and never announce stale coordinates;
- source, stale, invalid, redacted, and unavailable states are textually available;
- charts expose their summary and an equivalent data table without hover;
- focus remains visible after edits, errors, panel dismissal, and stale-conflict recovery;
- large text does not clip the formula bar, toolbar, warnings, or delete/recovery controls;
- reduced motion disables chart/grid transitions but preserves status changes;
- destructive actions use labels and confirmations, not color alone.

## 15. Work packages

### M20-A — Canonical grid projection and navigator

Build the read-only projection first: sheet navigator, revision/status display, stable row/column identity, bounded grid virtualization, selection, source markers, empty/error states, keyboard navigation, VoiceOver semantics, and browser-first behavior.

**Done when:** a clean profile can open a Honeycomb sheet, inspect all visible data and source states, navigate without a mouse, and remain usable when AI/charts/connectors are unavailable.

### M20-B — Typed editing, schema warnings, and safe CSV flows

Wire one commit path for inline/formula-bar edits, typed validation, stale-revision rejection, row/column mutation previews, import preview, export profiles, loss reports, and recovery receipts.

**Done when:** edits never target a stale presentation index, invalid values remain explicit, CSV formula injection is inert, partial imports are visible, and crash/restart behavior is truthful.

### M20-C — Views, formulas, and provenance inspection

Expose deterministic formula states/errors, filter/sort/group projections, saved query definitions, revision pinning/rebase, cell/row lineage, source inspectors, and deletion/revocation degradation.

**Done when:** a user can reproduce a saved view against a pinned revision, trace a displayed value to retained evidence, and understand every stale or degraded state.

### M20-D — Charts and accessible data representations

Add bounded bar/line/scatter chart objects over saved queries, stale-input detection, explicit null/filter/aggregation disclosures, keyboard/data-point access, textual summaries, and a complete table fallback.

**Done when:** chart output is reproducible from a retained query/revision, never fabricates values, and a VoiceOver/keyboard user can obtain the same data without the graphic.

### M20-E — Reviewable agent proposals and integrated validation

Add proposal diff rendering for formulas/mappings/transforms/queries/charts, M11 approval and M12 command receipts, fresh-revision checks, EventLedger evidence, prompt-injection fixtures, and degraded-mode validation.

**Done when:** no model output can mutate a sheet without exact approval, stale proposals fail closed, remote scope is disclosed, and ordinary browsing plus direct local Sheets use remains complete with AI disabled.

## 16. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M20-01 | Open sheet with stable IDs | Grid renders canonical rows/columns; no UI-only authority |
| M20-02 | Empty sheet | Actionable empty state; create/import remains available |
| M20-03 | Honeycomb unavailable | Browser works; sheet shows honest unavailable state |
| M20-04 | Revision changes while open | Stale status appears; edit requires reload/rebase |
| M20-05 | Filtered row edit | Mutation targets stable row ID, not display index |
| M20-06 | Sorted row delete | Preview names stable row and affected lineage |
| M20-07 | Keyboard grid navigation | Arrow/Tab/Enter/Escape behavior deterministic |
| M20-08 | VoiceOver cell | Header, row identity, type, value, state announced |
| M20-09 | Dynamic type | Toolbar/formula/status controls remain reachable and readable |
| M20-10 | Reduce motion | No essential transition or status disappears |
| M20-11 | Typed number/bool/date edit | Valid values commit; invalid values remain explicit |
| M20-12 | Formula-bar/inline parity | One buffer and one commit result |
| M20-13 | Formula parse error | Draft preserved; typed error shown; no mutation |
| M20-14 | Formula divide/cycle/ref/limit error | Specific error and recovery, never plausible value |
| M20-15 | Formula version mismatch | Cached result marked stale/recomputed by supported engine |
| M20-16 | Unsupported formula/function | Inert text or rejected formula; no script/model execution |
| M20-17 | Filter/sort/group projection | Stable ordering and row identity preserved |
| M20-18 | Empty filtered view | Distinguishes no rows from unavailable source |
| M20-19 | Saved query pinned revision | Repeatable result and stable tie-breaking |
| M20-20 | Rebase stale query | New version with changed columns/counts/warnings disclosed |
| M20-21 | Source-backed row | Inspector resolves source/version/evidence |
| M20-22 | Sort/filter lineage | Source marker follows row, not screen position |
| M20-23 | Source deletion/revocation | Value state and provenance degradation disclosed |
| M20-24 | CSV BOM/delimiter/CRLF | Preview reports configuration; bounded import |
| M20-25 | Quoted commas/quotes/newlines | Values preserved within contract |
| M20-26 | Formula-like CSV text | Inert text; warning; no execution |
| M20-27 | Ambiguous dates | Unresolved with coordinate and chosen parse path |
| M20-28 | Malformed/oversized CSV | Bounded failure or explicit partial report; no silent drop |
| M20-29 | CSV replacement target | Scope/revision/provenance preview before overwrite |
| M20-30 | Excel-safe export | Triggering strings escaped with warning/profile recorded |
| M20-31 | Raw interchange export | Manifest records exact contract and warnings |
| M20-32 | Export filtered view | Query and input revision included in manifest |
| M20-33 | Clipboard redacted value | Copy blocked or scope-confirmed; no implicit leak |
| M20-34 | Bar/line/scatter chart | Query-backed, bounded, reproducible output |
| M20-35 | Stale chart input | Stale reason and rebase/refresh choice shown |
| M20-36 | Null/filtered/aggregate chart | Treatment disclosed in summary and table |
| M20-37 | Chart renderer failure | Table and text summary remain complete |
| M20-38 | Chart VoiceOver path | Summary and exact data table available without hover |
| M20-39 | High contrast chart | Meaning not color-only; labels/patterns remain distinct |
| M20-40 | AI formula proposal | Before/after patch, target revision, validation shown |
| M20-41 | AI mapping/transform proposal | Provenance impact and expected counts shown |
| M20-42 | Stale AI proposal | Rejected; no invisible merge |
| M20-43 | Prompt injection in cell/source | Data only; no authority/tool/permission effect |
| M20-44 | Remote model proposal | Provider/scope/retention disclosure and approval required |
| M20-45 | Crash during edit/import | Prior revision or quarantined recoverable operation; no half-state |
| M20-46 | Delete sheet | Affected queries/charts/edges/proposals previewed |
| M20-47 | Restore sheet | New revision; revoked/deleted source not silently resurrected |
| M20-48 | Browser-first degraded mode | Browsing and local textual Sheets path work with AI/charts disabled |

## 17. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M20-A | Canonical grid projection | Clean-profile open/navigate/empty/unavailable fixtures |
| M20-B | Stable editing | Revision-bound commits, stale rejection, typed validation |
| M20-C | View semantics | Filter/sort/group/save/rebase repeatability tests |
| M20-D | Formula truthfulness | Typed errors, versioning, limits, no-execution tests |
| M20-E | CSV safety | Preview, formula-injection, loss-report, export-manifest evidence |
| M20-F | Provenance | Row/cell/source lineage through all projections and deletion states |
| M20-G | Charts | Query/revision binding, stale/null disclosure, no-fabrication evidence |
| M20-H | Accessibility | Keyboard, VoiceOver, contrast, reduced motion, dynamic-size evidence |
| M20-I | Agent boundary | Diff/approval/revision/prompt-injection fixtures |
| M20-J | Lifecycle/recovery | Crash, delete/restore, export, quarantine, EventLedger evidence |
| M20-K | Performance/cancellation | Bounded large-sheet behavior and cancellable queries/renders |
| M20-L | Truthful status | No verified UI claim without current build, tests, and clean-profile runtime path |

## 18. Implementation order and handoff

Implement M20-A against the existing M14 schema without expanding the data model unnecessarily. M20-B may wire current typed editing only after the revision and error semantics are explicit. M20-C must define saved-query identity before chart work. M20-D consumes query objects and cannot become a parallel chart-only data path. M20-E comes last because proposal diffs and approvals depend on stable revision/query/provenance semantics.

The next smallest safe implementation slice is **M20-A: a read-only, revision-aware accessible grid projection with source markers and honest unavailable/empty states**. No model training, connector permission request, background sync, or autonomous spreadsheet mutation is part of M20.
