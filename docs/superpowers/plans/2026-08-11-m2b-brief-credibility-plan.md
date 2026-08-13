# Hive M2B — Brief Credibility Implementation Plan

> **For agentic workers:** This is an execution plan, not an implementation. Use the repository's approved planning/execution workflow only after M0 is verified. Do not edit Swift or WebChrome assets during this planning pass.

**Goal:** Make Hive's first tab useful before it knows the user, truthful as activity accumulates, and calm enough that memory feels like continuity rather than surveillance.

**Architecture:** Preserve the current deterministic pipeline: browser/session/Honeycomb/calendar adapters → pure `ProactiveBriefPlanner` → versioned allow-listed Brief payload → `hive://brief` template. Keep Ring 1 browser utility independent of memory, EventKit, models, and network. Add explicit resume/provenance/dismissal contracts around the existing planner rather than introducing model-generated copy or a second start-page data source.

**Tech Stack:** Swift 6; SwiftUI/AppKit browser state; pure HiveCore planner/policy types; existing `buildBriefJSON()` and WebChrome brief assets; EventKit only through the existing opt-in adapter; Swift Testing; static payload/XSS/accessibility contract tests. No network, model, analytics, or new third-party dependency.

## Global Constraints

- The start page must be useful with zero history, zero memory, no account, no model, no network, and no calendar permission.
- Browser action owns the first interaction: search/omnibox and resume precede memory-derived cards.
- Private tabs/history and private memory never enter a normal-profile Brief.
- Raw note content is not copied into M2 Brief prose; the current generic-note-label rule remains.
- Every non-empty proactive card exposes compact provenance and a direct source action.
- Dismissal hides a Brief card; it does not delete the underlying source or memory.
- Forget/delete uses the existing memory lifecycle contracts and is never conflated with dismissal.
- Calendar is opt-in, lazy, bounded to today, local-only, and non-fatal when denied/unavailable.
- No algorithmic news feed, sponsored content, weather, remote continuity, or model-generated summary in M2.
- Payload fields are allow-listed, versioned, bounded, escaped, and deterministic apart from explicitly documented current-time fields.
- Do not make Swarm onboarding, model download, Screen Recording, Accessibility, or cloud sign-in prerequisites for the Brief.

## Source of Truth and Current Gaps

Canonical product contract: `Sources/Hive/Resources/Swarm_System_Prompts/MORNING_BRIEF_SPEC.md`.

Current implementation seams:

- `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift` is pure and deterministic but currently returns only `Plan(proactiveWork, paintingCaption, lookingAheadBlurb)`.
- `Sources/Hive/BrowserState+Brief.swift` builds escaped JSON from open tabs, history domains, Honeycomb titles/timestamps, and optional EventKit events.
- `Sources/Hive/ProactiveBriefCalendar.swift` requests access lazily and degrades to no events.
- `Sources/Hive/WebChrome/brief/index.html` and `app.js` render the Brief payload.
- `Tests/HiveCoreTests/ProactiveBriefPlannerTests.swift` covers empty state, time window, memory preference, calendar summaries, note redaction, and determinism.
- `Tests/HiveCoreTests/MorningBriefContractTests.swift` covers placeholders, embedded assets, internal routes, XSS escaping, and WebChrome contracts.
- Proposed `ResumeItem`, provenance labels, dismissal semantics, and versioned payload fields are not yet current APIs.

## Payload Contract

### Top-level envelope

The implementation must introduce a versioned envelope without breaking the existing placeholder replacement path:

```json
{
  "schema_version": "brief.v2",
  "generated_at": "ISO-8601",
  "profile_scope": "opaque-local-scope",
  "navigation": {
    "search_available": true,
    "omnibox_shortcut": "⌘L"
  },
  "resume": [],
  "proactive_work": null,
  "painting": { "caption": "...", "provenance": null },
  "looking_ahead": { "blurb": "...", "provenance": null },
  "tasks": [],
  "footer": { "sources": [] }
}
```

`profile_scope` must be an opaque stable scope label or local identifier safe for the page; it must never be a username, filesystem path, or account identifier. If backward compatibility requires the current top-level keys, emit them with documented aliases during the transition and test both schemas.

### `ResumeItem`

```text
ResumeItem {
  id: String
  title: String
  sourceURL: URL
  origin: open_tab | reading_list | history
  workspaceID: UUID?
  lastObservedAt: Date?
  provenanceLabel: open_tab | saved_reading_list | recent_history
  private: false
}
```

Dismissal is native-only selection state and is applied before serialization; `ResumeItem` never carries a `dismissed` payload field. This prevents a hidden item from being emitted to the page and keeps source state separate from Brief UI state.

Rules:

- Open tabs outrank reading list, which outranks history.
- Pinned/essential tabs may outrank ordinary open tabs through a documented deterministic tie-break.
- Sort ties by stable ID or canonical URL, never array/hash iteration order.
- Only `http`/`https` external URLs qualify; internal Hive routes and blank pages do not.
- Private entries are rejected before payload construction, not merely hidden by the template.
- The output is capped at eight items.
- Dismissing a resume item suppresses that item in the Brief without closing the tab or deleting history.

### `ProvenanceLabel`

Allowed values are intentionally small:

```text
Open tab
Saved reading list
Recent browsing
Saved yesterday
From your workspace
Today's calendar
```

The UI may format these values, but the data layer must not synthesize prose that implies hidden inference.

### `BriefDismissal`

```text
BriefDismissal {
  dismissalID: UUID
  scopeID: String
  cardID: String
  dismissedAt: Date
  expiresAt: Date?
  sourceKind: resume | proactive_work | looking_ahead
}
```

Dismissal is a local UI preference/state record. It is not a Honeycomb memory node and must not delete or mutate the source object. A dismissal key must be stable for the same source/card version and change when the underlying source meaningfully changes.

## Information Architecture Contract

Above the fold, in fixed order:

1. Greeting/date.
2. Search/omnibox action.
3. Resume row, maximum eight items.
4. One proactive memory card only when a real eligible signal exists.
5. Looking-ahead only when calendar is enabled and populated, or a subdued deterministic memory fallback is explicitly selected.
6. Secondary controls and footer sources.

Empty sections disappear. Do not render empty skeleton cards, fake metrics, news feeds, or generic AI insight panels.

## State Machines

### Brief data availability

```text
zero_data
  → browser_utility_only
  → resume_available
  → memory_signal_available
  → calendar_signal_available (opt-in only)
```

These are derived states, not onboarding gates. The user can always search/browse.

### Resume eligibility

```text
candidate
  → validate scope/privacy/scheme
      ├─ rejected_private
      ├─ rejected_internal
      ├─ rejected_invalid
      └─ eligible
            → rank deterministically
            → apply dismissal
            → cap eight
            → emit direct-open action
```

### Proactive card

```text
planner inputs
  → filter to bounded local window
  → exclude private/candidate/forgotten/ineligible nodes
  → redact note bodies
  → prefer latest real brief, then count-based captures/notes
      ├─ no eligible signal → omit card
      └─ eligible signal → emit one card + provenance + reversible open action
```

### Calendar

```text
off
  → user enables preference
  → request permission lazily
      ├─ denied/restricted/error → no calendar payload
      └─ granted → fetch today's bounded titled events
            → omit if empty
            → emit at most 12 local events/summary
```

## Execution Tasks

### Task B1 — Define versioned Brief contracts and pure validators

**Files:**
- Create: `Sources/HiveCore/Browser/BriefContracts.swift`
- Modify: `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift`
- Test: `Tests/HiveCoreTests/BriefContractsTests.swift`

**Required behavior:**

1. Define `BriefSchemaVersion`, `ResumeItem`, `ProvenanceLabel`, `BriefDismissal`, `BriefProactiveWork`, `BriefLookingAhead`, bounded card types, and explicit optional sections.
2. `BriefProactiveWork` must carry `cardID`, `title`, `reasoning`, `provenanceLabel`, and a typed direct-open source reference; it must never carry raw note content.
3. Make contracts `Sendable`, `Equatable`, and `Codable` where serialized.
4. Add pure validation for field allow-list, caps, URL scheme, private=false invariant, stable ordering, and card/source identity.
5. Preserve the existing planner's deterministic output semantics while making provenance/direct-open fields explicit.
6. Reject unknown/unsafe payload fields at the native boundary before injection.

### Task B2 — Build deterministic resume selection

**Files:**
- Create: `Sources/HiveCore/Browser/BriefResumePolicy.swift`
- Modify: `Sources/Hive/BrowserState+Brief.swift`
- Test: `Tests/HiveCoreTests/BriefResumePolicyTests.swift`

**Required inputs:**

```text
BriefResumePolicy.Input {
  openTabs: [OpenTabInput]
  readingList: [ReadingListInput]
  history: [HistoryInput]
  dismissedCardIDs: Set<String>
  scope: BriefScope
}
```

**Required behavior:**

1. Consume open-tab, reading-list, and history metadata through typed inputs.
2. Exclude private tabs, private history, internal Hive routes, blank pages, non-http(s), forgotten scopes, and dismissed card IDs.
3. Rank open tabs before reading list before history; document pinned/essential tie-breaks.
4. Use stable tie-breaks and cap at eight.
5. Return direct source URLs and provenance labels without raw page body or note text.
6. Prove dismissal does not mutate or delete the underlying browser source.

### Task B3 — Introduce local dismissal state with explicit semantics

**Files:**
- Create: `Sources/HiveCore/Browser/BriefDismissalStore.swift`
- Modify: `Sources/Hive/BrowserState+Persistence.swift`
- Modify: `Sources/Hive/BrowserState+Brief.swift`
- Test: `Tests/HiveCoreTests/BriefDismissalStoreTests.swift`

**Storage authority:** `BriefDismissalStore` is a dedicated schema-version-1 JSON store at the exact path `Application Support/Hive/brief-dismissals.json`, separate from Honeycomb and the session envelope. It uses an actor, atomic temporary-write/replace, bounded record retention, and quarantine-on-decode-failure to `brief-dismissals.corrupt-<timestamp>-<uuid>.json`. A dismissal record is keyed by `(scopeID, cardID, sourceIdentity, cardVersion)`; source deletion/forgetting invalidates matching dismissals during payload assembly and cleanup. The store exposes `dismiss`, `restore`, `isDismissed`, and `purgeInvalidated` operations. Unknown future schema versions are rejected into a visible `dismissalsUnavailable` state rather than treated as an empty dismissal set.

**Required behavior:**

1. Persist dismissals outside Honeycomb memory nodes with schema versioning.
2. Scope dismissals to profile/workspace and card/source identity.
3. Make writes idempotent and restart-safe.
4. Keep dismissal distinct from `HotMemoryStore.forgetNode` and durable Honeycomb deletion.
5. Support explicit restore/unhide without resurrecting deleted or private sources.
6. If dismissal persistence is unavailable, keep the Brief usable and disclose that the hide action did not persist.

### Task B4 — Define and enforce the memory eligibility boundary

**Files:**
- Create: `Sources/HiveCore/Browser/BriefMemoryEligibility.swift`
- Modify: `Sources/Hive/BrowserState+Brief.swift`
- Test: `Tests/HiveCoreTests/BriefMemoryEligibilityTests.swift`

**Required behavior:**

1. Define a pure `BriefMemoryEligibility.evaluate(node:captureAttempt:scope:)` result with `eligible`, `private`, `candidate`, `forgotten`, `outOfScope`, `auditIncomplete`, `unknownLegacy`, and `unknown` denial reasons.
2. Reuse the M1 `MemoryRetrievalAdmission.evaluate(...)` contract and its exact eligible-attempt selection rule: for a node with multiple attempts, select an eligible `complete` attempt for the requested scope; never blindly use the latest failed duplicate. Brief eligibility is not a retrieval bypass.
3. Resolve Honeycomb node provenance/privacy/candidate state before handing memory items to `ProactiveBriefPlanner`; do not rely on the WebChrome template to hide unsafe records.
4. Exclude private, candidate, forgotten, audit-incomplete, out-of-scope, and unknown-legacy records.
5. Preserve the existing generic note-label rule and never pass raw note content into the planner's card text.
6. Add fixtures proving a private/candidate/forgotten/audit-incomplete node cannot reach proactive cards, payload, or resume sources, while a node with a separate prior complete attempt remains eligible only through that complete attempt.

### Task B5 — Build the versioned allow-listed payload

**Files:**
- Modify: `Sources/Hive/BrowserState+Brief.swift`
- Modify: `Sources/Hive/WebChromeHandler.swift` only if placeholder transport needs a typed schema boundary
- Test: `Tests/HiveCoreTests/MorningBriefPayloadTests.swift`

**Required behavior:**

1. Emit `brief.v2` with documented compatibility aliases during transition.
2. Keep Ring 1 fields available without Honeycomb/EventKit/model/network.
3. Emit only validated resume/proactive/calendar/task/source fields.
4. Preserve hardened escaping for `</script>`, quotes, control characters, U+2028/U+2029, and untrusted titles/URLs.
5. Bound tabs/history/memory/calendar inputs before serialization.
6. Make generated payload semantically deterministic; isolate current timestamp/greeting as explicit variable fields.
7. Do not include raw note content, hidden memory narration, credentials, private data, or analytics identifiers.

### Task B6 — Keep proactive memory cards provenance-bound

**Files:**
- Modify: `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift`
- Modify: `Sources/Hive/BrowserState+Brief.swift`
- Test: `Tests/HiveCoreTests/ProactiveBriefPlannerTests.swift`

**Required behavior:**

1. Keep latest real brief preference and count-based note/capture fallback.
2. Require at least one eligible non-private, non-candidate, non-forgotten source in the bounded window.
3. Redact user note text and do not allow caller-provided raw note labels into card prose.
4. Emit one card maximum with a compact provenance label and reversible open action.
5. Omit the card entirely when no eligible signal exists.
6. Prove identical inputs produce identical semantic plans.

### Task B7 — Preserve lazy, local, bounded calendar behavior

**Files:**
- Modify: `Sources/Hive/ProactiveBriefCalendar.swift` only if contract alignment requires it
- Modify: `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift` only for typed calendar contract
- Test: `Tests/HiveCoreTests/ProactiveBriefCalendarPolicyTests.swift`

**Required behavior:**

1. Default preference remains off.
2. Request permission only after explicit enablement.
3. Read today's titled events only, capped at 12.
4. Retain title/start only; do not expose attendees, locations, notes, conferencing URLs, or account identifiers.
5. Denial/restriction/error returns an empty calendar input and preserves a useful Brief.
6. No EventKit call occurs in the zero-history path while the preference is off.

### Task B8 — Update the Brief WebChrome contract and accessibility surface

**Files:**
- Modify: `Sources/Hive/WebChrome/brief/index.html`
- Modify: `Sources/Hive/WebChrome/brief/app.js`
- Modify: `Sources/Hive/WebChrome/brief/tokens.css` if present and required by existing asset contract
- Test: `Tests/HiveCoreTests/MorningBriefContractTests.swift`

**Required behavior:**

1. Render the fixed hierarchy: search → resume → one memory card → look-ahead → secondary controls.
2. Hide absent sections rather than leaving empty cards.
3. Show compact provenance labels and direct open/dismiss actions.
4. Keep internal navigation shell-gated; do not let untrusted payload strings become executable HTML.
5. Preserve keyboard order, focus visibility, VoiceOver labels, contrast, and reduced-motion behavior.
6. Keep the current Hive branding and embedded asset inventory contract green.

### Task B9 — Add clean-profile and privacy evidence

**Files:**
- Extend: `Tests/HiveCoreTests/ProactiveBriefPlannerTests.swift`
- Extend: `Tests/HiveCoreTests/MorningBriefContractTests.swift`
- Create if needed: `Tests/HiveCoreTests/BriefRuntimeFixtureTests.swift`

**Required fixtures:**

- zero data, zero memory, no calendar permission;
- open normal tabs plus private tabs;
- internal Hive routes and blank tabs;
- reading-list/history candidates with stable ordering ties;
- real captured source plus forgotten/private/candidate records;
- hostile title/URL/control-character payload;
- raw note secret that must not appear in Brief JSON;
- calendar off, denied, restricted, empty, one event, twelve events, >12 events;
- thousands of tab/history/memory inputs with output caps;
- repeated identical inputs with semantic byte-stable output apart from explicit generated-time fields;
- dismissal persisted, restored, restored/unhidden, and deletion-versus-dismissal separation.

## Failure and Recovery Matrix

| Scenario | Required result | Must not happen |
|---|---|---|
| zero data | search/import/blank-workspace utility | fake tasks, fake memories, feed, forced calendar |
| Honeycomb unavailable | Ring 1 still renders; memory card omitted | blank page or false memory card |
| EventKit denied | useful non-calendar Brief | permission error wall |
| private tab present | omitted before payload construction | private title/URL in JSON or DOM |
| internal Hive tab | omitted as external resume destination | internal routing exposed as user content |
| invalid URL/scheme | rejected by pure policy | javascript/data/file URL emitted |
| dismissed resume/card | omitted for scope; source remains unchanged | hidden action mutates tab/history/memory |
| dismissal persistence fails | Brief remains useful; hide is marked non-persistent | false “hidden forever” claim |
| raw note content | generic note label or omission | secret text in payload/card |
| hostile title | escaped safe text | `</script>` breakout/XSS/layout corruption |
| huge input | bounded output and deterministic cap | unbounded payload/main-actor stall |
| calendar >12 events | deterministic first 12 by start/tie-break | full calendar dump |
| day rollover | explicit refresh only on rollover/state change | 60-second content reload loop |
| model unavailable | deterministic local Brief still works | model required for first tab |
| network unavailable | Brief still works with local inputs | network-backed cards silently inserted |

## M2B Acceptance Gates

| Gate | Requirement | Fresh evidence |
|---|---|---|
| M2B-1 | Zero-history Brief renders useful browser actions without model/network/calendar | clean-profile runtime path |
| M2B-2 | `brief.v2` validates against an allow-listed schema and preserves transport compatibility | payload contract tests |
| M2B-3 | Resume selection is deterministic, bounded, provenance-labeled, and private-safe | pure policy matrix |
| M2B-4 | Dismissal is persistent, scoped, reversible, and distinct from deletion/forgetting | store/lifecycle tests |
| M2B-5 | Proactive card appears only for real eligible signals | planner matrix |
| M2B-6 | Raw note content never reaches Brief payload/card prose | static/runtime redaction tests |
| M2B-7 | Calendar is opt-in, lazy, bounded, local-only, and denial-safe | EventKit policy tests |
| M2B-8 | XSS/escaping and untrusted metadata tests remain green | MorningBriefContractTests |
| M2B-9 | Output caps hold under thousands of inputs | bounded payload fixture |
| M2B-10 | Absent sections disappear; no fake cards/feed/metrics render | WebChrome contract/runtime evidence |
| M2B-11 | Resume actions open exact external source without mutating source state | UI integration evidence |
| M2B-12 | Keyboard/VoiceOver/contrast/reduced-motion path is complete | accessibility evidence |
| M2B-13 | Day rollover refreshes only on rollover or explicit state change | lifecycle test |
| M2B-14 | Clean profile remains useful with Swarm and memory disabled | manual browser runtime evidence |

M2B is `verified` only after all gates pass with current build/test/runtime evidence. Existing deterministic planner tests alone are not sufficient.

## Implementation Order and Stop Conditions

1. Define versioned contracts and pure validators.
2. Add deterministic resume policy and dismissal semantics.
3. Build the allow-listed native payload while preserving the existing placeholder transport.
4. Reconcile proactive memory and calendar adapters with the privacy contract.
5. Update WebChrome rendering and accessibility contracts.
6. Run focused tests, `swift build`, `swift test`, and clean-profile runtime evidence.
7. Stop M2B before model-generated copy, news/weather feeds, cloud continuity, ambient capture, or remote services.

## Explicit Deferrals

- Model-generated Morning Brief prose.
- News, sponsored content, weather, RSS, and external feeds.
- Cloud account continuity or cross-device resume.
- Screen Recording, Accessibility, and OS-wide activity summaries.
- Ambient capture, promise inference, vectors, and long-term forgetting.
- Analytics containing titles, URLs, notes, calendar strings, or generated copy.
