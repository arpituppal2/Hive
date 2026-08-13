# M32 — Ship-Ready Reliability, Distribution & Trust Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M32 Ship-ready reliability, distribution & trust
> **Depends on:** M0–M6 storage/provenance/recovery; M12 Command Center; M15 browser credibility; M16/M17 worker and action boundaries; M18/M21 suppression; M22 distribution/presets; M25 engine sovereignty; M26 ownership/policy; M27 encrypted collaboration; M28 Flow runtime; M29 context governance; M30 work loop; M31 portability/extensibility.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** Apple code signing, hardened runtime, notarization, Gatekeeper, Instruments, accessibility guidance; Sparkle signing/security; current Hive release scripts, entitlements, crash/update surfaces, and local evidence documents.
>
> M32 turns “the repository has a release pipeline” into an evidence contract for a trustworthy distributable browser. It separates local validation from credential-gated distribution, measures the real artifact on clean machines, protects diagnostics and update channels, and makes browser recovery/accessibility/performance claims reproducible. Scripts, green tests, a historical launch checklist, or an ad-hoc bundle do not by themselves prove ship readiness.

## 0. Decision summary

The smallest safe M32 architecture is:

```text
source + dependencies + build identity
  → reproducible artifact manifest / notices / SBOM
    → nested signing + hardened-runtime verification
      → notarization + staple + Gatekeeper clean-machine evidence
        → authenticated update feed + install/rollback drill
          → browser smoke / recovery / accessibility / performance evidence
            → truthful release receipt and go / hold / blocked decision
```

| Slice | User value | Hard boundary |
|---|---|---|
| **R1 — Evidence inventory** | Know what was actually tested and shipped | Local green status, scripts, and historical snapshots are labeled evidence—not proof of external distribution |
| **R2 — Artifact and signing integrity** | Trust the app and every nested helper | Every release artifact has identity, provenance, notices, entitlements, signatures, and reproducible verification |
| **R3 — Install/update/recovery** | Install safely, update safely, and recover without losing browser state | Sparkle authenticity, version policy, rollback, crash receipts, and session recovery are tested separately |
| **R4 — Browser quality evidence** | Daily browsing remains fast, accessible, private, and resilient | Clean-profile, P0 browser, renderer recovery, performance, accessibility, privacy, and power measurements are required |
| **R5 — Release decision** | Make an honest ship/hold/block call | Missing credentials, hardware, external services, or human visual review remain explicit blockers; no false ship claim |

M32 does **not** claim a notarized download exists, manufacture Apple credentials, enable CloudKit, guarantee crash-free operation, certify legal/privacy compliance, add hidden telemetry, replace M25’s engine decision, re-vendor CEF, add Chrome Web Store parity, or make a local ad-hoc artifact suitable for distribution.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Surface | Current truth | M32 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| `docs/RELEASE_PIPELINE.md` | Local validation and scripts are documented; Developer ID/notarization/Sparkle credentials are gated | Release evidence inventory and external blocker report | A script existing is not a notarized artifact |
| `docs/PRELAUNCH.md` | Historical v1 snapshot plus current open clean-machine/privacy/notice checks | Replace stale checkboxes with dated evidence receipts | Checked historical boxes do not certify current builds |
| `docs/RECOVERY_PLAN.md` | Local crash/session recovery claims and human visual sign-off limitation | Recovery and manual-review evidence boundaries | Headless evidence cannot certify pixel fidelity or all HIG behavior |
| `docs/ARCHITECTURE.md` | CEF/Chromium product baseline, helper processes, debug-only CDP, session recovery | Artifact/helper inventory and renderer recovery gates | CEF is not Chrome Web Store parity |
| Release scripts/workflow | Build, preflight, signing, notarization, release artifact steps exist | Fail-closed inputs and redacted release receipt | CI configuration is not proof a protected job ran successfully |
| `CrashReporter` | Local crash log/install and optional submission surface exists | Redaction, opt-in, retention, consent, recovery evidence | A crash log must not contain secrets, content, or arbitrary paths |
| `UpdateManager`/Sparkle | Update surface exists; feed/signature is credential-gated | Authenticated feed, version policy, rollback, staged release | Empty or unsigned appcast is not a usable update channel |
| `Hive.entitlements` | Checked-in policy is intentionally CloudKit-disabled; release overrides may exist | Entitlement diff and nested-signature review | Entitlements do not prove provisioning or Apple approval |
| Tests/build/smoke | Current docs report 1,635 tests / 157 suites and local build/bundle/smoke green | Fresh evidence format with commit/toolchain/profile identity | Historical counts must not be copied as current without rerun |
| `THIRD_PARTY_NOTICES.md` / privacy manifest | Open checklist items remain | Dependency, license, privacy API, and notice inventory | Absence or staleness is a release blocker, not an omission to hide |

**Current implementation classification:** Hive has substantial code-present release, update, crash, build, preflight, and smoke surfaces. It has documented local evidence and explicit external credential blockers. It does not yet have a single verified ship receipt combining artifact identity, nested signature verification, notarization/stapling, clean-machine install, authenticated update/rollback, accessibility evidence, performance distributions, privacy-manifest/notice completeness, and disaster-recovery evidence. No M32 claim may be marked verified from scripts, a CI YAML file, a green historical test count, or an ad-hoc bundle alone.

### 1.2 Authority table

| Concern | Single authority | M32 rule |
|---|---|---|
| Release inputs | Versioned source, lockfiles, vendored binaries, build environment | Receipt records exact commit, versions, hashes, and toolchain |
| Artifact identity | Release manifest and canonical bundle hash | Hash identifies bytes; it does not prove trust or notarization |
| Signing | `codesign` verification over complete nested bundle | Every helper/framework/resource is inventoried; no ad-hoc artifact may be called distributable |
| Entitlements | Reviewed checked-in/release entitlements | Release-only capability differences are explicit and diffed |
| Notarization | Apple `notarytool` result plus stapled ticket and Gatekeeper check | Credential-gated result is `blocked`, never inferred from local signing |
| Updates | Sparkle feed/signature and local update policy | Feed authenticity, version/build identity, rollback, and failure states are visible |
| Crash diagnostics | Local CrashReporter policy + user consent | Diagnostics are minimized/redacted/retained locally unless explicitly submitted |
| Browser state | BrowserState/session/Honeycomb/EventLedger authorities | Recovery never invents success or silently discards canonical state |
| Performance | Frozen fixture harness + Instruments/process measurements | Unavailable measurements stay unavailable; missing data is not zero |
| Accessibility | Native accessibility tree + manual VoiceOver/keyboard review | Headless selectors cannot certify visual or assistive quality alone |
| Privacy | Data inventory, privacy manifest, notices, retention/deletion authorities | No content telemetry or third-party SDK assumption without evidence |
| Ship decision | Dated release receipt | `ship`, `hold`, or `blocked` requires evidence and named unresolved risks |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A reproducible release evidence receipt with commit, version/build, toolchain, engine, dependency, artifact, and environment identity.
2. Complete nested bundle inventory: app, CEF helpers, frameworks, Rust worker, resources, entitlements, signatures, hashes, licenses, and third-party notices.
3. Fail-closed signing, hardened-runtime, notarization, stapling, Gatekeeper, and clean-machine install checks.
4. Authenticated Sparkle appcast/update verification, version/build policy, failed-update recovery, and rollback drill using synthetic or credentialed artifacts as available.
5. Crash/renderer termination/session recovery evidence with redacted local diagnostics, consent, retention, deletion, and no-content defaults.
6. Clean-profile browser smoke coverage for navigation, tabs, workspaces, private mode, downloads, permissions, content blocking, reader/capture boundaries, and browser-first Swarm-off operation.
7. Performance and reliability measurement on the stated M1 8GB floor where hardware is available: launch, first useful frame, input, scroll, RSS, CPU, battery/thermal, crash/termination, and recovery distributions.
8. Accessibility evidence for keyboard-only, VoiceOver, Dynamic Type/large text, high contrast, reduced motion, focus order, and degraded/error states.
9. Privacy-manifest, API usage, third-party notice, secret scanning, diagnostic redaction, and local retention review.
10. Disaster/recovery rehearsal for corrupt session, interrupted update, failed notarization, renderer termination, crash during save, and incomplete release artifact.
11. An honest release receipt that distinguishes verified, locally verified, externally blocked, unavailable, and not-applicable evidence.

### 2.2 Explicit non-goals

- Obtaining or fabricating Apple Developer credentials, notarization tickets, Sparkle private keys, CloudKit provisioning, or App Store approval.
- Claiming a release is distributable because it is ad-hoc signed, locally launched, or present in GitHub Actions configuration.
- Adding analytics, session replay, page-content collection, hidden crash uploads, or remote telemetry to make the release look measured.
- Guaranteeing zero crashes, universal accessibility, legal/privacy certification, universal macOS compatibility, or remote deletion from all provider backups.
- Replacing CEF, re-vendoring CEF extension headers, adding Chrome Web Store support, or changing M25’s renderer decision.
- Treating a release pipeline as a second product authority for browser state, memory, permissions, tasks, Flow runs, notifications, or secrets.
- Sending secrets, page text, private memory, Keychain values, cookies, API keys, tokens, screenshots, or raw prompts into release logs, crash reports, benchmarks, or analytics.
- Using synthetic passes to imply production distribution; fake credentials, fake notarization, fake appcast signatures, and fake hardware measurements remain test fixtures only.

## 3. Release receipt contract

### 3.1 Receipt envelope

```text
HiveReleaseReceipt {
  receipt_id: stable UUID
  status: ship | hold | blocked | failed
  source_commit: immutable revision
  version: semantic version
  build: monotonically increasing build identity
  toolchain: Xcode/Swift/SDK/macOS identity
  engine: CEF/Chromium revision + wrapper identity
  dependencies: [{name, version, source, hash, license_status}]
  artifact: [{path, bytes, sha256, kind}]
  nested_components: [{path, type, hash, signature_status}]
  entitlements: {checked_in_hash, release_hash, diff_status}
  notarization: {status, ticket, staple_status, gatekeeper_status}
  update: {feed, signature_status, install_status, rollback_status}
  evidence: [{gate, status, command_or_manual_path, redacted_location}]
  external_blockers: [Blocker]
  unresolved_risks: [Risk]
  generated_at: Date
}
```

A receipt is an evidence index, not a marketing badge. `blocked` means an external dependency or missing evidence prevents the claim; `hold` means a known product/reliability issue requires resolution; `failed` means a check ran and did not pass. The receipt must never coerce unavailable or skipped measurements into pass.

### 3.2 Evidence status vocabulary

```text
verified       fresh command/manual evidence passed for this exact artifact
local_verified repository/build evidence passed but external distribution is absent
blocked        cannot run or complete because credentials/provisioning/hardware/service is missing
failed         ran and failed; remediation is required
unavailable    capability or measurement cannot be obtained in this environment
not_applicable fixture does not apply, with a recorded reason
stale          evidence belongs to another commit/version/build
```

Every release-facing statement links to a receipt entry. Historical counts and screenshots retain their original date and identity.

## 4. Signing, provenance, and distribution contract

### 4.1 Artifact inventory

The release process enumerates, hashes, and classifies every item in the app bundle and DMG:

```text
Hive.app
  executable(s)
  CEF framework and helper apps
  Rust fetch worker
  Sparkle framework/agent if enabled
  resources, schemes, WebChrome assets
  entitlements and embedded provisioning data
  license/notice/privacy metadata
```

The inventory records expected versus observed nested paths. Unknown executable content, unsigned nested code, a changed entitlement, a missing notice, or an untracked network-capable helper blocks the release receipt. A hash proves identity/corruption detection, not Apple trust or safety.

### 4.2 Signing and notarization

The release candidate must distinguish ad-hoc development from Developer ID distribution. A passing candidate requires, when distribution is claimed:

- valid Developer ID signing over the complete nested bundle;
- hardened runtime and reviewed exceptions only where required by CEF/worker behavior;
- `codesign --verify --deep --strict` plus entitlement/application verification;
- notarization submission result retained without credentials in logs;
- stapled ticket verification on the app/DMG;
- Gatekeeper assessment on a clean machine or explicitly recorded unavailable state;
- reproducible failure when required protected inputs are missing.

No release log stores certificate private keys, app-specific passwords, API keys, Sparkle private keys, or raw Keychain values. Credential presence is checked by protected CI context, never printed.

### 4.3 Third-party and privacy inventory

Before a ship decision, the receipt records:

- dependency source/revision/license and `THIRD_PARTY_NOTICES.md` coverage;
- CEF/Chromium and Rust worker provenance;
- PrivacyInfo.xcprivacy/API-reason declaration status where required;
- network endpoints and update/feed domains;
- data classes touched by crash/update/release tooling;
- local diagnostic retention and deletion behavior;
- unresolved legal/security review items.

M32 does not assert Apple approval or legal sufficiency from a checklist. It requires the missing review to remain visible.

## 5. Update, rollback, and crash/recovery contract

### 5.1 Update lifecycle

```text
feed discovery
  → feed/authenticity/version validation
    → user-visible candidate summary
      → download + archive verification
        → install transaction
          → launch health check
            → commit success or revert/report failure
```

The update path must bind the release version/build to the signed artifact, reject unsigned/invalid/ambiguous candidates, show unavailable/offline/feed errors honestly, and preserve the last known-good app. An update failure must never be presented as successful merely because bytes downloaded.

The rollback drill covers interrupted download, corrupted archive, signature mismatch, incompatible helper, failed post-update launch, and user-selected return to the last known-good release. Rollback preserves canonical tabs, workspaces, private flags, bookmarks/history where applicable, memory references, and deletion generations; opaque renderer caches may be invalidated and reported as lost.

### 5.2 Crash and renderer termination

Crash diagnostics are opt-in for submission, local-first, content-minimized, and bounded. A crash receipt may contain process/component identity, build, timestamp, signal/exception, redacted stack metadata, and recovery outcome. It must not contain page text, screenshots, form values, passwords, cookies, raw prompts, memory contents, arbitrary absolute paths, or secrets.

A renderer termination is not an app crash and must be reported separately. Recovery revalidates target/profile/workspace generations, restores from canonical state, marks page-only state stale when necessary, and exposes retry/close/reopen choices. If state cannot be recovered, Hive says what was lost; it does not invent a successful navigation, download, capture, or Flow run.

### 5.3 Disaster recovery

The release rehearsal uses disposable profiles and synthetic data to verify:

- corrupt current session with valid previous snapshot;
- corrupt both snapshots with truthful repair/empty-state behavior;
- crash during atomic write or ledger flush;
- renderer termination during navigation/download/capture;
- interrupted update and failed first launch;
- stale/incompatible build reopening an older session;
- private profile close/restart with no durable private content;
- export/release evidence directory loss and receipt regeneration.

No recovery test may use real personal memory, credentials, private browsing data, or production CloudKit content.

## 6. Browser quality, performance, and accessibility contract

### 6.1 Clean-profile browser corpus

The clean-profile release path tests: first launch and useful new tab; navigation/error/redirect; back/forward/reload/find/zoom/mute; new/close/select/reorder/pin/private tabs; workspace/profile isolation; session restore; downloads and reveal; site permission denial; content blocking; reader and explicit capture; crash/renderer recovery; window/peek/mini-window behavior; Swarm and memory disabled; offline and unavailable-update states.

The corpus uses local fixtures where possible and records network/content limitations when real sites are used. It never captures browsing content into ordinary release telemetry.

### 6.2 Performance evidence

Measure on the stated hardware floor when available, with clean and warm profiles and environment metadata:

| Metric | Required report |
|---|---|
| cold launch / first useful frame | p50/p95, fixture/profile, build identity |
| new-tab and omnibox readiness | p50/p95 and timeout/error rate |
| keyboard/input latency | p50/p95 and dropped interaction rate |
| scroll/resize/frame pacing | missed-frame distribution under light/heavy fixtures |
| idle and tab-ladder RSS | app/CEF/helper totals and post-close recovery |
| CPU/battery/thermal | workload, power state, averages/peaks, unavailable status |
| crash/termination/recovery | rate, confidence/context, canonical-state recovery |
| download and session correctness | receipts, duplicate/false-complete rate |

Missing instrumentation is `unavailable`, not zero. Thresholds are review gates, not promises: investigate p95 launch/new-tab regressions above 20%, median idle RSS above 20%, tab slope above 25%, or thermal/battery regression above 15% against the frozen baseline unless a dated exception explains the user value and owner.

### 6.3 Accessibility evidence

The release review covers keyboard-only paths, focus order, native labels/roles/values, VoiceOver announcements for loading/error/permission/recovery states, large text, high contrast, reduced motion/transparency, tooltip alternatives, and no-color-only status. Headless DOM checks supplement but do not replace a manual assistive-technology pass. A missing display/VoiceOver harness is recorded as blocked or unavailable, never silently passed.

## 7. Privacy and observability contract

M32 permits only minimal local release diagnostics required to answer a documented reliability question. Every diagnostic field has owner, purpose, data class, retention, deletion path, and consent state. Default behavior excludes page content, URLs/titles when not essential, form values, screenshots, private-memory text, prompts, tokens, and cross-app activity.

Crash submission is off by default unless the user opts in through an accessible, understandable control. The user can inspect, delete, and cancel a pending report. Release/update logs redact credentials and are bounded by retention. No third-party analytics or engagement optimization is introduced by M32.

## 8. Work packages

### M32-A — Evidence reconciliation and release receipt

Reconcile current docs, scripts, CI, package identity, version/build sources, test counts, and historical snapshots. Define the receipt schema, evidence vocabulary, stale-evidence rules, external blocker format, artifact naming, and redacted evidence locations.

**Done when:** every release claim has one status and receipt link; local validation, external credential gates, human visual review, and unavailable hardware are not conflated.

### M32-B — Artifact, dependency, signing, and privacy inventory

Freeze the nested bundle inventory, dependency/license/provenance list, entitlements diff, privacy API/manifest review, secret scan, and release-log redaction rules. Verify fail-closed behavior for missing protected inputs and unknown nested executables.

**Done when:** a candidate receipt can identify every shipped executable/resource and its signature/hash/license/privacy status without exposing secrets.

### M32-C — Update, crash, renderer recovery, and disaster rehearsal

Exercise Sparkle/feed authenticity, install/launch health, interrupted/corrupt update, rollback, crash-report opt-in/redaction/deletion, renderer termination, session repair, private-profile non-persistence, and evidence regeneration. Keep credentialed external steps separate from synthetic local fixtures.

**Done when:** successful, failed, blocked, stale, and unavailable states are distinguishable; recovery preserves canonical state or records exact loss.

### M32-D — Clean-profile browser, performance, accessibility, and privacy evidence

Run the frozen P0 browser corpus on clean/warm profiles and the M1 8GB floor where available. Record launch/input/frame/RSS/CPU/thermal/crash distributions, keyboard/VoiceOver/large-text/reduced-motion review, offline behavior, and Swarm-off browser usability.

**Done when:** no P0 journey is silently skipped, accessibility/manual gaps are visible, performance distributions identify workload/build, and no release telemetry contains user content.

### M32-E — Ship/hold/blocked decision and release handoff

Produce the final dated receipt, changelog/version identity, release notes, update feed status, external credential checklist, rollback owner, security/update owner, unresolved-risk list, and next smallest action. Review against M25 engine truth and M31 portability truth.

**Done when:** the decision is `ship`, `hold`, or `blocked` with evidence; any downloadable release is explicitly Developer ID/notarized/clean-machine verified, and no local ad-hoc artifact is marketed as distributable.

## 9. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M32-01 | Receipt for exact commit/build | Identity fields are complete and immutable |
| M32-02 | Stale prior receipt | Marked stale; cannot certify current artifact |
| M32-03 | Missing version/build | Release blocks before packaging |
| M32-04 | Reproducible artifact hash | Same inputs produce recorded identity or explain variance |
| M32-05 | Nested helper inventory | Every executable/framework/resource is classified |
| M32-06 | Unknown nested executable | Release blocks and names the path |
| M32-07 | Unsigned nested code | Verification fails closed |
| M32-08 | Entitlement drift | Release blocks or records reviewed exception |
| M32-09 | Ad-hoc artifact labeled dev-only | Receipt is local_verified, never distributable |
| M32-10 | Missing Developer ID credentials | Status is blocked; secrets are not printed |
| M32-11 | Notarization rejection | Status is failed with redacted reason and remediation |
| M32-12 | Staple/Gatekeeper unavailable | Status is blocked/unavailable, not passed |
| M32-13 | Dependency hash/provenance | Source, revision, license, and notice are recorded |
| M32-14 | Missing third-party notice | Release hold/block is explicit |
| M32-15 | Privacy manifest/API review incomplete | Release hold/block is explicit |
| M32-16 | Secret scan finds token | Build/release receipt fails without revealing token |
| M32-17 | Sparkle unsigned feed | Candidate rejected; no install |
| M32-18 | Sparkle signature mismatch | Candidate rejected and last known-good remains |
| M32-19 | Offline feed | Honest unavailable state; browsing continues |
| M32-20 | Interrupted download | No false install success; retry/cancel visible |
| M32-21 | Corrupt update archive | Archive rejected; current app remains usable |
| M32-22 | Failed post-update launch | Rollback/recovery receipt is shown |
| M32-23 | User-selected rollback | Canonical state preserved; opaque state loss disclosed |
| M32-24 | Crash opt-in denied | No report leaves device |
| M32-25 | Crash report redaction | No page text, secrets, prompts, tokens, or raw paths |
| M32-26 | Pending report deletion | Local report and queue are deleted |
| M32-27 | Crash during session save | Previous valid snapshot recovers |
| M32-28 | Corrupt current snapshot | Previous snapshot and repair notice are used |
| M32-29 | Corrupt both snapshots | Truthful empty/repair path; no invented tabs |
| M32-30 | Renderer termination during navigation | Canonical tab state recovers or loss is stated |
| M32-31 | Renderer termination during download | No false completion or duplicate receipt |
| M32-32 | Renderer termination during capture | Retryable, no silent duplicate memory |
| M32-33 | Private profile restart | No private content enters durable session/memory |
| M32-34 | Swarm/memory disabled | Browser navigation and tabs remain useful |
| M32-35 | Clean cold launch | App-ready and first-useful-frame distribution recorded |
| M32-36 | New-tab/omnibox readiness | p50/p95 and failures recorded |
| M32-37 | Keyboard/input latency | Focus and interaction distribution recorded |
| M32-38 | Scroll/resize heavy fixture | Frame pacing and missed frames recorded |
| M32-39 | Tab RSS ladder | App/helper totals and post-close recovery recorded |
| M32-40 | Battery/thermal run | Workload/power state and unavailable status recorded |
| M32-41 | Keyboard-only browser | All P0 actions reachable and labeled |
| M32-42 | VoiceOver loading/error/recovery | State announcements are accurate |
| M32-43 | Large text/high contrast | Essential controls/state remain visible |
| M32-44 | Reduced motion/transparency | No essential transition depends on motion |
| M32-45 | Offline/restricted network | Browser remains usable; update/research degrade honestly |
| M32-46 | Permission denial | Denied state is clear and non-blocking for ordinary browsing |
| M32-47 | Content blocking fixture | Network/cosmetic behavior and privacy report match policy |
| M32-48 | Human visual sign-off unavailable | Gate is blocked/unavailable, not headlessly passed |
| M32-49 | Evidence directory loss | Receipt can regenerate without user content or secrets |
| M32-50 | Final ship/hold/blocked review | Decision names evidence, owners, blockers, and next action |

## 10. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M32-A | Evidence truth | Exact artifact/build/commit receipt with stale/local/external statuses |
| M32-B | Artifact integrity | Complete nested inventory, hashes, signatures, entitlements, notices |
| M32-C | Secret/privacy safety | Secret scan, privacy/API review, redacted logs, no-content diagnostics |
| M32-D | Distribution signing | Developer ID/hardened-runtime verification or explicit external block |
| M32-E | Notarization/Gatekeeper | Notary result, stapled ticket, clean-machine assessment or blocked status |
| M32-F | Update authenticity | Signed feed, version/build binding, invalid-candidate rejection |
| M32-G | Update rollback | Interrupted/corrupt/failed-launch/user rollback preserves canonical state |
| M32-H | Crash/renderer recovery | Redacted opt-in diagnostics and truthful session/page recovery |
| M32-I | Browser P0 | Clean-profile navigation, tabs, private, downloads, permissions, recovery |
| M32-J | Performance/reliability | Launch/input/frame/RSS/CPU/thermal/crash distributions or unavailable status |
| M32-K | Accessibility | Keyboard, VoiceOver, large text, contrast, reduced-motion evidence |
| M32-L | Ship decision | Dated ship/hold/blocked receipt with owners, risks, and no overclaim |

## 11. Safety, privacy, and claim boundaries

M32 must remain release infrastructure, not a new data-collection system. It must never enable passive screen/audio/keystroke capture, engagement optimization, remote page-content telemetry, secret logging, or model training on diagnostics. Release content, page content, crash content, private memory, extension content, and update metadata are untrusted inputs; none can widen permissions or bypass native policy.

The release process may inspect artifacts and synthetic fixtures. It must not upload user data to prove a gate. Private, deleted, revoked, stale, or cross-scope data is excluded from test fixtures unless represented by synthetic typed records. A failed or unavailable external check remains visible to the user and release owner.

No M32 document may say “shipped,” “notarized,” “secure,” “accessible,” “crash-safe,” or “production-ready” without a fresh receipt for the exact artifact and scope. Apple documentation and Sparkle documentation constrain the process; they do not substitute for Hive’s own evidence.

## 12. Execution order and handoff

Implement M32-A as documentation and evidence reconciliation before changing release scripts. Implement M32-B against a disposable/local artifact before attempting credentialed distribution. Implement M32-C with synthetic update/crash/recovery fixtures and only then run external notarization/Sparkle steps when credentials are intentionally provisioned. Implement M32-D on the supported hardware/display harness; record unavailable manual gates rather than faking them. Implement M32-E only after all evidence is tied to one immutable build identity.

The next smallest safe action is **M32-A: create the release receipt schema and reconcile the current local/external evidence boundary**. Do not request credentials, publish a release, enable telemetry, modify the renderer, or call an ad-hoc artifact distributable as part of M32 planning.
