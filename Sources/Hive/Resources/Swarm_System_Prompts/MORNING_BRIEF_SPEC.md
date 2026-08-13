# MORNING_BRIEF_SPEC — Useful Before It Knows You

> **Canonical status:** active
> **Created:** 2026-08-11
> **Purpose:** Define the first-launch and daily-start experience so Hive's Morning Brief is a calm browser surface, not a creepy dashboard. It must be useful with zero history, become more relevant through explicit browser activity, and remain deterministic/local by construction.
> **Dependencies:** `Sources/Hive/BrowserState+Brief.swift`, `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift`, `Sources/Hive/WebChrome/brief/index.html`, `app.js`, `MorningBriefContractTests.swift`, `ProactiveBriefPlannerTests.swift`, `MEMORY_ARCHITECTURE_SPEC.md`, `VISION_SPEC.md`, `HONEYCOMB_SPEC.md`, `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md`
> **Evidence anchor:** First-party browser start-page patterns converge on modular controls, direct shortcuts, recent/continuity surfaces, and explicit feed toggles. Safari stays local and quiet; Chrome offers shortcuts/continuity and optional cards; Firefox exposes granular section toggles; Edge demonstrates the risk of an algorithmic news dashboard. Hive should take the useful parts without importing the feed business model.

---

## 1. Product thesis

The first Hive tab must answer one question quickly:

> **“What should I do next, and how do I get back to what I was already doing?”**

It must not answer “what can Hive infer about me?” The brief is a browser start surface with a memory-aware layer, not a surveillance report.

### 1.1 The three rings of usefulness

1. **Immediate utility — always available:** search/omnibox, recent or pinned destinations, open-tab resume, browser controls.
2. **Local continuity — earned by activity:** real open tabs, recent history domains, reading list, workspace context, captured sources, deterministic “pick up where you left off.”
3. **Proactive assistance — opt-in and evidence-backed:** memory-derived “Started for you,” optional calendar look-ahead, and later source-grounded suggestions.

Ring 1 must never wait for Honeycomb, EventKit, a model, network access, or an account. Ring 2 may be empty and should say so. Ring 3 is hidden until there is a real signal and the relevant preference is enabled.

---

## 2. Verified current implementation

The `ResumeItem`, provenance-label, dismissal, and ranking contracts introduced below are **planned schema/interaction contracts**, not current payload fields. Current `buildBriefJSON()` emits `top_todos`, `tasks`, optional `proactive_work`, `painting`, `looking_ahead_blurb`, and optional footer sources; implementation must add a versioned payload schema before requiring the new fields.

| Symbol/file | Current contract | Spec guard |
|---|---|---|
| `BrowserState.buildBriefJSON()` | Produces escaped JSON for the `__HIVE_BRIEF_JSON__` script placeholder | Preserve the placeholder and XSS escaping contract. |
| `proactiveBriefPlan()` | Reads Honeycomb node titles/timestamps; notes are replaced with generic labels; optional EventKit events only when enabled | Never put raw note text into the brief by default. |
| `ProactiveBriefPlanner.plan` | Pure deterministic planner; identical inputs produce identical output; honest empty fallbacks | No model-generated prose or fabricated tasks in M2. |
| `top_todos` | Derived from open non-private tabs, capped at eight | Private tabs remain excluded; titles/URLs are untrusted and escaped. |
| `tasks` / `footer.sources` | Derived from recent history domains, capped at six | History-derived cards must remain local and dismissible. |
| `proactive_work` | Omitted when there is no real memory signal | Do not render an empty “AI insight” card. |
| `painting.caption` | “Quiet start” fallback or count of real new items | Counts must reconcile with the planner input window. |
| `looking_ahead_blurb` | Calendar-aware only with opt-in; otherwise memory/empty fallback | Calendar is local-only and never silently enabled. |
| `startProactiveBriefTimer()` | Refreshes open brief tabs on local calendar-day rollover | No minute-by-minute reload; avoid surprising the user. |
| `MorningBriefContractTests` | Guards asset placeholder, branding, embedded assets, XSS, internal routing | Extend contract tests rather than relying on visual inspection only. |

---

## 3. First launch: zero-history contract

A new user must see a complete, useful page without an account, network call, model, calendar permission, or imported data.

### 3.1 Required empty state

- A focused search/omnibox entry point.
- A concise “Import from another browser” action with supported data types stated: **bookmarks and history**.
- A “Start with a blank workspace” option.
- A small keyboard hint for the primary command (`⌘L` / new-tab shortcut), not a tutorial wall.
- Optional static quick actions: open settings, choose search engine, read privacy explanation.
- No fake tasks, fake memories, news feed, personalized recommendation, fabricated weather, or “we learned about you” copy.

### 3.2 First action sequencing

The first page should ask for only one meaningful action at a time:

1. **Browse:** search or open a URL.
2. **Import:** offer detected sources; user may skip.
3. **Remember:** after a real page or explicit note, show the capture affordance.
4. **Ask:** reveal Swarm after a page or memory exists; do not force chat onboarding.

The brief must not demand calendar access, Screen Recording, Accessibility, cloud sign-in, or model downloads to become useful.

---

## 4. Daily brief information architecture

### 4.1 Above the fold

Order is fixed for M2:

1. Greeting/date — quiet, short.
2. Search/omnibox — direct browser action.
3. Resume row — open-tab “pick up where you left off” items (maximum eight, non-private, valid http/https only).
4. One memory/proactive card only if the planner has a real signal.
5. Looking ahead only if enabled and populated; otherwise omit or use a subdued empty line.

Do not place a large painting/illustration between the user and the next navigation action on a small window. Visual identity is welcome, but utility owns the first interaction.

### 4.2 Resume semantics

A resume item must represent a real browser state:

```text
ResumeItem {
  title: String
  sourceURL: URL
  origin: open_tab | reading_list | history
  workspaceID: UUID?
  private: false
  lastObservedAt: Date?
}
```

- Open tabs outrank history because they represent unfinished work.
- Pinned/essential tabs may outrank ordinary tabs, but the ranking must be deterministic and documented.
- A private tab can never become a resume item in a normal-profile brief.
- A Hive-owned internal route is not presented as an external resume destination.
- Every item has a direct open action and a remove/hide affordance; dismissal must not delete the source tab/history record.

### 4.3 Memory card semantics

`proactive_work` is a proposal, never a claim about the user’s intention. It may appear only when:

- there is at least one real source/note/brief/capture in the planner window;
- the source is not private;
- the item has not been dismissed or forgotten;
- the card can name its provenance in a compact disclosure (`Saved yesterday`, `From this workspace`);
- the action is reversible and opens the source or knowledge panel rather than mutating data.

The card must never say “I know you…” or narrate hidden memory. Use natural copy such as “You saved 3 pages yesterday — pick up where you left off.” This follows the verbosity/memory UX rule: memory should be implicit in the answer, not performative.

### 4.4 Calendar semantics

Calendar is a separate opt-in ring:

- preference default is off;
- permission requested only when the user enables it;
- event title/start are processed locally;
- event content is never sent to remote models or analytics by default;
- permission denial yields a useful non-calendar brief, not an error wall;
- only today’s bounded event window is shown, capped at 12;
- no attendee names, locations, notes, or conferencing URLs in the M2 card unless separately specified and explicitly enabled.

### 4.5 No feed contract

Hive M2 has no algorithmic news/sponsored feed. This is deliberate:

- Edge demonstrates how a feed can dominate a browser start page and become a privacy/quality complaint.
- Firefox and Chrome demonstrate that modular toggles are necessary when cards exist.
- Safari demonstrates a quieter continuity-oriented start page.

If a future source/research feed is added, it needs its own provenance, network, ranking, advertising, and consent spec. It must not arrive as an accidental “brief enhancement.”

---

## 5. Data and privacy contract

> **M5 extension:** this M2 Brief contract remains the authority for zero-history and deterministic start-page behavior. M5 adds the separate `DigestManifest`/`DigestItem` review queue; a digest approval does not silently mutate the M2 Brief, create a Task, or delete a source. Those transitions require the M5 approval and M1 audit contracts.

### 5.1 Local-only by default

The brief’s input classes are local-only:

| Input | Default retention/use | Remote model eligibility |
|---|---|---|
| Open-tab metadata | session/browser state | Not eligible by default |
| History domains | local history | Not eligible by default |
| Honeycomb node labels/timestamps | local memory | Not eligible by default |
| Note content | hidden from M2 brief copy | Explicit user scope only |
| Calendar title/start | local, opt-in | Not eligible by default |
| Weather/news/external feed | absent in M2 | Future separate consent |

The brief JSON is an internal page payload, not telemetry. Do not add analytics events containing titles, URLs, notes, calendar strings, or generated copy. Local aggregate counters may be used for debugging if they contain no content identifiers.

### 5.2 Provenance labels

Every non-empty non-navigation card must expose a lightweight source label in the UI:

- `Open tab`
- `Saved yesterday`
- `From your workspace`
- `Today’s calendar` (only when enabled)

The label is an inspectability feature, not a memory monologue. A detail action can open the source/provenance view.

### 5.3 Deletion and dismissal

- Hide a card: suppress that card instance without deleting its source.
- Forget a memory: use Honeycomb deletion/retention semantics.
- Close a tab: normal browser close behavior; no hidden brief copy survives unless explicitly captured.
- Private mode: no brief ingestion, no resume, no memory-derived card.
- “Clear last 10 minutes”: must include brief candidates and any brief-local derived cache, not only browser history; M5 defines the crash-resumable cross-store purge and its honest secure-erasure boundary.

---

## 6. Visual and interaction direction

The brief should feel like a composed browser page, not a SaaS dashboard:

- One dominant hierarchy; no grid of equal-weight cards.
- The browser action is the primary control; memory is secondary.
- Warm, restrained Hive palette; no generic AI purple/blue treatment or sparkle iconography.
- Cards use progressive disclosure: one-line proposition first, provenance/details on demand.
- Empty sections disappear instead of leaving skeleton placeholders.
- Keyboard focus order follows the visual order: search → resume → memory → look-ahead → secondary controls.
- Reduce Motion and Increase Contrast must be honored by the brief asset CSS and interactions.
- All data-derived text is escaped and treated as untrusted; the existing `MorningBriefContractTests` XSS checks remain release gates.

---

## 7. Determinism and eval hooks

| ID | Gate | Evidence |
|---|---|---|
| B-1 | Zero-data brief renders with no fabricated items | Pure planner test + clean-profile manual path |
| B-2 | Identical inputs produce byte-stable semantic output | Planner snapshot test (allowing only explicit timestamp fields) |
| B-3 | Private tabs never appear in resume/tasks/footer | Fixture with mixed private/normal tabs |
| B-4 | Calendar remains absent when disabled or denied | EventKit adapter denial test |
| B-5 | Memory card appears only with real in-window memory | Planner matrix: zero/one/many item kinds |
| B-6 | Raw note text does not leak into brief copy | Static and runtime payload test |
| B-7 | Every non-empty proactive card has a provenance label | DOM contract test + JSON schema validation |
| B-8 | No feed or network-derived content appears in M2 payload | JSON field allow-list + network-disabled fixture |
| B-9 | Escaping defeats `</script>` and JSON/control-character payloads | Existing XSS contract tests remain green |
| B-10 | Open brief refreshes only on day rollover or explicit state change | Timer/lifecycle test; no 60-second reload loop |
| B-11 | Resume actions open the exact source and do not mutate it | UI integration test |
| B-12 | Dismissal and forget semantics are distinct | State transition tests |
| B-13 | Narrow-window payload stays bounded | Fixture with thousands of tabs/history/memory nodes; output cap enforced |
| B-14 | Accessibility paths are complete | VoiceOver labels, keyboard-only order, contrast/reduced-motion checks |

---

## 8. Rollout sequence

### 8.0 Evidence references

The start-page recommendations are grounded in first-party documentation: [Apple Safari Start Page](https://support.apple.com/guide/safari/customize-a-start-page-ibrw01514823/mac), [Google Chrome New Tab customization](https://support.google.com/chrome/answer/11032183), [Mozilla Firefox New Tab customization](https://support.mozilla.org/en-US/kb/customize-items-firefox-new-tab), and [Microsoft Edge New Tab customization](https://support.microsoft.com/en-us/topic/customize-the-microsoft-edge-new-tab-page-e819bbfc-bd7d-434e-cd91-ab6eb61da9d5). Those sources establish modular sections, shortcuts, continuity/recent activity, and feed toggles; the Hive information architecture and no-feed recommendation are product decisions, not claims that every browser behaves identically.

### Stage 1 — Zero-history credibility

Lock the empty state, search/omnibox, import entry point, and deterministic no-data contract. This stage ships without calendar or proactive memory.

### Stage 2 — Resume utility

Add open-tab ranking, provenance labels, dismissal, direct resume actions, and clean-profile runtime evidence.

### Stage 3 — Memory-aware brief

Enable the existing `ProactiveBriefPlanner` cards with explicit provenance and the privacy/deletion semantics above. No model-generated copy.

### Stage 4 — Calendar opt-in

Expose the existing `includeCalendarInBrief` path only after permission-denied, local-only, bounded-field, and no-remote-context tests pass.

### Stage 5 — Optional future intelligence

Any model-generated summary, external feed, weather, or cross-device continuity receives a separate design and data-lifecycle review. It must not silently widen the current brief contract.

**Definition of done:** Morning Brief is **verified** only when B-1 through B-14 pass and a clean-profile user can launch Hive, search/browse, skip import, and return to a useful start surface without seeing invented personal content or a forced AI experience.
