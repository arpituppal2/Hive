# M31 — User-Controlled Extensibility & Data Portability Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M31 User-controlled extensibility & data portability
> **Depends on:** M0–M6 storage/provenance/lifecycle/MCP/encryption contracts; M10 Sidecar; M12 Command Center; M13 Projects & Tasks; M22 Menu-Bar Modes & Presets; M25 Engine Sovereignty; M26 tenant/policy/lifecycle; M27 collaboration/sync; M28 Flow runtime; M29 memory/context governance; M30 work-loop/proactive agenda.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities reused:** M0 storage/migration/recovery, M6 read-only local-agent boundary, M12 typed command authority, M22 declarative presets, M25 renderer/extension capability truth, M26 ownership/policy, M27 membership/epoch scope, M28 typed Flow authority, M29 deletion/context governance, M30 proposal/notification governance, Keychain, Honeycomb, and EventLedger.
>
> M31 creates an open, inspectable portability and extension seam without creating an arbitrary plugin runtime. Users can export their own eligible Hive data, import validated archives into a quarantine/review path, and install declarative commands, presets, read-only MCP descriptions, and bounded Flow templates whose capabilities remain native-owned. A manifest, JSON file, shared workspace, page, model, or imported archive is data—not permission and not executable authority.

## 0. Decision summary

The smallest safe M31 architecture is:

```text
user-owned Hive objects
  → scoped export manifest + deterministic archive
    → user inspection / redaction / portability report
      → validated import quarantine
        → explicit merge / replace / reject decision

user-authored declarative manifest
  → schema + signature/provenance + capability review
    → native registry projection
      → M12 command / M22 preset / M28 Flow / M6 read-only adapter
        → existing policy, approval, worker, scope, and EventLedger authorities
```

| Slice | User value | Hard boundary |
|---|---|---|
| **X1 — Portable export** | Own and inspect Hive data outside the app | Export is scoped, versioned, omission-aware, and secret-free; it is not a claim that every derived or external copy is erased |
| **X2 — Safe import** | Restore or move work without silently merging hostile state | Imports are schema-validated, quarantined, previewed, and explicitly applied; malformed or unsupported data never reaches live authority |
| **X3 — Declarative extensions** | Customize commands, presets, and bounded Flows | Manifests declare outcomes and capabilities; native registries decide availability and authority |
| **X4 — Capability/revocation lifecycle** | See what an extension can do and disable it cleanly | Grants are narrow, expiring/revocable, scope-bound, and never inferred from installation or shared content |
| **X5 — Ecosystem and browser-first validation** | Get composability without turning Hive into a marketplace risk | No arbitrary code, Chrome Web Store parity, remote marketplace, hidden helper, or browser degradation is implied |

M31 does **not** ship a general plugin process, arbitrary Swift/JavaScript/Python execution, Chrome Web Store integration, a public extension marketplace, remote code loading, automatic cloud sharing, silent import merge, secret export, or a universal portability/deletion guarantee.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Existing surface | Current truth | M31 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| Honeycomb/EventLedger | Code-present storage/provenance/audit primitives with planned lifecycle contracts | Export object graph, provenance, consent, deletion generations | A database copy is not a portable archive or an independent verifier |
| M0–M6 | Planned migration, backup, read-only MCP, deletion, and encryption boundaries | Archive consistency, connection identity, read-only export/query boundary | M6 does not grant write/import authority or arbitrary file access |
| M12 Command Center | Typed local command authority and receipts | Registry projection for declarative commands | A manifest cannot create a native executor or bypass availability/policy |
| M22 Presets | Planned declarative menu-bar/status projection | Preset manifest schema and local projection | Presets cannot contain executable code, secrets, or hidden context |
| M25 Engine Sovereignty | Current product is CEF/Chromium; extension loading is not proven | Capability truth and explicit extension-state reporting | Embedded Chromium is not Chrome Web Store parity; management UI is not execution |
| M26 tenant/policy | Planned ownership, policy admission, export/audit, deletion | Scope and ownership on every archive/manifest | Tenant or workspace membership cannot authorize arbitrary imported code |
| M27 shared sync | Planned encrypted operation log and shared workspace authority | Shared manifest metadata only when explicitly typed | Shared content cannot publish executable definitions or grant capabilities |
| M28 Flows | Planned typed immutable Flow revisions and durable runs | Flow template export/import as inert proposals | Imported Flow cannot become published, enabled, or scheduled automatically |
| M29 context governance | Planned preferences/signals/packets/deletion generations | Export classes, redaction, deletion propagation | Signals, hidden preferences, raw packets, and provider secrets are excluded by default |
| M30 work loop | Planned objectives, agenda, proposals, notification consent | Export agenda preferences/objectives and proposal history where eligible | Notifications, proposals, and acceptance events do not become execution authority |
| Keychain | Native secret/key custody seam | Secret references and omission records | Keychain material, OAuth refresh tokens, API keys, and bearer tokens never enter archives |
| README/extension UI | Extension management UI exists; unpacked loading is deferred pending CEF API reality | Honest capability matrix | UI existence is not evidence of extension execution or Web Store compatibility |

**Current implementation classification:** Hive has code-present storage, command, profile, sync, and AI runtime primitives plus planned M6/M12/M22/M25–M30 contracts. It does not have a verified portable archive format, safe import quarantine, declarative extension registry, or revocable extension-capability lifecycle. No M31 claim may be marked verified from a JSON schema, export button, manifest parser, or extension settings screen alone.

### 1.2 Authority table

| Concern | Single authority | M31 rule |
|---|---|---|
| Archive contents | Export planner + source authorities | Only eligible typed objects are exported; omissions are explicit |
| Archive integrity | Canonical manifest/hash + independent verifier | A valid hash proves integrity, not trust or permission |
| Import | Quarantine/import planner | Imported data is inert until preview and explicit native apply |
| Commands | M12 CommandRegistry | Manifest entries project into commands only if native executor exists |
| Presets | M22 preset authority | Declarative predicates and command IDs only; no scripts or hidden inputs |
| Flows | M28 FlowDefinition/Publication authority | Templates import as drafts; publish/enable/schedule remain separate user decisions |
| MCP | M6 connection/grant authority | Exported MCP descriptions never include active tokens or active grants |
| Scope/ownership | M26/M27/M29 authorities | Archive scope cannot widen on import; shared data remains explicitly shared |
| Secrets | Keychain/connector authorities | SecretRef metadata may be retained; secret material is omitted and re-bound interactively |
| Revocation | Native extension/grant projection + EventLedger | Disable/revoke invalidates cached projections and queued work |
| Renderer extension | M25 capability matrix | `supports_extension_loading` is measured; no UI may imply parity |
| Deletion | M0–M6/M26/M29 lifecycle | Delete reports local/archive/sync/external-copy boundaries honestly |
| User consent | Native import/install/apply UI + EventLedger | Installation, import, capability grant, publish, enable, and schedule are distinct decisions |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned, open, deterministic export envelope for eligible Hive objects.
2. Per-scope export selection: profile, workspace, project, memory/source, tasks, preferences, objectives, agenda settings, command/preset/Flow templates, audit metadata, and connector metadata.
3. Explicit omission classes for secrets, private content, candidates/signals, raw context packets, renderer-opaque state, unavailable/deleted data, and external copies.
4. Archive manifest with schema version, producer version, object counts, source generations, deletion generation, content hashes, dependency references, and portability report.
5. Import parsing, schema migration, signature/hash verification, quarantine, hostile-content scanning, conflict preview, and explicit apply/merge/skip decisions.
6. Declarative command, preset, read-only MCP description, and Flow-template manifests with typed schemas and capability declarations.
7. Native capability review, narrow grant state, revocation, disable, uninstall, stale-manifest handling, and EventLedger evidence.
8. Import/export of personal data without silently transferring tenant authority, CloudKit grants, Keychain material, private renderer state, or remote model credentials.
9. Browser-first operation with all portability/extensibility features disabled, unavailable, or denied.
10. Synthetic security, migration, portability, revocation, accessibility, and prompt-injection evaluation.

### 2.2 Explicit non-goals

- Arbitrary plugin code, dynamic library injection, JIT-hosted extension code, shell scripts, AppleScript, CGEvent, browser JavaScript injection, or unreviewed subprocesses.
- Chrome Web Store integration, full Chrome extension API parity, Safari Web Extension packaging, or any claim that embedded CEF equals Chrome.
- A public marketplace, remote manifest registry, automatic updates from arbitrary URLs, or install-by-click from page/model/shared content.
- Exporting passwords, API keys, OAuth refresh tokens, cookies, private keys, bearer tokens, raw Keychain values, or hidden prompt/system instructions.
- Importing an archive directly into live stores, replacing a profile silently, merging by title/URL alone, or trusting an archive because it is signed.
- Exporting renderer-opaque state as if it were portable, preserving an external client’s copied plaintext, or guaranteeing remote deletion from all backups/exports.
- Sharing personal memory, inferred signals, notification history, or private context by default with M27 workspaces or extensions.
- A capability grant inferred from archive presence, manifest signature, workspace membership, model output, or user opening a file.
- A second command authority, scheduler, Flow runtime, permission center, or secret store.
- Model training/fine-tuning on exported/imported personal data or remote analytics on portability events.

## 3. Portable archive contract

### 3.1 Archive envelope

```text
HiveArchive {
  archive_id: stable UUID
  schema_version: semantic version
  producer: product ID + version + build identity
  created_at: Date
  export_scope: typed scope expression
  source_generations: [authority → generation]
  deletion_generation: UInt64
  portability_mode: full_eligible | selected_scope | manifest_only
  objects: archive entries
  dependencies: typed references
  omissions: OmissionRecord[]
  warnings: WarningRecord[]
  manifest_hash: canonical hash
  signature: optional user/device signature metadata
}
```

The archive has a deterministic canonical manifest. Hashes detect corruption or accidental changes; signatures identify a signer only when the key and trust decision are independently validated. Neither hash nor signature grants import authority.

### 3.2 Export classes

| Class | Default | Examples | Required treatment |
|---|---|---|---|
| `portable_content` | included when selected | user notes, approved sources, claims, projects, tasks, objectives | Stable IDs, provenance, revisions, deletion state, source links |
| `portable_preferences` | opt-in by scope | explicit preferences, agenda settings, command/preset definitions | Typed values only; no executable instructions or hidden signals |
| `portable_templates` | opt-in and inert | Flow drafts, declarative commands, presets, MCP method descriptions | Draft/quarantined on import; capabilities re-evaluated locally |
| `audit_metadata` | selectable | event IDs/timestamps/types/status summaries | No secrets, deleted content, raw prompts, or hidden context |
| `connector_metadata` | manifest-only by default | provider/account/root labels, cursor status, revocation state | No tokens or raw external payloads; reconnect required |
| `private_or_sensitive` | excluded | private captures, sensitive classes, credential-shaped text | Omission reason; no content preview in archive report |
| `ephemeral_or_inferred` | excluded by default | M29 signals, raw packets, ranking traces, proposal cache | Export only a coarse policy manifest if explicitly allowed |
| `opaque_renderer_state` | excluded | CEF profile/cache/session internals | Canonical tab/session metadata may export separately |
| `external_copy` | not controllable | client copies, backups, prior exports, remote provider retention | Explicit limitation; never claim universal deletion |

### 3.3 Provenance and references

Every exported object retains stable identity, object type, owner scope, revision, provenance references, creation/update time, deletion state, and source generation where eligible. A reference to an omitted object becomes a typed `omitted_reference` with reason—not a dangling pointer silently dropped or replaced by fabricated content.

Exported archive text is data. It may include page/task/source content that contains prompt injection. Export tools and reports must not render imperative content as application instructions, and archive previews must sanitize notification-like or credential-shaped text.

### 3.4 Deterministic export

Given the same admitted source generations, scope, export options, and serializer version, the archive manifest and portable object ordering are deterministic. Volatile fields are separated into a reproducibility section. Export cancellation produces an incomplete artifact clearly marked unusable until resumed or discarded.

## 4. Import quarantine and merge

### 4.1 Import state machine

```text
selected
  → copied_to_quarantine
    → parsed
      → schema_validated
        → migrated
          → integrity_checked
            → security_scanned
              → conflict_planned
                → user_review
                  → applied | partially_applied | rejected | cancelled | expired
```

No imported object reaches Honeycomb, EventLedger authority, CommandRegistry, PresetRegistry, Flow publication, notification preferences, or Keychain before the explicit apply step. A parser must preserve malformed records in a rejection report; it may not silently discard them.

### 4.2 Import identity and conflict rules

Import identity is based on archive object ID, type, schema, source lineage, revision, and content hash. Title, URL, display name, or file path alone is not identity. Conflicts are typed:

```text
new_object | same_revision | newer_local | newer_archive | divergent_revision
  | scope_mismatch | deleted_local | deleted_archive | unsupported_type
  | secret_omitted | capability_reapproval_required
```

Default action is `review`, not last-write-wins. User may apply selected objects, create a visible fork, skip, or cancel. Imported deletes do not erase local objects without a separate scoped delete confirmation.

### 4.3 Migration and trust

Schema migration is deterministic, versioned, bounded, and testable. Unsupported future schemas remain quarantined and exportable for a newer Hive version. A valid signature may reduce corruption risk but never bypasses schema validation, scope checks, prompt-injection scanning, capability review, or user consent.

Imported shared/workspace/tenant metadata is remapped to local identities unless the user explicitly reconnects through the owning authority. CloudKit records, M27 membership, device epochs, M6 grants, M16 worker grants, and M28 run leases are never revived from an archive alone.

## 5. Declarative extension manifests

### 5.1 Manifest envelope

```text
ExtensionManifest {
  manifest_id: stable UUID
  schema_version: semantic version
  kind: command | preset | flow_template | mcp_read_description
  name: bounded display name
  author_label: untrusted display metadata
  description: bounded text
  declared_inputs: typed schema
  declared_outputs: typed schema
  outcome_steps: typed declarative steps
  requested_capabilities: typed list
  requested_scopes: typed scope expression
  network_domains: explicit empty-or-allow-list metadata
  data_classes: declared classes
  update_policy: pinned_local | user_selected_file | managed_policy
  provenance: archive/source/signature metadata
  status: quarantined | review | installed | disabled | revoked | rejected
  content_hash: canonical hash
}
```

M31 v1 allows only four manifest kinds:

- **Command:** maps to an existing M12 command ID and typed argument schema;
- **Preset:** maps to existing M12 commands and non-executable M22 predicates;
- **Flow template:** maps to existing M28 activities and imports only as a draft;
- **MCP read description:** documents fixed M6 read methods and requested scope, never active grants or write tools.

A manifest cannot define a new native executor, invoke an unknown command, add an arbitrary URL scheme, set a secret, change policy, create a permission, or make itself enabled.

### 5.2 Capability review

Capability requests are explicit and user-readable:

```text
none
read_current_tab_metadata
read_selected_memory
read_selected_connector_scope
open_hive_surface
create_local_draft
request_existing_approval
run_existing_bounded_flow
```

No manifest receives a capability merely because it is installed, signed, authored by a workspace member, or recommended by a model. High-risk capabilities remain unavailable to M31 declarative manifests unless a later milestone defines a typed adapter, approval, worker boundary, and rollback/reconciliation contract.

### 5.3 Native projection

Installation creates a projection, not authority:

```text
quarantined → inspected → user_accepts_scope → installed_disabled
installed_disabled → user_enables → active_projection
active_projection → paused | disabled | revoked | deleted
```

The native registry revalidates the manifest at invocation time against current command availability, policy revision, scope generation, capability grants, deletion generation, and manifest hash. Stale projections fail closed and request review; they do not silently update.

## 6. Revocation, updates, and distribution

### 6.1 Revocation

Revocation is local and immediate for new invocations. It invalidates active projections, queued manifest-originated work, cached capability decisions, scheduled template triggers, and pending approvals that reference the manifest. Already-materialized user-visible data follows normal deletion/export policy; revocation does not pretend to erase copies already exported or read by another client.

### 6.2 Update policy

M31 v1 supports only pinned local manifests or explicitly selected local files. There is no background URL fetch, auto-update, remote marketplace, or silent update. A future distribution service would require signed metadata, rollback, transparency, domain allow-listing, vulnerability response, permission-diff review, and user-visible release history.

Signing is provenance, not trust. The UI shows signer, hash, source path, requested capabilities, requested scopes, last review, and update policy. An unsigned local manifest may be inspected/imported as quarantined data, but it cannot be silently enabled.

### 6.3 Renderer extension reality

M31 does not alter M25’s engine decision. If the current CEF build reports extension loading unavailable or unmeasured, Hive must show that state and keep declarative Hive manifests separate from browser extension APIs. A command/preset/Flow manifest is not a Chrome extension and must not be marketed as one.

## 7. Data portability, deletion, and secrets

- Export selection intersects profile/workspace/project/tenant/shared/private/deletion policy before serialization.
- Private, deleted, revoked, candidate, inferred, secret-bearing, and policy-blocked records are omitted or represented by safe metadata only.
- Export never includes Keychain values, bearer tokens, refresh tokens, cookies, private keys, hidden system prompts, raw provider credentials, or unbounded raw context packets.
- Import never writes Keychain from archive data. Connector accounts require fresh interactive reconnection and least-privilege consent.
- Deletion creates a generation and invalidates archive planners, export caches, manifests, installed projections, pending imports, Flow templates, M29 context packets, M30 proposals, and M6/M27 projections according to their authorities.
- Deletion reports distinguish `requested`, `queued`, `applied_local`, `awaiting_sync`, `blocked`, `failed`, and `verified_local`; they do not claim erasure from copied archives, OS backups, external clients, or provider retention.
- Archives containing omitted sensitive/private content never disclose its raw value in logs, filenames, previews, or rejection explanations.

## 8. User experience and accessibility

### 8.1 Portability Center

The user-facing surface groups:

- **Export:** scope picker, class toggles, estimated counts, omissions, manifest hash, cancel/resume, save destination, and portability limitations;
- **Import:** quarantine status, schema/migration report, integrity/security warnings, conflicts, capabilities, omitted secrets, and per-object apply/skip/fork;
- **Extensions:** installed/quarantined/disabled/revoked manifests, signer/hash/source, requested capabilities/scopes, enable/disable/revoke/delete, and last review;
- **Connections:** M6 read-only descriptions and grants remain in the existing permission surface; archives cannot silently reactivate them;
- **Deletion:** dependency status across local stores, projections, archives, sync, and external-copy limits.

### 8.2 Accessibility

All export/import/extension actions are keyboard reachable. VoiceOver announces object kind, scope, source, hash/status, requested capability, and next action without reading sensitive archive content unexpectedly. Conflict choices are semantic and not color-only. Large text, high contrast, reduced motion, cancel, retry, and safe fallback paths remain usable. The browser remains complete if the Portability Center or extension projection is unavailable.

## 9. Evaluation and threat model

### 9.1 Frozen local corpus

M31 uses synthetic archives/manifests with schema versions, object graphs, revisions, deletions, private content, secrets, prompt injection, tenant/shared scopes, renderer-opaque state, connector metadata, and capability requests. Metrics include deterministic export reproducibility, omission correctness, import preservation, migration correctness, conflict safety, secret leakage rate, unauthorized projection rate, revocation latency, stale-projection rejection, accessibility coverage, and browser-first degradation.

A valid signature, clean JSON parse, or successful hash check is never counted as proof of safety by itself. Report integrity, provenance, scope, and authority metrics separately.

### 9.2 Stop conditions

Do not enable M31 behavior if:

- an archive can include a secret, private raw content, hidden prompt, or bearer token;
- import writes live stores before explicit quarantine review and apply;
- a title/URL/hash shortcut can merge unrelated objects or erase local data;
- a manifest can create a new executor, invoke an unknown command, or alter policy;
- installation or signature silently grants capability, scope, or network access;
- revocation leaves queued invocation or active approval usable;
- a shared/page/model/archive string can publish, enable, or update a manifest;
- an extension update changes capabilities without a visible review;
- CEF extension UI implies Chrome Web Store or full `chrome.*` parity;
- deletion leaves a live projection, pending import, export cache, Flow template, proposal, or context packet using the deleted generation;
- archives or imports are treated as universally portable or universally erasable;
- Portability Center failure degrades ordinary browsing;
- M31 collects marketplace/install/engagement analytics beyond minimal local receipts.

## 10. Failure matrix

M31 requires fake stores, fake Keychain, fake signatures, fake scopes/policies, synthetic archives/manifests, fake renderer capabilities, fake CloudKit/M27 state, and no production network.

| ID | Fixture | Required assertion |
|---|---|---|
| M31-01 | Export selected project | Only admitted eligible objects and references are included |
| M31-02 | Export profile with private content | Private content omitted with safe reason, no raw preview |
| M31-03 | Export with inferred M29 signals | Signals excluded by default |
| M31-04 | Export with secrets | Tokens/keys/cookies/Keychain values never serialized |
| M31-05 | Export renderer-opaque state | Canonical metadata exports; opaque state omitted |
| M31-06 | Export deterministic repeat | Same generations/options produce same manifest/hash |
| M31-07 | Export cancellation | Incomplete archive marked unusable or resumable, never presented complete |
| M31-08 | Export deletion generation advances | Stale export plan/cache invalidated |
| M31-09 | Export deleted object | Safe tombstone/omission, no deleted content leakage |
| M31-10 | Export tenant/shared scope | Ownership and membership boundaries are preserved |
| M31-11 | Import current schema | Parsed into quarantine, no live write before apply |
| M31-12 | Import older schema | Deterministic migration report and preview |
| M31-13 | Import future schema | Quarantined/rejected but retained for newer version |
| M31-14 | Malformed archive record | Preserved in rejection report; no silent discard |
| M31-15 | Hash mismatch | Import blocked; no live projection |
| M31-16 | Signature invalid | Provenance warning/review; no implicit trust or enable |
| M31-17 | Valid signature from unknown signer | Still requires local scope/capability/user review |
| M31-18 | Archive contains prompt injection | Data-only; no authority or install mutation |
| M31-19 | Archive contains notification impersonation | Preview sanitized; no system-like alert injection |
| M31-20 | Same object revision | No duplicate or destructive merge |
| M31-21 | Divergent revision | Visible conflict; user chooses fork/skip/apply |
| M31-22 | Imported delete | No local deletion without separate scoped confirmation |
| M31-23 | Scope mismatch | Quarantined; no tenant/workspace widening |
| M31-24 | Connector metadata import | Reconnect required; no token restoration |
| M31-25 | M6 grant in archive | Grant/token not revived; fresh consent required |
| M31-26 | M27 epoch/device metadata | Shared authority not restored from archive alone |
| M31-27 | Flow template import | Draft only; not published/enabled/scheduled |
| M31-28 | Command manifest unknown ID | Rejected; no new executor created |
| M31-29 | Preset manifest executable text | Validation rejects script/hidden action |
| M31-30 | MCP description requests write tool | Rejected; fixed M6 read-only methods only |
| M31-31 | Manifest requests secret | Rejected/redacted; no Keychain access |
| M31-32 | Manifest requests broad scope | Narrowed/rejected; user scope and policy win |
| M31-33 | Manifest signature changes | Hash/provenance diff requires re-review |
| M31-34 | Manifest update adds capability | Cannot auto-enable; visible permission diff |
| M31-35 | User installs manifest | Quarantined/reviewed/disabled projection; no implicit activation |
| M31-36 | User enables manifest | Native current policy/capability checks run again |
| M31-37 | Manifest revoked | Queued work/approvals/projections invalidated |
| M31-38 | Stale installed projection | Invocation blocked; review required |
| M31-39 | Shared content proposes extension | Proposal only; no publish/install/enable |
| M31-40 | Page/model text requests install | Ignored as authority; no install side effect |
| M31-41 | CEF reports extension unavailable | UI shows unavailable; no Chrome parity claim |
| M31-42 | Deletion during export | Export cancelled/marked stale; deleted content withheld |
| M31-43 | Deletion during import | Pending object excluded; generation wins |
| M31-44 | Deletion after install | Projection/template/cache revoked or deleted by scope |
| M31-45 | Archive copied externally | UI states external copy cannot be controlled |
| M31-46 | Keychain locked | Import/export excludes secrets; browser remains usable |
| M31-47 | Portability Center unavailable | Ordinary browsing and existing commands remain usable |
| M31-48 | Large archive | Bounded streaming/cancellation/backpressure; no unbounded memory |
| M31-49 | Accessibility/reduced-motion path | Keyboard/VoiceOver/large text/high contrast work |
| M31-50 | Clean profile with M31 disabled | Navigation/tabs/private mode/session restore remain complete |

The fixture matrix contains **50 cases**. New cases require an update to this plan and all progress mirrors.

## 11. Work packages after approval

### M31-A — Export envelope and portability report

- Freeze archive schema, canonical manifest/hash, eligible classes, omissions, dependency references, deterministic serializer, cancellation, and independent verifier.
- Reuse M0/M4/M6/M26/M29 deletion/scope/provenance authorities.
- Add M31-01…M31-10.

**Done when:** users can export a selected scope into an open, deterministic, secret-free archive with honest omissions and generation metadata.

### M31-B — Import quarantine, migration, and conflict review

- Implement parse/migrate/integrity/security/quarantine state machine, identity rules, conflict taxonomy, rejection preservation, and explicit apply/skip/fork decisions.
- Never write live stores or Keychain before apply; preserve unsupported archives for newer versions.
- Add M31-11…M31-26.

**Done when:** imports are reversible planning artifacts until explicit application, and no malformed, stale, private, or authority-bearing data reaches live state silently.

### M31-C — Declarative command, preset, MCP, and Flow manifests

- Define the four allowed manifest kinds, typed schemas, outcome-oriented steps, command/preset/activity references, requested capabilities/scopes, provenance, and update policy.
- Project only to existing M12/M22/M6/M28 authorities; unknown executors, arbitrary scripts, write MCP methods, and hidden inputs are rejected.
- Add M31-27…M31-32.

**Done when:** users can inspect and import inert, useful declarative customizations without creating a new execution authority or claiming browser extension parity.

### M31-D — Capability review, revocation, and distribution boundary

- Add quarantine/review/disabled/active/revoked lifecycle, current-policy revalidation, capability-diff review, queued-work invalidation, local pinned update policy, and EventLedger evidence.
- Keep renderer extension capability truth under M25; no remote marketplace or auto-update in v1.
- Add M31-33…M31-41.

**Done when:** every installed projection has visible scope/capability/provenance, revocation is immediate for new work, and stale/changed manifests fail closed.

### M31-E — Deletion, accessibility, security, and browser-first validation

- Integrate deletion generations across archives, caches, imports, projections, M6/M27 metadata, M28 templates, M29 context, and M30 proposals.
- Run secret-leakage, prompt-injection, conflict, scope, renderer, large-archive, accessibility, and clean-profile validation.
- Add M31-42…M31-50.

**Done when:** portability and declarative extensibility improve ownership without leaking secrets, widening authority, reviving grants, or degrading the browser.

## 12. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M31-A | Portable archive | Versioned deterministic envelope, manifest/hash, scope, generations, omissions, provenance, independent verification |
| M31-B | Secret/privacy boundary | No Keychain values, tokens, cookies, private raw content, hidden prompts, or inferred signals by default |
| M31-C | Import quarantine | Parse/migrate/scan/review/apply state machine; no live writes before explicit apply |
| M31-D | Conflict safety | Stable identity, revision/hash checks, visible forks, no title/URL destructive merge |
| M31-E | Declarative manifests | Commands/presets/MCP-read/Flow-template only; native executors and typed schemas required |
| M31-F | Capability review | Human-readable capability/scope requests; no install-implies-authority |
| M31-G | Revocation | Active projections, queued work, approvals, caches, and schedules invalidated by revoke |
| M31-H | Update truth | Pinned/local updates only; capability diffs require review; no remote marketplace claim |
| M31-I | Renderer truth | CEF extension availability is measured and honestly exposed; no Chrome parity claim |
| M31-J | Deletion | Generations propagate across archives/imports/projections/templates/context/proposals; external-copy limits disclosed |
| M31-K | Accessibility/security | Keyboard, VoiceOver, large text, reduced motion, injection, secret, malformed, and large-archive fixtures pass |
| M31-L | Browser-first release | 50 fixtures, clean profile, M31-disabled path, private/offline/locked/revoked states pass |

M31 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and a clean-profile export/import plus declarative-manifest journey is demonstrated. A JSON parser, export file, manifest signature, settings panel, or extension-management UI alone is `scaffold`/`code-present`, not verified portability or extensibility.

## 13. Implementation order and stop conditions

After M0–M30 contracts have fresh evidence:

1. Freeze fake stores, archive schemas, manifests, signatures, scopes, policies, Keychain, renderer capabilities, deletion generations, and conflict fixtures.
2. Implement M31-A export envelope/report independently of import and extensions.
3. Implement M31-B quarantine/migration/conflict review with apply disabled by default.
4. Implement M31-C inert declarative manifests projected into existing registries only.
5. Implement M31-D capability review, revocation, pinned/local update, and renderer truth surfaces.
6. Implement M31-E deletion, accessibility, injection, large-archive, and browser-first integration.
7. Enable export first; enable import after quarantine/review evidence; enable declarative projections only after capability/revocation gates.
8. Re-run M6 MCP, M12 commands, M22 presets, M25 renderer, M26/M27 scope, M28 Flow, M29 deletion/context, and M30 proposal/notification paths.
9. Record exact evidence and remaining risk in the canonical progress mirrors.

Stop and do not widen scope if:

- an archive contains secret/private raw content or an imported token/grant;
- import writes live authority before explicit review/apply;
- signature/hash is treated as permission;
- a manifest creates a native executor, arbitrary code path, hidden network path, or policy override;
- installation, sharing, page content, model output, or workspace membership activates a manifest;
- revocation cannot invalidate queued/projection/approval state;
- a capability or network scope changes without visible review;
- renderer UI implies Chrome extension/Web Store parity without measured support;
- deletion leaves a live archive, import, manifest projection, Flow template, context packet, or work-loop proposal using deleted generations;
- portability or extensibility failures degrade ordinary browser behavior;
- M31 claims universal export, universal deletion, legal compliance, or safe execution based solely on signatures, hashes, or schemas.

## 14. Explicitly deferred

- Arbitrary plugin processes, native code, dynamic libraries, JIT/script runtimes, shell/AppleScript/CGEvent, and extension code execution.
- Chrome Web Store, full Chrome `chrome.*` APIs, Safari Web Extension packaging, remote extension marketplace, public registry, and automatic remote updates.
- OAuth/token/password/cookie/private-key export or archive-based credential restoration.
- Automatic publish/enable/schedule of imported Flows, commands, presets, or MCP connections.
- Collaborative editing of manifests, public sharing, anonymous links, tenant-wide extension deployment, or administrator decryption.
- Universal portability across engine-opaque renderer state, OS backups, external clients, provider retention, or copied plaintext.
- Model training/fine-tuning, remote behavioral analytics, marketplace engagement optimization, or extension usage surveillance.
- A second permission, command, scheduler, task, memory, Flow, or secret authority.

## 15. Evidence references

Platform and extension boundaries:

- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple Security-Scoped Bookmarks](https://developer.apple.com/documentation/foundation/nsurl/security-scoped_bookmarks)
- [Apple Safari Web Extensions](https://developer.apple.com/documentation/safariextensions)
- [Chrome Extensions documentation](https://developer.chrome.com/docs/extensions)
- [Apple Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Apple login items and background tasks](https://support.apple.com/guide/deployment/manage-login-items-background-tasks-mac-depdca572563/web)

Protocols and data portability:

- [Model Context Protocol specification](https://modelcontextprotocol.io/)
- [JSON Schema](https://json-schema.org/specification)
- [Apple CloudKit](https://developer.apple.com/documentation/cloudkit)
- [GDPR — Regulation (EU) 2016/679](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [NIST Privacy Framework](https://www.nist.gov/privacy-framework)
- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)

These sources establish platform, protocol, signing, portability, privacy, and threat-model constraints. The M31 archive schema, omission taxonomy, quarantine state machine, declarative manifest kinds, capability list, revocation lifecycle, fixtures, and exit gates are Hive-specific proposed contracts and require implementation evidence before any capability status changes.
