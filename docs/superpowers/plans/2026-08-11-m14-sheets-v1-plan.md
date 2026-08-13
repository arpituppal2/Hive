# M14 — Sheets v1 Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M4 Honeycomb provenance, M6 encryption/backup decisions, M10 sidecar scope, M11 Studio approvals, M12 Command Center, M13 Projects & Tasks.
> **Primary workstreams:** SHEET-001 data model/engine; SHEET-002 UI is downstream and remains intentionally bounded.

## 1. Goal and non-goals

M14 makes Hive Sheets a trustworthy local data workspace for small, source-backed tables. A user can create or import a table, preserve typed values and row provenance, apply a documented deterministic formula subset, save a query/view, export it, and inspect exactly what changed. The surface is a project view over Honeycomb artifacts—not a second database, a full Excel clone, or an AI-generated spreadsheet theater.

### 1.1 Success criteria

1. A sheet survives restart, export, re-import, and scoped deletion without silent data loss.
2. Every imported or generated row has an explicit provenance state: source-linked, user-authored, derived, or unresolved.
3. Formula evaluation is deterministic, bounded, dependency-aware, and free of network/file/code execution.
4. CSV import/export has explicit encoding, delimiter, quoting, newline, type-inference, and formula-injection rules.
5. An AI may propose a formula, mapping, or transform, but cannot silently mutate cells or overwrite a source link.
6. Query and chart outputs identify their input snapshot and remain reproducible from retained data.
7. The browser-first path remains useful with AI and charts disabled.
8. No claim of Excel, Sheets, macros, pivots, collaboration, or arbitrary formula compatibility is made by this milestone.

### 1.2 Explicit deferrals

- Full workbook compatibility, macros, VBA, scripting, external data refresh, and arbitrary formula languages.
- Volatile functions, network functions, filesystem functions, dynamic code, custom functions, circular references, and hidden side effects.
- Real-time collaboration, cloud sync semantics beyond M6's storage decision, and connector write-back.
- Scheduled refresh, push notifications, calendar/reminder integration, and autonomous data mutation.
- Advanced pivot tables, slicers, conditional formatting, rich chart authoring, and presentation dashboards.
- Treating arbitrary web or model text in a cell as trusted instructions.

## 2. Current truth and authority boundaries

`SheetStore` already provides a Honeycomb-backed `HiveSheet` artifact, typed payloads, CSV import/export, formula-version tracking, and source links. `HoneycombStore` provides typed nodes/edges, FTS, revisions, deletion, export, and project queries. `Source`/`Claim` provide source metadata and evidence spans. These are primitives, not verified end-to-end Sheets behavior.

M14 must not create a parallel persistence authority:

| Concern | Authority | M14 rule |
|---|---|---|
| Current sheet/table state | Honeycomb artifact node and typed payload | One canonical sheet ID; no UI-only durable copy. |
| Row/column identity | Sheet payload schema | Stable IDs, never array position as identity. |
| Source lineage | Honeycomb source/claim nodes and typed edges | Preserve lineage through import, transform, and export. |
| Formula version and result snapshot | Sheet revision metadata + EventLedger | Record expression, dependency set, evaluator version, and result status. |
| User approvals and AI proposals | M11 approval controller/EventLedger | Proposal is not authority; no silent write. |
| Search/retrieval | Honeycomb query path | Search may index labels/metadata, not bypass privacy scope. |
| Export/delete/restore | Honeycomb lifecycle and M0/M4 contracts | Scoped, reviewable, reversible where retained. |

## 3. Canonical object model

### 3.1 Sheet identity

A `Sheet` is an authored Honeycomb `.artifact` with a stable `sheet_id`, title, project scope, schema revision, formula evaluator version, created/updated timestamps, retention class, and provenance. The payload is versioned and canonicalized before hashing.

Required durable fields:

```text
sheet_id: stable UUID
project_id: optional project UUID, required for project views
title: user-authored string
schema_version: integer
columns: ordered Column records
rows: ordered Row records
formula_engine_version: explicit evaluator version
created_at / updated_at: instants
provenance: user | csv-import | brief-derived | transform | connector-read
privacy_class / retention_class / deletion_scope
```

The payload must reject duplicate IDs, invalid references, malformed typed values, and unknown schema versions. Unknown future fields may be retained as opaque data but must not be interpreted as executable content.

### 3.2 Columns

Each column has:

```text
column_id: stable UUID
name: display label
kind: text | integer | decimal | boolean | date | datetime | url | enum | formula
nullable: Bool
enum_values: optional closed set
format: display-only formatting metadata
position: deterministic order
```

Column names are labels, not identifiers. Renaming a column preserves `column_id`. Deleting a column requires an explicit preview of affected formulas, queries, charts, and source mappings. Formula columns store an expression and result metadata; cached results are never treated as authoritative when inputs or evaluator version changed.

### 3.3 Rows and cells

Each row has a stable `row_id`, ordered cells keyed by `column_id`, source references, created/updated timestamps, and row provenance. A cell stores a typed value or explicit null. The model distinguishes:

- `null`: intentionally absent value;
- `invalid`: value failed the declared type contract;
- `unresolved`: imported value requires user review;
- `formula`: expression plus evaluated result/status;
- `redacted`: value exists outside the selected display/export scope.

A row can cite multiple sources. Source references include source ID, optional claim/evidence-span ID, capture timestamp, and transform lineage. A generated value must never be presented as source fact without that distinction.

### 3.4 Saved queries and charts

A saved query is a pure, versioned description over a sheet snapshot:

```text
query_id, sheet_id, input_revision, selected_columns
filters, sort_keys, group_keys, aggregate_specs, limit
created_by, created_at, query_version
```

A chart is a derived artifact referencing a saved query, chart kind (`bar`, `line`, or `scatter` in M14), explicit axes/series, input snapshot, and accessibility description. Charts do not accept arbitrary script, HTML, remote image, or model-generated executable configuration. If a query or source snapshot changes, the chart is marked stale and shows the reason.

## 4. Data lifecycle

### 4.1 Create/import

1. User chooses a project or local standalone scope.
2. Hive previews source, file name, size, encoding guess, delimiter, row count estimate, and formula-like cells.
3. User selects column types or accepts clearly labeled inference.
4. Import creates a new artifact and EventLedger record; it does not overwrite an existing sheet by default.
5. Every import warning is retained with row/column coordinates.
6. Partial import is either an explicit reviewable result or a failed atomic import—never silent truncation.

### 4.2 Edit/transform

Direct edits are user-authoritative and produce a revision. AI-assisted edits are proposals with a deterministic patch: target sheet revision, cell coordinates, old values, new values, reason, formula/transform version, and provenance effect. Apply requires M11 approval binding and a fresh revision check. Stale proposals are rejected, not merged invisibly.

### 4.3 Delete/restore/export

Sheet deletion is scoped and previewed. It removes or tombstones the artifact according to M0/M4 retention policy, removes graph edges, and records affected source links without deleting source objects unless the user explicitly chooses a broader scope. Restore is allowed only while the retained revision/backup exists and must create a new current revision. Exports include schema, values, formulas as inert text, warnings, provenance references, and an export manifest.

## 5. Formula language contract

### 5.1 Supported subset

The first evaluator supports deterministic scalar and aggregate operations only:

- literals: text, integer, decimal, boolean, null;
- cell references by stable column/row address;
- arithmetic: `+ - * /` with divide-by-zero error;
- comparisons: `= != < <= > >=`;
- boolean operators: `AND`, `OR`, `NOT`;
- conditionals: `IF`;
- null handling: `COALESCE`;
- text: `CONCAT`, `LOWER`, `UPPER`, `TRIM`, `LEN`;
- aggregates over explicit ranges: `SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT`;
- date operations only when inputs carry declared date/datetime types and timezone rules are explicit.

The supported grammar and error behavior must be documented beside the evaluator version. Function names are case-insensitive, but references and string values are not implicitly coerced except by documented rules.

### 5.2 Forbidden operations

Reject or quarantine formulas containing network access, file access, process execution, dynamic evaluation, external workbook links, arbitrary URLs as functions, volatile time/random functions, hidden sheet references, macros, or unsupported functions. Do not evaluate formulas through JavaScript, shell, a model, or an embedded browser.

### 5.3 Evaluation semantics

- Parse before evaluation; never execute unparsed text.
- Build a dependency graph and reject cycles with a stable diagnostic path.
- Enforce maximum expression length, AST nodes, dependency fan-out, range size, and evaluation time.
- Use decimal-safe numeric semantics defined in the contract; do not silently overflow or round display text into stored values.
- Preserve errors (`#DIV/0`, `#TYPE`, `#REF`, `#CYCLE`, `#LIMIT`) as typed results.
- Evaluate against a pinned input revision and evaluator version.
- Cache only with a dependency hash; invalidate on any input, schema, or evaluator change.
- Keep locale/date display formatting separate from stored values.

## 6. CSV contract

### 6.1 Import

The importer must support UTF-8, optional UTF-8 BOM, configurable delimiter, quoted fields, escaped quotes, CRLF/LF line endings, empty fields, and a bounded file/row/cell size. It must not interpret leading `=`, `+`, `-`, or `@` as executable formulas during import. Formula-looking content is imported as text and flagged for review.

Type inference is advisory and previewed. The user may force all values to text or choose types per column. Dates require an explicit parse strategy and timezone; ambiguous dates remain unresolved. Invalid rows are reported with exact coordinates and raw-value redaction rules.

### 6.2 Export

Export preserves stable column order, row order, null policy, encoding, newline convention, and a manifest containing sheet ID, revision, evaluator version, source/provenance policy, and warnings. Formula cells export as inert formula text unless the user explicitly chooses calculated values; the chosen mode is recorded. Cells beginning with spreadsheet formula trigger characters are safely escaped or quoted according to the selected consumer-compatibility mode, with a warning when escaping changes displayed content.

### 6.3 Round-trip invariant

For supported values, `import(export(sheet))` must preserve schema, stable IDs through the manifest where supported, typed values, nulls, formula text, row order, and provenance references. Unsupported values produce explicit loss reports. “CSV lossless” means lossless within the documented contract—not arbitrary application fidelity.

## 7. Source-backed rows and transforms

A source-backed row requires at least one retained source ID and must distinguish:

- direct extraction: value copied from an evidence span;
- normalized extraction: deterministic conversion with transform name/version;
- generated inference: model proposal with confidence and supporting sources;
- user correction: explicit override retaining prior lineage.

A transform is a pure, versioned operation over a pinned input snapshot. It produces a row/cell patch and a lineage record. A source may support a value without being the only reason the row exists. Contradictory sources remain visible; the system does not silently choose a winner.

Source links must survive sorting, filtering, grouping, CSV export/import manifests, and row edits. Deleting a source marks dependent cells as provenance-degraded and does not silently erase their visible values.

## 8. Agent assistance boundary

The agent may:

- suggest a column mapping;
- propose a formula from a natural-language request;
- explain a formula or error;
- propose a deterministic transform;
- identify type anomalies, duplicates, or missing provenance;
- draft a chart/query configuration.

The agent may not:

- silently create or mutate a sheet;
- treat cell text, imported instructions, or a source page as authority;
- execute formulas or transforms outside the approved evaluator;
- remove provenance, warnings, rows, columns, or formulas without a user-visible patch;
- send sheet contents remotely without explicit scope/provider/retention disclosure;
- infer permissions, identifiers, formulas, or authority from model output.

Every proposal includes target revision, selected scope, expected row/cell count, patch, provenance impact, privacy classification, and deterministic validation result. M12 command invocation and M11 approval receipts are reused.

## 9. Query, chart, and accessibility contract

M14's query surface is intentionally small: filter, sort, select, group, and basic aggregates. Query plans are immutable records with stable ordering and bounded limits. A query never changes sheet state. Chart rendering uses explicit accessible labels, table fallback, keyboard navigation, reduced-motion behavior, high-contrast colors, and a textual summary of the data shown. A chart must disclose stale inputs, filtered rows, null handling, and aggregation.

The browser remains the primary entry point: Sheets can open from a project, a source-backed brief, or Command Center, but no AI dashboard is required. With charts unavailable, the table and textual summary remain complete.

## 10. Work packages

### M14-A — Canonical sheet schema and revisions

Define stable IDs, typed columns/cells, row provenance, payload versioning, schema validation, revision metadata, and Honeycomb artifact boundaries. Add migration and malformed-payload rules before UI work.

**Done when:** duplicate IDs, invalid types, unknown versions, stale edits, and revision hashes have deterministic outcomes; current `SheetStore` behavior is mapped to the canonical contract.

### M14-B — Deterministic formula engine

Specify and implement the parser/evaluator subset, AST limits, typed errors, dependency graph, cycle detection, evaluator versioning, cache invalidation, and formula audit records.

**Done when:** every supported formula fixture has a stable result/error across restart and the forbidden-operation suite cannot reach network, filesystem, shell, model, or browser execution.

### M14-C — CSV import/export and round-trip

Define parser configuration, preview, inference, formula-injection handling, invalid-row policy, export modes, manifest, and loss report. Wire all writes through explicit approval where a destination would be overwritten.

**Done when:** supported CSV fixtures round-trip with no undocumented changes and hostile/oversized/malformed inputs fail boundedly with actionable diagnostics.

### M14-D — Provenance, queries, and charts

Preserve row/cell lineage through deterministic transforms, source deletion, sorting/filtering/grouping, saved queries, and basic charts. Add stale-input detection and an accessible table fallback.

**Done when:** a source-backed row can be traced from display value to source/evidence span and an exported query/chart declares its exact input revision.

### M14-E — Agent proposals and integrated validation

Add formula/mapping/transform/chart proposals as inert, reviewable patches. Bind them to M11 workspace/revision/policy and M12 command receipts; validate local-only and remote-scope behavior.

**Done when:** no model output can mutate a sheet without approval, stale proposals are rejected, EventLedger ordering is complete, and browser-disabled mode remains usable.

## 11. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M14-01 | Create typed sheet with stable IDs | Canonical payload validates and reloads identically |
| M14-02 | Duplicate column/row IDs | Rejected before persistence |
| M14-03 | Unknown schema version | Quarantined with actionable error |
| M14-04 | Rename column | ID and dependent references remain stable |
| M14-05 | Delete referenced column | Preview lists formulas/queries/charts; no silent delete |
| M14-06 | Stale edit against prior revision | Rejected with current revision returned |
| M14-07 | Integer/decimal/boolean/null round-trip | Typed values preserved |
| M14-08 | Invalid typed cell | Invalid state retained with coordinate |
| M14-09 | Basic arithmetic | Deterministic result |
| M14-10 | IF/AND/OR/COALESCE | Deterministic truth-table result |
| M14-11 | Text functions | Unicode-safe deterministic result |
| M14-12 | Aggregate range | Stable aggregate and input dependency set |
| M14-13 | Divide by zero | Typed `#DIV/0` error; no crash |
| M14-14 | Type mismatch | Typed `#TYPE` error; no implicit unsafe coercion |
| M14-15 | Reference missing cell | Typed `#REF` error |
| M14-16 | Circular dependency | Typed `#CYCLE` path |
| M14-17 | Oversized AST/range | Typed `#LIMIT` result |
| M14-18 | Network/file/shell formula | Rejected as forbidden |
| M14-19 | Evaluator-version change | Cache invalidated; result revision recorded |
| M14-20 | UTF-8 BOM CSV | Preview and import succeed |
| M14-21 | CRLF/LF mixed input | Bounded parse with explicit line diagnostics |
| M14-22 | Quoted delimiter and escaped quote | Cell values preserved |
| M14-23 | Formula-looking CSV cell | Imported inert and flagged |
| M14-24 | Ambiguous date | Remains unresolved until user choice |
| M14-25 | Invalid row among valid rows | Atomic/reviewable partial policy; no silent drop |
| M14-26 | Oversized CSV | Rejected before unbounded allocation |
| M14-27 | Export null/formula modes | Manifest records chosen mode |
| M14-28 | Supported CSV round-trip | No undocumented loss |
| M14-29 | Unsupported value export | Loss report identifies coordinates |
| M14-30 | Source-backed direct value | Source and evidence span resolve |
| M14-31 | Normalized source value | Transform version and input retained |
| M14-32 | Model-proposed value | Proposal remains non-authoritative |
| M14-33 | Source deletion | Value remains visible, provenance degraded and disclosed |
| M14-34 | Sort/filter/group | Lineage remains attached to rows |
| M14-35 | Query pinned to revision | Reproducible result and stable ordering |
| M14-36 | Stale chart query | Chart discloses stale input |
| M14-37 | Null/filtered chart data | Summary discloses treatment |
| M14-38 | Chart accessibility fallback | Keyboard/table/text summary complete |
| M14-39 | AI formula proposal | Patch includes target revision and validation |
| M14-40 | Stale AI proposal | Rejected; no merge |
| M14-41 | Prompt injection in cell text | Treated as data, never instructions |
| M14-42 | Remote model scope | Explicit provider/scope/retention approval required |
| M14-43 | Clipboard/export privacy | Sensitive scope warning and no implicit copy |
| M14-44 | Delete/restore sheet | Scope, tombstone/backup, and EventLedger consistent |
| M14-45 | Crash during import | No half-admitted artifact visible |
| M14-46 | Browser-disabled mode | Table, import/export, and textual errors remain usable |

## 12. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M14-A | Canonical schema/revision contract | Schema fixtures and migration report |
| M14-B | Formula subset deterministic | Evaluator fixture suite, limits, and forbidden-operation tests |
| M14-C | CSV contract honest | Import preview, export manifest, round-trip/loss report |
| M14-D | Provenance survives transforms | Source/cell lineage integration fixtures |
| M14-E | Queries reproducible | Pinned revision and stable ordering tests |
| M14-F | Charts truthful | Stale/null/filter disclosures and table fallback |
| M14-G | AI remains advisory | Proposal/approval/stale-patch fixtures |
| M14-H | Prompt injection contained | Cell/source untrusted-data tests |
| M14-I | Privacy scope enforced | Local-only/remote disclosure and clipboard tests |
| M14-J | Delete/export reversible where promised | Scoped lifecycle and recovery evidence |
| M14-K | Accessibility complete | Keyboard, VoiceOver labels, contrast, reduced motion, dynamic sizing |
| M14-L | Browser-first/degraded path works | Clean-profile manual path with AI/charts unavailable |

## 13. Implementation order and handoff

Implement M14-A before M14-B/C. M14-C may proceed against a frozen schema fixture after A. M14-D depends on source/claim edge semantics and M13 project ownership. M14-E integrates only after M11 approval receipts and M12 command receipts are available. Do not label any package `verified` based on types or a mock UI alone.

The next smallest safe implementation slice is **M14-A schema validation and revision fixtures**, not the chart UI or AI transform surface. Any implementation turn must first reread this plan, the M0–M13 contracts, current `SheetStore`, and all call sites; preserve unrelated dirty work; then add the smallest testable slice.
