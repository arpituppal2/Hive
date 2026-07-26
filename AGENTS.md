# The Hive Browser: Master Product Specification and AI Continuation Protocol

> Canonical status: active
>
> Product form: one macOS product called The Hive Browser. Swarm is its integrated
> intelligence and execution layer, not a separate user-facing app.
>
> Last evidence refresh: 2026-07-24
>
> This file is intentionally named AGENTS.md so coding agents that support a
> repository instruction file can load it automatically. It is also the durable
> handoff document for humans and agents that do not.

## 0. Read This Before Doing Anything

The Hive Browser is not a bundle of unrelated replacements. It is a browser
that accumulates context, turns context into durable knowledge, and gives the
user controlled ways to act on that knowledge.

The product starts as an excellent browser. As a person uses it, capabilities
appear when they are useful:

1. Browse.
2. Remember.
3. Ask.
4. Organize.
5. Act.
6. Extend the computer.

The desired end state is one app that can replace large portions of the
browser, knowledge, research, coding-agent, personal-automation, task, and
desktop-utility stack. The near-term product must not look like a dashboard
that claims to replace everything. The browser is the entry point and the
context graph is the compounding advantage.

Any agent working in this repository must preserve this distinction:

- One product does not mean one executable process or one privilege level.
- A source file, prompt, model registry entry, or UI mock is not a shipped
  capability.
- A capability is complete only when its user journey works end to end, has
  the required permission behavior, is tested, and has fresh evidence.
- Browser pages, connector output, and model output are untrusted input.
- User data, credentials, browsing history, and local files are never
  marketing fuel or implicit model context.

Do not claim that Hive is an "AI browser." Describe it as a browser-native
workspace with Swarm inside it.

## 1. Canonical Product Decisions

These decisions supersede conflicting historical wording elsewhere in the
repository.

| ID | Decision | Status | Consequence |
| --- | --- | --- | --- |
| DEC-001 | The Hive Browser is one user-facing app. Swarm lives in the browser as home, sidebar, omnibar modes, and controlled action surface. | Accepted | Do not recreate a standalone Swarm app or IPC split. |
| DEC-002 | The browser is the acquisition wedge. The rest of Hive is progressively disclosed from meaningful browsing context. | Accepted | Default launch must be useful with AI disabled. |
| DEC-003 | Hive replaces workflows, not every feature checkbox of every competitor. | Accepted | Scope is prioritized by repeated user jobs and compounding context. |
| DEC-004 | Local-first and memory-first are product properties, not slogans. | Accepted | Offline behavior, provenance, export, deletion, and model routing are first-class acceptance criteria. |
| DEC-005 | Swarm must be capability-gated. Read, write, command execution, browser actions, and OS control require different trust and confirmation rules. | Accepted | No raw "agent mode" bypass. |
| DEC-006 | The UI remains dark-first, warm, dense, native, and restrained. AI is a capability, not a decorative brand layer. | Accepted | Follow SPEC.md; do not introduce generic chat-app aesthetics. |
| DEC-007 | WKWebView is the current shipping renderer. Full Chrome-extension parity is not currently promised. | Accepted for V1 | A CEF or Chromium spike is a later gated decision, not a YC critical path. |
| DEC-008 | A single product may contain separately permissioned helpers or isolated workers. | Accepted | Full personal-computer behavior cannot be safely treated as ordinary browser UI code. |
| DEC-009 | Honeycomb becomes the durable knowledge substrate; flat JSON MemoryStore is transitional. | Accepted | Do not build more strategic features directly on a flat store without a migration seam. |
| DEC-010 | Every future agent starts with a live repository audit before it edits or updates status. | Accepted | This document is a starting point, never an excuse to trust stale claims. |

### 1.1 Historical Conflicts Resolved

The following materials remain useful but are not canonical in the areas noted:

| Source | Use it for | Do not inherit without checking |
| --- | --- | --- |
| /Users/arpituppal/Downloads/spec.txt | Historical breadth and original capability ideas | Two-app architecture and any old milestone claims |
| README.md | Product thesis, target users, terminology | The diagram that still describes a separate Swarm executable |
| SPEC.md | Visual, interaction, accessibility, performance, and browser UX rules | Product prioritization outside browser UI |
| docs/build/DECISIONS.md | Accepted local architecture decisions | Any decision not listed with a date and status |
| docs/build/CHECKPOINT.md | Historical module inventory | Green-build claim from 2026-07-17; it is stale |
| PITCH/chromium-adr.md | Tradeoffs of WebKit, CEF, and a dual-engine path | A commitment to CEF |
| PITCH/chromium-migration.md | Bounded future migration spike and kill criteria | Its statement that CEF is already the decision |
| PITCH/ai-architecture.md | Model roles, evaluation intent, and resource budget | Claims that local model execution is live |
| PITCH/system-prompts-reference.md | Pattern research and safety ideas | Any copied system prompt as production policy |

If two documents conflict, use this order:

1. This file for current product scope and continuation rules.
2. Accepted entries in docs/build/DECISIONS.md.
3. Current source code plus fresh build, test, and runtime evidence.
4. SPEC.md for UI behavior and design language.
5. Other repository documentation as proposals or historical context.

## 2. Product Thesis and YC-Ready Wedge

### 2.1 One Sentence

The Hive Browser turns what you browse into an organized, actionable memory.

### 2.2 Expanded Thesis

Most people lose work when context crosses an application boundary: browser to
notes, notes to research, research to code, code to a task list, and task list
to a desktop action. Hive owns the boundary because it starts where work
already happens: the browser. Swarm uses the current page, open tabs, project
space, and Honeycomb memory to research, synthesize, organize, and act with
visible permissions and provenance.

The long-term ambition is a personal work operating system. The credible
near-term claim is narrower: "a browser that remembers and acts on your
work." YC explicitly advises startups to begin with a narrow, clear
description rather than lose people in the full generality of the idea:
[YC's application guidance](https://www.ycombinator.com/howtoapply).

### 2.3 YC Demo Spine

The YC demo should prove one unforgettable compound workflow, not enumerate
twenty apps:

1. Import a real browser profile and open a project space.
2. Research a decision across several tabs.
3. Capture the relevant sources automatically or intentionally, preserving
   URL, title, timestamp, extraction method, and user edits.
4. Ask Swarm for a cited brief grounded in those sources and existing memory.
5. Turn the brief into a Hive project with decisions, open questions, and
   next actions.
6. Open a local repository, ask Swarm to make a small approved change, inspect
   the diff, and run the project check in a bounded workspace.
7. Return to the browser with the new state still attached to the project.

The demo does not need full Excel, a total OS automation layer, or an extension
marketplace. It needs a real browser, real memory, real research provenance,
and one safe, inspectable action loop. YC asks applicants to include a demo
when they have one; its application video itself is meant to introduce the
founders, not serve as a promotional demo:
[YC demo guidance](https://www.ycombinator.com/library/J8-yc-application-tips-include-a-demo)
and [YC video instructions](https://www.ycombinator.com/video).

### 2.4 Progressive Discovery Model

| Stage | What the user sees | Unlock trigger | What Hive proves |
| --- | --- | --- | --- |
| Browse | Familiar tabs, omnibar, import, spaces, privacy, reader, downloads | First launch | It is a credible daily browser. |
| Remember | Quiet capture cue and a project-aware sidebar | First capture or revisit | It does not make the user re-file what they read. |
| Ask | Swarm panel with source scope and citations | User asks or selects a page | It understands current work without requiring copy-paste. |
| Organize | Honeycomb-backed project, wiki, brief, and task views | Repeated captures around one topic | It turns activity into a system of record. |
| Act | Suggested, reviewable browser, file, code, or desktop actions | Explicit user intent and permission | It converts knowledge into reversible work. |
| Extend | Command center, connectors, utilities, custom flows | User opts into a capability | It becomes the work surface, not a noisy super-app. |

Never force users into a workspace dashboard before the browser has earned
their trust. Every unlock must be dismissible and reversible.

## 3. What "Replace" Means

Hive should replace repeated user jobs. Do not use competitor names as a
backlog taxonomy.

| Existing product | User job to replace | Hive expression | Earliest phase | Boundary |
| --- | --- | --- | --- | --- |
| Safari, Arc, Chrome | Browse reliably, organize tabs, import history, manage profiles | Browser shell, spaces, import, layouts, sessions, privacy | P0 | Do not claim Chrome-extension compatibility on WKWebView. |
| Perplexity Comet | Ask about active pages, tabs, history, and web research | Swarm context scopes, cited research, browser actions | P1 | Research must use real sources and real citations, never generated source labels. |
| Notion | Store projects, structured documents, and lightweight databases | Honeycomb objects, projects, briefs, views, task relations | P2 | Team collaboration and full block-editor parity are later. |
| Obsidian | Own Markdown, link ideas, inspect a graph, work offline | Local wiki, Honeycomb graph, exportable Markdown, backlinks | P1-P2 | Graph visuals alone are not a knowledge system. |
| Codex, Cursor, Codebuff, Aider, Claude Code | Understand a repo, plan, edit, test, review, preserve git history | Studio mode, isolated project runner, plan/diff/test/review loop | P2 | No unrestricted shell or silent write path. |
| Claude Cowork, Perplexity Computer | Observe and act across the desktop under user control | Optional personal-computer worker, consent ledger, action ladder | P3 | Accessibility and screen access remain opt-in and scoped. |
| Things 3 | Turn commitments into a trusted daily plan | Action inbox, projects, scheduling, reminders, flow output | P2 | Start with project actions, not a generic task-manager clone. |
| Excel | Turn data into tables, calculations, charts, and decisions | Hive Sheets: local tables, formulas, sources, charts, agent-assisted analysis | P3 | Do not promise macro, Pivot, or full workbook compatibility initially. |
| Raycast | Find and run commands, snippets, quick links, file actions | Global command center and typed commands | P3 | Require a fast keyboard path and useful local index. |
| Magnet | Place windows and restore work layouts | Optional window-layout actions | P3 | Needs Accessibility permission and per-display validation. |
| Bartender | Organize menu-bar items and switch states | Optional menu-bar companion and contextual modes | P4 | Separate optional helper; never a default browser burden. |
| Amphetamine | Keep the Mac awake during intentional work | Work session guard tied to explicit tasks | P3 | Respect battery, thermal, and user policy. |
| LookAway | Protect focus and eyes with contextual breaks | Wellness guard that understands meetings, recording, and focus sessions | P4 | Gentle, private, and easily disabled. |

The competitive research supports this framing. Comet blends a browser with an
assistant across tabs, automation, and persistent memory
([Perplexity's Comet guide](https://www.perplexity.ai/help-center/comet/en/articles/11732243-advice-and-use-cases)).
Notion's key primitive is a page-backed database with properties and multiple
views ([Notion database documentation](https://www.notion.com/help/intro-to-databases)).
Obsidian's graph is a navigable view over real note links, filters, and local
context ([Obsidian Graph view](https://obsidian.md/help/Plugins/Graph%2Bview)).
The correct Hive response is a shared context model, not a visual imitation of
each application.

## 4. Non-Negotiable Experience Principles

1. Browser-first. Opening links, tabs, pages, and spaces must be fast and
   familiar before advanced modes matter.
2. Context without surveillance. Hive may use current page and user-approved
   context; it must expose scope and never silently widen it.
3. One memory, many views. Captures, notes, claims, tasks, source artifacts,
   and code runs link to the same durable substrate.
4. Explain what happened. Every generated brief, citation, action, model
   route, edit, and automation must be inspectable.
5. Show, then ask, then act. Swarm proposes concrete work and asks at the
   correct trust level before any consequential change.
6. Local by default. Use structure and local retrieval before a model; use
   on-device inference where it is actually capable; use remote models only
   when the user opts in or the stated policy permits it.
7. Reversible by design. Imports, memory edits, files, code changes, tasks,
   and automation actions must retain a rollback or delete path.
8. No false theater. No fake streaming, fake citations, fake research,
   simulated live model labels, or capability buttons that are not wired.
9. Progressive density. Power is available by keyboard and command palette;
   novice users should not see a cockpit they did not ask for.
10. Native Mac quality. Follow SPEC.md for typography, materials, motion,
    keyboard access, accessibility, and performance.

## 5. Source-of-Truth Reading Map

Before changing a product area, read its source document and its code owner.
Do not skim only headings for work that changes behavior.

| Area | Product source | Code owner | Required companion |
| --- | --- | --- | --- |
| Browser UX and visual system | SPEC.md sections 1-25 and appendices | Sources/HiveBrowser/Views and BrowserApp.swift | PITCH/chromium-adr.md |
| Swarm workspace | SPEC.md section 26 | Sources/HiveBrowser/Swarm and Omnibar | PITCH/system-prompts-reference.md |
| Browser migration and switchability | docs/competitive-scorecard.md | Models/ImportManager.swift and Onboarding | PITCH/chromium-migration.md |
| Knowledge, projects, and graph | docs/build/MISSION.md | HiveCore/Memory, HiveCore/Wiki, future HiveCore/Honeycomb | README.md and PITCH/competitive.md |
| AI roles and model policy | PITCH/ai-architecture.md | HiveCore/AI | PITCH/research.md |
| Agent tools and permissions | PITCH/system-prompts-reference.md | HiveCore/Bee, Tools, Code, OS | OpenAI and Apple security sources in section 19 |
| Platform and distribution | PITCH/research.md | Package.swift, entitlements, signing scripts when added | Apple documentation |

## 6. Repository Truth Snapshot: 2026-07-24

This section is evidence, not product copy. It must be updated whenever a
future agent completes an audit.

### 6.1 Current Layout

~~~text
HiveCore
  AI/             routing, policy, model registry, prompts, telemetry
  Bee/            job queue, runner, policy, tool registry
  Memory/         JSON memory, session, cookies
  Models/         bookmarks, history, profiles, spaces, persistence
  Wiki/           Markdown-backed wiki and backlink index
  Code/            project file and shell runner
  Tools/           constrained file and terminal tools
  OS/              Accessibility and AppleScript computer-use surface
  Security/        keychain access
  DesignTokens/   colors, typography, motion

HiveBrowser
  BrowserApp.swift
  Models/          tabs, imports, migration, tracker blocking, hibernation
  Omnibar/         unified input and mode switcher
  Swarm/           chat, workspace, wiki browser, graph views
  Views/Chrome/    top bar, sidebar, vertical tabs, inspector
  Views/Content/   browser, reader, split, downloads, PIP, start page
  Views/Settings/  preferences and migration UI
  Views/Spaces/    workspace management
  Views/Components command palette and toasts
  Views/Onboarding migration-first onboarding
~~~

There are approximately 82 Swift source files and 26,777 Swift lines on disk.
The worktree is dirty, with both modified tracked files and untracked source
files. Treat the on-disk worktree as user work. Never reset, checkout, clean,
or discard it unless the user explicitly requests that exact action.

### 6.2 Fresh Build Baseline

On 2026-07-24:

- swift build: failed.
- swift test: blocked by the same HiveBrowser compilation failure.
- The previous green claim in docs/build/CHECKPOINT.md is dated 2026-07-17
  and is no longer current.

The active compile blockers are:

| ID | Location | Failure | Required resolution |
| --- | --- | --- | --- |
| BUILD-001 | Sources/HiveBrowser/Views/Components/HiveToastView.swift:257 | A synchronous nonisolated helper calls main-actor-isolated HiveMotion.animation. | Align actor isolation or avoid the actor-isolated API from that helper; rebuild. |
| BUILD-002 | Sources/HiveBrowser/Views/Components/HiveToastView.swift:261 | HiveMotion.Duration.value is internal to HiveCore and unavailable to HiveBrowser. | Expose a valid public API or make the view use a public duration. |
| WARN-001 | Sources/HiveBrowser/Views/Content/ReadingModeView.swift:448 | SpeechFinishDelegate holds a non-Sendable closure under strict concurrency. | Resolve during build-recovery work; do not normalize warnings. |

No feature may advance from "code present" to "verified" while BUILD-001 and
BUILD-002 are unresolved.

### 6.3 Current Capability Classification

Use these labels exactly:

| Label | Meaning |
| --- | --- |
| verified | Build, relevant tests, and a user-observable runtime path passed in the current audit. |
| code-present | Implementation exists on disk, but the feature is not proven end to end in the current audit. |
| scaffold | API, types, prompts, or UI exist, but a required runtime dependency or real journey is missing. |
| planned | Named in a spec or mission but absent from source. |
| blocked | Cannot be verified because of a known build, environment, or design blocker. |
| rejected | Deliberately outside the product or security boundary. |

### 6.4 Present in Code, Not Yet Safe to Market as Complete

| Capability | Status | Evidence | Critical remaining proof |
| --- | --- | --- | --- |
| Browser tabs, navigation, private windows, history, session persistence | code-present | BrowserApp.swift and Models/BrowserTab.swift | Build, smoke tests, session restore, crash recovery, privacy checks. |
| Three tab layouts and layout presets | code-present | BrowserApp.swift, TopChromeView.swift, VerticalTabBarView.swift | Build and interaction test for top, vertical, and bottom modes. |
| Browser import and onboarding | code-present | ImportManager.swift, MigrationDetector.swift, OnboardingSheet.swift | Real profile fixtures for each source and reporting of partial imports. |
| Content blocking | code-present | TrackerBlocker.swift | Rule-list loading, regression fixture, visible privacy report. |
| Manual and auto page capture | code-present | BrowserTab.capturePage and autoExtractIfEnabled | Real extraction quality, forbidden/private data rules, durable provenance. |
| Reading and reader modes | code-present | ReaderModeView.swift and ReadingModeView.swift | Accessibility, article parsing quality, strict-concurrency warning fix. |
| Downloads, split panes, PIP, tab hibernation | code-present or partial | DownloadManagerView.swift, SplitBrowserView.swift, PictureInPictureController.swift, TabHibernationEngine.swift | Wire controls end to end. PIP monitoring currently returns no active tab. Download pause/cancel are mostly UI state, not transfer control. |
| Swarm chat and workspace | scaffold | SwarmChatViewModel.swift and SwarmWorkspaceView.swift | Real model provider, real citations, durable conversations, cancellation, error and policy UI. |
| Web research | scaffold | WebSearchProvider.swift uses MockWebSearchProvider by default | A vetted provider, fetch/extract pipeline, source credibility, citation grounding. |
| Foundation Models, local models, BYOK cloud models | scaffold | Dispatcher.swift and FoundationModelExecutor.swift use mock or simulated output | Real provider adapters, capability checks, cost/privacy controls, tests. |
| Bee orchestration and action ladder | code-present | HiveCore/Bee and AI/ActionLadder.swift | Runtime orchestration, action approval UI, durable audit ledger, adversarial tests. |
| Local wiki and backlinks | code-present | HiveCore/Wiki/WikiStore.swift and WikiBrowserView.swift | Honeycomb integration, capture-to-wiki flow, export/import, migration and graph correctness. |
| Code studio primitives | scaffold | HiveCore/Code/CodeRunner.swift | Isolated execution workspace, non-bypassable policy, diff review, git-aware rollback, UI. |
| File and terminal primitives | code-present | HiveCore/Tools/FileTool.swift and TerminalTool.swift | Structured tool calls, approval UI, audit trail, integration tests through Swarm. |
| Personal computer automation | scaffold and high risk | HiveCore/OS/ComputerUse.swift | Permission center, real observation pipeline, action ladder integration, screen privacy, audit/rollback. |
| Honeycomb graph | planned | docs/build/MISSION.md names it; no HiveCore/Honeycomb directory exists | SQLite schema, retrieval, migration, tests, UI. |
| EventLedger | planned | docs/build/MISSION.md | Append-only action, model, consent, and data-lifecycle evidence. |
| Flows and Briefs | planned | docs/build/MISSION.md | Versioned flow model, durable outputs, consent and retries. |
| Connectors | planned | docs/build/MISSION.md | Account linking, least privilege, rate limits, deletion, revocation. |
| Task system, spreadsheets, menu bar, wellness | planned | Not present as first-class modules | Product and data model design before UI. |

### 6.5 Important Reality Checks

- SwarmChatViewModel defaults to MockWebSearchProvider.
- Dispatcher.executeFMF, local-model execution, cloud-model execution, and
  stream behavior currently return mock, simulated, or configuration-only
  responses. Streaming is artificial token pacing over a completed result.
- The chat citation chips parse labels out of response text; they do not yet
  prove that a cited claim is grounded in a source.
- CodeRunner can run a shell command through zsh and write files, but it is
  not yet governed by a non-bypassable action policy or isolated workspace.
- ComputerUse can execute AppleScript and type text after an action is
  approved, but is not yet integrated with the ActionLadder, EventLedger, or
  a permission-center UX.
- Tab hibernation stores state, but its background timer/wiring and visual
  placeholder behavior need runtime verification.
- PictureInPictureController.getActiveTab currently returns nil, so automatic
  PIP monitoring cannot activate.
- The command palette contains no-op action closures for at least split,
  bookmark, and downloads routing.

## 7. The Missing Product Specifications

The existing materials are strong on visual browser detail and broad ambition.
They do not yet specify the cross-cutting contracts that make an "infinite
capability" product safe, comprehensible, and buildable.

### 7.1 Missing: A Unified Object Model

Hive needs a canonical object graph, not separate JSON stores and screen-local
state. Honeycomb should model at least:

| Object | Required fields | Important edges |
| --- | --- | --- |
| Source | canonical URL, capture method, content hash, author/date when known, retrieval timestamp, license/robots status | supports Claim, Artifact, Brief, Capture |
| Capture | source reference, extracted text, selection, user note, privacy class, retention policy | belongs to Project, produces Claim |
| Claim | text, confidence, evidence spans, freshness, contradiction state | supported-by Source, derived-from Capture |
| Artifact | Markdown, file, code diff, image, table, generated output | derived-from Source or Flow |
| Project or Hive | title, purpose, owner, lifecycle, pinned context, permissions | contains all work objects |
| Task | title, state, schedule, estimate, dependency, source link | belongs to Project, created-by Flow |
| Flow | version, inputs, outputs, capability grants, steps, retry state | runs against Project |
| Action | typed intent, target, diff or preview, trust level, approval, result | logged-by EventLedger |
| ConnectorAccount | provider, granted scopes, last sync, revocation state | owns external source data |
| Preference | explicit user rule, scope, provenance, expiry | affects routing and automation |

Every object needs creation time, update time, provenance, user ownership,
deletion behavior, and export behavior. Every relation needs typed semantics,
not only a rendered line in a graph.

### 7.2 Missing: Data Lifecycle and Trust Semantics

For each object type, specify:

- What data is captured automatically, manually, or only after confirmation.
- Whether it is local-only, eligible for sync, eligible for a remote model, or
  prohibited from leaving the device.
- How it is cited in a Swarm response.
- How a user edits, corrects, denies, merges, splits, or forgets it.
- How it expires or becomes stale.
- How it is deleted from local disk, sync, indexes, model queues, and logs.
- What survives private browsing and what must never persist.

No raw page text should be sent to a remote model solely because the user
opened it. Scope must be explicit. Remote model requests must show the model,
provider, data scope, and cost/retention implications before the first use.

### 7.3 Missing: Real Research Contract

Research mode needs a real source pipeline:

1. Query plan and requested scope.
2. Source search with a provider policy.
3. Fetch/extract with SSRF, redirect, malware, and content-type defenses.
4. Source normalization and a source-quality score.
5. Claim extraction with quote/span references.
6. Synthesis that renders only citations linked to stored source evidence.
7. User-visible limitations: source count, date range, disagreement, and
   unverified claims.
8. Store research as a Brief and linked Honeycomb objects only after the
   chosen retention policy allows it.

Perplexity's browser assistant offers task automation, research across tabs,
and persistent browsing memory. That raises the bar for grounded experience,
not for unverified output:
[Comet's stated workflow](https://www.perplexity.ai/help-center/comet/en/articles/11732243-advice-and-use-cases).

### 7.4 Missing: Agent Runtime Contract

Prompts are guidance, not a security boundary. Swarm needs typed runtime
contracts:

| Layer | Required responsibility |
| --- | --- |
| Planner | Creates a typed plan with capability and data-scope requests. |
| Context broker | Selects only approved page, Honeycomb, file, connector, and web context. |
| Tool registry | Defines typed input, output, risk class, idempotency, timeout, and rollback. |
| Policy engine | Evaluates trust level before a tool receives executable arguments. |
| Approval controller | Renders a human-readable preview, collects consent, and records it. |
| Worker | Executes in an allowed scope; never decides its own permissions. |
| Verifier | Checks actual output, tests, and cited evidence. |
| EventLedger | Records intent, policy decision, approval, action, result, and rollback. |

Use a structured action envelope rather than string-matching natural-language
commands:

~~~json
{
  "action_id": "uuid",
  "kind": "file.write",
  "target": {
    "workspace_id": "uuid",
    "path": "relative/path.swift"
  },
  "preview": {
    "diff": "..."
  },
  "trust_level": "t3",
  "requires_confirmation": true,
  "rollback": {
    "kind": "git.restore_or_patch"
  },
  "evidence": ["source:uuid", "test:uuid"]
}
~~~

The current code's regex-triggered chat commands are a temporary UI
experiment, not the permanent tool protocol.

### 7.5 Missing: Personal-Computer Permission Architecture

One product can provide OS-level capabilities, but it must not turn the
browser process into an unbounded automation host.

Recommended architecture:

~~~text
The Hive Browser.app
  Browser UI and Honeycomb UI
  Context broker and approval center
  Sandboxed or least-privilege browsing surface

Hive Worker
  Optional signed helper
  Explicitly permissioned file, terminal, Accessibility, AppleScript,
  Screen Recording, connector, and local-model capabilities
  Per-project or per-action policy enforcement

EventLedger
  Durable evidence shared by the UI and worker
~~~

The product still looks like one app. The privilege boundary is internal and
visible through an excellent permission center. A Mac App Store configuration
and a Developer ID configuration may have different feature sets. Apple
describes App Sandbox as an access-control boundary and documents its
entitlement model ([App Sandbox configuration](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)).
Accessibility control acts through AXUIElement interfaces
([Apple's AXUIElement documentation](https://developer.apple.com/documentation/applicationservices/axuielement_h)).
Screen capture requires explicit user permission and should filter to the
specific display, app, or window the user approved
([Apple ScreenCaptureKit sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)).

### 7.6 Missing: Connectors and Account Model

Connectors are a major source of compounding value but must not be bundled as
opaque "integrations." Define:

- Provider and user identity.
- OAuth or token storage in Keychain.
- Minimum requested scopes.
- Sync direction, cadence, cursor, backoff, and rate limits.
- Source normalization into Honeycomb.
- Deletion, disconnection, revocation, and re-auth flows.
- Content classification and remote-model policy.
- Per-connector prompt-injection handling.
- Offline behavior and an explicit last-synced timestamp.

Start with high-context, read-only connectors after browser and Honeycomb
work: local filesystem/project roots, Calendar, and optionally email. Do not
add a broad connector gallery before the data model and permission ledger
exist.

### 7.7 Missing: Tasks, Tables, and Briefs

Things-like tasks, Notion-like structured documents, and Excel-like analysis
must share the same objects:

- A task can cite source claims and generated briefs.
- A brief can create reviewable tasks.
- A table can contain source-backed rows and compute simple formulas.
- A chart can point to a versioned table query.
- A project can show all four without a separate data silo.

Start with a small "Hive Sheet" contract:

| Capability | P3 minimum |
| --- | --- |
| Table | Typed columns, local rows, sort, filter, group, import/export CSV. |
| Formula | Safe deterministic formulas with a documented supported subset. |
| Source row | Every imported or generated row retains a source object. |
| Chart | Basic bar, line, and scatter charts from a saved query. |
| Agent help | Generate a proposed formula, transform, or explanation; never silently mutate data. |
| Audit | Formula version, input snapshot, and generated result visible. |

Power Query demonstrates the practical value of a transparent
extract-transform-load pipeline ([Microsoft Power Query overview](https://learn.microsoft.com/en-us/power-query/power-query-what-is-power-query)).
Do not attempt DAX, macros, full Excel import fidelity, or enterprise
collaboration before this core is trustworthy.

### 7.8 Missing: Command Center and Mac Utilities

The command palette must evolve into a typed global command center, not a
growing list of view callbacks.

Required command schema:

- Stable command ID and namespace.
- Title, aliases, icon, category, availability predicate, and argument schema.
- Permission class and optional preview renderer.
- Keyboard shortcut and conflict resolution.
- Invocation telemetry stored locally.
- User-defined commands, quick links, and snippets.

Raycast sets a useful expectation for keyboard-first window management,
quick links, snippets, file search, and extensibility
([Raycast window management](https://manual.raycast.com/window-management),
[Raycast quicklinks](https://manual.raycast.com/quicklinks)).
Window management requires Accessibility permission. Magnet validates the
basic job: reusable keyboard and drag-based window tiling across displays
([Magnet](https://magnet.crowdcafe.com/)). Bartender validates a separate job:
contextual menu-bar visibility, groups, presets, search, and triggers
([Bartender 6](https://www.macbartender.com/)).
Treat all of these as opt-in extensions of the command center, never as
default browser chrome.

### 7.9 Missing: Wellness and Power Policy

Wellness and awake behavior are useful because Hive knows when work is
intentional, but they must not become paternalistic.

Required policies:

- Work session can request a keep-awake lease with a visible expiration.
- Lease revokes on battery/thermal thresholds selected by the user.
- Break reminders honor calls, screen sharing, presentations, and dictation.
- User can snooze, schedule, or disable without shame.
- Nothing leaves the device for wellness analytics.

Amphetamine's useful unit is an explicit, bounded keep-awake session with
conditions ([Apple's Amphetamine feature story](https://apps.apple.com/us/mac/story/id1470456860)).
LookAway's useful unit is a gentle, configurable break with awareness of
screen sharing and smart pauses
([LookAway on the App Store](https://apps.apple.com/gb/app/lookaway-break-reminder/id6747192301)).

### 7.10 Missing: Extension and Rendering-Engine Strategy

This is a business-critical but non-urgent decision.

Current rule:

- Ship V1 on WKWebView.
- Do not claim Chrome extension support.
- Treat Safari Web Extension conversion as a different ecosystem, not as
  Chrome Web Store compatibility.
- Use content blockers and first-party capability integrations first.
- Run a bounded Chromium or CEF feasibility spike only when browser retention
  data proves extensions are the primary switch blocker.

Apple supports Safari Web Extensions through app extensions and a conversion
tool, but that is not equivalent to embedding the Chrome extension ecosystem
inside WKWebView ([Apple Safari extensions](https://developer.apple.com/safari/extensions/)).
The existing PITCH CEF documents are useful spike plans; retain their binary
size, compatibility, performance, update, and crash-rate kill criteria.

## 8. Target Architecture

### 8.1 Product Flow

~~~mermaid
flowchart LR
  B["Browser Pages and Tabs"] --> C["Context Broker"]
  U["User Selection and Intent"] --> C
  C --> H["Honeycomb"]
  H --> S["Swarm Planner and Retriever"]
  S --> P["Policy and Approval Center"]
  P --> W["Isolated Workers and Connectors"]
  W --> E["EventLedger"]
  E --> H
  H --> V["Browser, Brief, Wiki, Task, Sheet Views"]
~~~

### 8.2 Required Boundaries

| Boundary | Owns | Must not own |
| --- | --- | --- |
| Browser UI | Navigation, rendering, local interaction state, explicit capture and scope selection | Secret storage, unrestricted shell, silent automation. |
| Context broker | Selecting and redacting approved context | Choosing its own wider permissions. |
| Honeycomb | Structured knowledge, relationships, provenance, retrieval, deletion | Direct UI behavior or provider-specific network code. |
| Swarm planner | Typed plan and explanation | Direct privileged execution. |
| Policy and approval | Trust decision, consent, preview, denials, revocation | Content generation or execution mechanics. |
| Tool adapter | Exact capability implementation | Natural-language intent interpretation. |
| Worker sandbox | Bounded command/file/task execution | Browser UI state and broad user data access. |
| EventLedger | Append-only evidence, outcomes, rollback links | Mutable product state as its only storage. |

### 8.3 Honeycomb Design Requirements

Honeycomb must use SQLite with:

- Schema migrations and a version table.
- Parameterized SQL only.
- Full text search plus structured indexes.
- Typed nodes and typed directed edges.
- Source-level content hashing and deduplication.
- Revision history for corrections.
- A retention and delete-by-scope API.
- Separate query paths for user-visible graph exploration and model retrieval.
- An adapter so existing MemoryStore content can migrate without data loss.
- Actor isolation and cancellation-aware long operations.

### 8.4 EventLedger Design Requirements

Every consequential event records:

- Event ID, time, actor, session, project, and parent action.
- User intent and typed action.
- Context identifiers, never raw secrets in the default log.
- Policy decision, trust level, and consent state.
- Tool version, environment, and output summary.
- Result, error, verification result, and rollback reference.
- Export and deletion scope.

The ledger is a trust feature and debugging system. It is also essential for
future partial handoffs: an agent can see what actually happened instead of
inferring it from a UI state.

## 9. Security, Privacy, and Trust Requirements

### 9.1 Threat Model

Treat all of these as untrusted unless explicitly protected:

- Web pages, page text, PDFs, messages, connector content, and screenshots.
- Model outputs, tool arguments proposed by a model, and generated links.
- Browser history, local project files, credentials, calendar, and email.
- Extension data, imported browser data, and clipboard contents.

Prompt injection is a known systems problem, not one that a system prompt can
solve. OpenAI recommends constraining risky actions and preventing the impact
of manipulation, rather than relying only on attack detection
([OpenAI on prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)).
OpenAI also calls out prompt injection, secret exfiltration, malicious
downloads, and licensing risk when agents have internet access
([agent internet-access risks](https://developers.openai.com/codex/cloud/internet-access)).

### 9.2 Hard Rules

1. Browsing content never changes the user's request or grants permission.
2. An external source cannot cause a tool call merely by containing
   instructions.
3. No shell command, file write, connector mutation, purchase, send, publish,
   account change, or OS automation runs without policy evaluation.
4. Network access for code or computer-use workers is denied by default and
   allowed per task/domain when needed.
5. File access is limited to a user-selected project root or document scope.
6. Secrets never appear in prompt context, logs, diffs, screenshots, test
   fixtures, source control, or this document.
7. Use Keychain for credentials. Never add plaintext credentials to config
   files.
8. A potentially exposed provider credential is currently present in the
   repository configuration. The owner must rotate it, remove it from tracked
   material and history where applicable, and replace it with environment or
   Keychain-backed configuration before any release or external sharing.
9. Private browsing is non-persistent by default. Captures, search scopes, and
   Swarm memory from private content require an explicit user opt-in and clear
   label.
10. Every remote model invocation states provider, model, intended context
    scope, and retention implications.

### 9.3 Trust Levels

| Level | User-facing label | Example | Default |
| --- | --- | --- | --- |
| T0 | Observe | Read current tab metadata, local graph query | Auto within approved scope. |
| T1 | Suggest | Draft a brief, propose a task, generate a plan | Auto, clearly marked as a proposal. |
| T2 | Assist | Create an unsent file draft or local task draft | Allowed only in a user-selected workspace, reversible. |
| T3 | Act | Apply a file diff, run a project test, navigate a browser tab | Explicit approval per action or session rule. |
| T4 | Privileged | Send a message, modify an account, use Accessibility to control another app | Explicit approval per action and EventLedger record. |
| T5 | Developer | Irreversible delete, system configuration, destructive command | Disabled by default; dedicated confirmation and no model self-approval. |

The existing ActionLadder provides a starting model. It is not enough until
every tool adapter routes through it and the user can inspect and revoke
grants. Claude Code similarly treats read-only exploration differently from
edits and command execution ([Claude Code security model](https://docs.anthropic.com/en/docs/claude-code/security)).

## 10. Browser Quality Bar

The Hive Browser must earn replacement status before it asks people to trust
their work system to it.

### 10.1 P0 Browser Acceptance

- New tab, navigation, back/forward, reload, find in page, keyboard parity,
  private browsing, downloads, reader mode, tabs, and session restore work.
- Import supports the published browsers with fixture-based tests and an honest
  migration report.
- Spaces keep their separate tab sets and persist correctly.
- Top, vertical, and bottom tab layouts work, survive restart, and remain
  keyboard accessible.
- Tracker blocking behavior is real, observable, and configurable.
- Browser crash and WebContent process recovery preserve a useful state.
- Startup, scrolling, and memory usage meet the SPEC.md performance budget on
  the stated M1 8GB floor.
- No browser capability is hidden behind a false "AI enabled" requirement.

### 10.2 P1 Browser Differentiators

- Capture page, selection, screenshot, and reading state into Honeycomb.
- Associate captures with a project or existing related knowledge.
- Offer current-page, open-tabs, workspace, and web context scopes.
- Provide a useful privacy report and clear site permissions.
- Hibernation works safely, visibly, and excludes audio/pinned/selected sites.
- Split views represent a saved browser workspace, not only a temporary layout.

Arc validates that spaces and split views are significant browser jobs
([Arc spaces](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas),
[Arc split view](https://resources.arc.net/hc/en-us/articles/19335393146775-Split-View-View-Multiple-Tabs-at-Once)).
This supports finishing browser quality before building a wider super-app.

## 11. Swarm Quality Bar

### 11.1 Research

Research is complete only when it:

- Uses a real provider or approved source corpus.
- Stores each source with URL, retrieval time, title, extractor version, and
  content hash.
- Cites exact source objects, not labels inferred from model text.
- Shows user scope and the difference between discovered, read, and cited
  sources.
- Communicates disagreement, stale evidence, and uncertainty.
- Can regenerate a brief from retained inputs.
- Saves an optional durable brief with references into Honeycomb.

### 11.2 Coding

Coding is complete only when it:

- Starts in a user-selected project root.
- Reads repository instructions and working-tree state first.
- Creates a plan for non-trivial work and asks before writes according to
  trust level.
- Shows a diff before approval.
- Runs user-approved build/tests in a bounded environment.
- Records exact commands and outputs in EventLedger.
- Never overwrites pre-existing user changes.
- Provides rollback through patch, backup, or git-aware operation.

Cursor, Codebuff, Aider, Codex, and Claude Code all reinforce individual
pieces of the expected loop: persistent project instructions
([Cursor rules](https://docs.cursor.com/context/rules-for-ai)), specialized
agent roles ([Codebuff agents](https://www.codebuff.com/docs/agents/overview)),
git-aware reversibility ([Aider git integration](https://aider.chat/docs/git.html)),
and explicit permission modes ([OpenAI Codex CLI overview](https://help.openai.com/en/articles/11096431)).
Hive must combine those practices with browser context; it does not get a pass
on safety because it has more context.

### 11.3 Personal Computer

Personal-computer automation is complete only when it:

- Has a dedicated permission center showing Accessibility, Automation, Screen
  Recording, Files, Network, and connector grants.
- Requests each OS permission just in time, explains why, and works when
  denied.
- Shows a preview before external changes.
- Uses typed actions, no freeform AppleScript from model output.
- Keeps screenshots and OCR content within the selected scope and retention
  policy.
- Records and exposes every action and result.
- Provides a stop button that stops workers, revokes active sessions, and
  leaves the user in control.

Anthropic's computer-use guidance illustrates why detection alone is not
sufficient: it adds confirmation when its classifiers identify likely prompt
injection. Hive must enforce a stronger runtime permission boundary regardless
([Anthropic computer-use documentation](https://docs.anthropic.com/en/docs/agents-and-tools/computer-use)).

## 12. Phased Roadmap

The phases are sequenced by dependency and demo value, not by which competitor
has the most impressive feature list.

### P0: Build Recovery and Browser Credibility

Goal: restore a green build and turn existing browser code into a verified
daily-driver baseline.

- Resolve BUILD-001, BUILD-002, and strict-concurrency warnings.
- Run full tests, add browser smoke coverage, and record fresh evidence.
- Verify onboarding/import, spaces, profiles, session restore, all three tab
  positions, private mode, download lifecycle, reader mode, and content
  blocking.
- Replace no-op command palette actions or remove them until wired.
- Fix only those browser defects necessary to make the demo journey reliable.
- Rotate and remove configuration secrets before sharing the repo or a build.

Exit criteria: swift build and swift test are green; the browser demo works
from a clean test profile; every P0 claim has test or runtime evidence.

### P1: Real Swarm Research and Honeycomb Foundation

Goal: prove the differentiated browser-to-memory-to-cited-answer loop.

- Implement HoneycombStore, migrations, typed nodes/edges, and read/write
  adapters for MemoryStore/WikiStore.
- Implement EventLedger enough to cover capture, research, consent, and
  browser actions.
- Replace mock search with a vetted, policy-controlled provider.
- Integrate actual Foundation Models where available and a correctly labeled
  no-model fallback where unavailable.
- Implement source ingestion, claim spans, durable citations, and brief
  generation.
- Add Swarm Home as the project's memory/brief/research surface, not a generic
  dashboard.

Exit criteria: a user can browse, capture, ask, receive a real cited answer,
save a brief, reopen it, inspect its sources, edit/delete it, and see the
provenance in the browser.

### P2: Project Workflows and Safe Studio

Goal: make knowledge turn into reviewable work.

- Implement Projects as Honeycomb views over sources, briefs, decisions,
  tasks, and active sessions.
- Implement versioned Flows with input/output/permission schemas.
- Add a task inbox, a minimal scheduled task model, and project action views.
- Add code-project selection, structured plan/diff/test/review workflow, and
  an isolated worker boundary.
- Add a global Command Center with typed commands and fast local search.

Exit criteria: the demo can produce a project brief, create next actions,
apply one approved code change in a selected project, run a test, and retain a
complete audit trail.

### P3: Personal Computer and Data Workspaces

Goal: expand from browser-native work into safe desktop actions and
source-grounded data work.

- Implement optional Worker installation and permission center.
- Add screen/window observation, limited navigation, approved file actions,
  and window-layout flows.
- Implement Hive Sheets P3 minimum contract.
- Add Focus Sessions with bounded awake leases and task-linked notifications.
- Add a small initial set of connectors with revocation and deletion semantics.

Exit criteria: every external action has a preview, consent, log, result, and
rollback or clear irreversibility warning.

### P4: Personal Operating Layer

Goal: deliver optional Mac utility consolidation without compromising the
browser's clarity or performance.

- Menu-bar modes and contextual presets.
- Wellness rhythms and break intelligence.
- User-defined commands, snippets, quick links, and flows.
- Advanced sheets, dashboards, charts, and automations.
- Collaboration and sync only after local semantics are proven.

## 13. Workstream Ledger

This ledger is the continuation queue. An agent must choose the highest
unblocked work item that advances the current phase. It must update the
evidence field after completing a card.

| ID | Workstream | Current status | Dependency | Definition of done |
| --- | --- | --- | --- | --- |
| HIVE-001 | Build recovery | blocked | None | BUILD-001 and BUILD-002 fixed; build/test evidence recorded. |
| HIVE-002 | Strict concurrency | blocked | HIVE-001 | All warnings reviewed; unsafe annotations have a documented reason. |
| BROW-001 | Core navigation | code-present | HIVE-001 | Manual smoke path and regression tests pass. |
| BROW-002 | Sessions and spaces | code-present | HIVE-001 | Restart restores selected space/tab/history/scroll semantics correctly. |
| BROW-003 | Import and migration | code-present | HIVE-001 | Fixture tests for Chrome, Safari, Firefox, Edge, Brave, Arc; user sees omissions. |
| BROW-004 | Layout modes | code-present | HIVE-001 | Top/vertical/bottom layouts are complete, accessible, and persistent. |
| BROW-005 | Browser privacy | code-present | HIVE-001 | Content rules, site permissions, private mode, clear-on-quit, and report verified. |
| BROW-006 | Downloads | partial | HIVE-001 | Actual pause, resume, cancel, retry, persistence, and Finder behavior verified. |
| BROW-007 | PIP and media | partial | HIVE-001 | Active-tab resolution, user controls, exclusions, and lifecycle verified. |
| BROW-008 | Hibernation | partial | HIVE-001 | Scheduling, state capture, wake, audio/pinned exclusions, memory test verified. |
| BROW-009 | Command palette | partial | HIVE-001 | No command lists an unavailable action; command registry is typed. |
| DATA-001 | Honeycomb schema | planned | HIVE-001 | SQLite migration, CRUD, typed edges, FTS, retrieval tests. |
| DATA-002 | Memory migration | planned | DATA-001 | Flat memory/wiki data migrates losslessly and can roll back. |
| DATA-003 | EventLedger | planned | DATA-001 | Capture/action/model/approval events append and query correctly. |
| DATA-004 | Source and claim model | planned | DATA-001 | Source spans, freshness, correction, delete, and citations work. |
| DATA-005 | Briefs | planned | DATA-003, DATA-004 | Briefs are reproducible, source-linked, editable, and exportable. |
| DATA-006 | Projects and tasks | planned | DATA-001 | Project action inbox and task lifecycle are source-linked and local-first. |
| SWARM-001 | Real provider layer | scaffold | HIVE-001 | FMF, local, cloud, unavailable, and cancellation states are honest and tested. |
| SWARM-002 | Real web research | scaffold | SWARM-001, DATA-004 | Real search/fetch/citation pipeline passes adversarial fixtures. |
| SWARM-003 | Context broker | partial | DATA-001 | Scope previews, redaction, privacy labels, and context limits work. |
| SWARM-004 | Structured tool protocol | planned | DATA-003 | Typed tool inputs/outputs are policy-gated; no command regex is privileged. |
| SWARM-005 | Approval center | planned | DATA-003, SWARM-004 | Consent, deny, revoke, preview, and audit flows work. |
| SWARM-006 | Bee orchestration | partial | SWARM-004 | Durable jobs, retries, cancellation, and verification are observable. |
| STUDIO-001 | Project-root selection | planned | SWARM-005 | User selects a root; scope persists and revokes cleanly. |
| STUDIO-002 | Code plan/diff/test loop | scaffold | STUDIO-001, SWARM-004 | No write before preview; bounded commands, tests, evidence, rollback. |
| PC-001 | Worker boundary | planned | SWARM-005 | Worker install, signed IPC, capability grants, stop/revoke state. |
| PC-002 | Desktop observation | scaffold | PC-001 | Per-window/user-approved observation with no broad screenshot retention. |
| PC-003 | Desktop actions | scaffold | PC-001, PC-002 | Typed actions route through policy, confirmation, ledger, and rollback. |
| CMD-001 | Command center | partial | HIVE-001 | Typed registry, local search, shortcuts, snippets, quick links. |
| SHEET-001 | Hive Sheets model | planned | DATA-001 | Local table/formula/query schema and CSV round-trip tests. |
| SHEET-002 | Hive Sheets UI | planned | SHEET-001 | Table/filter/formula/chart view with source provenance. |
| WELL-001 | Focus and awake leases | planned | DATA-006, PC-001 | Explicit time-bounded leases respect power policy. |
| WELL-002 | Wellness breaks | planned | WELL-001 | Gentle reminders have smart pause, privacy, and disable paths. |
| CONN-001 | Connector platform | planned | DATA-001, SWARM-005 | Identity/scopes/sync/revoke/delete contract and one reference connector. |
| DIST-001 | Signing and release | planned | HIVE-001 | Signing, notarization, update, privacy, and crash-report policy documented and tested. |
| ENG-001 | Extension engine spike | planned | BROW-001 and retention evidence | Explicit CEF/WKWebView decision supported by measured spike and kill criteria. |

## 14. Required Audit Protocol for Every Future Agent

Do this before declaring any task complete, resuming a partial effort, or
changing a status label:

~~~sh
git status --short
git log --oneline -8
rg --files
rg -n -i 'mock|simulat|todo|fixme|not implemented|not wired|stub|return nil|placeholder' Sources Tests docs PITCH
swift build
swift test
~~~

Then:

1. Read this file in full.
2. Read docs/build/MISSION.md, docs/build/DECISIONS.md, and the relevant
   source-of-truth document in section 5.
3. Inventory every current modified and untracked file. Do not assume the
   latest commit describes the current state.
4. Read every source file in the touched subsystem, its tests, and its call
   sites. For a broad task, first map all public types and entry points with
   rg, then read files in manageable batches.
5. Treat compile output, tests, and in-app behavior as stronger evidence than
   code comments and task checkboxes.
6. If build is red, classify the failure as a blocker and decide whether the
   requested work must wait behind it. Do not report green tests if tests did
   not run.
7. Select one workstream card or create a new card with ID, dependencies,
   acceptance criteria, and explicit evidence requirements.
8. Preserve unrelated user work. Do not use destructive git commands.
9. After work, rerun the smallest relevant test, then the build and full test
   suite when the baseline permits.
10. Update section 18 with what changed, exact commands, result, and remaining
    risk. Do not change a status to verified without fresh evidence.

### 14.1 Context-Window-Safe Codebase Reading

The source tree is too large to reason about from filename guesses. Use this
order:

1. Package.swift and this file.
2. HiveCore/HiveCore.swift and BrowserApp.swift.
3. Public model types under HiveCore/Models and HiveCore/Bee.
4. The touched feature's UI, model, store, tool, and tests.
5. All references to the touched public API.
6. Existing acceptance tests and documentation.
7. Build/test/runtime evidence.

For a full refresh, read all Swift files by subsystem in the directory order
shown in section 6.1. Record the commit, worktree state, source count, build
result, test result, and discovered placeholders in the handoff log.

### 14.2 Partial Completion Handoff

Before stopping after partial work, the agent must leave:

- A concise summary of implemented behavior and exact changed paths.
- Tests run and their outcome.
- Build status and full test status.
- A list of non-obvious decisions and rejected alternatives.
- Known risks, unimplemented paths, and failed experiments.
- The next smallest safe action, not a vague feature name.
- Updated workstream evidence in section 18.

The next agent starts with the audit protocol, checks the actual diff, and
does not blindly trust the previous agent's handoff.

## 15. Engineering Rules

### 15.1 General

- Preserve the zero-external-dependency policy unless a new ADR intentionally
  changes it.
- Prefer Swift actors and structured concurrency; do not hide data races with
  unsafe annotations without a documented reason.
- Keep user-facing state and persistent state separate.
- Use structured models and parsers rather than fragile string patterns for
  privileged actions.
- Avoid global singleton coupling for new features when a scoped dependency can
  be injected.
- Keep source files focused. Split only when it reduces genuine complexity.
- Test behavior, not implementation trivia.
- Use public APIs across targets; do not depend on accidental internal access.

### 15.2 Data

- Never silently discard malformed user data. Preserve it, surface an error,
  or quarantine it with a reason.
- Use atomic writes, migrations, checksums/content hashes, and recovery paths.
- Define delete semantics before storing a new data type.
- Do not use a model to generate identifiers, permissions, formulas, or
  authority decisions.
- Add fixtures for imported browser profiles, research sources, and migration
  data.

### 15.3 Browser

- Preserve keyboard parity and native focus behavior.
- Do not inject page JavaScript for automation without a capability policy and
  a visible reason.
- Respect private browsing at every data-storage boundary.
- Do not conflate a view's local state with persisted browser state.
- Keep browser performance budgets in SPEC.md as acceptance criteria.

### 15.4 AI and Agents

- Use memory and deterministic retrieval before a model.
- Label actual model/provider/availability accurately.
- Context must be scoped, size-limited, classified, and observable.
- Make model output advisory until a typed policy allows an action.
- Require citations from stored source objects, never syntax parsed from model
  prose alone.
- Test prompt injection, secret exfiltration, destructive commands, URL
  redirects, path traversal, data retention, cancel, retry, and denial paths.

### 15.5 UX

- Follow SPEC.md, including its anti-slop rules.
- Use the warm Hive palette and semantic tokens. No generic blue/purple AI
  treatment, fake gradients, sparkle icons, or marketing-card dashboards.
- Provide enough density for power users, but make advanced sections opt-in.
- Respect Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver,
  keyboard full access, and dynamic type.
- No disabled button that appears functional. If a capability is planned,
  omit it or label it honestly.

## 16. Test Strategy and Release Gates

### 16.1 Test Layers

| Layer | Required examples |
| --- | --- |
| Unit | Honeycomb schema, migration, source dedupe, task state, policy classification, tool input validation. |
| Integration | Browser capture to Honeycomb, research source to citation, approval to EventLedger, code diff to test result. |
| UI | Keyboard paths, onboarding, context-scope picker, approval preview, private-mode labels, layout persistence. |
| Browser regression | Navigation, session restore, process crash, download, reader, import fixtures, content blocker behavior. |
| Security | Prompt injection, unsafe redirects, SSRF, path traversal, symlink escape, shell metacharacters, secret redaction. |
| Performance | Cold launch, tab memory, hibernation, capture throughput, retrieval latency, frame rate. |
| Accessibility | VoiceOver labels/actions, focus order, contrast, motion, keyboard-only flows. |
| Manual release | Clean-profile demo, imports, real research citations, approve/deny action, delete/export, recovery from restart. |

### 16.2 Release Gates

A build cannot ship until:

- Build and full test suite are green.
- The active phase's exit criteria have fresh evidence.
- No plaintext credentials remain in source-controlled or distributed config.
- Private-mode behavior and deletion/export paths have been tested.
- The permission center has a deny path for every privileged capability.
- User-visible research citations resolve to retained source objects.
- User-visible model labels match the actual model/provider behavior.
- Critical browser, data, and agent errors are observable through local logs
  without retaining more data than necessary.

## 17. Research Notes That Shape the Product

This is not a competitor feature checklist. It records durable product
implications of current research.

| Research finding | Product implication |
| --- | --- |
| Apple Foundation Models supports on-device models, structured output, tools, and dynamic profiles, while availability and model behavior vary across OS/hardware versions. | Build a real capability detector and evaluation suite; do not assume FMF is always available or suitable for high-trust planning. [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels/) |
| Comet's value is browser context plus actions across tabs, history, email, and calendar. | Hive's unique advantage must be persistent local knowledge and auditable actions, not just a side chat. [Comet guide](https://www.perplexity.ai/help-center/comet/en/articles/11732243-advice-and-use-cases) |
| Notion connects page-backed items, properties, and multiple views. | Honeycomb should power structured project/task/table views from shared objects. [Notion databases](https://www.notion.com/help/intro-to-databases) |
| Obsidian's graph remains useful because it is connected to durable notes, filters, and backlinks. | Build source and claim relationships before spending time on graph polish. [Obsidian Graph view](https://obsidian.md/help/Plugins/Graph%2Bview) |
| Coding agents benefit from persistent project instructions, planning, typed tools, git-aware review, and controlled autonomy. | Studio needs a repo instruction reader, plan/diff/test loop, event evidence, and rollback. [Cursor rules](https://docs.cursor.com/context/rules-for-ai), [Codebuff agents](https://www.codebuff.com/docs/agents/overview), [Aider git](https://aider.chat/docs/git.html) |
| Screen capture and Accessibility APIs are powerful and permissioned. | Separate personal-computer capabilities behind a visible worker and just-in-time permissions. [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h) |
| Window management, quick links, snippets, and menu-bar modes are valuable only when fast and contextual. | Add these as Command Center extensions after its typed registry and permission model exist. [Raycast](https://manual.raycast.com/window-management), [Bartender](https://www.macbartender.com/) |
| Things succeeds through quick capture, areas/projects, tags, scheduling, and a fast daily view. | Let Hive project work create actions and a daily agenda; avoid a disconnected generic task clone. [Things features](https://culturedcode.com/things/features/) |
| Power Query centers data preparation and transparent transformations. | Hive Sheets should begin as a source-backed, versioned transform pipeline, not a full spreadsheet compatibility layer. [Power Query](https://learn.microsoft.com/en-us/power-query/power-query-what-is-power-query) |
| Agent web access creates injection, exfiltration, dependency, and licensing risk. | Default-deny network/action scopes, typed approvals, source trust, and local audit logs are mandatory. [OpenAI agent internet access](https://developers.openai.com/codex/cloud/internet-access) |

## 18. Append-Only Handoff Log

Do not delete prior entries. Add a new entry at the top after any meaningful
audit, implementation task, or handoff.

### 2026-07-24 - Master Handoff Baseline

- Scope: created the canonical single-app product and AI continuation protocol.
- Repository state: dirty; modified tracked files and many untracked source
  files were present before this document was added.
- Fresh evidence:
  - swift build failed at HiveToastView.swift:257 and :261.
  - swift test failed for the same compile blockers.
  - ReadingModeView.swift:448 emitted a strict-concurrency warning.
- Product correction: Swarm is integrated inside The Hive Browser. The old
  two-app framing is historical only.
- Highest unblocked next action: HIVE-001, restore the build without reverting
  unrelated user changes; then rerun the audit protocol.
- Remaining critical risk: live AI, search, citations, code execution, and
  computer use have code surfaces but are not end-to-end verified products.

### Handoff Entry Template

~~~markdown
### YYYY-MM-DD - Short task name

- Card(s): HIVE-000, DATA-000
- Starting state: commit, dirty paths, build/test state.
- Changed paths: exact relative paths.
- Behavior added or changed: user-observable result.
- Evidence:
  - Command: exact command.
  - Result: pass/fail and key output.
  - Manual path: exact steps and observed result.
- Risks and limits: exact remaining gaps.
- Next smallest action: one concrete action.
~~~

## 19. Copy/Paste Handoff Prompt for Any AI

~~~text
You are continuing work on The Hive Browser in this repository.

Read AGENTS.md in full before changing anything. Hive is one browser-native
macOS product; Swarm is integrated inside it. Treat AGENTS.md as the canonical
handoff and current source/build/test evidence as stronger than stale docs.

First run the full audit protocol from AGENTS.md section 14. Report the
worktree state, source inventory, build/test result, current blockers, and
the highest unblocked workstream card. Read the full touched subsystem and its
callers/tests before proposing a change.

Do not reset, checkout, clean, or discard unrelated work. Never claim a
feature is complete merely because source types, prompts, or mock UI exist.
Use the product's browser-first, local-first, provenance-first, permissioned
principles. For any non-trivial task, create a concise implementation plan
with acceptance tests, implement the smallest coherent slice, verify it, and
append an evidence-based entry to AGENTS.md section 18.

Prefer the current phase in the roadmap. If build is red, first determine
whether the requested task can be safely completed without clearing the
blocker. Preserve private data, secrets, and user control. Never execute
privileged browser, file, terminal, connector, or OS actions from model text
without typed policy and approval.
~~~

## 20. Maintainer Rule

This document should become more precise after every implementation cycle.
It must not become a feature wish list or a claim ledger. Record evidence,
tradeoffs, constraints, and the next verified slice of work. The goal is that
an unfamiliar but capable agent can open the repository, establish the real
state, and move Hive forward without rediscovering the product from scratch.
