# IMPORT_MIGRATION_SPEC — Trustworthy Browser Migration

> **Canonical status:** active
> **Created:** 2026-08-11
> **Purpose:** Define the import journey that converts a curious user into a retained Hive user without losing trust at the first hour. Import is not a setup checkbox; it is the first product promise: *your old browser comes with you, and Hive tells you exactly what did and did not make it across.*
> **Dependencies:** `Sources/HiveCore/Browser/BrowserImportEngine.swift`, `BrowserImportMergePolicy.swift`, `BookmarkImportPolicy.swift`, `HistoryImportPolicy.swift`, `Sources/Hive/BrowserImport.swift`, `OnboardingSheet.swift`, `BrowserState+Setup.swift`, `conversion-playbook.md`, `HONEYCOMB_SPEC.md`
> **Scope:** Bookmarks and history are the current verified import surface. Passwords, extensions, open tabs, settings, and autofill are explicitly separate workstreams and must not be implied by the onboarding copy.

---

## 1. Product contract

A migration is successful only when the user can answer all four questions without opening a support thread:

1. **What did Hive find?** Source browser, profile, and counts.
2. **What did Hive import?** Accepted bookmarks/history counts after sanitation and deduplication.
3. **What did Hive skip?** Invalid, duplicate, unsupported, locked, or unreadable records, with reason counts.
4. **Can I undo or retry it?** The import is non-destructive, repeatable, and has a visible import report.

The first-launch journey must optimize for *confidence*, not for the shortest number of screens. A one-click import that silently loses 30% of a profile is a failed migration even if the app opens quickly.

### 1.1 User-facing promise

> “Hive reads your selected browser profiles locally. It never modifies them or uploads them. You can import now, skip, or do it later from Settings. If something cannot be read, Hive shows you exactly what happened.”

Do not say “everything is imported” unless the report proves it. Do not say “browser data” when only bookmarks/history are supported.

---

## 2. Verified current implementation

The report types and source availability states introduced in §3 are **planned contracts**, not current Swift APIs. Current code returns value snapshots and aggregate counts; the implementation work must add source-level status/report models without rewriting the existing parser and merge-policy boundaries.

| Current symbol/file | Verified behavior | Contract implication |
|---|---|---|
| `BrowserImportEngine.importFrom(browserID:)` | Supports `safari`, `chrome`, `edge`, `brave`, `arc`, `firefox`, `zen`; returns bookmarks/history value snapshots | Source detection and parsing remain local and non-destructive. |
| `parseChromiumBookmarks` / `parseSafariBookmarks` / `parseFirefoxDatabase` | Parses bookmark records with title and URL | Bookmark import needs a per-source count and skipped-record count. |
| `parseChromiumHistory` / `parseSafariHistory` / Firefox history query | Parses URL, title, visit date, visit count | History import needs a per-source count and merge report. |
| SQLite profile copy before read-only parsing | Avoids modifying or holding live profile databases | Preserve this boundary; never parse a live SQLite profile in place. |
| `BookmarkImportPolicy.merge` | Normalizes URLs, rejects unsafe schemes, removes duplicates, reports `skippedCount` | User-visible report must distinguish duplicates from malformed/unsafe records. |
| `HistoryImportPolicy.merge` + `BrowserImportMergePolicy.mergeHistory` | Sanitizes, deduplicates, merges against existing history, caps at 1,000 | “Imported” means retained after policy, not raw rows found. |
| `BrowserImport.detectAvailableBrowsers()` | Produces only sources with non-empty bookmark/history snapshots | Empty/locked/unreadable sources currently disappear from the onboarding list; M1 must expose “detected but unavailable” separately. |
| `OnboardingSheet.importSelected()` | Aggregates selected browser values and only shows an error when total imported count is zero | This is the primary trust gap: partial failures can be invisible. |
| `BrowserState.mergeImportedData` | One state-owned boundary for bookmarks/history, persistence, dedup, ordering, and counts | All import surfaces must call this boundary; no UI may mutate imported arrays directly. |

---

## 3. Import journey

### 3.1 Step A — Detect, do not silently filter

Detection returns a per-source `ImportSourceSnapshot`, not only a list of sources with data:

```text
ImportSourceSnapshot {
  sourceID: safari | chrome | edge | brave | arc | firefox | zen
  displayName: String
  profileLabel: String?
  availability: available | installed_but_empty | locked | unreadable | unsupported_profile | not_installed
  discovered: { bookmarks: Int, history: Int }
  capabilities: { bookmarks: supported, history: supported, passwords: unsupported, extensions: unsupported, tabs: unsupported }
  diagnostic: redacted user-readable reason?
}
```

- Installed-but-empty is not the same as not installed.
- A locked profile is not the same as “no data.”
- A source with only bookmarks must remain selectable even when history is unavailable.
- Never display raw filesystem paths, account names, cookies, passwords, or database errors.

### 3.2 Step B — Preview before commit

The onboarding card shows:

- source name and profile label;
- discovered counts by data type;
- exact data types Hive supports today;
- a disclosure: “Hive will merge these with existing Hive data; duplicates are skipped”;
- `Import now`, `Skip for now`, and `Choose data` actions.

The default selection is the most recently active detected browser only when the OS/browser signal is reliable. Otherwise, require a deliberate source selection. Do not import every installed browser by default: a user may have old profiles they do not consider current.

### 3.3 Step C — Progress by source and data type

Progress is a phase state, not fake percentage theater:

```text
scanning → copying profile → parsing bookmarks → parsing history → merging → complete | partial | failed | cancelled
```

Show one active source at a time and a compact completed-source list. If exact record totals are known, show `1,842 / 2,031 bookmarks`; otherwise show phase text, never invented progress.

Imports run off the main actor. The browser remains usable; the user may continue to the next onboarding step while import finishes. The report must survive the transition from onboarding to Settings.

### 3.4 Step D — Report, even on partial success

Every selected source receives a report:

```text
ImportReport {
  sourceID: String
  startedAt: Date
  finishedAt: Date?
  status: complete | partial | failed | cancelled
  discoveredBookmarks: Int
  importedBookmarks: Int
  skippedBookmarks: Int
  discoveredHistory: Int
  importedHistory: Int
  skippedHistory: Int
  skippedReasons: {
    duplicate: Int
    invalidURL: Int
    unsupportedScheme: Int
    malformedRecord: Int
    unreadableSource: Int
    lockedSource: Int
    cappedByLimit: Int
  }
  retryable: Bool
  userMessage: String
}
```

Required user-visible examples:

- “Chrome imported 1,842 bookmarks and 9,120 history entries. 21 duplicate bookmarks were skipped.”
- “Safari bookmarks imported. Safari history could not be read because the source was unavailable. Retry from Settings.”
- “Firefox was detected, but no supported profile was found. Nothing was changed.”

A partial import is a successful *journey state*, not an error modal. The user should see the imported data immediately and a clear retry path for the missing portion.

### 3.5 Step E — Verify the result

After completion, show three proof links:

1. `Open imported bookmarks` — navigates to the bookmark manager filtered to the import batch.
2. `Open imported history` — opens history filtered to the source/time window.
3. `View report` — preserves raw counts, skip reasons, source, timestamp, and retry action.

The final onboarding summary must not claim “history imported” when only bookmarks succeeded. It should say “Bookmarks ready; history unavailable” or equivalent.

### 3.6 Step F — Import later

Import remains available from Settings and the bookmark manager. Re-running the same source is safe:

- no duplicate bookmarks after URL normalization;
- no duplicate history after canonical URL/date policy;
- no destructive overwrite of user edits;
- a new report is created, linked to the source and timestamp;
- previously skipped records can be retried if the source becomes readable.

---

## 4. Data boundaries and safety

1. **Read-only source access.** Copy SQLite/plist/JSON inputs to an ephemeral import directory, parse the copy, then remove it. Never write into a source browser profile.
2. **No credentials implied.** Password import is not part of the current contract. Never tell users passwords came over when only bookmarks/history did. A future Keychain migration requires its own permission and audit contract.
3. **URL sanitation before persistence.** Keep `BookmarkImportPolicy` and `HistoryImportPolicy` as the only acceptance boundary. Reject `file:`, `javascript:`, `data:`, internal Hive routes, embedded credentials, malformed hosts, and other unsafe inputs according to current policy tests.
4. **No private browsing data.** A source profile importer must not infer or label private/incognito windows as normal history. If a source format cannot distinguish them, document the limitation and do not claim private-data filtering that the parser cannot prove.
5. **No remote model context.** Raw imported history/bookmarks never enter a model request merely because they were imported. They become browser data; Swarm scope must explicitly include them through the context broker.
6. **Redacted diagnostics.** Logs and reports contain source ID, phase, counts, and stable error class — not raw paths, usernames, URLs, page content, or secrets by default.
7. **Cancellation is safe.** Cancellation deletes temporary copies, leaves already-committed records valid, marks the report `cancelled`, and never presents the operation as complete.
8. **Atomic user-visible state.** A source's report is written only after its accepted data and report metadata are consistent. If report persistence fails, surface degraded persistence and do not claim verified completion.

---

## 5. Performance and scale

The import path must handle a profile with tens of thousands of bookmarks without blocking the UI or exhausting memory.

- Parse in bounded batches; do not retain all raw SQLite rows and all sanitized rows simultaneously when avoidable.
- Use a temporary copy and read-only connection for SQLite.
- Deduplicate with bounded canonical-key sets and report cap behavior.
- Keep the existing 1,000-history retained cap explicit in the report until the product changes that policy.
- Target: the onboarding shell stays interactive; import work is cancellable; a 40,000-bookmark fixture completes without a main-actor stall.
- If a source exceeds safe limits, complete with `partial` and a reason, never timeout into a false success.

---

## 6. Acceptance gates

| ID | Gate | Evidence |
|---|---|---|
| I-1 | All seven supported source IDs have deterministic fixture coverage | Fixture matrix for Safari, Chrome, Edge, Brave, Arc, Firefox, Zen |
| I-2 | Detection distinguishes not installed / empty / locked / unreadable / available | Pure policy tests + fixture report |
| I-3 | Partial source failure does not erase successful source data | Integration fixture: Chrome succeeds, Safari history fails |
| I-4 | Every selected source receives a report | Report-store test; no aggregate-only result |
| I-5 | Counts reconcile | discovered = imported + skipped + failed remainder, with explicit cap bucket |
| I-6 | Re-running an import is idempotent | Two identical runs produce zero duplicate persisted records |
| I-7 | Existing user edits survive import | Merge test with same URL and changed local title/folder |
| I-8 | Cancellation cleans temporary files and reports cancelled | Cancellation integration test |
| I-9 | No source profile is modified | Hash/mtime fixture before/after import |
| I-10 | Import does not leak private or secret data into logs/model context | Redaction tests + context-broker negative test |
| I-11 | Large profile stays interactive | 40k-bookmark performance fixture; main-actor watchdog |
| I-12 | Onboarding copy matches actual capabilities | Static contract test: no passwords/extensions/tabs claims until implemented |
| I-13 | User can retry only the failed portion | UI/runtime path from report to source-specific retry |
| I-14 | Import remains usable after onboarding | Settings/bookmark-manager integration test |

---

## 7. Rollout sequence

### 7.0 Evidence references

The migration UX recommendations are grounded in first-party documentation: [Apple Safari import/export](https://support.apple.com/guide/safari/import-bookmarks-and-other-data-ibrw1015/mac), [Google Chrome import bookmarks and settings](https://support.google.com/chrome/answer/96816), [Mozilla Firefox import browser data](https://support.mozilla.org/en-US/kb/import-bookmarks-data-from-another-browser), and [Microsoft Edge import favorites](https://support.microsoft.com/en-us/office/import-favorites-in-microsoft-edge-f61b3ca9-ec3b-4f44-839c-e2f7b054238b). These sources establish the existence of granular import choices and browser/file-based migration paths; the report schema, partial-failure behavior, and Hive-specific recommendations below are product proposals to be tested.

### M1 — Honest report foundation

Add source-level statuses, report model, and partial-success UI without expanding supported data types. Existing parsers and merge policies remain the source of truth.

### M2 — Migration resilience

Add cancellable background jobs, temporary-file lifecycle evidence, source-specific retry, persistent report history, and large-profile fixture coverage.

### M3 — Conversion polish

Add cohort-specific import landing paths (Pocket/Omnivore/Arc/Chrome), import preview filtering, bookmark-folder preservation proof, and a post-import “first useful page” flow. Do not add password import to M3 by implication.

### Definition of done

Import is **verified** only when I-1 through I-14 pass on a clean test profile and a manual migration path shows: detect → choose → progress → partial/complete report → open imported data → retry/undo explanation. Code presence alone remains `code-present`.
