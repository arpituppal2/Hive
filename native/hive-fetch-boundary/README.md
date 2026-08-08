# Hive Fetch Boundary

A small, cross-platform Rust boundary for Hive's research transport.

## What it does

- Resolves hosts with the platform resolver from a blocking worker.
- Rejects private, loopback, link-local, unique-local, CGNAT, multicast,
  reserved, tunnel, and documentation addresses.
- Fails closed when a resolver response contains any unsafe address.
- Deduplicates approved `SocketAddr` values and requires endpoint ports to
  match the requested target port.
- Connects only to approved socket addresses; connection does not perform a
  second DNS lookup.
- Preserves the original hostname separately for HTTP authority and TLS SNI.
- Fetches HTTP/1.1 over a pinned TCP connection, or HTTPS over rustls with the
  original hostname used for certificate verification and SNI.
- Uses manual redirect handling with a configurable redirect limit and blocks
  HTTPS-to-HTTP downgrade redirects.
- Sends no cookies and does not maintain a cookie jar.
- Rejects request-header control characters, unsupported schemes, credentials
  in URLs, ambiguous response framing, malformed chunk trailers, and bodies
  larger than the configured limit.
- Enforces one deadline across connection setup, TCP reads/writes, the rustls
  handshake path, and response-body parsing after DNS resolution. DNS resolution
  itself is synchronous, is not interruptible by this deadline, and must run
  off the UI/async executor.

## Deliberate boundary

This crate does **not** yet provide HTML extraction, source/claim persistence,
an IPC/FFI bridge into HiveChromium, or a browser network interception layer.
The `research_client` module provides an in-memory, source-shaped fetch record
with requested/final URL, HTTP metadata, redirect count, retrieval time, and a
SHA-256 body hash; it does not persist that record or invent titles, claims, or
citations. It also intentionally rejects interim `1xx` responses rather than
attempting to consume and combine them with a final response.

The `handoff` module wraps that record in a versioned, bounded JSON envelope.
It preserves requested/final URLs, redirect provenance, exact decimal-string
retrieval time, content hash, body bytes, capture provenance, extraction state,
and citation readiness. It accepts additive unknown fields and legacy v1
numeric timestamps/missing provenance, but validates URL/body limits and
recomputes the SHA-256 before a caller can pass it to another boundary.
Retention class, expiration, and deletion scope are explicit **advisory
metadata only** here: Honeycomb/application code must enforce deletion,
private-mode rules, export, and project ownership. This module does not persist
or delete data and cannot make a raw fetch citation-ready.

The fetcher is not a proxy, certificate-pinning system, DNSSEC implementation,
or browser-equivalent web renderer. `protocol.rs` defines the typed, bounded
NDJSON message contract and the session-aware supervisor reader. It enforces a
`Ready` handshake, rejects responses after shutdown, validates response
URLs/status/metadata/body limits, and keeps raw response framing crate-private.
`src/main.rs` now provides a standalone worker executable with a bounded active
job registry, session-wide request-ID uniqueness, cooperative cancellation,
shutdown handling, and stderr-only diagnostics.

Cancellation and shutdown are cooperative: an in-flight synchronous fetch may
run until its deadline before its cancelled result is suppressed/emitted. A
`ResearchClient.wait_fetch` timeout leaves the job available for an explicit
`cancel` call; it does not silently discard work or release the slot early.
Cancelling an inactive or already finished ID returns `not_found`; terminal
results are not retained for idempotent replay. DNS resolution can also outlive
the per-fetch deadline because it is synchronous. The worker is still not wired
to HiveChromium, and Honeycomb persistence, lifecycle enforcement, extraction,
and browser network interception remain unimplemented.

## Packaging for HiveChromium

Build and stage the optional browser helper explicitly:

```sh
../../scripts/build-research-worker.sh
```

The script requires `HIVE_WORKER_REQUIREMENT` and places an unsigned
`hive-fetch-worker` plus `hive-worker-requirement.txt` in
`Sources/HiveChromium/Resources/ResearchWorker/`. Both generated files are
git-ignored. `HIVE_WORKER_REQUIREMENT` must be the exact macOS designated
requirement for the signed Hive helper; do not substitute a placeholder Team ID.
Direct staging also rejects the local all-zero Team ID unless the caller passes
`--allow-adhoc` explicitly. That flag is for local development only and emits a
non-distribution warning; the release assembler never passes it in its default
mode.
The release pipeline must sign the helper, embed both files in the final app
bundle, and verify the requirement against the signed helper before enabling
production handoff. Until those steps exist, HiveChromium's grounding action
remains visible but fails closed with an unavailable status; it never runs an
arbitrary development executable.

## Release verification

After the app has been signed, verify the actual HiveChromium bundle before
creating a DMG or submitting it for notarization:

```sh
HIVE_WORKER_TEAM_ID="$APPLE_TEAM_ID" \
  scripts/verify-research-worker.sh \
  --app path/to/HiveChromium.app
```

The verifier is read-only. It checks the helper's strict code signature, the
SwiftPM `Hive_HiveChromium.bundle` resource location, the fixed helper
identifier, the exact Team ID in both signature metadata and the designated
requirement, and the bounded requirement file. Add
`--require-stapled-ticket` only after notarization/stapling and only when the
release gate is meant to require that ticket. The verifier never signs,
notarizes, or prints the requirement contents. The protected workflow then runs
`xcrun stapler validate` and `spctl --assess --type execute --verbose=4` on the
stapled app, so a release claim requires both a stapled ticket and a successful
Gatekeeper execution assessment.

Before treating a bundle as a release artifact, run the structural preflight:

```sh
scripts/preflight-hivechromium-app.sh --app path/to/HiveChromium.app
```

It checks the actual CEF framework, framework binary, all five helper bundles
and helper executables, the main executable, SwiftPM resource bundle, worker,
metadata, deep seal, and signer Team ID consistency. The pinned minimal CEF
flavor may omit `Frameworks/.../Libraries`; when that directory exists, every
`*.dylib` leaf is also checked. It rejects ad-hoc or Team-ID-less signatures by
default. `--allow-adhoc` is available only for structural local-development
audits and never appears in the default release path.
A stale or incomplete bundle is expected to fail this check rather than being
silently treated as distributable.

For a signed CI fixture that is not yet inside an app bundle, pass all three
explicit inputs instead:

```sh
scripts/verify-research-worker.sh \
  --worker path/to/hive-fetch-worker \
  --requirement path/to/hive-worker-requirement.txt \
  --team-id "$APPLE_TEAM_ID"
```

## Local HiveChromium assembly scaffold

The repository includes a deterministic macOS assembly wrapper around CefSwift's
own CEF bundler:

```sh
DEVELOPER_ID_APPLICATION='Developer ID Application: Hive, Inc. (TEAMID)' \\
HIVE_WORKER_TEAM_ID="$APPLE_TEAM_ID" \\
HIVE_WORKER_REQUIREMENT='anchor apple generic and certificate leaf[subject.OU] = "TEAMID" and identifier "com.hive.browser.research-worker"' \\
  scripts/build-hivechromium-app.sh
```

The wrapper requires a real Developer ID identity, stages the Rust worker,
builds the SwiftPM release product, asks CefSwift to assemble Chromium and its
helper apps, embeds the exact `Hive_HiveChromium.bundle` from
`swift build --show-bin-path`, signs the worker/resource/app layers, and runs
`verify-research-worker.sh`. The exact three-key policy is checked by
`scripts/verify-hivechromium-entitlements.sh` before signing. For a
release-grade assembly, pass the reviewed entitlements policy explicitly:

```sh
scripts/build-hivechromium-app.sh \
  --entitlements Sources/HiveChromium/HiveChromium.entitlements
```

When that flag is supplied, the assembler signs the pinned CefSwift layout
inside-out: CEF libraries when present, the framework binary/framework bundle,
each known Chromium helper executable/helper bundle, the worker, SwiftPM
resource bundle, main executable, and outer app. The structural preflight then
checks every required item and signer consistency. This is intentionally scoped
to the pinned CefSwift layout; a CefSwift upgrade requires a fresh bundle-tree
inspection and paired preflight/signing update. The wrapper refuses ad-hoc
signing and missing release inputs. It does not notarize or staple, and the
final hardened-runtime/entitlements policy plus a positive signed-helper
fixture remain release inputs. Do not put the example Team ID or requirement in
a release environment.

The dedicated protected CI workflow is
`.github/workflows/hivechromium-release.yml`. It invokes the same exact
allowlist validator before importing credentials. It runs only for protected
`hive-v*.*.*` tags, requires the `hivechromium-release` GitHub Environment, and
fails closed unless that environment supplies the Developer ID certificate,
worker requirement, Apple Team ID, and App Store Connect API-key inputs. GitHub
repository administrators must protect the tag pattern and require human
reviewers on that Environment; the workflow cannot make an unprotected tag
trustworthy by itself. It also refuses to run until
`Sources/HiveChromium/HiveChromium.entitlements` exists and sets the reviewed
CEF library-validation policy explicitly.

For local cached development assembly only, use the explicit `--allow-adhoc`
flag. It uses the all-zero sentinel requirement, signs ad hoc, runs structural
preflight, and skips release-only worker verification. It must never be used
for distribution or notarization:

```sh
scripts/build-hivechromium-app.sh --allow-adhoc --output /tmp/hivechromium-local
```

## Validation

```sh
cargo fmt --manifest-path native/hive-fetch-boundary/Cargo.toml -- --check
cargo check --manifest-path native/hive-fetch-boundary/Cargo.toml
cargo test --manifest-path native/hive-fetch-boundary/Cargo.toml
cargo test --manifest-path native/hive-fetch-boundary/Cargo.toml --features test-support
```

The default build excludes hostile and synthetic fixture binaries. The
`test-support` run enables the compiled-worker integration tests, including
source provenance mapping, already-finished cancellation, and watchdog-forced
shutdown.

The crate currently has no dependency on the Swift targets and is not wired
into the shipped browser shell. It is a tested Rust transport plus standalone
worker foundation, not an end-to-end Hive research feature. The reusable
`supervisor` module now owns a compiled worker process, performs the `Ready`
handshake, routes typed responses, enforces a fetch in-flight limit, drains
stdout/stderr on dedicated threads, and applies an explicit graceful-shutdown
watchdog with kill/reap fallback. It deliberately does not restart workers;
restart/backoff is an application policy above this boundary. The worker still
maintains its own active registry and writes diagnostics only to stderr.
The repository includes subprocess integration tests against the compiled
worker binary, while worker and supervisor tests cover cancellation races,
saturation, request routing, duplicate IDs, and shutdown ordering. `ShutdownAck`
is not a hard wall-clock guarantee: synchronous DNS remains non-interruptible.
The supervisor's watchdog is the process-level boundary, and the hostile worker
fixture verifies the direct-child `Forced` kill/reap path.
Process-group or descendant cleanup, restart/backoff, and application-specific
retry policy remain outside this crate. The worker is still not wired to
HiveChromium, and no FFI/browser IPC claim is made.

