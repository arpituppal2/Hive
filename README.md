# Hive

Hive is a local-first AI Wiki compiler for macOS. It is not a RAG app that rediscovers raw chunks on every question. Field sources remain immutable evidence; Hive incrementally compiles them into an AI-maintained Colony, keeps that Colony consistent, and exposes the shape of the compiled knowledge through The Hive graph.

There are four product layers:

- Field: the junk drawer of immutable evidence such as files, notes, browser captures, images, transcripts, bookmarks, highlights, research, and screenshots. Hive reads and mirrors it but does not clean it up in place.
- The Colony: the persistent, compounding markdown artifact. Hive maintains article pages, cross-links, contradictions, open questions, and synthesis.
- Schema: `Vault/AGENTS.md`, the local maintainer contract that tells Hive how to ingest, answer, consolidate, query, download attachments, and repair knowledge.
- Hive: the graph view of the compiled Colony, showing hubs, clusters, selected paths, and orphans.

This repository currently contains the first production slice: a SwiftUI app with four primary views, a durable SQLite-backed core, ingestion/extraction, a Hive-maintained markdown vault, provenance-aware Wiki generation, a graph engine, Swarm chat over stored claims and approved sources, retention/delete controls, URL/browser safety policy, runtime throttling, and a background daemon entrypoint.

## Run

```bash
swift run HiveApp
```

## Build Hive.app

```bash
chmod +x scripts/build_app.sh
scripts/build_app.sh release
open ~/Applications/Hive.app
```

## Background Worker

```bash
swift run HiveDaemon --manual
swift run HiveDaemon
```

`HiveDaemon` runs one idle-aware maintenance cycle: purge expired unpinned Field source copies, process queued extraction jobs, rebuild The Colony, and refresh graph relationships. `launchd/com.hive.daemon.plist.template` is the 12:00 AM local-time LaunchAgent template; replace the executable and log placeholders with absolute paths during packaging.

Bundled helper path:

```text
~/Applications/Hive.app/Contents/Library/Helpers/HiveDaemon
```

After building `Hive.app`, install or remove the user LaunchAgent with:

```bash
scripts/install_launch_agent.sh
scripts/uninstall_launch_agent.sh
```

The installer validates the generated plist, points launchd at the bundled `HiveDaemon`, runs at 12:00 AM local time, and writes logs to `~/Library/Logs/Hive/`. It is not run automatically by the build script.

## Sign-in build

Hive requires provider sign-in before opening the app workspace. `scripts/build_app.sh` refuses to package a usable app unless you provide the real Apple Developer App ID, team, and signing identity that own the Sign in with Apple entitlement:

```bash
HIVE_BUNDLE_IDENTIFIER="com.example.hive" \
HIVE_DEVELOPMENT_TEAM="TEAMID" \
HIVE_CODESIGN_IDENTITY="Apple Development: Name (TEAMID)" \
scripts/build_app.sh release
```

The Apple Developer App ID for `HIVE_BUNDLE_IDENTIFIER` must have Sign in with Apple enabled, and the signing identity must belong to `HIVE_DEVELOPMENT_TEAM`.
See [docs/sign-in-with-apple.md](docs/sign-in-with-apple.md) for setup and verification.

Google sign-in is optional but supported in the same login gate. To include it in a packaged app, provide both Google OAuth values when building:

```bash
HIVE_GOOGLE_CLIENT_ID="your-google-client-id.apps.googleusercontent.com" \
HIVE_GOOGLE_REVERSED_CLIENT_ID="com.googleusercontent.apps.your-reversed-client-id" \
scripts/build_app.sh release
```

Verify the installed app also has the Google OAuth client ID and callback URL scheme:

```bash
scripts/google_signin_preflight.sh
```

On the first successful sign-in with either provider on a device, Hive asks whether to use cloud data, keep the current local workspace, or let Swarm prepare a reviewed merge of both.

Verify the installed app is actually capable of native Apple login:

```bash
scripts/apple_signin_preflight.sh
```

For UI-only local development, an ad-hoc package can still be created with `HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1`. Provider sign-in is unavailable in that build, and the temporary `Continue as Guest` gate is enabled only for local testing.

## Test

```bash
swift test
```

Full local acceptance:

```bash
scripts/acceptance.sh
```

This runs tests, builds and verifies `~/Applications/Hive.app`, validates the launch-agent scripts, and runs the bundled daemon once. It does not install the LaunchAgent.

## Current Product Surface

- `Field`: drag/drop and import panel, per-entry browser history rows, quick notes, current-page screenshot capture from the menu bar, screenshots, dropped text/images, source timeline, extraction state, 14-day retention, pin, raw delete with extracted-text scrubbing, full forget with local tombstone compaction.
- `The Colony`: compounding markdown wiki surface backed by SQLite and mirrored to `Vault/Colony/`, article index rail, Dataview-style `hive-query` blocks over page frontmatter, content-oriented `index.md` with per-page metadata, chronological grep-friendly `log.md`, qmd-compatible local wiki search with deterministic fallback, bookkeeping plans for summaries/cross-links/conflicts/index/log upkeep, topic/project/question/synthesis/health/answer pages, chat answer filing back into durable answer pages, stricter lint for contradictions/stale claims/orphans/missing cross-links/missing concept pages/research gaps, compact Needs Confirmation queue only for understood claim/wiki content below 70% effective certainty, article consolidation, local attachment download into `Vault/flower-field/assets/`, inline confirm/matters/incidental triage, explicit claim row selection, confidence labels, source trail, evidence spans, correction drafts, approve/deny/incidental/matters/ask-later/delete controls, and authoritative user corrections made through Hive.
- `Hive`: SwiftUI Canvas graph, default personal-evidence filter that hides internal algorithm/path edges and weak auto topics, claim/topic/project/user-memory nodes, canonical claim/entity merging, topic-web expansion, saved topic-web create/delete controls, strength edges, path following, one-hop search context, visible-node budgets, fast large-graph layout, collision-aware labels, time-window scrubber, durable-first graph privacy filter, accessible list/VoiceOver representation, explain panel with feedback/delete controls, reduced-motion static rendering, and low-cost tension motion.
- `Swarm`: AI conversation surface with persisted chat history, new/open/delete chat controls, `@` imports for Field, Colony, and Hive context, plugin toggles, approved URL capture, Field review, Hive re-indexing, answer filing, and the same local-first Ask routing used elsewhere in Hive.
- Secondary surfaces: menu bar controls with manual maintenance, `Command-1/2/3/4` primary-view shortcuts, deterministic `Command-K` command/search overlay, Settings, local export, browser-history consent/forget controls, background-worker status, recent audit log, and local cited chat sheet.

## Local Data

The default workspace is:

```text
~/Library/Application Support/Hive
```

Important local stores:

- `Hive.sqlite`: metadata, claims, relationships, wiki pages, audit log, and FTS.
- `Raw/`: internal content-addressed source blobs.
- `Vault/`: readable Hive-maintained vault with `AGENTS.md`, `flower-field/`, `Colony/index.md`, `Colony/log.md`, and generated markdown pages. SQLite stays canonical; the vault is durable, inspectable, and exportable.
- `Vault/flower-field/`: immutable junk drawer for raw files, articles, notes, screenshots, transcripts, bookmarks, research, and imported material. Do not organize it by hand; Hive compiles from it.
- `Vault/flower-field/assets/`: fixed local attachment directory for downloaded article images and current-page screenshot captures.
- `Artifacts/`: reserved for processed artifacts.
- `Snapshots/`: transient safe browser/database snapshots, deleted after sanitized extraction.
- `Models/`: local model packs. Hive detects compatible dropped-in model files/folders for status and selection without downloading or launching models.

## Architecture

The implementation is split into:

- `HiveCore`: persistence, ingestion, extraction, wiki, graph, runtime policy, safety, assistant, and control-plane logic.
- `HiveApp`: SwiftUI macOS app.
- `HiveDaemon`: one-shot or looped background worker.

The first slice deliberately avoids fake model output. Media/OCR/transcription/model-dependent work is represented as queued local capability and review state until a local model pack is installed. Hive does not require Obsidian, Claude, or a terminal agent at runtime; those references inform the product pattern, not the shipped dependency model.
