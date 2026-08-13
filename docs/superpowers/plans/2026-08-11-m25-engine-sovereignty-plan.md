# M25 — Engine Sovereignty Decision Execution Plan

> **Status:** planned decision contract; no engine migration or runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M12 Command Center, M15 browser credibility, M16 worker/permission boundaries, M22 signing/distribution decisions, current CEF baseline, and fresh retention/extension-demand evidence.
> **Scope:** reconcile the actual renderer choice, measure the current CEF/Chromium product, establish engine-neutral browser seams, evaluate a reversible WKWebView product path and research-only alternative engines, and make a documented go/hold/exit decision.

## 1. Decision correction

M25 is not a greenfield choice between unused engines. The repository already ships the main `Hive` target on a vendored CEF/Chromium stack:

```text
Hive executable
  → CefSwiftUI
  → vendored CefSwift 0.1.0
  → CEF 148 / Chromium 148.0.7778.218
  → CEF browser, renderer, GPU, utility, and helper processes
```

`HiveWebKitSmoke` is an opt-in developer/runtime smoke target that launches a real `WKWebView`; it is not the product renderer or a package product. `Package.swift`, `README.md`, `docs/DECISIONS.md`, and the vendored CefSwift source are stronger current evidence than the older roadmap wording that frames CEF/WKWebView as an undecided future selection.

M25 therefore has two responsibilities:

1. **Truth correction:** record CEF/Chromium as the current product baseline and WKWebView as a smoke/reference path until a product-level alternative is proven.
2. **Sovereignty decision:** decide, from measured retention, extension demand, compatibility, performance, security-update, distribution, and maintenance evidence, whether Hive should remain CEF-based, add a supported WKWebView product path, or run a separately funded engine migration spike.

No M25 document may claim Chrome extension parity merely because Chromium is embedded. The current release pipeline explicitly says CEF extension loading is blocked by missing vendored extension C API headers, and even a later re-vendor would initially support local unpacked loading—not Chrome Web Store integration or every Google-backed `chrome.*` API.

## 2. Goal and user-facing question

M25 answers one product question:

> **Which rendering engine lets Hive be the most trustworthy, capable, maintainable, and distributable browser for the users we actually retain—without sacrificing the browser-first experience?**

The answer must account for the complete product, not only synthetic page speed:

- clean launch and first useful frame;
- navigation, tabs, private profiles, session restore, downloads, media, permissions, content blocking, reader mode, and web chrome;
- memory, CPU, battery, thermal behavior, renderer recovery, and crash rate;
- extension demand and actual job completion, not extension wish-list volume;
- CEF/Chromium security update turnaround and binary maintenance;
- App Sandbox, helper signing, hardened runtime, notarization, Sparkle updates, and release size;
- compatibility with Hive’s Honeycomb, Swarm, Command Center, Worker, and privacy boundaries;
- a credible rollback path that preserves sessions, bookmarks, history, downloads, private-mode rules, and memory provenance.

## 3. Candidates and current posture

### 3.1 CEF/Chromium — current product baseline

**Current evidence:** `Hive` depends on vendored `CefSwiftUI`; the package and README identify CEF 148 / Chromium 148.0.7778.218; `HiveApp` initializes CEF; browser tabs use `CefWebViewModel`; the CEF wrapper includes browser, renderer, GPU, utility, and helper lifecycle.

**Strengths to measure:** Chromium compatibility, DevTools/CDP surface, native browser controls, web platform coverage, current Hive feature integration, extension API potential, and control over the renderer version.

**Costs to measure:** bundle size, helper count, idle and multi-tab RSS, startup work, GPU/thermal behavior, code-signing/notarization complexity, CEF/Chromium patch lag, vendored wrapper maintenance, CEF API churn, crash recovery, and update delivery.

**Current hard limitation:** the vendored CEF distribution does not expose the extension C API headers needed for a native loader. The existing extension manager must remain honest: management UI is not proof of live extension execution.

### 3.2 WKWebView — reference/smoke path, not current product

**Current evidence:** `HiveWebKitSmoke` is an opt-in executable target excluded from the normal product and test product path. It proves that a WebKit smoke harness exists, not that Hive can switch its full browser to WebKit.

**Strengths to measure:** native macOS integration, system-managed WebKit updates, smaller application payload, Apple-managed sandbox/process lifecycle, lower distribution burden, and direct platform APIs.

**Costs and gaps to measure:** lack of Chrome Web Store parity, Safari Web Extension packaging/conversion boundaries, missing Chromium-specific APIs, CDP/DevTools differences, content-blocker and injection differences, navigation/download/permission behavior, session restoration, multi-profile isolation, and compatibility with all current Hive browser features.

A WKWebView product path must not be treated as a free rollback. It is a separate renderer implementation with its own process recovery, bridge, downloads, permissions, storage, and feature gates.

### 3.3 Ladybird-class or independent engines — research-only alternative

Ladybird and similar independent engines are not a near-term production fallback. They may be tracked for standards maturity, security model, platform support, performance, and licensing, but M25 must not spend product-critical work on them unless the project clears an explicit maturity gate:

- stable macOS distribution path;
- required Web Platform Tests and real-site compatibility;
- usable downloads, media, accessibility, storage, private profiles, and developer tools;
- security/update process suitable for a daily browser;
- a signed/notarized embedding story or supported integration API;
- a funded team and measurable support horizon.

A project roadmap or public research page is not runtime evidence. Until those gates pass, Ladybird remains a watchlist item, not a candidate product engine.

## 4. Non-goals and explicit deferrals

M25 does not ship a renderer migration, dual-engine production mode, Chrome Web Store integration, a general extension marketplace, a browser-engine rewrite, a new network stack, a new profile database, or a third-party engine embedded into the product without a separate approved spike.

Deferred:

- automatic per-site engine switching;
- claiming that CEF equals Chrome or that WKWebView equals Safari;
- importing arbitrary Chrome extension state or credentials;
- extension code execution from page content or model output;
- broad extension permissions before typed permission/admission contracts exist;
- engine-specific memory or browsing telemetry sent off-device;
- replacing CEF because an alternative has a smaller bundle without measuring compatibility and retention;
- choosing Ladybird, Servo, Gecko embedding, or another engine from headlines rather than a controlled fixture corpus;
- making the browser depend on an engine migration for the memory wedge or YC demo.

## 5. Authority and decision boundaries

| Concern | Authority | M25 rule |
|---|---|---|
| Current renderer truth | Package/build/runtime evidence | Docs cannot call WKWebView the product renderer while `Hive` initializes CEF. |
| Browser domain behavior | Engine-neutral HiveCore policies and browser state | Navigation, tabs, sessions, privacy, and memory contracts must not depend on engine internals. |
| Renderer adapter | Engine-specific adapter | CEF and any future WebKit adapter own only renderer lifecycle and capability translation. |
| Page content | Untrusted renderer input | Page text, extension content, DevTools output, and model output cannot widen permissions or choose an engine. |
| Extension capability | Separate typed extension/permission contract | A renderer does not grant extension privileges by default. |
| Worker/OS privilege | M16 permission center and Worker boundary | Engine choice cannot bypass file, Accessibility, Screen Recording, Apple Events, or network policy. |
| Storage/provenance | M0/M4 Honeycomb/EventLedger authorities | Engine adapters do not create parallel session, memory, or audit stores. |
| Release/signing | Distribution pipeline and M22/platform decision | Every helper/framework must be signed, verified, notarized, and updateable before a candidate can ship. |
| Decision | Recorded M25 ADR after evidence review | Go/hold/exit requires the complete matrix and explicit unresolved risks. |

## 6. Engine-neutral seam contract

Before comparing engines fairly, Hive must define the boundary that a future renderer can implement without rewriting product state. This is a planning contract, not permission to edit Swift yet.

### 6.1 Renderer adapter responsibilities

A renderer adapter may own:

```text
create / attach / detach / destroy
navigate / reload / stop
back / forward / canGoBack / canGoForward
execute approved page action
read bounded page metadata
capture approved DOM/page text
set zoom / mute / find state
manage download decision and progress
report permission/certificate/load failures
report renderer crash/termination/recovery state
```

The adapter must not own:

```text
profile identity and durable session authority
Honeycomb memory or citations
EventLedger consent authority
Worker grants or OS permissions
arbitrary shell/file/network actions
model routing or model-generated privilege
```

### 6.2 Capability matrix

Every adapter reports typed capabilities rather than pretending feature parity:

```text
engine_id / engine_revision
supports_cdp
supports_dom_capture
supports_download_control
supports_site_permissions
supports_private_profile
supports_session_restore
supports_page_find
supports_reader_pipeline
supports_content_blocking
supports_media_observation
supports_accessibility_bridge
supports_extension_loading
supports_extension_debugging
supports_custom_scheme_per_profile
supports_renderer_recovery
```

Each capability has `available`, `limited(reason)`, `unavailable`, or `not_measured`. A UI feature must show the capability state; a button cannot appear live because another engine supports it.

### 6.3 Shared state and migration

Browser tabs, workspaces, profiles, bookmarks, history, downloads, permissions, and memory references remain engine-neutral. Renderer-specific data is isolated:

```text
engine_session_state {
  engine_id
  profile_id
  tab_id
  opaque_state_reference
  created_at
  last_validated_at
  migration_state
}
```

Opaque renderer state is never copied between engines without a verified conversion. On fallback, Hive restores from canonical URL/title/scroll/history/session metadata and reports any lost renderer-only state. Private profiles must never be restored into persistent profiles or vice versa.

## 7. Measurement harness

M25 requires a reproducible harness that runs the same Hive fixture corpus against the current CEF build and every serious candidate. Synthetic browser benchmarks are supplementary; the product gates use real Hive journeys.

### 7.1 Environment lock

Record:

```text
machine_model / chip / RAM / macOS_version
build_commit / engine_revision / wrapper_revision
release_or_debug / code-signing-mode
network_fixture_mode / cache_state / profile_state
power_mode / display_scale / monitor_count
background_process_policy / benchmark_repeat
```

Use a clean disposable profile for cold runs, a standardized warm profile for steady-state runs, and an adversarial fixture profile for private/permission/download/crash behavior. Do not collect page URLs, titles, form values, message bodies, memory text, or extension code in ordinary telemetry.

### 7.2 User-journey benchmark corpus

The corpus must include:

1. cold launch → one useful new tab;
2. restore 1, 10, 50, and 100 tabs across workspaces;
3. navigation across static, media, long-document, login-like, error, and redirect fixtures;
4. tab creation/close/select/reorder/duplicate/pin/private transitions;
5. back/forward/reload/find/zoom/mute and keyboard paths;
6. downloads: start, progress, pause/resume/cancel, failure, and reveal;
7. private profile create, navigate, close, restart, and no-persistence checks;
8. content blocking and cosmetic filtering fixtures;
9. reader/page capture/brief/citation paths with memory enabled and disabled;
10. renderer termination during navigation, download, capture, and session restore;
11. multi-display/window/mini-window/peek lifecycle where supported;
12. selected extension fixtures only if a candidate reports extension loading as available.

### 7.3 Required metrics

| Metric | Collection | Report |
|---|---|---|
| cold process launch | app/renderer signposts | p50/p95 to app-ready and first useful frame |
| new-tab readiness | browser lifecycle signposts | p50/p95 to interactive chrome and page-ready |
| navigation completion | typed load states | p50/p95 and timeout/error rate by fixture |
| first contentful/usable frame | renderer/native frame markers | p50/p95; distinguish page from chrome |
| input latency | keyboard/mouse/omnibox timestamps | p50/p95 and dropped interaction rate |
| scroll/resize smoothness | frame pacing and native signposts | missed-frame rate under normal and heavy pages |
| idle RSS | process tree snapshot | app, renderer, GPU, utility, helper totals |
| tab RSS slope | controlled tab ladder | incremental memory per tab and recovery after close |
| CPU/battery/thermal | local Instruments/power/thermal runs | average, peak, and state transitions |
| crash/termination | app + renderer lifecycle | app crash, renderer termination, recovery success |
| session recovery | canonical-state comparison | tabs/URLs/private flags/workspaces restored |
| download correctness | typed download receipts | completion, pause/cancel accuracy, duplicate files |
| permission truth | fixture expectations | prompt/deny/grant state and no-leak behavior |
| update success | signed artifact pipeline | install, launch, rollback, helper compatibility |
| extension job completion | task fixture, not install count | successful user outcome and permission clarity |

Every metric must carry a `measurement_status`: measured, unavailable, or not-applicable. Missing instrumentation is not a zero.

## 8. Security and distribution evaluation

### 8.1 CEF/Chromium candidate requirements

A CEF candidate must provide:

- explicit Chromium/CEF version and source/binary provenance;
- repeatable framework/helper download or build process;
- all nested helper/framework signatures verified before packaging;
- hardened-runtime and entitlement review for JIT, unsigned memory, plugins, and helper processes;
- notarization on a clean machine, not only ad-hoc launch;
- renderer/GPU/utility crash handling and bounded reaping;
- a documented Chromium security-update intake, patch, test, and release SLA;
- Sparkle/update compatibility across the full nested bundle;
- a license and third-party-notice inventory;
- rollback to the last known-good engine without destroying canonical browser state.

A CEF major-version update is not routine dependency maintenance. It is a browser release candidate requiring the full fixture corpus, security review, packaging validation, and crash/performance comparison.

### 8.2 WKWebView candidate requirements

A WKWebView product candidate must provide:

- a real product target, not only `HiveWebKitSmoke`;
- profile/private-session isolation matching the current product contract;
- navigation, downloads, permissions, media, find, zoom, content blocking, reader, capture, custom schemes, and crash/reload behavior;
- a clear Safari Web Extension position and conversion plan, without promising Chrome Web Store parity;
- equivalent Honeycomb/Swarm bridge safety and no page-driven authority expansion;
- clean App Sandbox, signing, notarization, and update evidence;
- a recovery path for WebContent process termination and lost page state;
- compatibility evidence on the oldest supported macOS and the M1 8GB floor.

A smaller bundle or Apple-managed runtime is not sufficient to declare victory if core browser journeys fail or user retention regresses.

### 8.3 Alternative engine requirements

An independent engine cannot advance past research-only status without proving:

- required real-site compatibility from the frozen corpus;
- stable embedding API and multi-process/security model;
- macOS support and distribution path;
- downloads, media, accessibility, private data, storage, and recovery;
- security response process and update cadence;
- acceptable performance/RSS/thermal results;
- a team/support commitment appropriate for a daily browser.

## 9. Extension reality and demand evidence

Extension demand must be measured by completed user jobs, not online enthusiasm or a raw list of requested extensions.

### 9.1 Demand taxonomy

Classify every request as:

```text
native Hive feature can replace job
content-blocking rule can replace job
Safari Web Extension can replace job
local unpacked Chromium extension can replace job
requires Chromium-specific privileged API
requires Google backend/account service
requires unsupported browser UI/devtools hook
unknown or unsafe
```

For each cohort, record the job, frequency, current workaround, failure cost, permission scope, and whether Hive’s native context graph gives a better solution. Do not collect extension source or browsing history as telemetry without explicit consent.

### 9.2 Minimum evidence before engine escalation

Before a renderer migration receives engineering priority, require:

- a documented cohort of users who fail to adopt or retain Hive because of a specific extension job;
- a reproducible task fixture for that job;
- evidence that a native Hive feature or Safari Web Extension cannot solve it within the security boundary;
- evidence that the extension requires a capability the current engine cannot provide;
- measured willingness to remain with Hive if the capability ships;
- an estimate of permission, support, update, and abuse costs.

“Users want extensions” is not a decision. “Users abandon Hive after failing job X, and only engine path Y can solve X under an acceptable permission model” is decision evidence.

## 10. Decision matrix and gates

### 10.1 Candidate scorecard

Score each candidate from 0–5 per category, with raw evidence links and confidence:

| Category | Weight | Required question |
|---|---:|---|
| Browser job compatibility | 25% | Does it pass the real Hive journey corpus? |
| Retention/extension demand | 20% | Does it solve a measured switching/retention blocker? |
| Security/update posture | 15% | Can Hive patch and ship safely within its SLA? |
| Distribution/signing | 10% | Can the complete bundle sign, notarize, update, and roll back? |
| Performance/RSS/thermal | 10% | Does it meet the M1 8GB and latency budgets? |
| Crash/recovery | 10% | Can renderer failures preserve user state honestly? |
| Engineering ownership | 5% | Can the team maintain the adapter and test corpus? |
| Privacy/control | 5% | Does it preserve local-first scope and permission boundaries? |

The weights are a decision aid, not a substitute for hard gates. A candidate that fails security, distribution, privacy, or core browser compatibility cannot pass through a high weighted score.

### 10.2 Proposed hard gates

A candidate is **ship-eligible** only if it:

- passes all P0 browser journeys in the frozen corpus;
- has no unresolved critical security or signing issue;
- has measured clean-profile startup, RSS, thermal, and crash results;
- preserves private-profile and deletion invariants;
- has a supported update and rollback path;
- reports unsupported capabilities honestly;
- has a concrete retention or extension-demand case;
- passes accessibility and keyboard validation;
- has an owner and maintenance budget for engine updates.

A candidate is **hold** if it clears compatibility but lacks demand, distribution, or maintenance evidence. It is **exit** if it fails a hard gate or creates a worse product than the current baseline.

## 11. Kill criteria and rollback

The following are proposed stop signals for the bounded spike. They are not a claim that any candidate has already failed.

### 11.1 Immediate kill criteria

Stop the candidate path immediately if it:

- cannot be signed/notarized with all nested helpers/frameworks;
- requires unreviewed broad entitlements or a privileged permission unrelated to a user-visible job;
- breaks private-profile persistence boundaries or deletion scope;
- allows page/extension/model content to invoke privileged actions without the existing policy/approval path;
- cannot recover from renderer termination without silently losing canonical tab/session state;
- cannot receive security updates within the agreed release SLA;
- lacks a supported license/provenance/update story;
- introduces an unbounded network, file, or process authority.

### 11.2 Quantitative hold/exit signals

Compare against the current CEF baseline on the same machine and corpus. Treat these as proposed review thresholds, not universal performance truths:

- p95 cold launch regression above 20% without a retention-critical capability;
- p95 new-tab readiness regression above 20%;
- median idle RSS increase above 20% or tab-ladder slope above 25% without a compensating capability;
- thermal-state or battery-cost regression above 15% in the same workload;
- crash or renderer-termination rate above baseline by more than the predeclared confidence interval;
- recovery success below 99% for canonical tab/session state on injected renderer termination;
- any P0 browser journey regression;
- release artifact growth above 500 MB compressed or a documented distribution limit without an approved exception;
- security/update turnaround beyond the agreed critical-CVE SLA.

One metric may trigger investigation; no single synthetic score automatically chooses the engine. The decision record must show raw distributions, workload, confidence, and user impact.

### 11.3 Rollback contract

Rollback must be an engine-version rollback, not a destructive data migration:

1. stop new candidate sessions;
2. preserve canonical browser/session/memory state;
3. mark engine-specific opaque state as stale;
4. restore tabs from canonical URL/profile/workspace metadata;
5. invalidate incompatible renderer caches and extension state;
6. launch the last known-good engine bundle;
7. verify private flags, tab count, workspace identity, downloads, and memory references;
8. show a truthful recovery receipt and retain redacted evidence.

No rollback may copy private renderer state into a persistent profile or claim to restore opaque state that was never convertible.

## 12. Work packages

### M25-A — Truth reconciliation and engine-neutral boundary

Record CEF 148 as the current product engine, WKWebView as smoke-only, and identify all renderer-specific dependencies. Define the engine adapter capability matrix, canonical browser state, opaque engine state, recovery, and feature-status contract.

**Done when:** the repository’s docs agree on current engine truth, no roadmap line implies an unmade choice, and a future adapter can be evaluated without creating a second session/memory/permission authority.

### M25-B — Baseline instrumentation and fixture corpus

Build the measurement specification and disposable-profile harness around the current CEF product. Freeze the real Hive browser journeys, environment metadata, signposts, process/RSS/thermal/crash measurements, and browser/privacy/accessibility fixtures.

**Done when:** a repeatable CEF baseline report exists with measured/ unavailable states explicit, no browsing content is collected by default, and failures identify the affected user journey.

### M25-C — Candidate feasibility spikes

Evaluate only the candidate justified by demand evidence. For WKWebView, prove a bounded product vertical slice: one tab, profile/private state, navigation, custom `hive://` scheme, download, permission denial, session checkpoint, and renderer termination recovery. For CEF, measure a controlled wrapper/CEF update and extension-header re-vendor only if a concrete extension job requires it. Keep Ladybird-class engines research-only unless the maturity gate is met.

**Done when:** each candidate has a capability matrix, compatibility report, binary/signing report, RSS/thermal/crash report, security/update report, and explicit list of missing work.

### M25-D — Demand, distribution, and security decision

Run the extension/job cohort analysis, review Chrome Web Store versus local-unpacked versus Safari Web Extension reality, validate nested signing/notarization/Sparkle update paths, and review security-patch ownership and maintenance budget.

**Done when:** every proposed migration benefit maps to a measured user job, every cost has an owner and release SLA, and the decision is not based on raw extension counts or synthetic benchmark winners.

### M25-E — Go/hold/exit ADR and browser-first validation

Publish a dated decision record: remain CEF, invest in a WKWebView product path, run a scoped CEF update/re-vendor, or keep an alternative engine research-only. Include raw evidence, unresolved risks, rollback, support horizon, and next smallest action. Validate that the browser remains usable with the candidate disabled.

**Done when:** the decision is reversible, signed artifacts are proven for any candidate that advances, no false extension claim remains, and ordinary browsing/memory behavior is unaffected by the spike.

## 13. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M25-01 | Current engine inventory | CEF 148 product / WKWebKit smoke-only recorded accurately |
| M25-02 | Renderer adapter capability report | Every capability is available, limited, unavailable, or unmeasured |
| M25-03 | Clean cold launch | p50/p95 app-ready and first useful frame recorded |
| M25-04 | One-tab navigation | URL/title/load/error states match canonical contract |
| M25-05 | Ten-tab restore | Canonical tab/workspace/private metadata restored |
| M25-06 | Fifty-tab restore | Memory/RSS slope and recovery measured |
| M25-07 | Hundred-tab restore | Bounded behavior, truthful partial/degraded state |
| M25-08 | Back/forward/reload/find/zoom/mute | Keyboard and command paths behave consistently |
| M25-09 | Private profile lifecycle | No private persistence or cross-profile leakage |
| M25-10 | Custom `hive://` scheme | Per-profile scheme behavior and failure state measured |
| M25-11 | Download lifecycle | Start/progress/pause/resume/cancel/reveal receipts match engine state |
| M25-12 | Site permission denial | Denied state is honest and browser remains usable |
| M25-13 | Certificate/load failure | Failure is visible; no false secure/loaded state |
| M25-14 | Content blocking | Network/cosmetic behavior and diagnostics remain bounded |
| M25-15 | Reader/page action | Hosted-page gating and action result match capability report |
| M25-16 | Renderer termination during navigation | Canonical state preserved; recovery receipt shown |
| M25-17 | Renderer termination during download | Download state reconciles without duplicate file or false completion |
| M25-18 | Renderer termination during capture | Capture is retryable and never silently duplicated |
| M25-19 | App crash during session save | Previous valid session remains recoverable |
| M25-20 | Display scale/window resize | Input and first-frame behavior remain valid |
| M25-21 | Multi-display/peek/mini-window | Auxiliary lifecycle is bounded or explicitly unavailable |
| M25-22 | Keyboard-only browser | Focus, shortcuts, and recovery paths remain reachable |
| M25-23 | VoiceOver browser chrome | Engine-specific content states are announced accurately |
| M25-24 | Large text/high contrast/reduced motion | No essential state is hidden or clipped |
| M25-25 | Memory/Swarm disabled | Browser remains fully useful without model or memory dependency |
| M25-26 | CEF helper inventory | Helpers, frameworks, resources, and signatures are enumerated |
| M25-27 | WKWebView product slice | Product-level WebKit path, not smoke-only, reports capabilities |
| M25-28 | Safari Web Extension fixture | Conversion limits and unsupported API surface are explicit |
| M25-29 | Local unpacked extension fixture | Only available if CEF headers/loader are actually present |
| M25-30 | Chrome Web Store request | Honest unavailable state; no fake remote install |
| M25-31 | Extension permission preview | Scope is typed, visible, and cannot be self-approved |
| M25-32 | Extension prompt injection | Extension/page content cannot widen Hive permissions |
| M25-33 | CEF update candidate | Wrapper/API/build/security/compatibility report produced |
| M25-34 | WKWebView WebContent termination | Recovery preserves canonical state or reports loss |
| M25-35 | Candidate bundle signing | Nested helpers/frameworks sign and verify cleanly |
| M25-36 | Candidate notarization | Clean-machine notarization and staple pass or block |
| M25-37 | Sparkle candidate update | Install/launch/rollback works for complete bundle |
| M25-38 | Critical-CVE update drill | Candidate has owner, patch path, SLA, and test evidence |
| M25-39 | Idle RSS comparison | App/renderer/GPU/helper totals reported by engine |
| M25-40 | Tab RSS ladder | Incremental cost and post-close recovery compared |
| M25-41 | Battery/thermal comparison | Same workload and power state produce distributions |
| M25-42 | Crash/termination comparison | Confidence-bounded baseline comparison reported |
| M25-43 | Real-site compatibility corpus | Required pages and interactions pass or are typed failures |
| M25-44 | Retention cohort evidence | Specific engine-blocked user jobs are documented |
| M25-45 | Native replacement attempt | Native Hive feature/Safari extension alternatives assessed |
| M25-46 | Engine rollback | Canonical tabs/workspaces/private flags survive rollback |
| M25-47 | Candidate disabled | Current product path remains unchanged and usable |
| M25-48 | Decision record review | Go/hold/exit, unresolved risks, owner, and next action are present |

## 14. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M25-A | Current-engine truth | Package/source/runtime/docs agree that CEF 148 is current and WKWebView is smoke-only |
| M25-B | Engine-neutral state | Canonical tabs/profiles/workspaces/session/memory boundaries are documented |
| M25-C | Capability honesty | Engine features report available/limited/unavailable/unmeasured states |
| M25-D | Browser compatibility | Frozen real-journey corpus passes or records typed failures |
| M25-E | Performance baseline | Launch, frame, input, RSS, CPU, battery, and thermal distributions measured |
| M25-F | Crash/recovery | App/renderer termination recovery preserves canonical state or reports loss |
| M25-G | Private/privacy boundary | No cross-profile persistence, hidden telemetry, or page-driven authority |
| M25-H | Extension reality | CEF local-unpacked, Safari conversion, Chrome Web Store, and unsupported APIs are distinguished |
| M25-I | Security/update ownership | Critical-CVE path, wrapper/engine ownership, and release SLA documented |
| M25-J | Distribution | Nested signing, notarization, update, and rollback evidence exists |
| M25-K | Demand evidence | Engine choice maps to measured retention/user jobs, not feature counts |
| M25-L | Decision truthfulness | Dated go/hold/exit ADR has raw evidence and no unsupported migration claim |

## 15. Implementation order and handoff

Implement M25-A as documentation and inventory before creating any product renderer adapter. Implement M25-B against the current CEF build before comparing a candidate. Implement M25-C only for a candidate justified by M25-D demand evidence; keep the WKWebView slice isolated and keep Ladybird-class alternatives research-only. Implement M25-D before re-vendoring CEF extension headers or changing distribution. Implement M25-E only after signed-artifact, rollback, compatibility, and security evidence exists.

The next smallest safe action is **M25-A: correct the canonical engine truth and inventory renderer-specific dependencies**, followed by a documentation-only baseline measurement specification. Do not switch engines, add extension loaders, re-vendor CEF, install alternative engines, or alter the product package as part of M25 planning.
