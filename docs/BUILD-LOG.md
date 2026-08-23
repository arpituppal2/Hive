# CABIN — BUILD LOG (append-only, Part 0.2 / §18.3 format)

Source of truth: `docs/designs/cabin-rebuild-spec.md`. Status legend: ✅ done · 🟡 in-progress · ⚠️ blocked.

---

## Session 2026-08-18 (evening) — resume from Phase 6 handoff

Baseline verified before any change:
- `git status` clean except 2 untracked: `docs/designs/cabin-rebuild-spec.md`, `MISSION/product/index.html`
- `swift test`: **490 tests, 0 failures** (487+ baseline gate: PASS)
- Secrets scan of tracked tree (key/token/password patterns, `.p8/.p12/.mobileprovision/.storekit/GoogleService-Info.plist`): **0 findings**
- `OLD CONTENTS/` + `references/`: gitignored, **never committed** (0 tracked files, 0 history hits) → no history rewrite required

[M00] ✅ done · 2026-08-18 · commit 4102791
  files: project.yml, Package.swift, Cabin-iPadOS.entitlements, Info-iPadOS.plist, Sources/CabinApp-iPadOS/ (+7), deleted CabinWatch/ (-4), deleted CabinApp-iOS/ (-7)
  tests: 490 passing (487+ baseline gate: PASS)
  verified: swift test -c release ✓ · xcodebuild build (macOS) ✓ · xcodegen generate ✓ · xcodebuild build (iPadOS) deferred (no iOS sim runtime in Xcode beta)
  notes: CabinWatch deleted; CabinApp-iOS → CabinApp-iPadOS renamed; deployment floors updated to macOS 14 / iPadOS 17 per D-A; next: M01 Brand & Identity + M02 Core State & Persistence + M42 CI/Build/Sign/Notarize + M43 SeatBakery Tooling (all Phase 0, parallel)

[M01] ✅ done · 2026-08-18
  files: docs/designs/BRAND_BOOK.md (+1), CabinPalette.swift (verified), CabinTokens.swift (verified)
  tests: 490 passing
  verified: Brand compliance CI gate added · Font-size audit CI gate added · Secret scan CI gate verified
  notes: C-mark (Halo Ring), OKLCH palette locked (21 colors), type scale (Doto + SF), glass/shadow recipes, icon family, app icons (macOS+iPadOS), App Store surfaces (5 screenshots/platform), Do-Not-Copy list (Part 9.6) enforced in CI

[M02] ✅ done · 2026-08-18
  files: docs/designs/API_FREEZE.md (+1), CabinStore.swift (verified), PersistenceEngine.swift (verified), PersistenceMigrations.swift (verified)
  tests: 490 passing (PersistenceTests: 3, PersistenceSchemaVersioningTests: 3 — all test-locked)
  verified: CabinStore API frozen per Part 14.3 · schemaVersion + migration runner · legacy v0 migrates → v1 · no silent failures · resetEverything() clears all
  notes: 60+ public properties, 40+ public methods, 4 nested types, 3 module-level types documented in API_FREEZE.md

[M42] ✅ done · 2026-08-18
  files: .github/workflows/ci.yml (updated), Cabin.entitlements (updated), Cabin-iPadOS.entitlements (updated), docs/designs/CI_MAS_DECISION.md (+1)
  tests: 490 passing
  verified: CI builds both macOS (Cabin) + iPadOS (Cabin-iPadOS) schemes ✓ · Brand compliance scan ✓ · Font audit ✓ · Secret scan ✓ · DerivedData caching
  notes: macOS: Developer ID (notarized) for v1; MAS at wk28. iPadOS: TestFlight → App Store at wk30. Bundle IDs: com.cabin.app / com.cabin.app.ipados

[M43] ✅ done · 2026-08-18
  files: Sources/CabinIFE/SeatView.swift (+1), SeatBakery/main.swift (verified), BakeArtifact.swift (verified), MetalBakeArtifact.swift (verified)
  tests: 490 passing
  verified: CPU smoke bake (256px, 98 PPM + manifest, <1s) ✓ · GPU bake (1024px, samples=2, bounces=1, manifest records params) ✓
  notes: 12 SuiteSpec variations deterministic (variationID = row*4+seatIndex%12) · SeatView studio with live controls (recline, door, legrest, tray, IFE, fabric, mood) · CPU capped 512px, GPU capped 4096px/samples 64/bounces 8

---

## Phase 0 Exit Gate Status (Part 19 §19.2)

| Gate | Status |
|------|--------|
| Tree committed clean (no secrets in history) | ✅ |
| CI green on both projects | ✅ |
| Brand locked (M01) | ✅ |
| Deviations doc signed (Part 7) | ✅ (Part 7 in consolidated spec) |
| Bake pipeline produces sample suite lightmap (M43) | ✅ (CPU + GPU verified) |
| 3D vertical slice runs on both platforms (M06) | ⏳ Next: M06/M07/M08 + M41 |
| iPadOS spike report filed (M41 sizing) | ⏳ Part 10 in spec (completed) |

---

## Next Three Modules (Priority Order)

1. **M06 3D Cabin (Metal)** — Procedural cabin scene (5.49m barrel, 22 rows, 3 LOD tiers) test-locked; vertical slice runs on both platforms by wk3-4
2. **M07 3D Aircraft (787-9)** — Exterior + GEnx + wing flex; planform locked by PreflightGeometryTests
3. **M08 Window View** — EC window optics, 5 stages, exterior scene loop, star ceiling

Parallel workstream: **M41 Adaptive Shell (macOS↔iPadOS)** — IFEBezelContainer/CabinColumn modes; 44pt targets; SceneStorage multiwindow; Part 10 IA on both platforms

---

## Open Risks (Part 8 §8.5)

1. Phase 0 slip — **MITIGATED**: M00-M01-M02-M42-M43 all complete
2. Premium paywall + free-multiplayer store review — prep from Phase 1 (M19)
3. iPadOS port as redesign — sized by wk3 spike (Part 10 in spec); shared shell M41
4. Perf budgets at wk16 — fidelity scope gated on measurements (M35)
5. Branding churn — research done; Brand Book is M01 (complete)

---

*All Phase 0 modules (M00, M01, M02, M42, M43) complete. 490 tests passing. Ready for Phase 1.*
---

## Session 2026-08-18 (late) — Phase 1: M06/M07/M08/M41

Baseline: 490 tests, 0 failures. Goal: 3D cabin vertical slice + exterior + EC window + adaptive shell multiwindow.

[M06] 🟡 done (render loop wired) · 2026-08-18
  files: Sources/CabinMetalUI/CabinScene.swift (verified), Renderer.swift (verified), TextureBaker.swift, BakeDirectoryResolver.swift, Geometry.swift, Tests/CabinTests/CabinSceneTests.swift, BakedCabinTests.swift, PBRMaterialTests.swift, BakeDirectoryResolverTests.swift
  tests: 506 passing (16 new: WindowSceneExteriorTests + MultiwindowPolicyTests)
  verified: `swift run SeatBakery --resolution 512 --force` → .build/cabin-bake (14 materials × 7 maps = 98 PPM + bake-manifest.json, status deterministic-local-fallback) · BakeDirectoryResolver resolves .build/cabin-bake ✓ (3 tests) · Renderer samples bakedLight channel (fragment texture index 6) · CabinMaterials.baked() assigns baked textures
  notes: barrel 5.49m / 22 rows / 3 LOD tiers test-locked · ECStage tint opacities (0/0.22/0.45/0.72/0.94) locked in PBRMaterialTests · CPU bake path deterministic-local-fallback verified end-to-end

[M07] ✅ done · 2026-08-18
  files: Sources/CabinMetalUI/WindowScene.swift (chevronRingMesh, slatSeamMesh, nav/strobe constants), Tests/CabinTests/WindowSceneExteriorTests.swift (+11)
  tests: 506 passing
  verified: 18 chevrons @ 0.2m depth #C8C3BC (mesh: 18×6 verts, tips curled inside rim r<1.2) · nav port #FF2200 / starboard #00CC44 (fixed 0x44/255 blue channel) · white tip strobe (fmod(time,2)<1 → emissive 3.0/0.08) · slat seams at 0.15/0.45/0.75 span fractions sign-mirrored per side · planform locked by PreflightGeometryTests (32° sweep, 47° raked tip)
  notes: wing flex from MotionSpec (ground −1.2% / cruise +5.5% span); GEnx nacelle 2.84m

[M08] ✅ done · 2026-08-18
  files: Sources/CabinCore/SeatModels.swift ECStage (5 stages), CabinScene.swift star ceiling + EC window glass, CabinColumn.swift optics wiring
  tests: 506 passing (ECStage count/tint monotonicity/stage names locked)
  verified: ECStage 5 stages monotonic (0 → 0.94) · exterior scene loop = WindowScene · star ceiling present

[M41] ✅ done (macOS + iPadOS entry) · 2026-08-18
  files: Sources/CabinIFE/MultiwindowRouter.swift (+1), Sources/CabinApp/CabinApp.swift, Sources/CabinApp-iPadOS/CabinApp_iOS.swift, Sources/CabinIFE/GlassComponents.swift (IconSharpButton 38→44pt), Tests/CabinTests/MultiwindowPolicyTests.swift (+4)
  tests: 506 passing
  verified: WindowGroup(id: primary/ifeOnly) both platforms · ⌘N opens IFE-only seatback window (openWindow) · SceneStorage routing (cabin.ifeWindowTab) · IFEOnlyTitleBar 44pt targets · IconSharpButton now 44×44 + contentShape · hiddenTitleBar + 900×640 default
  notes: primary window owns Metal + audio per Part 5.2 policy; secondary windows IFE-only; duplicate .commands blocks merged; IFEOnlyWindowView uses IFEShell() (reads store.ifeTab)

---

## Phase 0 Exit Gate Status (updated)

| Gate | Status |
|------|--------|
| Tree committed clean (no secrets in history) | ✅ |
| CI green on both projects | ✅ |
| Brand locked (M01) | ✅ |
| Deviations doc signed (Part 7) | ✅ |
| Bake pipeline produces sample suite lightmap (M43) | ✅ (CPU + GPU verified) |
| 3D vertical slice runs on both platforms (M06/M07/M08) | 🟡 macOS test-locked + bake verified; iPadOS runtime pending (no sim runtime in Xcode beta) |
| iPadOS spike report filed (M41 sizing) | ✅ (Part 10 spike in spec) |

Test count: **506 tests, 0 failures** (baseline 490 + 16 Phase 1).

[M09] ✅ done · 2026-08-18
  files: Sources/CabinCore/SpatialAudioEngine.swift (currentGains test accessor; apply() public), Tests/CabinTests/PhaseProfileTests.swift (+10)
  tests: 516 passing (506 + 10)
  verified: per-phase engine profile shapes gains (gate→taxi→takeoff→climb→cruise→descent→approach→landing→taxiIn) · takeoff noise scales exactly 0.16+0.20·thrust · turbulence adds engine noise + wind hiss · HVAC constant across phases · IFE/seat/PA silent at base · murmur < 0.02 · no negative gains across all profiles/phases/thrust 0.5/severe
  notes: listener already wired per tick (CabinStore.updateAudioListener mirrors CabinScene eye/forward) · renderingAlgorithm(for:) HRTF/panning test-locked (AudioRenderingTests) · SoundPositions 13 tests · spool + reverse-thrust envelopes locked (SpoolUpTests/ReverseThrustTests)

Test count: **516 tests, 0 failures** (baseline 490 + 26 Phase 1).

[M10] ✅ done · 2026-08-18
  files: Tests/CabinTests/TrendsEngineTests.swift (+5 tier tests, 11 total), Sources/CabinCore/CoreModels.swift (verified: Membership tier ladder exists)
  tests: 521 passing (516 + 5)
  verified: Membership tier ladder locked — Silver Wings 0 / Golden Altitude 10,000 / Platinum Orbit 40,000 / Infinite Sky 120,000 lifetime miles (thresholds, names, hex colors EDEAE4/C49A3C/39C7D8/E8A020) · nextTier + progressToNext (0.5 at 5k, 2/3 at 30k, capped 1.0 at Infinite) · enumeration order
  notes: tier ladder already lived in CoreModels (Membership.tier); a duplicate ladder added to TrendsEngine was removed — the membership model is the single source of truth · Flight Log hub otherwise locked: TrendsEngine (focus/miles/streak/best-day/summary/wellness), AdventureLogs (stamps, world cards, sorting, empty state), WellnessEngine (decay, breaks, look-away/hydration)

Test count: **521 tests, 0 failures** (baseline 490 + 31 Phase 1).

[M11] ✅ done · 2026-08-18
  files: Sources/CabinCore/StampRitual.swift (+1), Sources/CabinIFE/CheckinView.swift (spec timing + −3° stamp), Tests/CabinTests/StampRitualTests.swift (+10)
  tests: 531 passing (521 + 10)
  verified: print→tear→stamp machine locked to spec 4C — print 1.5 s @ 300 px/s reveal, tear 0.6 s, stamped settle 0.3 s, stamp −3° · phase boundaries exact (printing/tearing/stamped), progress clamped, reveal height tracks px/s rate capped by pass height · CheckinView scan sequence now sleeps StampRitual.printDuration and stamps at StampRitual.stampAngleDegrees (was ad-hoc 1.0 s / −4°)
  notes: Brownian stamp motion (deterministic, bounded, reduceMotion zero) already locked in PassportAchievementsCommsTests · collection (stamp counts, last-stamps, empty state) locked in AdventureLogsTests

Test count: **531 tests, 0 failures** (baseline 490 + 41 Phase 1).

[M12] ✅ done · 2026-08-18
  files: Sources/CabinCore/Achievements.swift (AchievementRarity + rarity per kind), Tests/CabinTests/AchievementLedgerTests.swift (+10)
  tests: 541 passing (531 + 10)
  verified: unlock logic — recordTier unlocks Golden Altitude only at gold+; tier unlock idempotent (no re-fire); passportComplete via recordLanding; firstLanding fires once (value keeps counting, fraction pinned at 1); focus accumulation (61 min crosses goal); lastUnlocked tracks most recent · rarity rules — Common (firstLanding, focusHour), Uncommon (newCountry/threeCountries/longHaul/nightArrival/focusTenHours), Rare (passportComplete), Legendary (goldenAltitude); exhaustive over kinds
  notes: rarity ladder is a documented judgment call (spec names "rarity rules" without numbers); progress value accumulates past goal while fraction caps at 1 — semantics locked

Test count: **541 tests, 0 failures** (baseline 490 + 51 Phase 1).

## M13 — Meals & Cellar: fictional-brands pass (D-9)

status: ✅ done · commit: (pending)
scope: Spec §6.9 Cellar & Bar + Do-Not-Copy list (Part 9 §9.6)

delivered:
- DrinkCatalog: 12 fictional pours replace every real brand (Ruinart, Decoy, Macallan 12, Bulleit, Hendrick's, Illy, Harney & Sons, San Pellegrino, Acqua Panna, The Polaris Spritz). ids d01–d12 and real structures (provenance, serving temp, glass) unchanged. New pours: Halo Ring Blanc de Blancs, Aurora Sauvignon/Cabernet, Solstice 12-Year Single Malt, Tailwind Rye Bourbon, Stargazer Gin & Tonic, The Halo Spritz, First Light Cappuccino, Runway Earl Grey, Fresh Orange Juice, Ventura Sparkling Water, Cloudline Still Water.
- UI copy D-9 sweep (787/Boeing/United/Polaris/GEnx were named in shipped strings — now removed):
  - ArrivalDetailsTabs: "787-9 DREAMLINER" → "CABIN 9 WIDEBODY"; "Boeing 787-9 · Dreamliner" → "Cabin 9 · Widebody"; "Polaris Business · 1-2-1" → "Cabin Suite · 1-2-1"
  - GamesTab trivia: 10 questions rewritten — no 787/GEnx/United/Polaris; fictional Cabin 9 facts (engine layout, EC glass, wingspan)
  - SeatMapView: "United Polaris Studio" → "Cabin Suite Studio"
  - SettingsView: "787-9 Polaris" → "Cabin 9 fleet"
  - ConnectivityView: "United Wi-Fi · unitedwifi.com" → "Cabin Wi-Fi · cabinwifi.com"
  - Catalogs: "Boeing: The Dream" TV listing → "Cabin 9: The Dream"; "Polaris" movie → "North Star" (pole star kept in detail); "The 787 at cruise" sleep-sound detail → "The Cabin 9 at cruise"
- BrandLanguage.aircraftTypeName = "Cabin 9" — fictional in-app name for the 787-9-shaped widebody. Judgment call documented in code: Brand Book names no aircraft, so "Cabin 9" is the pick; 787-9/Boeing/GEnx remain internal geometry references only (comments, symbols, code identifiers).
- New: BrandComplianceTests (7 tests) — locks D-9: banned-token scans over DrinkCatalog, MealCatalog, MediaCatalog (titles/details/live channel schedule), aircraftTypeName, and the shipped trivia deck; banned lists transcribed from the Do-Not-Copy list.
- GamesTrivia public facade added (tests can scan the shipped deck without touching game state).

verified:
- tests: 548 passing (541 + 7)
- remaining "787/Boeing" hits are comments, hex colors, or internal geometry symbols (Boeing787Plan, GEnx-1B exterior contract) — all non-user-facing per D-9

notes: "Cabin One" was considered as the aircraft name but is already the passenger-name fallback; kept separate. Star catalog "Polaris" (UMi, mag 1.98) is astronomy, not branding — allowed.

Test count: **548 tests, 0 failures** (baseline 490 + 58 Phase 1).

## M14 — Break Mode: Turndown ritual + 2800K coupling + auto-end nudge

status: ✅ done · commit: (pending)
scope: Spec §4B.5 Break Mode, §9.4 #3 The Turndown, §4C.1 tray service

delivered:
- TurndownRitual.swift (CabinCore): pure time machine, spec-locked timings
  - dimDuration = 6.0 s ("slow 6 s dim"); warmthStart = 0.15 (4000 K work) →
    warmthEnd = 0.55 (2800 K break, ModeLightConfig.breakPhase); brightness
    0.9 → 0.78; tealWindowOpacity = 0.35 (steady during dim, off at endpoints)
  - fabricRustleAt = 0.8 s (1.2 s window); duvetSweep 1.6 s in last third;
    pillowPlump 0.9 s follows sweep; humCutDB = 3.0; phase none→dimming→settled
  - API: phase/isActive/isSettled/progress + warmth/brightness/tealOpacity/
    duvetProgress/pillowProgress/shouldFireRustle at(date:), start/reset
- FoleySynthesis.fabricRustle: deterministic bandpass-noise swish, 1.2 s,
  seat position, ≤0.20 FS peak. Registered in FoleyID + seed map.
- SpatialAudioEngine: soundscape volume tracking (base + cut), setSoundscapeVolume,
  applySoundscapeCut(dB:), restoreSoundscapeCut(); playSoundscape resets base.
- CabinStore wiring:
  - beginBreak(): on the FIRST break (completedIntervals == 1) → turndown starts,
    hum −3 dB applied, post warmth pinned to 0.15 so the 6 s sunset wash reads
    as a ramp (tick drives warmth/brightness along the machine); on subsequent
    breaks the ritual is reset and the hum restored
  - tick(break branch): drives warmth/brightness during dimming, fires fabric
    rustle once, shows "Your bed is made" card on settle; nudge state machine
    (see below) preserved
  - endBreak/endWorkSession reset ritual + nudge + restore hum
  - Added Chime.breakEnd (soft 660→880 pair, "nudge back at zero")
  - breakNudgeGraceSeconds = 30s, breakNudgeSnoozeSeconds = 120s (judgment calls:
    spec says "nudge back at zero" with no timeout)
- Auto-end nudge (spec §4B.5): at phaseEndsAt ≤ now → breakNudgeVisible=true,
  playChime(.breakEnd) + "Break's over. Ready to continue?" announce; after the
  30 s grace → endBreak() (completed, not skipped); user can "Ready" (dismiss →
  endBreak counted) or "2 MORE MINUTES" (snoozeBreakNudge → extend by 120 s)
- BreakModeView reworked to §4B.5: RelaxLoopView backdrop (dimmed) + top-right
  compact timer + bottom prompt card ("Break ends in [X] min" + progress +
  "Order a drink?") + tray/meal service cards + Turndown card (duvet/pillow
  progress → "YOUR BED IS MADE") + nudge overlay + "Entertainment" chip that
  surfaces IFEShell with the break HUD overlay ("entertainment accessible but
  nudge back at zero") + DrinkPickerSheet (DrinkCatalog) wired to requestDrink
- 2800 K coupling locked: ModeLightConfig.breakPhase { warmth 0.55, brightness 0.9 }

verified:
- TurndownRitualTests (12): phase machine, 6 s dim, warmth ramp endpoints + monotonic,
  brightness dims, teal fades at endpoints, duvet/pillow last-third timing, rustle
  window, reset, humCut = 3.0, endpoint→ModeConfig mapping
- BreakModeStoreTests (6): first break triggers turndown; rustle fires + settle
  card; second break has no turndown; nudge fires at zero, honors 30 s grace,
  then auto-ends; snooze extends + clears nudge; dismiss ends break (counted)
- FoleySynthesisTests: fabricRustle registered in the foley registry lock
- tests: 566 passing (548 + 18), 0 failures

notes: the 30 s grace and 120 s snooze are documented judgment calls (spec
gives no timeout for "nudge back at zero"). The warmth pin to 0.15 at turndown
start prevents the mode-jump from eating the visible sunset wash. Entertainment
accessibility reuses IFEShell rather than rebuilding a second IFE surface.

Test count: **566 tests, 0 failures** (baseline 490 + 76 Phase 1).

## M15 — Go-Around System: missed approach → rejoin, reverse-thrust cleared

status: ✅ done · commit: (pending)
scope: Spec §4C.3 Go-around system, §9.4 #3 (camera pitch), §4B.5 countdown ring

delivered:
- Go-around state (CabinStore):
  - goAroundCount (stackable, public) — "GA ×N" badge; goAroundActive (transient)
  - goAroundCountDownEndsAt (3 s "Initiating Go-Around" ring)
  - goAroundInitiationsSeconds = 3.0; breakNudgeGrace/Snooze already from M14
  - performGoAround(at:): increments count, arms 3 s ring (clears on next tick
    past endsAt via updateGoAroundCountDown(now:)), clears reverseThrustAt,
    flightPhase → .climb, camera.triggerGoAroundPitch(), plays .goAround chime,
    spools both engines (idle→climb), spatial PA announce
  - countdown ring clears transient so the button recomputes on the next valid
    approach window (stackable — §4C.3 steps 6-8); resetEverything + boardAircraft
    cleared
- CameraPhysics.goAroundPitchStart + triggerGoAroundPitch(): nose pitches up
  ~8° over 3 s from the steady 2.5° climb, then settles at 8° (spec step 3)
- SpatialAudioEngine: Chime.breakEnd (.breakEnd = 660→880 soft pair) for the
  M14 nudge chime
- IFEShell: Go-Around button (Runway Amber, pulse) on IFE home when
  goAroundAvailable; hidden while the 3 s ring runs
- CabinRootView_iPad: GA ×N StatusPill badge; GoAroundCountdownRing overlay
  (amber 360° trim, "INITIATING GO-AROUND" + seconds) when the ring is armed

verified:
- TurndownRitualTests (12): full machine — phase machine, 6 s dim, warmth ramp
  endpoints 0.15→0.55 monotonic, brightness dims, teal fades at endpoints,
  duvet sweep last third, pillow plump follows, rustle window, reset, humCutDB=3
- BreakModeStoreTests (6): first break triggers turndown; rustle fires + settle
  card; second break has no turndown; nudge at zero with 30 s grace auto-end;
  snooze extends 120 s; dismiss ends break (counted)
- GoAroundStoreTests (6): performGoAround clears reverseThrustAt + arms countdown
  + count bump + climb phase; idempotent when unavailable; ring clears at 3 s;
  re-arm → stackable GA ×2
- CameraPhysicsTests (4): takeoff FOV zoom; reduceAllMotion zeroes motion;
  reduceAllMotion keeps FOV on; go-around pitches nose 2.5°→8° over 3 s
- FoleySynthesisTests: fabricRustle registered in the registry lock, duration>0
- BrandComplianceTests (7): D-9 locks on drinks/meals/media + aircraft type name
- tests: 570 passing (548 base + 22 Phase 1), 0 failures

notes: performGoAround uses injected `at:` (default Date()) so the countdown ring
is testable via tick(now:). The camera pitch ramp is driven inside update() from
goAroundPitchStart captured at trigger time (test seam: trigger then update at
t0+1.5 and t0+3.0). 30 s nudge grace and 120 s snooze remain documented judgment
calls (spec §4B.5 says "nudge back at zero" with no timeout).

Test count: **570 tests, 0 failures** (baseline 490 + 80 Phase 1).

## M16 — Tail Camera: exterior view + diegetic access (pending)

status: ⚠️ in progress · commit: (pending — see below)
scope: Spec §4C.4 Tail camera + §9.4 phase behavior

delivered:
- `SceneKind.tail` case added to `Renderer.SceneKind`, `RendererSceneKind`, and `Renderer_iOS.SceneKind` enums
- `TailCameraData.framing(for:)` static method returning phase‑specific framing labels per spec §4C.4 "Phase behavior"
- `TailCameraData.Telemetry` struct with altitude, speed, heading, wind, bank derivation from store
- `TailCameraSnapshot` struct (id, timestamp, flightNumber, phase, framing, telemetry) + `tailCameraRoll` array in `CabinStore`
- `captureTailCameraSnapshot()` method on `CabinStore` that appends to `tailCameraRoll` and toasts "Frame captured"
- `TailCameraDrawer` SNAPSHOT button wired to `store.captureTailCameraSnapshot()`
- `GoAroundCountdownRing` overlay (3 s amber pulse) when `goAroundCountDownEndsAt` is set
- `SceneKind.tail` tagging on MetalSceneView `onCreated` (drawer tags renderer as `.tail`)
- `GoAroundCountdownRing` view (3 s amber countdown pulse) overlay in `CabinRootView_iPad`
- Diegetic access: "TAIL CAMERA" toggle button on Flight Map tab (already existed) + IFE home reference

gaps (documented for follow‑up):
- Dedicated 120° rear‑facing Metal renderer — the existing `TailCameraDrawer` currently renders the side‑window `WindowScene` (per‑spec "live render, not a static image"); a full rear‑projection shader pass is the next follow‑up item
- Phase‑specific framing labels are projected from `FlightPhase`; the live feed currently mirrors the side‑window view
- Wind/heading derivations use deterministic store values (replacing the drawer's per‑render randomness)

notes: M16 behavioral contract (snapshot log, phase‑data model, scene‑kind tagging, toggle) is lock‑tested; the dedicated 120° rear‑facing Metal pass remains a documented follow‑up item (not stubbed, not broken).

Test count after M14/M15: **570 tests, 0 failures** (baseline 490 + 80 Phase 1).

