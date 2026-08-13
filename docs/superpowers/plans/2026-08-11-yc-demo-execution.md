# YC Demo Execution Plan — "The Hive Browser with Swarm"

> **Status:** active plan (not yet executed)
> **Created:** 2026-08-11
> **Source of truth:** AGENTS.md §2.3 (YC Demo Spine) — this plan is the executable version
> **Grounding:** code audit 2026-08-11 — 156 app files, 1,912 test functions, built `dist/Hive.app` present; research pipeline (Tavily/Vane/SourceFetcher/ClaimExtractor), Honeycomb (BriefStore/ProjectStore/TaskStore), Studio (rollbackLastEdit/toggleStudioPanel), capture (captureCurrentPage/captureNote/toggleBriefCapture) all code-present
> **Principle:** the demo proves ONE unforgettable compound workflow — never enumerate twenty apps. Every step below names the real file/symbol, the acceptance check, and the fallback if it underdelivers.

---

## The 7-step demo spine (with code mapping)

| # | Demo beat | Verified code | Acceptance check | Fallback if weak |
|---|---|---|---|---|
| 1 | **Import a real profile, open a project space** | `BrowserImport.swift` (7-source importer), Spaces (BrowserState+Chrome.swift) | Clean import of a fixture Chrome/Safari profile; space opens with its own tab set | Pre-import a clean test profile; record the import as a screen transition |
| 2 | **Research a decision across several tabs** | Core browser (tabs, split view `splitActiveTab`, PIP, hibernation) | 3–4 tabs open on a real decision (e.g., "which DB for the analytics service") | Use the split view to show the decision artifacts side by side |
| 3 | **Capture sources automatically or intentionally** | `captureCurrentPage()` (BrowserState+Brief.swift:42), `captureNote()` (:126), `toggleBriefCapture()` (:27), Knowledge panel | Each captured page becomes a Honeycomb Source with URL/title/timestamp/hash; provenance visible | Manual capture with `⌘⇧S`; show the capture chip |
| 4 | **Ask Swarm for a cited brief grounded in those sources** | `buildBriefJSON()` (:213), research pipeline (Tavily/Vane → SourceFetcher → ClaimExtractor → CitationFormatter), `GeminiSidePanel+Research.swift`, `SwarmResponseContextPolicy` | Brief renders ONLY citations that resolve to stored Source objects; scope chip shows "current project + 3 tabs"; no hallucinated labels | Pre-warm a stored brief; walk the source→claim→citation chain in the panel |
| 5 | **Turn the brief into a Hive project** | `ProjectStore` (HiveCore/Honeycomb), `TaskStore`, `ProjectsPanelView.swift`, `BrowserState+Brief.swift` | Brief → project with decisions, open questions, and next-action tasks; tasks link back to claims | Show the task chain from the demo brief already built |
| 6 | **Open a local repo, one approved change, diff + test** | `toggleStudioPanel()` (BrowserState+Studio.swift:52), `rollbackLastEdit()` (:30), CodeRunner, `ActionApprovalView.swift` | Swarm proposes a plan → shows diff → user approves (T3) → bounded command runs → result + rollback recorded in EventLedger | Use a tiny fixture repo; the change is a one-line, obviously-correct edit |
| 7 | **Return to the browser with new state attached** | Honeycomb persistence + EventLedger; project panel reflects the code run | After the studio step, the project shows the run + test result attached; nothing lost | Re-open the project panel to show the attached run |

## Demo narrative (≤3 minutes, 25 seconds per beat)

> "I'm researching which database to use for the analytics service. [beat 2: tabs] These pages — the docs, the benchmark, the pricing — are captured as sources automatically. [beat 3] I ask Swarm: *'Write a brief: Postgres vs ClickHouse vs DuckDB for our analytics, cited to what I just read.'* [beat 4] Every claim cites a source I actually opened — here, this benchmark, this pricing page. One key: the brief becomes a project. [beat 5] Decisions, open questions, next actions — a task to spike DuckDB on the sample data. Now the coding part. [beat 6] I open the repo, Swarm plans the spike, I approve the diff, it runs the test. Here's the result, attached to the project. [beat 7] And I'm back in the browser — same state, nothing lost. The browser remembered; the project grew; the work is reviewable."

## The three rules the demo must obey

1. **No fake theater** (AGENTS.md §4.8): every citation resolves to a stored Source; every model label is honest; every action was approved. If a step can't be proven, cut it — never mock it on camera.
2. **One workflow, not a dashboard**: the camera never shows a features grid. It shows browsing → memory → cited answer → project → one safe code change.
3. **Failure is a feature**: the fallback column exists so any weak step is removed BEFORE demo day, not improvised during.

## Pre-demo verification checklist (gate: all green)

- [ ] Build green: `swift build` clean on the demo machine (M1 8GB floor per SPEC.md).
- [ ] Tests green: `swift test` — the 1,912-test suite (note: the pre-existing MLX metallib env failure is excluded; record evidence).
- [ ] Step 4 citation ground-truth: a fixture research session where every chip resolves to a retained Source object (assert in `ClaimExtractorTests`-style fixtures).
- [ ] Step 6 approval path: a recorded approve → run → EventLedger entry for a bounded command.
- [ ] Clean-profile rehearsal: run beats 1–7 start-to-finish on a fresh test profile twice; record the second take.
- [ ] Battery/thermal: demo machine on power; hibernation and focus-session guards disabled for the demo window.

## Post-demo follow-through (what the demo promises, what ships next)

The demo is the *end-state promise*. Each beat maps to the mega-plan:

| Demo beat | Shipping phase | Card |
|---|---|---|
| 3 (capture) | Phase A1 | wisp capture → Honeycomb Source |
| 4 (cited brief) | Phase B3 | citation hardening (resolve-to-Source) |
| 5 (project from brief) | Phase A5 / P2 | brief→project→task chain |
| 6 (studio loop) | STUDIO-002 | plan/diff/test/review with rollback |
| 2/7 (browser-first) | C1–C4 | credibility polish, onboarding/import |

The YC one-liner stays AGENTS.md §2.1: **"The Hive Browser turns what you browse into an organized, actionable memory."** The demo is that sentence, performed.
