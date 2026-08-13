# M24 — Media + Audio Modules Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M4 source versions and hybrid retrieval, M6 encryption/deletion decision, M12 Command Center, M13 Projects/Tasks, M19 read-only local filesystem connector, and the existing embedding/runtime capability detector.
> **Scope:** a local-first media browser for user-selected roots, provenance-preserving transcript/subtitle ingestion, optional user-requested on-device transcription, timestamp-addressable search, accessible playback, and browser-first degraded behavior.

## 1. Goal

M24 lets a user select a local media folder or file, inspect its metadata, play it, attach an existing transcript or timed-text file, optionally request transcription of a local asset when the device and locale support it, and search the resulting text with exact source/time provenance. A result opens the asset at the matching timestamp and shows whether the text came from an imported transcript, a subtitle track, a user edit, or an on-device transcription run.

The product goal is a trustworthy local media memory surface—not a general streaming service, podcast downloader, recorder, or copyright circumvention tool. “Podcast transcripts → Sources” means an explicitly selected local transcript or a user-approved local media-processing result becomes a typed, inspectable Source/Artifact lineage. It never means that Hive silently fetches a podcast, records the microphone, or copies a remote provider’s catalog.

M24 reuses M19 for local-root identity and security-scoped access, M4 for immutable SourceVersion identity and admission-before-ranking retrieval, M6 for encryption/deletion limits, M12 for commands, and M13 for explicit project/task promotion. M24 must not create a second file-permission, provenance, or vector authority.

## 2. Non-goals and explicit deferrals

M24 does not ship microphone recording, all-day screen/audio capture, passive listening, automatic podcast downloading, remote media ingestion, DRM circumvention, ripping, stream capture, cloud transcription by default, a system-wide Music/TV library replacement, media publishing, sharing, automatic playlist mutation, or autonomous copyright/licensing decisions.

Deferred:

- network podcast discovery, RSS synchronization, and provider account linking;
- cloud media libraries and cross-device media sync;
- camera, microphone, meeting, or browser-tab recording;
- automatic indexing of the home directory, mounted volumes, or every browser download;
- speech recognition for every locale or media codec;
- speaker diarization, translation, sentiment, emotion, or medical/legal transcription claims;
- arbitrary archive/container extraction, macro execution, script execution, or active attachment handling;
- background transcription while the user is on battery, thermally constrained, locked, or running a latency-sensitive browser task;
- generated highlights or summaries that cannot resolve to retained transcript spans;
- any promise that a local transcript is accurate without confidence/availability and provenance state.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository has Honeycomb typed nodes/edges, Source/Claim provenance, EventLedger, M4’s planned immutable SourceVersion and hybrid retrieval contracts, M19’s planned selected-root/security-scoped bookmark lifecycle, a verified system embedding runtime seam, browser downloads/media-playing-tab state, local speech recognition for dictation, and accessible browser UI patterns. It does not have a verified end-to-end media library index, AVPlayer module, transcript/subtitle parser, asset-to-source lineage, media timestamp search, or audio-file transcription pipeline.

Existing speech dictation is not proof of file transcription. Existing tab media indicators are not proof of a media library. Existing embedding support is an inference capability, not a permission to create a second vector store or to label unavailable models as semantic search.

### 3.2 Authority table

| Concern | Authority | M24 rule |
|---|---|---|
| Media root/file permission | M19 selected-root connector and security-scoped bookmark | No implicit home-directory, download, or mounted-volume indexing. |
| Asset identity/version | M24 media identity adapter over M19 root identity + M4 SourceVersion | Renames and uncertain matches never silently merge assets. |
| Playback | AVFoundation adapter owned by the media surface | Playback state is ephemeral and never a source of durable memory by itself. |
| Transcript source | Imported-file parser, media timed-track adapter, or approved local transcription run | Every segment records method, version, time range, and confidence state. |
| Durable provenance | Honeycomb Source/Artifact and M4 SourceVersion | No media-specific shadow graph or citation store. |
| Lexical/semantic retrieval | M4 FTS/vector generation authority | Embeddings are versioned, rebuildable, admission-filtered, and optional. |
| Transcription capability | OS/device/locale detector + explicit user request | Unavailable means unavailable; no fake completion or silent cloud fallback. |
| Privacy and retention | M1/M4/M6 admission, retention, deletion, and encryption contracts | Raw media is never copied merely to make search work. |
| Task/project promotion | M13 | Transcript suggestions remain proposals until explicit promotion. |
| User commands | M12 Command Center | Media commands are typed, local, and availability-aware. |
| Evidence | EventLedger | Store minimal asset/source IDs and result classes; never raw audio or transcript bodies by default. |
| Browser continuity | Main Hive browser | Index, playback, parser, or model failure never blocks ordinary browsing. |

## 4. Media root and asset identity

### 4.1 Root selection

A user selects a file or folder through an explicit system picker. M24 stores a reference to the M19 security-scoped root/bookmark and the minimum disclosed scope:

```text
media_root_id: stable UUID
connector_root_id: M19 identity
bookmark_reference_id: opaque access reference
canonical_root_identity: redacted filesystem identity
allowed_extensions / content-types
max_file_size / max_asset_count / max_scan_depth
watch_policy: manual | explicitly_enabled_bounded
status: proposed | awaiting_access | active | stale | paused | revoked | deleted
created_at / updated_at / last_scan_at / stale_reason
```

On each scan, the adapter resolves the bookmark, verifies that the resolved location is still the approved root, starts scoped access, performs bounded read-only enumeration, and stops access in a guaranteed cleanup path. A stale, moved, revoked, or changed root pauses the module and asks the user to reauthorize. Hive never searches for a nearby replacement folder.

Default discovery is manual. A user may explicitly enable a bounded watch or refresh cadence, but M24 never becomes an ambient file surveillance service. Private app data, browser profiles, credential stores, `.ssh`, Keychain exports, hidden system data, and user-defined deny paths are excluded by default.

### 4.2 Asset identity

An indexed asset has a stable local identity that is namespaced by root:

```text
media_asset_id: stable local UUID
media_root_id
relative_path: user-visible only inside approved scope
relative_path_identity_hash
resource_identifier: optional filesystem identity
content_hash: required after bounded read
file_size / modification_date
content_type / container_kind / codec_summary
identity_state: new | unchanged | changed | moved_candidate | deleted | inaccessible
source_version_id: optional M4 SourceVersion
```

The identity policy is deterministic:

1. Within the same root, a matching stable filesystem resource identifier plus content hash may preserve identity.
2. A matching content hash at a different path is a move candidate, not an automatic rename, unless the user-selected root policy explicitly permits deterministic moves.
3. A changed hash creates a new asset version; it does not overwrite the prior source version.
4. Ambiguous matches become delete-plus-new with an inspectable warning.
5. Identical relative paths in different roots never collide.

M24 records bounded metadata and hashes before any optional transcript work. It does not copy the original media into an application cache by default.

### 4.3 Supported media contract

The first implementation declares an allow-list of supported content types and a maximum asset size/duration. Unsupported, malformed, encrypted, DRM-protected, or resource-exhausted assets remain visible as typed unavailable entries with a recovery action. “Indexed” means metadata is available; it does not imply playable, transcribable, or searchable.

## 5. Metadata and playback

### 5.1 Normalized metadata

AVFoundation metadata is normalized into a bounded display record:

```text
asset_id / source_version_id
canonical_title / creator / album_or_series
artwork_reference: local bounded cache or unavailable
creation_date: optional with timezone/precision state
duration: exact | approximate | unavailable
chapters: bounded typed markers
container / codec / sample_rate / channel_count: optional diagnostic fields
playability: playable | preparing | unsupported | protected | failed
metadata_state: complete | partial | stale | unavailable
```

Metadata extraction is asynchronous and cancellable. Format-specific metadata is not treated as authoritative if it conflicts with the file identity or user edit. User edits are separate local metadata revisions and never rewrite the original file without a future explicit write contract.

### 5.2 Playback state machine

```text
unloaded → preparing → ready
ready → playing | paused | seeking | ended | failed
playing → interrupted | paused | seeking | ended | failed
any non-terminal state → cancelled
```

The playback adapter owns one bounded player session per visible media surface. It observes readiness, buffering, interruption, duration, seeking, and failure. A failed seek or unavailable asset produces an honest receipt and leaves the browser usable. Playback never requires an AI model, network, or transcript.

Search results and transcript rows may request a seek only after the target asset is revalidated. A stale or deleted asset cannot be used as an implicit file access grant. Seeking uses an explicit tolerance policy: exact timestamp when practical, bounded nearest position when precision is unavailable, with the resulting precision state disclosed.

### 5.3 Media UI and browser-first behavior

The media surface is progressively disclosed from an explicit file, folder, project, or Command Center action. It must provide empty, indexing, unsupported, permission-denied, stale, offline, partially indexed, and deleted states. Ordinary browsing, tabs, downloads, and memory remain useful when the media module is disabled or unavailable.

## 6. Transcript and timed-text sources

### 6.1 Source kinds

Every transcript segment belongs to exactly one source method:

```text
imported_text: user-selected .txt/.md/JSON or supported transcript export
webvtt: user-selected WebVTT timed-text file or approved local track
srt: user-selected SubRip timed-text file
embedded_track: readable timed metadata/caption track from the selected asset
on_device_transcription: explicit local processing of the selected asset
user_edit: correction linked to a prior segment/version
```

The parser records `method`, parser/transcriber identifier and version, locale, imported_at, source file/asset identity, content hash, timing precision, and confidence state. An imported or generated transcript is never presented as the media creator’s verified words merely because it has timestamps.

### 6.2 Timed segment model

```text
transcript_id: stable UUID
asset_id / source_version_id
segment_id: stable UUID
start_time / end_time: explicit media timebase
text: bounded normalized text
raw_text_hash / normalized_text_hash
speaker_label: optional, unverified unless source-provided
confidence: source_declared | high | medium | low | unavailable
source_method / extractor_version / locale
revision_state: original | user_edited | superseded | deleted
```

Segments must satisfy `0 <= start < end <= duration` when duration is known. Unknown duration or malformed timing remains a warning; the parser must not silently clamp a segment and call it exact. Overlap, duplicate, empty, and out-of-order cues are normalized deterministically and retain a diagnostic.

### 6.3 WebVTT/SRT parsing

The first parser supports a documented subset of UTF-8 WebVTT and SRT. It is streaming and bounded by bytes, cue count, text length, nesting/style handling, and wall-clock budget. Parser behavior is deterministic:

- malformed headers, timestamps, cue numbering, or settings produce a typed warning;
- unsupported styling is stripped or preserved as inert metadata, never executed;
- HTML/script-like payload is rendered as text after sanitization;
- duplicate cue identity is resolved by stable input order plus content hash;
- a parser-version change produces a new transcript revision rather than mutating the old one;
- an imported transcript with no timing remains searchable but cannot promise timestamp seeking.

A transcript file is a source artifact. It is not automatically copied into a remote model request, exported, or promoted to a durable Claim.

### 6.4 Embedded tracks and transcript precedence

When multiple transcript sources exist, M24 displays them as separate revisions or alternatives. It does not silently pick a “best” transcript based on a model score. Default display precedence is user-selected source, then explicitly imported timed text, then embedded track, then on-device transcription; the user can switch and compare. A user edit supersedes only the selected segment revision and keeps the prior text inspectable according to retention policy.

## 7. Optional on-device transcription

### 7.1 Explicit request and capability state

Transcription of a local asset starts only from an explicit user action or an explicitly enabled project workflow. The UI previews asset, duration, locale, processing destination, expected resource cost, retention, and whether the result will be searchable. No microphone permission is inferred or requested for processing an existing file; recording is not part of M24.

Before processing, the capability detector checks OS/API availability, locale, asset format, duration limits, device resource state, user power policy, and whether the selected transcription path is actually on-device. It returns:

```text
available_local
available_local_limited
unsupported_locale
unsupported_format
resource_budget_exceeded
permission_denied
temporarily_unavailable
not_implemented
```

`not_implemented`, `temporarily_unavailable`, or a missing local model never falls through to a remote provider without a separate explicit remote-model contract and consent. The result labels the actual engine and `is_on_device` truthfully.

### 7.2 Processing contract

Processing is chunked, cancellable, and bounded. It preserves the last committed transcript checkpoint and reports partial results as partial, never as complete. It yields to locked, sleeping, thermal, battery, or user-paused states according to M18/M21 policy when those policies are available; lack of a signal is not permission to run indefinitely.

```text
transcription_job_id
asset_id / input_hash / locale / engine_id / engine_revision
phase: proposed | admitted | preparing | processing | checkpointing | paused | cancelled | complete | failed
segment_count / processed_duration / total_duration
last_checkpoint / error_class / resource_state
is_on_device / network_used: false or explicit contract state
output_transcript_id / output_content_hash
```

A crash or cancellation resumes only from a validated input hash and checkpoint. A changed asset invalidates the job. Reprocessing with a different engine or locale creates a separate transcript revision.

### 7.3 Accuracy and uncertainty

M24 does not claim word-level accuracy from engine availability. The UI distinguishes source-provided, machine-generated, user-edited, low-confidence, and unavailable text. Search may return a low-confidence segment, but the result must disclose its confidence and link to the exact time span. A summary or task proposal may not omit uncertainty or cite a deleted/superseded segment as current.

## 8. Source provenance and retrieval

### 8.1 Honeycomb representation

Use existing Source/Artifact/SourceVersion authority:

```text
MediaAsset Source
  ├─ has_version → MediaAsset SourceVersion
  ├─ has_artifact → Transcript/TimedText Artifact
  ├─ supports → Transcript Segment evidence spans
  └─ belongs_to → Project only after explicit user choice
```

The exact relation names must reuse existing typed graph semantics or be introduced through a separate reviewed schema change; M24 must not add freeform edges. Each searchable segment carries `asset_id`, `transcript_id`, `segment_id`, `source_version_id`, start/end times, text hash, and method/revision metadata.

A transcript hit is a source-backed result, not a free-floating embedding. It opens the media item, positions the player at the segment, and exposes the underlying transcript source/version. If the source was deleted, revoked, or physically unavailable, retrieval excludes it immediately or returns an explicit unavailable state according to M4 policy.

### 8.2 Search pipeline

M24 uses the M4 order:

```text
query + explicit media/project scope
  → privacy/admission/deletion checks
  → FTS5 transcript/metadata candidates
  → compatible vector generation when available
  → M4 RRF fusion and temporal/revision filtering
  → deterministic ordering and token cap
  → source/time/provenance result
```

Exact names, episode identifiers, timestamps, and rare terms must retain lexical recall. Semantic search is optional and labeled with model ID, dimension, generation, and availability. If the embedder is unavailable, M24 uses an honest lexical-only path. No vector is fabricated and no model label is inferred from a mock result.

Chunking is deterministic and time-aware. A chunk may contain bounded overlapping segments, but every chunk links back to its exact constituent segment IDs and time interval. Chunk text is normalized once; a normalization or embedding revision creates a new derived generation.

### 8.3 Projects, Claims, Briefs, and Tasks

A user may explicitly promote a transcript segment or search result into a Project, Claim, Brief, or Task through M13/M4 provenance rules. A generated summary remains a proposal until the relevant approval path. Media content cannot silently create tasks, promises, reminders, or durable preferences. A task created from a segment retains asset, transcript revision, time range, and source deletion behavior.

## 9. Privacy, copyright, retention, and deletion

### 9.1 Data minimization

M24 stores metadata, hashes, transcript text, indexes, and bounded artwork/cache references only as the selected retention policy permits. It does not duplicate large media files merely to index them. Raw audio buffers used for local processing are released after the bounded job window and are not placed in EventLedger, prompts, diagnostics, or crash reports.

Remote processing is not part of the default contract. If a future remote provider is considered, it requires a separate capability, explicit provider/model/data-scope/retention disclosure, redaction policy, consent, audit record, and deletion limitation statement. “Local-first” must never be used to hide a remote fallback.

### 9.2 Copyright and user control

M24 operates on media and transcript files the user selected or is authorized to access. It does not bypass DRM, defeat access controls, scrape a provider, redistribute copyrighted transcripts, or make licensing judgments. Search snippets are bounded, source-linked, and subject to the user’s local retention/export policy.

The UI must disclose whether a transcript is user-provided, embedded, generated, or edited. It must provide inspect, export, delete, and forget controls without implying that deletion from Hive erases copies outside Hive or OS-level forensic remnants.

### 9.3 Deletion cascade

Deleting or forgetting a media scope must perform a resumable, generation-aware cascade:

1. stop active playback and invalidate pending seeks;
2. cancel or quarantine transcription jobs for the asset;
3. release security-scoped access and remove bookmark/reference material when the root is disconnected;
4. remove media metadata, transcript revisions, segment rows, FTS entries, vector entries, chunk manifests, artwork/cache files, and derived diff/brief/task links according to M4/M6 policy;
5. exclude deleted source IDs from retrieval immediately, even while physical cleanup is pending;
6. retain only minimal redacted ledger evidence and an honest deletion report.

User-authored tasks/briefs may remain only if the user chooses retention and the deleted media body/transcript is not retained inside them. Provenance-degraded state is visible. A purge is not complete until every participating store reports its generation and pending work.

## 10. Accessibility and interaction contract

The media surface is complete only when keyboard navigation, VoiceOver, Dynamic Type, Increase Contrast, Reduce Motion, and reduced transparency work across empty, indexing, playback, transcript, stale, denied, unsupported, error, and deletion states.

Requirements:

- playback exposes play/pause, seek, rate, volume/mute, current time, duration, and failure state with stable labels and keyboard commands;
- transcript rows expose timestamp, text, source method, confidence, speaker label when present, and current-playback state;
- activating a transcript row seeks playback when the asset is available and announces an unavailable/recovery state otherwise;
- the current segment highlight is not color-only and does not rely on animation;
- captions respect system caption preferences where a custom renderer is used;
- large text, long titles, localized times, long transcripts, and missing artwork do not hide scope/delete/recovery controls;
- imported/generated/user-edited states are announced and visually distinct;
- private/redacted text is not exposed through VoiceOver, copy, previews, exports, or logs;
- progress, pause, cancel, and partial-result state are exposed without requiring a hover or waveform;
- reduced-motion mode removes scrolling/highlight animation while preserving position and focus;
- media failure never removes ordinary browser keyboard paths.

## 11. Work packages

### M24-A — Media root, asset identity, and bounded index

Reuse M19’s selected-root/bookmark authority. Define media-root scope, allow/deny content types, stable asset/version identity, hash/rename/delete policy, bounded scans, metadata extraction, cancellation, stale access, and EventLedger receipts.

**Done when:** two roots cannot collide, symlink/path escapes are rejected, unsupported assets remain inspectable with honest status, a changed file creates a new version, and no background scan starts without explicit policy.

### M24-B — Playback and accessible media surface

Implement the typed AVFoundation adapter, asynchronous metadata/playability states, bounded player lifecycle, interruption/buffering/seek behavior, empty/error/unsupported states, and keyboard/VoiceOver media controls.

**Done when:** a selected local asset plays or reports an honest failure, transcript-independent browser use remains complete, and a stale/deleted asset cannot become a file-access authority through playback.

### M24-C — Transcript/subtitle ingestion and provenance

Implement bounded UTF-8 text/WebVTT/SRT ingestion, embedded-track inspection, deterministic cue normalization, transcript revisions, source/artifact lineage, user edits, confidence/method labels, and timestamp validation.

**Done when:** imported timed text is searchable and seekable with exact provenance, malformed cues are warned about rather than silently repaired, untimed text stays searchable without a false timestamp claim, and source deletion excludes all derived retrieval.

### M24-D — Optional on-device transcription and hybrid retrieval

Add explicit transcription proposals, capability/locale/format/resource checks, chunked cancellable local processing, checkpoint/restart behavior, honest engine/on-device labels, M4 FTS/vector/RRF integration, lexical-only fallback, and deterministic timestamp-linked results.

**Done when:** a supported local asset can produce a clearly labeled partial/complete transcript or a truthful unavailable state; no implicit network fallback occurs; search results resolve to segment/source/time IDs; vectors are versioned and rebuildable through M4.

### M24-E — Privacy, retention, accessibility, and browser-first validation

Validate selected scope, private/deny paths, prompt-injection text in transcripts, copyright boundary copy, deletion/forget cascade, offline behavior, thermal/battery/lock yielding, VoiceOver/keyboard/large text, crash/cancel/replay, and ordinary browsing with M24 disabled.

**Done when:** one local asset and one transcript path work read-only end to end, all derived rows can be deleted or honestly reported pending, no raw media enters logs/prompts, no unauthorized recording/network path exists, and the browser remains fully usable without M24.

## 12. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M24-01 | First launch | No media root or recording permission prompt |
| M24-02 | User selects one file | One scoped asset; no parent-folder expansion |
| M24-03 | User selects a folder | Bounded scan only within selected root |
| M24-04 | Root bookmark valid | Access starts/stops in balanced lifecycle |
| M24-05 | Root bookmark stale | Paused state and reauthorization; no guessed path |
| M24-06 | Symlink escapes root | Entry rejected and counted |
| M24-07 | Credential/browser-profile deny path | Skipped without raw path leakage |
| M24-08 | File count/size/depth limit | Bounded partial report; browser unaffected |
| M24-09 | Same asset rescanned | No duplicate SourceVersion or segment rows |
| M24-10 | Same content moved | Move candidate or deterministic move per policy; no silent merge |
| M24-11 | Same path changed hash | New asset/source version; prior version retained |
| M24-12 | Ambiguous rename | Delete-plus-new with warning |
| M24-13 | Unsupported codec/container | Metadata-only unavailable state; no fake playback |
| M24-14 | Malformed media metadata | Partial metadata and diagnostic |
| M24-15 | Asset deleted on disk | Tombstone and immediate retrieval exclusion |
| M24-16 | Asset contains prompt-injection text in metadata | Data only; no command or permission effect |
| M24-17 | Playable local asset | Async prepare → play/pause/ended states |
| M24-18 | Buffer/interruption | Honest paused/interrupted state and recovery |
| M24-19 | Seek to valid timestamp | Player opens at bounded requested position |
| M24-20 | Seek after asset deletion | Rejected; no implicit reauthorization |
| M24-21 | User-selected WebVTT | Timed segments preserve source file/version |
| M24-22 | User-selected SRT | Timed segments normalize deterministically |
| M24-23 | Untimed TXT/Markdown | Searchable text; timestamp seeking unavailable |
| M24-24 | Embedded timed track | Separate source method/revision; no silent overwrite |
| M24-25 | Malformed timestamp | Warning/unresolved timing; no silent clamp-as-exact |
| M24-26 | Overlapping/out-of-order cues | Deterministic ordering plus diagnostic |
| M24-27 | HTML/script-like cue payload | Sanitized inert text; never executed |
| M24-28 | Duplicate cue IDs | Stable input-order/content-hash resolution |
| M24-29 | Transcript parser version changes | New revision; prior revision remains inspectable |
| M24-30 | User edits one segment | User revision supersedes selected segment only |
| M24-31 | Low-confidence segment | Search result labels confidence and exact time |
| M24-32 | Multiple transcript sources | Explicit alternatives/precedence; no model-picked winner |
| M24-33 | Transcription not implemented | Honest unavailable state; no remote fallback |
| M24-34 | Unsupported locale | Capability error and recovery guidance |
| M24-35 | Resource budget exceeded | Refuse/pause with cost explanation |
| M24-36 | Local transcription request | Explicit preview before processing |
| M24-37 | Transcription cancellation | Partial checkpoint; result labeled partial |
| M24-38 | Crash during transcription | Resume/replay by input hash; no duplicate completion |
| M24-39 | Asset changes during job | Job invalidated; old output not attached to new asset |
| M24-40 | Thermal/battery/lock pause | Processing yields and resumes or reports paused |
| M24-41 | Exact identifier query | Lexical recall retained |
| M24-42 | Conceptual query with vectors | RRF result cites segment/source/time and model generation |
| M24-43 | Embedder unavailable | Lexical-only result with honest label |
| M24-44 | Deleted transcript search | Immediate exclusion; cleanup state visible |
| M24-45 | Segment promoted to task/brief | Explicit M13/M4 promotion with asset/time lineage |
| M24-46 | Transcript asks to run a command | Inert untrusted content |
| M24-47 | Forget media scope | Playback/jobs/indexes/vectors/cache cascade starts resumably |
| M24-48 | M24 disabled or unavailable | Ordinary browser, tabs, downloads, memory, and projects remain usable |

## 13. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M24-A | Root/asset scope authority | Selected-root, bookmark, containment, identity, and deny-path tests |
| M24-B | Metadata/playback truth | Async AVFoundation state, interruption/seek, unsupported/error evidence |
| M24-C | Transcript parser safety | WebVTT/SRT/text bounds, malformed cues, sanitization, revision tests |
| M24-D | Provenance/timestamp citations | Asset/source/version/segment/time links resolve or show unavailable |
| M24-E | Transcription honesty | Capability/locale/resource checks, explicit consent, actual engine/on-device labels |
| M24-F | Checkpoint/cancellation | Partial results, crash replay, input-hash invalidation, no duplicate completion |
| M24-G | Hybrid retrieval | FTS/vector/RRF generation, exact-token recall, lexical fallback, deterministic ordering |
| M24-H | Prompt-injection isolation | Metadata/transcript/attachment text cannot alter tools, scope, or authority |
| M24-I | Privacy/copyright boundary | No recording, DRM circumvention, hidden network, raw audio/log leakage, or redistribution path |
| M24-J | Revocation/deletion | Root disconnect and media forget remove/exclude metadata, transcript, indexes, vectors, caches, jobs |
| M24-K | Accessibility/browser-first | Keyboard, VoiceOver, caption preferences, large text, reduced motion, and disabled-module browsing |
| M24-L | Truthful planning status | No verified media/transcription claim without current fixtures and runtime evidence |

## 14. Implementation order and handoff

Implement M24-A before playback or transcription indexing. Implement M24-B independently so media playback remains useful with no transcript or model. Implement M24-C before embeddings or generated transcription so every searchable result has a source and time contract. Implement M24-D only after M4 admission/deletion and the local capability detector are evidenced. Implement M24-E against clean-profile and adversarial fixtures before any background scan or recurring processing is enabled.

The next smallest safe implementation slice is **M24-A: typed media-root/asset identity records, selected-root lifecycle adapters, bounded scan fixtures, and SourceVersion linkage**, with no media copying, no microphone recording, no provider credentials, no network ingestion, and no model training. M24 remains a planning contract until those runtime tests and a clean browser path exist.
