# WISP_CAPTURE_SPEC — Deterministic Automatic Capture (Wisp capability; execution plan M3)

> **Canonical status:** active
> **Created:** 2026-08-11
> **Purpose:** Makes the quiet memory layer ("wisps" — Rewisp-style ambient capture done *at the DOM instead of the OS*) fully deterministic: exact triggers, exact payloads, exact dedup, exact privacy gates, exact retention, exact eval hooks. Existing symbols are labeled **verified**; the dedicated candidate-store and promotion APIs are labeled **planned** and require the M0 four-store recovery contract and M3 gates before implementation.
> **Dependencies:** HONEYCOMB_SPEC.md (node/edge contract), VISION_SPEC.md (reduction-first capture), MEMORY_ARCHITECTURE_SPEC.md (reinforcement/forgetting), ROUTING_SPEC.md (latency SLAs), 00_INDEX.md, `docs/superpowers/plans/2026-08-11-m0-storage-migration-recovery-spec.md`, `docs/superpowers/plans/2026-08-11-m3-candidate-wisp-plan.md`, `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md`
> **Design principle:** A wisp is the smallest unit of *remembrance*. It is always automatic, always reversible, and never silently durable. The user promotes; the system proposes. Model extraction is a *candidate* until the user confirms (hard boundary inherited from `MemoryAdmissionPolicy`).

---

## 0. The thesis, restated for the wisp capability

The browser is the only surface that can capture *why* a page mattered: the tab it was opened from, how long it held attention, whether it was read, scrolled, searched, acted on. A screenshot recorder (Rewisp) captures *that text was on screen*. Hive captures *that the user actually worked with it*. That is the candidate-only M3 hypothesis to test:

- **Deterministic:** same page, same session pattern → same wisp. No model in the loop for capture itself.
- **Reduction-first:** wisps are metadata + short extracted signals, never page dumps, never screenshots. (VISION_SPEC §2.)
- **Two-tier admission:** automatic capture creates *candidates*; in M3 only explicit Save promotes to *durable*. Digest approval is deferred beyond M3; when M5 adds it, approval remains a separate M1-compatible promotion path and never bypasses the candidate lease, audit, provenance, or deletion contracts. (The durable boundary is enforced by `MemoryAdmissionPolicy` plus M1's attempt/audit contract.)
- **Honest:** the user can see exactly what was captured, where it lives, and delete it with one click ("nuke last 10 minutes" parity).

---

## 1. Verified code symbols this spec builds on

> **Execution naming:** this document contains historical “M2” labels from the original wisp proposal. The current dependency-ordered execution plan schedules the capability at M3, after storage, explicit capture, and import/Brief gates; new implementation guidance in this document uses M3.

### 1.1 Planned candidate storage — fixed M3 decision, not current code

The current `HoneycombStore.NodeType` enum has 11 production types listed in `HONEYCOMB_SPEC.md §1.1`; `.wisp` is **not** one of them today and M3 will not add it. The finalized M3 decision is a dedicated schema-v1 `wisp_candidates` SQLite store at `Application Support/Hive/wisp-candidates.sqlite3`, outside Honeycomb nodes/edges/FTS/Markdown export. This is not an untracked memory authority: M0 treats it as a first-class candidate participant alongside the planned M5 lifecycle store in `StorageEpochCoordinator`, diagnostics, recovery-journal classification, and four-store snapshots.

The `.wisp` Honeycomb-node alternative is explicitly rejected for M3. Do not add a Honeycomb enum case, FTS row, graph edge, or durable-node deletion path for automatic candidates. Promotion creates or reuses a durable `.source` through M1's capture-attempt/audit contract; it does not flip a candidate admission flag in HotMemory. The detailed schema, lease-safe promotion, shared exclusion, privacy, retention, and recovery contract lives in `docs/superpowers/plans/2026-08-11-m3-candidate-wisp-plan.md`. The `wisp_candidates` table and promotion/delete operations remain planned APIs, not current runtime behavior.

| Symbol | File | Role in M3 |
|---|---|---|
| `MemoryAdmissionPolicy.userAuthoredCapture(isPrivate:)` | Sources/HiveCore/Browser/MemoryAdmission.swift | Returns `.durable` (non-private) or `nil` (private) for explicit M3 Save promotion. Automatic candidates must not call it as a durable-ingress shortcut. |
| `MemoryAdmissionPolicy.modelExtraction(isPrivate:)` | same | Returns `.candidate` (non-private) or `nil`; M3 uses the candidate admission contract and never returns durable automatically. |
| `captureCurrentPage()` | Sources/Hive/BrowserState+Brief.swift | The durable M1 capture contract M3 reuses only through explicit promotion: dedup hash, fail-closed storage, audit, `memoryRevision` bump. |
| `captureNote(_:)` | same | Label = first 80 chars, hash = sha256(trimmed), provenance "user". |
| `pageNodeID(for:)` | Sources/Hive/BrowserState+Research.swift | Deterministic node-ID derivation — wisps must reuse it so dedup keys match manual captures. |
| `buildPageContext()` | same | `PageContext?` — the current-page snapshot (`url`, `title`). |
| `recordAuditEvent(_:)` | Sources/Hive/BrowserState+AI.swift | Every durable promotion is audited through the M1 attempt/event contract; candidate creation is not a raw-content ledger event. |
| `hotMemory.didAccessNode(id:sourceHint:label:workspaceID:profileID:)` | HotMemoryStore | Warm path for candidates — sourceHint distinguishes `"captured"` / `"explicit"` / `"wisp"`. |
| `HoneycombStore.findNode(type:contentHash:)` / `insertNode` | HoneycombStore | Dedup + write; fail-closed semantics copied verbatim from `captureCurrentPage`. |
| Probe contract | `mediaStateProbeScript`, `linkPeekProbeScript` (BrowserState.swift), `autofillProbeScript` (BrowserState+Autofill.swift) | The wisp probe follows the SAME contract: self-guarding IIFE, `HIVE_X|…` console-bridge messages, `encodeURIComponent` on delimiters, dwell timers, capture-phase document delegation. |

---

## 2. The wisp probe (DOM-side, deterministic, no model)

### 2.1 Contract

Injected into every non-private http/https page after load commit (same injection point and guards as the existing probes). Self-guarding:

```js
(function(){
  if (window.__hiveWispProbeInstalled) return;
  window.__hiveWispProbeInstalled = true;
  // …triggers below…
})();
```

Messages go over the existing console bridge, delimited with `|`, values `encodeURIComponent`-escaped (rule inherited from `linkPeekProbeScript` — a raw `|` in a URL must never collide with the delimiter).

### 2.2 Messages

| Message | When | Payload |
|---|---|---|
| `HIVE_WISP|settled|{url}\|{title}\|{depth}\|{time}` | Scroll settles (≥600ms no scroll) **and** ≥4s dwell on the page | url, title, max scroll-depth fraction (0–100), seconds since load |
| `HIVE_WISP|tabswitch|{url}\|{title}\|{depth}\|{time}` | User switches away from the tab (blur / visibilitychange) with ≥4s dwell | same |
| `HIVE_WISP|reader|{url}\|{title}\|{words}\|{time}` | Reader-mode eligible article detected (`<article>` + ≥500 words, same heuristic as reader mode) and ≥10s dwell | url, title, word count, seconds since load |
| `HIVE_WISP|linkout|{url}\|{title}\|{target}\|{time}` | User clicks a link away after ≥4s dwell (the page *led somewhere* — a directed edge) | url, title, destination url, seconds since load |

**Hard rules for the probe:**
1. Reads **only** `location`, `document.title`, scroll position, click targets, and the reader-eligibility heuristic. Never body text, never DOM subtree dumps, never screenshots. (VISION_SPEC reduction-first.)
2. All timers are dwell/scroll timers only — no interval polling of content. Background-tab throttling cannot stall it (event-driven, like `mediaStateProbeScript`).
3. A wisp is **suppressed** for the current page if the page ever reports a kill-list host, credential-shaped DOM (`input[type=password]` present — autofill already detects this), or the host is in `hostContextPolicy` deny.
4. At most **one** message per trigger class per page-visit (a `linkout` is always the terminal message for a visit; `settled` never re-fires after `linkout`).

### 2.3 Native-side trigger validation

The probe reports; the native side **validates deterministically** before any candidate is created. All privacy decisions come from one metadata-only `WispCapturePrivacyPolicy`; `allow`, `deny`, and `unknown` are explicit outcomes, and both `deny` and `unknown` prevent injection/storage. The policy never reads form values or page content, and unavailable host/private/password metadata fails closed. This is the anti-drift gate:

| Check | Rule |
|---|---|
| `MemoryAdmissionPolicy.modelExtraction(isPrivate: isPrivateBrowsing)` | Must return `.candidate`. Private → discard silently (no candidate, no log). |
| URL scheme | `http`/`https` only (same guard as the brief's todos). |
| Kill list | Host in the hard-coded sensitive-app set (messaging, banking, password managers — VISION_SPEC §2.3) → discard. |
| PII shape | URL or title matches card/SSN/credential shape → discard. |
| Host opt-out | Host in `siteWispOptOutHosts` (UserDefaults-backed set, toggled from the wisp panel) → discard. |
| Dedup | Candidate-store identity uses the versioned canonical URL/title/kind hash; identical candidate events are a candidate-store no-op. No Honeycomb `.wisp` lookup exists. |
| Interval | Same url within the same session already produced a candidate within the last 15 minutes → replace, don't duplicate (the deeper/reader variant supersedes the shallower one). |

Every discarded wisp is counted (diagnostics only — `wispDiscardCount`), never stored.

---

## 3. The candidate lifecycle (two-tier admission)

```
probe event → validation (all checks above)
  → candidate (in-memory + hotMemory, sourceHint: "wisp")
     → promotion paths:
        (a) explicit Save (button on the wisp toast / knowledge panel)  → durable .source
        (b) Daily Digest approval                                          → **deferred beyond M3; M5 path requires explicit approval + M1 audit**
        (c) reinforcement signals (asked about it, cited in a Swarm
            answer, opened from the panel ≥2×)                          → raise a visible approval suggestion only; NEVER promote
     → decay paths:
        (d) not promoted in 7 days                                      → dropped
        (e) user "Nuke last 10 minutes" / "Forget"                      → dropped immediately
        (f) private mode session ended                                  → dropped with the profile
```

### 3.1 Candidate storage

> **Canonical M3 correction:** this section is subordinate to the dedicated-store decision in §1.1 and `docs/superpowers/plans/2026-08-11-m3-candidate-wisp-plan.md`. Do not implement the older `.wisp` node alternative.

- **Planned:** candidates live in a bounded in-memory working set plus the dedicated schema-v1 `wisp_candidates` table described by the M3 plan. They are queryable by the dedicated candidate surface, but **excluded from Swarm context assembly by default and by one shared `WispContextAdmission` seam** across HotMemory, PageContextBroker, Honeycomb model retrieval, ranker input, Brief cards, and export. The table/API does not exist until M0 four-store recovery gates and M3 storage gates land.
- **Rejected for M3:** a candidate's node type is `.wisp`. Automatic candidates have no Honeycomb node, FTS row, graph edge, Markdown export row, or durable-node deletion semantics.
- **Planned:** promotion to durable **mints or reuses a `.source` node** with the M1 metadata/provenance shape (`observed_url`, canonical identity, host, captured_at, method: `promoted_from_wisp`) and the same page identity/content-hash policy, so a later manual `captureCurrentPage()` dedups to it. The candidate is removed only after M1 audit reconciliation succeeds; a Honeycomb-success/EventLedger-failure outcome remains audit-incomplete and model-quarantined.
- **Deferred:** any `.wisp` → `.source` graph edge. M3 does not add `opens` or another relation for automatic candidates; later research-trail work must be separately approved after M3 and must use an existing typed `EdgeRelation` or a versioned migration.

### 3.2 Promotion is ALWAYS user-visible

- Candidate creation shows a quiet, dismissible toast: **"Hive noticed this page — Save to memory?"** with Save / Not now / Never for this site. (Never-forsite writes `siteWispOptOutHosts`.)
- A Daily Digest approval surface is deferred beyond M3. M3 does not promote candidates from a digest; M5 supplies the separately reviewed consent, retention, and audit contract in `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md`.
- Every promotion is audited via `recordAuditEvent` (`.capture`, trustLevel `.t0`, consentState `.granted` for the explicit Save path) and bumps `memoryRevision` so open knowledge surfaces refresh live.

---

## 4. Retention & forgetting (MEMORY_ARCHITECTURE_SPEC §4, made concrete)

| Tier | Lifetime | Trigger |
|---|---|---|
| In-memory candidate | session working set | bounded HotMemory candidate entries; removed on dismiss/expiry/promotion/scope revoke |
| Dedicated candidate row | 7 days | schema-v1 store sweep; reinforcement may raise an approval suggestion, but never promotes automatically |
| `.source` durable (promoted) | governed by M1/M5 durable policy | created only through explicit M1 promotion and audit reconciliation |
| Candidate nuke | candidate window only | scope-bound deletion/tombstoning in the candidate store + candidate HotMemory; no durable-Honeycomb or forensic-erasure claim |

Nightly consolidation and digest promotion are deferred from M3. The candidate store must remain bounded and auditable rather than silently folding automatic rows into durable episodes. Candidate retention uses the M3 active/tombstone/size bounds; if non-evictable rows exhaust capacity, admission fails closed with `storeCapacityBlocked`.

---

## 5. Privacy UX (the un-scary surface)

1. **A "What Hive remembers" panel** (Knowledge panel → Memory section): every durable source + every pending candidate, each with a Forget button. No paging through settings.
2. **Per-site opt-out** that works from the toast, the panel, and the site-security popover (sitePermissions parity).
3. **Private mode is absolute**: private tabs never fire the probe, and the probe script is never injected there (same guard as `autofillProbeScript` — "never private tabs").
4. **The kill list is visible and auditable**: Settings → Privacy lists every hard-coded never-capture host and the user's additions.
5. **No screenshots, ever.** Nothing in M3 renders to pixels. (VISION_SPEC §2 is the contract.)
6. **Export**: durable sources already export via the existing Honeycomb export path; **planned** candidate export is a separate explicit JSON list (bounded observed/canonical URL, title, when, kind) — one file, one click. It is not Honeycomb Markdown export and never becomes model context; the export contract is governed by the M3 plan.

---

## 6. Determinism & eval hooks (how we prove "deterministic")

| # | Invariant | Test |
|---|---|---|
| W-1 | Same page, same session pattern → identical candidate (same contentHash, one candidate row) | Unit: two visits to the same fixture page → candidate store returns one row. |
| W-2 | Probe never fires on kill-list / private / password-present pages | Fixture pages per case → zero messages. |
| W-3 | Model extraction can never become durable | Sweep `MemoryAdmissionPolicy.modelExtraction` across private/non-private → never `.durable`. |
| W-4 | Promotion creates/reuses exactly one `.source` and removes the candidate only after M1 audit reconciliation | Integration: promote → one source, no `.wisp` node, candidate lifecycle reconciled. |
| W-5 | Dedup with manual capture | Wisp then `captureCurrentPage()` on the same page → same node ID (pageNodeID + contentHash agreement). |
| W-6 | Discard counter monotonic per reason | Fixture adversarial pages (card numbers, banking host, password form) → `wispDiscardCount` increments, store empty. |
| W-7 | Candidate nuke removes only the scoped candidate window | Seed candidates inside/outside the window → candidate store/HotMemory counts match; Honeycomb is untouched. |
| W-8 | Candidate retention/capacity bounds | Simulate 8 days and non-evictable-row exhaustion → tombstones sweep; `storeCapacityBlocked` fails closed; no quarantine eviction. |
| W-9 | Latency budget | Probe injection adds <5ms to load commit; native validation <1ms (no I/O on the hot path beyond the in-memory dedup set; SQLite dedup only on promotion). |
| W-10 | No theater | Every visible candidate is labeled candidate/not-in-AI-context with observed/canonical provenance; nothing auto-promotes without explicit M1 audit evidence. |

---

## 7. Rollout (staged, honest)

| Stage | Scope | Ship gate |
|---|---|---|
| 1. Settled probe + validation | `HIVE_WISP|settled` only, dedicated candidate store, no promotion UI claim yet | M0 four-store gate + M3 privacy/admission/latency gates |
| 2. Candidate surface | Candidate store + truthful toast/panel + Save/Not now/Never | M3 storage, exclusion, accessibility, and capacity gates |
| 3. Explicit promotion + retention | M1 promotion path, leases, reconciliation, scoped nuke/expiry | M1 audit gate + M3 promotion/retention gates |
| 4. Deferred extensions | tabswitch/reader/linkout, digest, edges, body extraction, and any context expansion require separate reviewed contracts | no automatic expansion from M3 |


Each stage ships independently; a stage that fails its gate blocks only itself. The wisp capability is **verified** (not code-present) only when the M0–M2 prerequisites and the M3 plan gates pass with clean-profile runtime evidence.

---

## 8. Deferred decisions (not part of M3)

The following do not reopen the dedicated-store decision and require separate post-M3 contracts:

- **Reader-detail wisps** (Stage 2 of extraction): the probe may run the existing bounded reader-eligibility heuristic in memory to decide whether to emit a reader signal; it must not store body text in the candidate. If the user explicitly promotes a reader candidate, the native reader extractor may then obtain plaintext under the separate capture/privacy contract, with the source hash covering `url + title + body` so edits re-hash. This is the one place the wisp capability may hold body text, and it remains an explicit user action—not automatic promotion.
- **`siteWispOptOutHosts` default**: empty. The kill list + password-detection guard covers the high-risk set; per-site opt-out is user-driven, not pre-seeded.
- **Wisp vs visit**: tab history already tracks visits; wisps are the *retention decision*, not the visit record. They never duplicate `historyItems`.
