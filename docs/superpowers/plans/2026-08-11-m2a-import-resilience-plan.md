# Hive M2A — Import Resilience Implementation Plan

> **For agentic workers:** This is an execution plan, not an implementation. Use the repository's approved planning/execution workflow only after M0 is verified. Do not edit Swift during this planning pass.

**Goal:** Turn Hive's existing local bookmark/history parsers into a truthful, cancellable, source-isolated migration journey that reports exactly what was found, retained, skipped, failed, or remains retryable.

**Architecture:** Preserve the current boundary: external profile snapshot → `BrowserImportEngine` parser → pure import policies → `BrowserState.mergeImportedData` persistence boundary → source-scoped report store/UI. Add reporting and job orchestration around the existing parsers; do not move imported records into Honeycomb memory nodes or broaden the supported data types. Each source is an independent unit of work with its own lifecycle, counts, diagnostics, and retry identity.

**Tech Stack:** Swift 6; SwiftUI/AppKit onboarding and Settings surfaces; Foundation file/plist/JSON APIs; system SQLite3; existing `BookmarkImportPolicy`, `HistoryImportPolicy`, `BrowserImportMergePolicy`, session persistence, and Swift Testing fixtures. No network, model, or new third-party dependency.

## Global Constraints

- Current supported data types are **bookmarks and history only**; passwords, extensions, open tabs, settings, cookies, and autofill remain explicitly unsupported.
- Source browser profiles are untrusted input and are never modified.
- Live SQLite sources are copied to a temporary location and opened read-only; temporary copies are removed on every terminal path.
- Private/incognito data must not be inferred as ordinary history when the source format cannot distinguish it.
- Raw paths, usernames, cookies, credentials, page bodies, and raw URLs are excluded from default diagnostics.
- One source failure must never erase or hide another source's successful import.
- Import must remain cancellable and must not block navigation, tabs, private browsing, or ordinary browser rendering.
- Duplicate imports are idempotent under the existing canonical URL policies.
- A report is not a success receipt unless accepted data and report metadata have reached their required durable boundaries.
- Do not add model calls, ambient capture, Honeycomb memory nodes, or remote services to M2A.

## Source of Truth and Current Gaps

Canonical product contract: `Sources/Hive/Resources/Swarm_System_Prompts/IMPORT_MIGRATION_SPEC.md`.

Current implementation seams:

- `Sources/HiveCore/Browser/BrowserImportEngine.swift` parses Safari plist, Chromium JSON/SQLite, and Firefox/Zen SQLite.
- `Sources/HiveCore/Browser/BookmarkImportPolicy.swift` sanitizes, canonicalizes, deduplicates, and counts skipped bookmarks.
- `Sources/HiveCore/Browser/HistoryImportPolicy.swift` sanitizes, canonicalizes, deduplicates, caps, and counts skipped history.
- `Sources/HiveCore/Browser/BrowserImportMergePolicy.swift` projects imported history onto existing history and the 1,000-entry retained cap.
- `Sources/Hive/BrowserImport.swift` currently advertises only non-empty aggregate snapshots, which hides empty/locked/unreadable sources.
- `Sources/Hive/BrowserState+Setup.swift` owns the persistence boundary and currently returns aggregate imported/skipped counts.
- `Sources/Hive/OnboardingSheet.swift` is the first-run UI boundary.
- Existing tests cover policy behavior and Firefox/Zen fixtures, but not source-level status/report persistence, cancellation cleanup, or partial multi-source UX.

M2A must add contracts around these seams rather than replace them with a second importer.

## Data Contracts

### `ImportSourceID`

Use a stable string-backed identifier with exactly these current values:

```text
safari | chrome | edge | brave | arc | firefox | zen
```

Unknown future identifiers must decode as `unsupported` rather than crash or silently route to a known parser.

### `ImportAvailability`

```text
available
installed_but_empty
locked
unreadable
unsupported_profile
not_installed
```

Availability describes detection/readability, not whether the user selected the source. `installed_but_empty` and `not_installed` must never collapse into one UI state.

### `ImportSourceSnapshot`

```text
ImportSourceSnapshot {
  sourceID: ImportSourceID
  displayName: String
  profileLabel: String?
  availability: ImportAvailability
  discoveredBookmarks: Int
  discoveredHistory: Int
  capabilities: {
    bookmarks: supported | unavailable(reason)
    history: supported | unavailable(reason)
    passwords: unsupported
    extensions: unsupported
    openTabs: unsupported
    settings: unsupported
  }
  diagnostic: RedactedImportDiagnostic?
  detectionRevision: String
}
```

`detectionRevision` must be deterministic for a source snapshot and must not contain a raw path. It exists to prevent a stale preview from committing against a different source state.

### `ImportReport`

```text
ImportReport {
  reportID: UUID
  sourceID: ImportSourceID
  profileLabel: String?
  startedAt: Date
  finishedAt: Date?
  status: scanning | copying | parsingBookmarks | parsingHistory | merging | complete | partial | failed | cancelled
  discoveredBookmarks: Int
  retainedBookmarks: Int
  skippedBookmarks: Int
  discoveredHistory: Int
  retainedHistory: Int
  skippedHistory: Int
  cappedHistory: Int
  skippedReasons: {
    duplicate: Int
    invalidURL: Int
    unsupportedScheme: Int
    malformedRecord: Int
    unreadableSource: Int
    lockedSource: Int
    unsupportedProfile: Int
    cappedByLimit: Int
  }
  retryable: Bool
  sourceRevision: String
  errorClass: String?
  userMessage: String
}
```

Counts must be reconciled by data type. A parser-level failure may leave a discovered count unknown; represent unknown as a separate state, never zero. `userMessage` is a bounded, localized-ready summary built from typed fields, not an exception description.

### Report persistence authority

`ImportReportStore` is a dedicated, browser-owned, version-1 JSON store at the exact path `Application Support/Hive/import-reports.json`, separate from Honeycomb memory nodes and the session envelope. It is an actor with an atomic write protocol: write a versioned temporary file, flush/close it, replace the active file, and retain the previous valid file until replacement succeeds. It stores report metadata and typed counts only; it never stores imported URLs, page text, credentials, cookies, raw source paths, or exception descriptions. On decode failure it quarantines the invalid report file as `import-reports.corrupt-<timestamp>-<uuid>.json` and exposes `reportsUnavailable`, never an empty report list that looks like no imports. The store has schema version `1`, forward-compatible decoding, deterministic `upsert(reportID:)`, `reports(for sourceID:)`, and `retryLineage(for reportID:)` APIs. A report is not marked verified-complete until both accepted data persistence and report persistence succeed; if accepted data commits first and the report write fails, the source result is `partialReportPersistence`, remains retryable, and is reconciled by the same `jobID`/batch identity on restart.

### `ImportJobID`, batch identity, and retry identity

- A new user invocation gets a new `jobID` and one `ImportBatchID` per selected source/data-type merge boundary.
- Add a dedicated schema-version-1 `ImportBatchLedger` inside `Application Support/Hive/import-reports.json`; each batch record stores `batchID`, `jobID`, `sourceID`, `reportID`, data type, accepted-count, skipped-count, commit state (`pending | committed | report_pending | reconciled`), and timestamps. It stores no imported URLs or content.
- `BrowserState.mergeImportedData` must accept an `ImportBatchContext` containing `jobID`, `batchID`, `sourceID`, `reportID`, and `attemptKind`; it returns retained/skipped counts plus the batch context, never aggregate counts without provenance.
- Before mutating browser arrays, the coordinator checks the batch ledger: `committed`/`reconciled` means no-op replay; `pending` permits one merge; after accepted rows persist it records `committed`; after the report persists it records `reconciled`.
- A source-specific retry reuses the source and creates a new report linked to the failed report, but never replays a completed batch blindly.
- Cancellation preserves the report, source/job identity, and any already-committed batch result. Restart reconciliation queries `pending`/`committed`/`report_pending` records and resolves them by batch ID, not by counts.
- A report records whether it is a first attempt, retry, or resumed operation.
- Batch IDs make accepted rows/report records/retries traceable without adding imported browser data to Honeycomb.

## State Machines

### Detection

```text
idle
  → detecting
      ├─ not_installed
      ├─ installed_but_empty
      ├─ locked
      ├─ unreadable
      ├─ unsupported_profile
      └─ available
```

Detection may inspect existence and safe metadata, but must not make the source appear importable merely because a directory exists. Locked/unreadable must be distinguishable when the OS error class supports it; otherwise use `unreadable` with a redacted diagnostic.

### Per-source import

```text
available
  → previewed
  → copying
  → parsingBookmarks
  → parsingHistory
  → merging
      ├─ complete
      ├─ partial
      ├─ failed
      └─ cancelled
```

Progress is phase-based. Exact progress percentages are allowed only when the source exposes a reliable denominator. Never synthesize percentage progress from elapsed time.

### Multi-source import

```text
idle
  → selected([source])
  → running(independent source jobs)
  → completed([source reports])
```

The aggregate result is derived from source reports:

- all complete → `complete`;
- at least one complete/partial and at least one failed/cancelled → `partial`;
- all failed/cancelled before accepted data → `failed` or `cancelled`, preserving each report;
- one source must never overwrite another source's report.

## Execution Tasks

### Task A1 — Model the source snapshot and report boundary

**Files:**
- Create: `Sources/HiveCore/Browser/ImportContracts.swift`
- Modify: `Sources/Hive/BrowserImport.swift`
- Test: `Tests/HiveCoreTests/ImportContractsTests.swift`

**Required behavior:**

1. Implement `ImportSourceID`, `ImportAvailability`, `ImportSourceSnapshot`, `ImportReport`, typed status/reason values, and bounded user-message formatting as `Sendable`, `Equatable`, and `Codable` where persistence requires it.
2. Make unknown decoded enum values fail into an explicit unsupported state rather than selecting a parser.
3. Ensure report count invariants are checkable through a pure validator:

```text
ImportReport.validateCounts() -> valid | invalid(reason)
```

4. Keep report diagnostics redacted and bounded; no raw source paths or URL payloads.
5. Add tests for complete, partial, failed, cancelled, unknown-count, retry-linked, and malformed-report cases.

### Task A2 — Make detection truthful without importing data

**Files:**
- Modify: `Sources/Hive/BrowserImport.swift`
- Modify: `Sources/HiveCore/Browser/BrowserImportEngine.swift` only if a pure detection helper is required
- Test: `Tests/HiveCoreTests/ImportDetectionPolicyTests.swift`

**Required behavior:**

1. Replace `compactMap`-only detection with a complete seven-source snapshot list or a stable source list plus explicit availability.
2. Distinguish `not_installed`, `installed_but_empty`, `locked`, `unreadable`, `unsupported_profile`, and `available` using typed, redacted evidence.
3. Keep profile labels user-facing and path-free.
4. Preserve source capabilities accurately: bookmarks/history only.
5. Add fixture tests where a source exists but is empty, a file is absent, a database cannot be copied, and a profile has an unsupported layout.

### Task A3 — Introduce a cancellable source-scoped job coordinator

**Files:**
- Create: `Sources/HiveCore/Browser/ImportJobCoordinator.swift`
- Modify: `Sources/HiveCore/Browser/BrowserImportEngine.swift`
- Modify: `Sources/Hive/BrowserImport.swift`
- Test: `Tests/HiveCoreTests/ImportJobCoordinatorTests.swift`

**Required behavior:**

1. Run each source as an independent child task with cooperative cancellation.
2. Define cancellation checkpoints before source access, after temporary-copy creation, between bookmark/history phases, every bounded parser batch, before merge, after merge, and before/after report persistence.
3. Refactor parser entry points used by the coordinator to be `async throws` or expose injected phase closures; synchronous legacy helpers may remain as compatibility wrappers but must not be used as the only cancellable path.
4. Emit typed phase transitions; never emit a successful terminal state before merge and report persistence complete.
5. Keep source jobs isolated so one thrown error becomes that source's report and does not cancel unrelated selected sources.
6. On cancellation, stop accepting new source work, allow already-committed records to remain valid, remove temporary copies in `defer`, and mark each affected report `cancelled` or `partialReportPersistence` when the report boundary itself failed.
7. Support source-specific retry using the prior report's source ID and a new report ID while retaining the prior batch lineage.
8. Do not add a second imported-data authority; coordinator output must flow through `BrowserState.mergeImportedData` and `ImportReportStore`.

### Task A4 — Extend the merge boundary with source-level reconciliation

**Files:**
- Modify: `Sources/Hive/BrowserState+Setup.swift`
- Create: `Sources/HiveCore/Browser/ImportBatchContext.swift` if the contract is not colocated with `ImportContracts.swift`
- Modify: `Sources/HiveCore/Browser/BookmarkImportPolicy.swift` only for typed reason counts if needed
- Modify: `Sources/HiveCore/Browser/HistoryImportPolicy.swift` only for typed reason counts if needed
- Test: `Tests/HiveCoreTests/ImportMergeReportTests.swift`

**Required behavior:**

1. Preserve the existing canonical URL and cap policies.
2. Return retained counts and reason buckets without changing existing accepted records.
3. Prove re-running the same fixture produces zero new duplicate records and a report that explains skipped duplicates.
4. Prove local title/folder edits survive an import with the same canonical URL.
5. Preserve import order and existing 1,000-history cap semantics.
6. If persistence fails after policy acceptance, report the source as partial/failed according to the durable boundary; never call it complete from policy output alone. The result must retain the `ImportBatchContext` so a restart or retry can reconcile the accepted-data and report sides without guessing from counts.

### Task A5 — Add durable report storage with safe retry semantics

**Files:**
- Create: `Sources/HiveCore/Browser/ImportReportStore.swift`
- Modify: `Sources/Hive/BrowserState+Persistence.swift` only to initialize the Application Support report-store location and recovery banner; do not place reports in the session envelope
- Test: `Tests/HiveCoreTests/ImportReportStoreTests.swift`

**Required behavior:**

1. Persist reports outside Honeycomb memory nodes, with schema version and forward-compatible decoding.
2. Redact diagnostics before persistence.
3. Store source/job/report/retry relationships and terminal state.
4. Make report writes idempotent by report ID; a retry creates a new report linked to the prior one.
5. Preserve reports across onboarding → Settings transition and app restart.
6. If report persistence fails, show a degraded report state and never upgrade the source to verified complete.
7. Do not store raw imported URLs, passwords, cookies, page content, or source paths in report diagnostics.

### Task A6 — Build onboarding and Settings report UX

**Files:**
- Modify: `Sources/Hive/OnboardingSheet.swift`
- Modify: `Sources/Hive/BrowserImport.swift`
- Modify: the existing Settings import surface identified during implementation audit
- Test: `Tests/HiveCoreTests/ImportSurfaceContractTests.swift`

**Required behavior:**

1. Preview source name/profile/counts/capabilities before commit.
2. Offer `Import now`, `Choose data`, and `Skip for now` without forcing import.
3. Show phase-based source progress and independent completed/failed source rows.
4. Show partial success as a useful state, not a generic error modal.
5. Provide `Open imported bookmarks`, `Open imported history`, `View report`, and source-specific `Retry`.
6. State unsupported data types honestly in the same surface.
7. Keep the browser usable while import runs.
8. Ensure keyboard, VoiceOver, reduced motion, and dynamic type paths remain usable.

### Task A7 — Add source fixtures, security fixtures, and scale evidence

**Files:**
- Create or extend: `Tests/HiveCoreTests/BrowserImportFixtureSupport.swift`
- Create: source fixtures under the existing test fixture convention
- Test: `Tests/HiveCoreTests/BrowserImportScaleTests.swift`

**Required fixtures:**

- all seven source IDs;
- malformed Safari plist;
- malformed Chromium JSON;
- missing/locked/unreadable SQLite copy;
- Firefox/Zen dangling bookmark rows;
- unsafe schemes, embedded credentials, fragments, malformed hosts;
- duplicate URLs differing by case/default port/fragment;
- same URL with a locally edited title/folder;
- partial multi-source run with one source failing;
- cancellation during copy, parse, merge, and report write;
- 40,000-bookmark bounded-interactivity fixture;
- source mtime/hash unchanged before and after import.

## Failure and Recovery Matrix

| Scenario | Required result | Must not happen |
|---|---|---|
| source not installed | visible `not_installed`; no job | source silently omitted |
| installed empty profile | visible `installed_but_empty`; skip or select intentionally | “not installed” claim |
| source locked/unreadable | source-specific retryable report | aggregate success |
| malformed source file | source `failed` with redacted reason | crash or raw path/error leak |
| bookmarks succeed/history fails | source `partial`; bookmarks openable; history retryable | history reported imported |
| Chrome succeeds/Safari fails | Chrome report preserved; Safari report retryable | Safari failure hides Chrome success |
| cancellation | committed records remain; report `cancelled`; temp copy removed | false complete or data rollback beyond contract |
| repeated import | zero duplicate persisted records; skipped duplicate count | duplicate rows or title overwrite |
| report write fails | degraded report state; no verified-complete label | success toast with no report |
| unsafe URL | skipped with reason bucket | unsafe URL persisted |
| source profile mutation attempt | read-only boundary/test failure | source browser data modified |
| private/incognito ambiguity | limitation disclosed; no unsupported filtering claim | private data marketed as excluded without proof |
| huge profile | bounded batches/partial cap report | main-actor stall or invented percentage |

## M2A Acceptance Gates

| Gate | Requirement | Fresh evidence |
|---|---|---|
| M2A-1 | Seven source IDs have deterministic detection and parser fixture coverage | Swift fixture suite |
| M2A-2 | Empty/locked/unreadable/unsupported/not-installed are distinct | pure detection tests + UI contract |
| M2A-3 | Every selected source receives its own report | report-store integration tests |
| M2A-4 | Counts reconcile or explicitly identify unknown/remainder buckets | report validator tests |
| M2A-5 | Partial source failure preserves successful source data | multi-source integration fixture |
| M2A-6 | Repeated import is idempotent and preserves local edits | merge integration fixture |
| M2A-7 | Cancellation removes temporary copies and reports cancellation | injected cancellation tests |
| M2A-8 | Source profiles are unchanged | mtime/hash before/after fixture |
| M2A-9 | Reports contain no raw paths, secrets, URLs, or page content by default | redaction sweep |
| M2A-10 | Import remains interactive at 40,000 bookmarks | performance/watchdog evidence |
| M2A-11 | Retry is source-specific and report-linked | retry UI/runtime path |
| M2A-12 | Onboarding copy names only supported data types | static contract test |
| M2A-13 | Reports survive onboarding transition and restart | persistence integration test |
| M2A-14 | Clean-profile import path is usable with Swarm disabled | manual browser runtime evidence |

M2A is `verified` only after all gates pass with current build/test/runtime evidence. A parser existing on disk is `code-present`, not verified.

## Implementation Order and Stop Conditions

1. Land contracts and pure validators before adding UI.
2. Make detection truthful before enabling background jobs.
3. Add source-isolated jobs and report persistence before adding retry controls.
4. Add report-aware merge results before claiming counts.
5. Add onboarding/Settings UX only after failure fixtures pass.
6. Run focused tests, `swift build`, `swift test`, and clean-profile import evidence.
7. Stop M2A before password/extension/tab/cookie migration, ambient capture, model context, or remote services.

## Explicit Deferrals

- Passwords and Keychain migration.
- Extensions and extension settings.
- Open tabs/session migration.
- Cookies, local storage, payment data, autofill, and account credentials.
- Cloud sync or remote profile import.
- Automatic import without explicit user selection.
- Importing foreign private/incognito sessions.
