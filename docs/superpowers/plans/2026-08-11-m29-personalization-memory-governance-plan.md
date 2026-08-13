# M29 — Personalization, Memory Governance & Adaptive Context Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M29 Personalization, memory governance & adaptive context
> **Depends on:** M0–M6 storage/provenance/lifecycle/MCP/encryption contracts; M10 Sidecar scope/approval; M11 Studio; M12 Command Center; M13 Projects & Tasks; M19/M23 connector boundaries; M26 tenant/policy/lifecycle; M27 collaboration/sync; M28 Flow inputs and run governance.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary code seams audited:** `Sources/HiveCore/Browser/MemoryAdmission.swift`, `HotMemoryStore.swift`, `ContextScope.swift`, `ContextRequestCoordinator.swift`, `PageContextBroker.swift`, `Sources/HiveCore/AI/ContextRedactor.swift`, `Sources/HiveCore/Browser/RetrievalRankerFilter.swift`, `Sources/HiveCore/AI/Search/RetentionCapability.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`, and the M0–M6/M10/M13/M26/M27/M28 plans.
>
> M29 is not a behavioral-surveillance system and not a hidden user-model project. It defines how Hive may use explicit preferences, durable memory, and narrowly bounded local signals to assemble better context while preserving purpose limitation, inspectability, deletion, private-mode boundaries, and user control. Personalization may improve ordering, summaries, defaults, and context budgeting; it may not create permissions, alter policy, infer sensitive identity, silently widen context, or turn retrieved memory into instructions.

## 0. Decision summary

The smallest safe adaptive-context architecture is three deliberately separate layers:

```text
user-authored preferences and controls
  → explicit preference authority

user-approved durable memory and provenance
  → Honeycomb/M0–M6 lifecycle authority

short-lived local ranking signals
  → ephemeral signal store with purpose + TTL

all three
  → context admission + redaction + budget planner
    → explainable candidate ranking
      → bounded model request / browser presentation
```

| Slice | User value | Hard boundary |
|---|---|---|
| **P1 — Memory governance** | Know what Hive remembers, why, and how to remove it | Durable memory, preferences, and inferred signals are separate types with separate retention and deletion paths |
| **P2 — Preference authority** | Make Hive adapt to explicit choices without repeatedly asking | User-authored preferences outrank inferred signals; preferences never grant capability or override policy |
| **P3 — Adaptive retrieval** | Surface the right retained context with less noise | Local ranking may use bounded relevance/recency/scope signals; it cannot use hidden sensitive traits or cross-scope leakage |
| **P4 — Context packet and explanation** | See exactly what enters a response and why | Context is explicit, capped, redacted, provenance-linked, and represented as untrusted data—not system instruction |
| **P5 — Forgetting, consent, and evaluation** | Correct, pause, export, delete, and measure personalization honestly | Consent withdrawal invalidates derived signals/indexes; ranking changes require frozen local evaluation and never claim universal lift |

M29 does **not** ship covert all-day profiling, cross-application behavioral surveillance, federated training, remote user embeddings, model fine-tuning on personal data, inferred sensitive traits, automatic durable memory promotion, or personalized permissions/actions.

## 1. Current truth and reusable authorities

### 1.1 Existing primitives

| Existing surface | Current truth | M29 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| `MemoryAdmission` / `MemoryAdmissionPolicy` | Distinguishes candidate versus durable admission and rejects private content | Durable-versus-candidate foundation | Does not define preference/signal classes, purpose, consent withdrawal, or derived ranking deletion |
| `HoneycombStore` | Typed graph/revisions/provenance/FTS/deletion primitives | Durable memory authority | Does not itself define adaptive profile semantics or privacy purpose boundaries |
| `HotMemoryStore` | Actor-backed, bounded in-memory context with scope and forgetting operations | Request-local context assembly and ephemeral cache | Access/relevance behavior must not silently become a long-lived user profile |
| `ContextScope` / `ContextScopeSummary` | Profile/workspace/project/tab/page/private scope model and user-visible summary | Server/native context scope intersection and preview | Scope fields are not a consent ledger or personalization policy by themselves |
| `ContextRedactor` | Credential redaction, sensitivity classification, bounded text, instruction fencing | Final packet redaction and untrusted-data delimiters | Redaction is not complete inference/PII detection and cannot replace purpose admission |
| `ContextRequestCoordinator` / `PageContextBroker` | Serializes scope transitions and page-context requests with private/consent checks | Generation-aware packet admission | Needs M29 packet IDs, purpose, budget, ranking explanation, and preference isolation |
| `RetrievalRankerFilter` | Validates model/ranker output against an allowed node list | Candidate allow-list defense | Does not choose candidates, learn from feedback, or prove ranking quality |
| `RetentionCapability` | Signed, scoped, expiring retention authority | Explicit retention/pin controls | Must not become a general bearer token for profile writes or ranking overrides |
| `EventLedgerStore` | Append-only local audit/consent/event authority | Preference changes, signal policy, context packet, deletion, and model-route evidence | Existing event vocabulary does not yet prove adaptive-profile lifecycle |
| M5 digest/forgetting plan | Planned approval, reinforcement, decay, retention, and purge boundaries | Durable memory lifecycle and explicit approval | M5 concepts such as reinforcement must not be interpreted as covert behavioral profiling |
| M26 enterprise plan | Planned tenant/policy/ownership/lifecycle/admission boundary | Policy intersection before personalization and model context | Enterprise enrollment cannot silently create a personal profile or expose admin-readable preferences |
| M27 collaboration plan | Planned shared workspace and encrypted operation log | Explicit shared preference/memory scope only if separately enabled | Shared content cannot publish preference policy, infer identity, or become executable instruction |
| M28 Flow plan | Planned typed inputs, SecretRef, run history, and activity admission | Context packet references and explicit Flow input bindings | Flow triggers/results cannot silently train a profile or widen future context |

**Current implementation classification:** Hive has **code-present admission and context primitives**, but not a verified unified personalization or adaptive-context governance system. `HotMemoryStore.didAccessNode` and related signals must not be marketed as a learned personal profile until M29 controls, retention, explanation, and deletion evidence exist.

### 1.2 Authority table

| Concern | Single authority | M29 rule |
|---|---|---|
| Durable memory | Honeycomb/M0–M6 lifecycle | Only user-authored or explicitly promoted objects become durable memory |
| Explicit preference | M29 PreferenceStore projection + EventLedger decisions | User-authored preference wins; every change is inspectable, versioned, and reversible |
| Inferred signal | M29 EphemeralSignalStore | Local-only, purpose-bound, low-retention, bounded, never a durable fact by default |
| Context scope | M10/M26 `ContextScope` intersection | Personalization cannot widen scope or override private/tenant policy |
| Ranking | M29 deterministic ranking policy | Signals influence ordering only within an admitted candidate set |
| Redaction | `ContextRedactor` plus source-specific admission | Redaction happens before model serialization and output; it is not permission |
| Consent | Native UI + EventLedger | Consent is granular, revocable, and never inferred from continued use |
| Deletion | M0–M6 lifecycle/deletion generations | Delete/forget invalidates primary memory and every derived signal/index/cache generation |
| Model routing | Dispatcher/context policy/M26 | Personalization cannot choose an unauthorized provider, model, or remote destination |
| Shared scope | M27 membership/epoch authority | Shared memory/preferences are opt-in typed objects; personal profile remains separate |
| Flow behavior | M28 Flow definition/run authority | Flow output may propose preference changes; it cannot silently write them |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A typed distinction between durable memory, explicit preferences, inferred local signals, and context-packet artifacts.
2. Purpose-bound collection, retention, consent, and deletion metadata for every adaptive object.
3. A user-controlled preference surface with inspect/edit/pause/forget/export behavior.
4. Bounded local adaptive ranking over already-admitted candidates.
5. Explainable context selection with candidate reasons, exclusions, privacy labels, and token/record budgets.
6. Preference precedence and conflict handling across personal, project, workspace, tenant, and shared scopes.
7. Signal decay, TTL, aggregation, and deletion generation semantics.
8. Private browsing, kill-list, sensitive-class, locked, offline, and policy-denied behavior.
9. Local-only evaluation fixtures for retrieval relevance, diversity, freshness, profile leakage, and deletion correctness.
10. Model/provider context disclosure and honest local/remote behavior.

### 2.2 Explicit non-goals

- A hidden “digital twin,” personality score, emotional state, political/health/financial inference, or sensitive identity classifier.
- Cross-application screen surveillance, passive audio capture, keystroke logging, mouse tracking, or covert dwell-time telemetry.
- Automatic durable memory promotion from browsing behavior, model output, or inferred ranking signals.
- Remote user-profile embeddings, cloud behavioral analytics, federated gradient uploads, or personal-model fine-tuning in M29.
- Differential privacy or federated learning as a marketing claim; these may be separately researched, not assumed to solve local governance.
- Personalization that grants permissions, changes trust levels, selects secrets, approves actions, changes retention, or overrides tenant policy.
- Personalized ranking across private profiles, tenants, unrelated workspaces, or shared M27 workspaces without an explicit typed scope.
- A universal “forget everything everywhere” guarantee for copied exports, OS backups, screenshots, or already-decrypted external clients.
- Using inferred signals as factual claims in briefs, tasks, citations, model system prompts, or EventLedger summaries.
- Training or downloading new models as a prerequisite for M29; existing honest local/provider labels remain the runtime boundary.

## 3. Governance object model

### 3.1 Common adaptive envelope

Every preference, inferred signal, profile projection, context packet, and derived ranking artifact carries:

```text
AdaptiveEnvelope {
  object_id: stable native UUID
  object_type: explicit_preference | inferred_signal | preference_projection
    | context_packet | ranking_artifact
  owner_scope: profile | workspace | project | tenant_assigned | shared_workspace
  profile_id: local profile ID
  workspace_id: local workspace ID?
  project_id: local project ID?
  tenant_id: M26 tenant ID?
  purpose: retrieval_ordering | context_budgeting | presentation_default
    | reminder_timing | user_requested_memory
  source_kind: user_authored | explicit_feedback | approved_memory
    | bounded_local_signal | system_default
  source_ids: provenance/event IDs
  content_class: ordinary | sensitive | restricted
  consent_state: not_required | active | paused | withdrawn | expired | denied
  retention: session | bounded_ttl | until_user_forgets | policy_ceiling
  deletion_generation: monotonic generation
  created_at: Date
  updated_at: Date
  expires_at: Date?
  version: Int
}
```

`purpose` is immutable for an object revision. Reusing a retrieval-ordering signal for model training, advertising, remote analytics, or capability selection requires a new explicit purpose and consent; it is not an implicit secondary use.

### 3.2 Three-layer memory model

| Layer | Examples | Default retention | User action | Model authority |
|---|---|---:|---|---|
| **Durable memory** | User capture, approved claim, confirmed task, source-backed note | M0–M6 policy | Inspect/edit/export/forget/delete | Untrusted retrieved data only |
| **Explicit preference** | “Prefer concise briefs,” “keep research local,” project vocabulary, source ranking choice | Until changed/forgotten, policy ceiling | Inspect/edit/pause/reset/export/delete | Cannot change policy/capabilities |
| **Inferred local signal** | Recent query topic, explicit result selection, bounded failed-search rescue signal | Session or short TTL | Inspect signal category/TTL, pause/reset/delete | Ranking hint only; never a fact |

A preference is not a memory claim. A signal is not a preference. A durable source is not permission to use all of its text in every context. The UI and event taxonomy must preserve these distinctions.

### 3.3 Explicit preference schema

```text
Preference {
  preference_id: stable UUID
  key: typed allow-listed key
  value: typed value; no executable text
  scope: profile | workspace | project | flow
  source: user_authored | user_confirmed_proposal
  purpose: typed enum
  precedence: system_safety > tenant_policy > user_project > user_workspace > user_profile > inferred
  version: Int
  status: active | paused | superseded | deleted
  evidence_event_id: EventLedger ID
  created_at/updated_at: Date
}
```

Initial M29 keys are deliberately narrow:

- `response.detail_level`: concise | balanced | detailed;
- `research.source_order`: local_first | selected_domains_first | recency_first;
- `context.include_hot_memory`: on | off;
- `context.default_scope`: current_page | attached_tabs | workspace_memory;
- `memory.auto_candidate_surface`: show | quiet | off;
- `memory.digest_frequency`: off | daily | weekly;
- `ranking.freshness_bias`: low | normal | high;
- `model.remote_inference`: ask_each_time | permitted_for_class | never;
- `accessibility.reduced_motion`: system-derived/user override;
- `privacy.capture_policy`: explicit_only | candidate_review | off.

Preferences cannot contain arbitrary system instructions, shell commands, URLs with credentials, secret values, policy JSON, model prompts, or executable Flow graphs.

### 3.4 Inferred signal schema

```text
InferredSignal {
  signal_id: stable UUID
  signal_type: explicit_result_selection | explicit_dismissal
    | repeated_local_query | recent_scope_use | failed_retrieval
  value: bounded numeric/category value
  source_scope: exact profile/workspace/project/session
  purpose: retrieval_ordering | context_budgeting
  confidence: bounded local score
  expires_at: mandatory Date
  aggregation_bucket: coarse typed bucket
  provenance_event_id: EventLedger ID?
  status: active | decayed | withdrawn | deleted
}
```

M29 does not store raw keystrokes, full query text, screen frames, message bodies, exact dwell duration, or cross-app activity as adaptive signals. Signals may be aggregated into coarse buckets, but aggregation does not make a sensitive source safe automatically. Unknown or sensitive classification is excluded rather than guessed.

## 4. Preference precedence, scope, and conflict

### 4.1 Scope intersection

Personalization is evaluated only after native scope admission:

```text
requested context
  ∩ profile scope
  ∩ active workspace/project scope
  ∩ M26 tenant policy
  ∩ M27 membership/shared scope
  ∩ privacy/private-mode policy
  ∩ M0–M6 memory admission
  ∩ M10/M28 explicit attachment/input
```

A preference can narrow an admitted scope but cannot widen it. For example, “always include my research memory” cannot override a page-only scope, private browsing, tenant denial, deleted state, or a user’s `includesHotMemory = false` choice.

### 4.2 Precedence

Resolution order is deterministic:

1. hard safety/privacy/private-mode denial;
2. M26 tenant policy and M27 membership/data class;
3. user explicit project preference;
4. user explicit workspace preference;
5. user explicit profile preference;
6. system accessibility and platform requirement;
7. bounded inferred signal;
8. static product default.

Conflicts produce an inspectable `preference_conflict` explanation. They never resolve by dictionary order, last-arrival time, model vote, or hidden priority.

### 4.3 Proposal lifecycle

A model, Flow, digest, or teammate surface may propose a preference only as:

```text
proposed → shown_with_reason → user_accepts_or_edits → active
proposed → dismissed | expired
active → paused | edited | deleted | superseded
```

No inferred signal can directly become a preference. User acceptance must record the exact proposed key/value, scope, purpose, and source evidence. A preference proposal must not phrase an inference as a fact (“you are anxious”); it may state a bounded behavior preference proposal (“Use shorter briefs?”).

## 5. Adaptive retrieval and context packet

### 5.1 Candidate admission before ranking

The ranker receives only candidates that already pass:

- M0/M1 complete capture-attempt eligibility;
- M3 candidate exclusion and explicit promotion rules;
- M4 source/version/deletion/temporal validity;
- M5 retention, forgotten, private, and lifecycle filters;
- M6 server-owned scope and redaction boundary;
- M26 tenant/policy ownership and content class;
- M27 membership/epoch/shared-scope checks where applicable;
- current profile/workspace/project/context generation.

Personalization is never an admission bypass. A highly relevant candidate that fails scope, privacy, deletion, or policy admission is not ranked.

### 5.2 Deterministic ranking features

M29 v1 may use only bounded, explainable features:

```text
score(candidate) =
  base_relevance
  + explicit_preference_boost
  + scope_affinity
  + bounded_recency_term
  + user_confirmed_pin_term
  + local_signal_term
  - duplication_penalty
  - stale_penalty
  - uncertainty_penalty
```

Feature weights are versioned and local. The ranker must emit a reason code such as `lexical_match`, `semantic_match`, `same_project`, `explicitly_pinned`, `recently_selected`, `fresh_source`, `stale_penalty`, or `excluded_by_scope`. It must not emit or persist sensitive trait explanations.

A model may propose a ranking, but `RetrievalRankerFilter` and native candidate allow-lists remain authoritative. A malformed, out-of-list, duplicate, or unexplained rank result falls back to deterministic native ordering.

### 5.3 Context packet contract

```text
ContextPacket {
  packet_id: stable UUID
  request_id: stable UUID
  generation: UInt64
  scope_summary: privacy-safe summary
  purpose: answer | brief | research | flow_input | command_preview
  model_destination: local_model | foundation_model | byok_remote | none
  selected_items: [ContextItem]
  excluded_items: [ContextExclusion]
  token_budget: bounded Int
  byte_budget: bounded Int
  redaction_summary: category counts only
  ranking_policy_version: String
  preference_versions: [IDs/versions]
  deletion_generation: UInt64
  created_at: Date
}
```

Each `ContextItem` contains a stable source/object ID, provenance, scope, content class, bounded excerpt or metadata, selection reason, and untrusted-data label. The packet never serializes raw secrets, private content, hidden preference values, or full profile history by default.

The user-visible preview distinguishes:

- **included:** selected and why;
- **excluded:** not selected due to budget/ranking;
- **blocked:** denied by privacy/policy/deletion/scope;
- **withheld:** metadata may be shown but content is unavailable;
- **inferred signal:** a ranking hint, not a memory fact;
- **preference:** user-authored setting affecting the request.

### 5.4 Context budgeting

Budget selection is deterministic and graceful:

1. reserve space for the current explicit user request and required system/tool contract;
2. include mandatory explicitly attached items if admitted;
3. include source evidence required for citations or verifier inputs;
4. rank optional memory/candidate items within the remaining budget;
5. truncate only at safe evidence boundaries; never cut credentials or instruction delimiters;
6. report omissions and budget saturation.

A larger model or remote provider cannot silently receive a wider packet. If the packet cannot fit, Hive returns a bounded `context_budget_exhausted` or asks the user to narrow scope.

### 5.5 Memory as untrusted data

Retrieved memory, preferences, task titles, source text, connector content, and shared M27 operations are data, never system instructions. The packet uses explicit delimiters and provenance labels. Memory text cannot:

- change the current user request;
- publish or modify a Flow;
- grant a tool/capability/permission;
- select a secret or remote destination;
- override M26/M27/M28 policy;
- suppress deletion, auditing, Stop, or verification;
- cause an action merely because it contains imperative language.

## 6. Signals, retention, and deletion

### 6.1 Signal collection rules

Signals are collected only from explicit Hive interactions within an admitted scope:

| Signal | Allowed use | Default retention | Not allowed |
|---|---|---:|---|
| User selects a result | Same-scope relevance boost | 30 days | Cross-profile identity inference |
| User dismisses a candidate | Same-scope suppression | 30 days | “User dislikes topic” claim |
| User explicitly pins/approves | Durable user preference/memory path | Until changed | Automatic promotion without consent |
| Repeated local query bucket | Rescue ranking within same scope | 7 days | Raw query logging or sensitive topic profiling |
| Failed retrieval bucket | Bounded rescue prompt/ranking | 7 days | Emotional/competence inference |
| Current active project | Request-local scope affinity | Session | Durable personality profile |

No signal is collected in private browsing, on kill-list/sensitive surfaces, when adaptive context is paused, or when the user has disabled the relevant purpose. `signal_collection_disabled` is a valid state, not an error.

### 6.2 Decay and aggregation

Signal decay is deterministic and purpose-specific. A signal expires by TTL or deletion generation, whichever comes first. Aggregates retain only coarse buckets and source-scope IDs; they do not preserve raw event text. Explicit preferences and pinned durable memory are not decayed by inferred signal logic.

M29 does not use “importance” as an opaque universal score. Any retention or rescue decision must identify whether it came from explicit approval, user pin, lifecycle policy, or bounded local signal. Explicit user deletion outranks every inferred score.

### 6.3 Deletion and consent withdrawal

A user can separately:

- pause adaptive ranking;
- pause inferred signal collection;
- reset ranking signals for the current scope;
- edit/delete explicit preferences;
- forget a durable memory/source;
- clear a session’s context packet history;
- revoke remote-model permission;
- delete a profile/workspace scope.

Each operation creates a deletion/consent generation. The generation invalidates signal rows, preference projections, ranking caches, HotMemory entries, context packets, vector/FTS-derived results where applicable, pending M28 Flow inputs, and M6/M27 projections according to their authorities. Stale results are withheld or marked deletion-pending; they are never silently reused.

Deletion reports distinguish `requested`, `queued`, `applied_local`, `awaiting_sync`, `blocked_by_policy`, `failed`, and `verified_local`. M29 does not claim removal from copied exports, OS backups, external clients, or previously decrypted plaintext.

### 6.4 Lock/offline/restart

- Locked/Keychain-unavailable: no new sensitive personalization reads; ordinary browsing remains usable; in-memory signals are cleared or held according to their class.
- Offline: local explicit preferences and eligible local ranking may work; remote policy/connector/profile claims are stale-labeled; no cloud profile sync is assumed.
- Restart: ephemeral signals are restored only if their retention class explicitly permits it and deletion generation matches; otherwise they are discarded.
- Policy unavailable: high-risk/remote/tenant-scoped personalization fails closed; local user-authored preferences may remain usable if their local scope is valid.
- Private mode: no durable memory, preference learning, signal collection, ranking reinforcement, or digest output from private content.

## 7. Model routing and privacy boundary

### 7.1 Local-first routing

Local deterministic retrieval, explicit preferences, and bounded context assembly occur before model invocation. On-device models receive only the admitted `ContextPacket`. `isRealInference`, provider, model, and remote/local state remain honest under the existing runtime contract.

M29 personalization cannot:

- select BYOK/cloud routing because a user’s inferred signal “prefers” it;
- send a profile embedding, ranking history, or raw signal log to a remote provider;
- treat a remote answer as permission to retain a new preference;
- use model confidence as proof that personalization is correct.

If remote inference is user-allowed, the UI states provider/model, context classes, retention/transport posture, and whether preferences/signals are included. Default is no remote personalization state.

### 7.2 Foundation/local model boundary

Apple Foundation Models or another local runtime may phrase a frozen packet or classify a bounded proposal, but model output is advisory. A model cannot promote memory, change preference scope, set retention, or create a system rule. Unsupported hardware/OS/model availability yields an honest unavailable/local-fallback state.

### 7.3 No local fine-tuning in M29

M29 does not fine-tune weights on personal data. Personalization is represented as typed preferences, bounded retrieval features, and ephemeral signals so users can inspect, correct, and delete it without model-weight erasure ambiguity. A future adaptation milestone would require a separate data/consent/deletion/evaluation contract.

## 8. User experience and transparency

### 8.1 Memory & Personalization Center

The user-facing surface is organized by control, not by a hidden “profile score”:

- **Remembered:** durable user-approved memories with source/provenance and delete/edit;
- **Preferences:** explicit keys, scope, purpose, current value, history, pause/reset;
- **Recent signals:** coarse categories, scope, expiry, and reset—never raw surveillance logs;
- **Current context:** packet preview for the active request with included/excluded/blocked reasons;
- **Privacy controls:** pause adaptive ranking, disable signal collection, private-mode policy, remote-model policy;
- **Deletion status:** current generation and pending derived-store cleanup;
- **Export:** typed preferences/signals/memory manifest without secret material.

The UI must avoid anthropomorphic claims such as “Hive knows you prefer…” when the evidence is only an inferred signal. Say “Recent local selections are temporarily boosting similar sources” and provide Reset.

### 8.2 Proactive suggestions

M29 allows suggestions only when:

- the suggestion is derived from current explicit scope or an approved durable object;
- it is labeled as a suggestion/proposal;
- it does not require hidden behavioral inference;
- it can be dismissed, paused, and explained;
- it cannot trigger an external action or Flow without M10/M28 approval.

Unknown context suppresses rather than interrupts. There is no “creepy threshold” tuning through more surveillance; reduce collection and improve explicit controls instead.

### 8.3 Accessibility

- Memory, preference, signal, packet, reset, pause, delete, export, and deletion-status paths are keyboard reachable.
- VoiceOver announces object class, scope, purpose, expiry, source, and safe action without reading sensitive content unexpectedly.
- Included/excluded/blocked/withheld/inferred states are semantic and not color-only.
- Reduced Motion removes list/ranking animations without hiding changes.
- Dynamic type and high contrast preserve long explanations, safe cancel, reset, and delete controls.
- Private-mode and adaptive-paused states are visible in text and accessibility labels.

## 9. Evaluation and anti-drift contract

### 9.1 Frozen local evaluation corpus

M29 ranking changes are measured against a versioned, synthetic/local corpus with:

- exact-token, conceptual, temporal, as-of, project, cross-scope, and ambiguous queries;
- explicit preference cases;
- no-preference baseline cases;
- stale/deleted/private/candidate/audit-incomplete records;
- prompt-injection memory/source fixtures;
- profile/workspace/tenant separation fixtures;
- context-budget saturation and citation-required cases.

Metrics include NDCG@k, MRR, Recall@k, precision of admission, exclusion/leakage rate, citation coverage, budget compliance, p50/p95 local latency, and signal-retention/deletion correctness. Report per category and against the deterministic baseline; do not claim universal lift from one aggregate score.

### 9.2 Personalization quality gates

A personalization change must not:

- reduce private/deleted/cross-scope exclusion precision;
- increase unsupported citation or stale-result rates;
- cause context-budget overflow;
- materially regress cold-start/no-preference quality;
- make ranking reasons non-reproducible;
- persist a signal beyond its TTL or deletion generation;
- change output authority, tool permissions, or remote routing.

User feedback may improve ordering only inside the admitted scope. Negative feedback is not a sensitive identity label and must not be reused outside its declared purpose.

### 9.3 Adversarial profile poisoning

Fixtures must include malicious or misleading memory/preferences/source text that attempts to:

- become a system instruction;
- request a tool/capability/secret;
- change a preference or retention value;
- suppress deletion or audit;
- widen context or remote routing;
- create a false user identity or sensitive trait.

The expected result is data-only treatment, safe exclusion/flagging, or user-visible proposal—not authority change.

## 10. Failure matrix

M29 requires deterministic synthetic memory, fake clocks, fake policies, no real browsing history, no real credentials, and no production network.

| ID | Fixture | Required assertion |
|---|---|---|
| M29-01 | Model proposes a durable preference | Remains proposal until explicit user acceptance |
| M29-02 | Inferred signal claims sensitive trait | Rejected; no trait object or explanation |
| M29-03 | Signal from private tab | No signal persisted or ranked |
| M29-04 | Signal from kill-list/sensitive host | No signal persisted or ranked |
| M29-05 | Signal purpose changes from ranking to remote analytics | New consent required; old purpose cannot be reused |
| M29-06 | Signal expires | Excluded from ranking after TTL and restart |
| M29-07 | Signal deletion generation advances | Signal/cache/projection invalidated |
| M29-08 | Preference contains executable text | Validation rejects value/type |
| M29-09 | User preference conflicts with tenant denial | Tenant denial wins and is explained |
| M29-10 | Project preference conflicts with profile preference | Project scope wins deterministically |
| M29-11 | Preference conflicts at equal precedence | Visible conflict; no dictionary-order winner |
| M29-12 | User pauses adaptive ranking | Inferred ranking terms disabled; deterministic baseline remains |
| M29-13 | User pauses signal collection | No new signals; existing signals decay/delete per choice |
| M29-14 | User resets current scope signals | Only selected scope is cleared; other scopes remain isolated |
| M29-15 | User deletes explicit preference | Projection/cache invalidated; no silent recreation |
| M29-16 | Candidate fails M0/M3 admission | Never reaches personalized ranker |
| M29-17 | Deleted source has stale vector/FTS result | Withheld/deletion-pending; no stale content |
| M29-18 | Private source is highly relevant | Excluded despite ranking score |
| M29-19 | Cross-tenant candidate looks relevant | Excluded before ranking |
| M29-20 | M27 shared content arrives | Untrusted data/proposal; no preference or authority change |
| M29-21 | M28 Flow output proposes preference | Requires explicit proposal/acceptance; no silent write |
| M29-22 | Memory contains “ignore policy” instruction | Data-only; policy remains authoritative |
| M29-23 | Preference asks to reveal secrets | Rejected/redacted; no secret access |
| M29-24 | Ranker returns unknown candidate ID | Native allow-list rejects output |
| M29-25 | Ranker returns duplicate/malformed output | Deterministic fallback ordering |
| M29-26 | Ranker gives unexplained boost | Boost rejected or marked untrusted; no hidden score |
| M29-27 | Ranking explanation contains sensitive trait | Redacted; safe reason code required |
| M29-28 | Context packet exceeds token budget | Deterministic truncation/exclusion and visible budget state |
| M29-29 | Explicit attached source exceeds budget | Preserve admitted evidence or ask user to narrow; no silent remote widening |
| M29-30 | Context generation changes mid-request | Stale packet rejected before serialization |
| M29-31 | Redactor finds credential-shaped content | Withheld/redacted before model/output/ledger |
| M29-32 | Remote model disabled | Local/no-model path remains honest and usable |
| M29-33 | BYOK configured but personalization not consented | No profile/signal data sent remotely |
| M29-34 | Model unavailable | Deterministic retrieval/controls remain usable |
| M29-35 | Locked Keychain/policy unavailable | High-risk personalization denied; browser remains usable |
| M29-36 | Offline policy stale | Local allowed preferences only; remote/tenant claims stale/blocked |
| M29-37 | Restart with expired signals | Expired signals not restored |
| M29-38 | Clock rollback during signal expiry | Conservative expiry/epoch reconciliation; no extension of retention |
| M29-39 | Export preferences/signals | Typed manifest excludes secrets/raw queries and includes scope/purpose/TTL |
| M29-40 | Delete scope during ranking | Stale result withheld; deletion generation wins |
| M29-41 | Delete durable memory | Durable node plus derived ranking/context artifacts follow lifecycle report |
| M29-42 | Consent withdrawn mid-request | New packet blocked; stale output suppressed or labeled |
| M29-43 | Pending M28 Flow input contains deleted memory | Flow input invalidated; no stale dispatch |
| M29-44 | M6 client requests personalized profile | Server-owned scope/purpose denies or returns bounded allowed fields only |
| M29-45 | Shared workspace requests personal preference | Scope mismatch; no cross-scope projection |
| M29-46 | Context packet includes hidden preference value | Preview/serialization exposes only allowed reason metadata |
| M29-47 | No-preference cold-start corpus | Baseline remains useful; no fabricated personalization |
| M29-48 | Relevance feedback improves one category but harms another | Report category metrics; no universal-lift claim |
| M29-49 | Signal poisoning via malicious source text | Source remains untrusted; no signal/policy mutation |
| M29-50 | Accessibility/reduced-motion/degraded browser path | Controls remain operable; browsing works with M29 disabled |

The fixture matrix contains **50 cases**. New cases require an update to this plan and all progress mirrors.

## 11. Work packages after approval

### M29-A — Governance objects, purposes, and preference authority

- Freeze `AdaptiveEnvelope`, `Preference`, `InferredSignal`, scope/precedence, purpose, consent, TTL, deletion generation, and proposal schemas.
- Define the separate authorities for durable memory, explicit preferences, inferred signals, and context packets.
- Add validation against executable preference values, sensitive-trait inference, cross-scope writes, and model-authored publication.
- Add M29-01…M29-15 before adaptive ranking is enabled.

**Done when:** users can inspect, edit, pause, reset, export, and delete explicit preferences and signals without changing tool permissions or policy; every object has purpose, scope, retention, and provenance.

### M29-B — Admission, scope intersection, and signal lifecycle

- Reuse M0–M6 admission, M10 explicit attachments, M26 policy, M27 membership, and private/kill-list boundaries before any signal reaches ranking.
- Implement bounded signal collection from explicit Hive interactions only, coarse aggregation, mandatory TTL, decay, restart/lock/offline behavior, and deletion-generation invalidation.
- Keep HotMemory request/session behavior separate from durable personalization state.
- Add M29-16…M29-23 and lifecycle/revocation fixtures before user-facing proactive suggestions.

**Done when:** no private, candidate, deleted, cross-tenant, unknown, or prompt-injected content can create adaptive authority; signal collection can be paused and forgotten by scope.

### M29-C — Deterministic adaptive ranking and context packet

- Define feature allow-list, versioned weights, reason codes, native candidate allow-list, ranking fallback, packet schema, budgets, redaction, and stale-generation handling.
- Keep explicit attachments and citation evidence ahead of optional personalized ranking.
- Ensure model/ranker output remains advisory and cannot choose context outside native admission.
- Add M29-24…M29-34 before adaptive ordering is used in production surfaces.

**Done when:** the same admitted inputs/prefs/signals produce reproducible ordering and a user can see included/excluded/blocked/withheld reasons without leaking hidden profile data.

### M29-D — Model routing, privacy controls, and user-facing transparency

- Add Memory & Personalization Center controls for remembered items, preferences, recent signals, packet preview, remote-model policy, pause/reset, deletion status, and export.
- Bind remote/model routing to M26 policy and explicit destination consent; no personal signal/profile embedding crosses the device in M29.
- Define locked/offline/restart/private/remote-unavailable behavior and accessible degraded states.
- Add M29-35…M29-46 before enabling proactive or Flow-adjacent context behavior.

**Done when:** users can understand and disable adaptive behavior, remote personalization never happens implicitly, and the browser remains complete with M29 unavailable.

### M29-E — Evaluation, poisoning resistance, and integrated deletion

- Freeze the local synthetic evaluation corpus and deterministic ranking baseline; measure NDCG/MRR/Recall, admission leakage, citation coverage, budget compliance, latency, and deletion correctness by category.
- Run profile-poisoning, prompt-injection, scope-conflict, cross-tenant, deletion, consent-withdrawal, and accessibility fixtures.
- Verify M28 Flow inputs, M6 read-only queries, M27 shared content, M10 packets, and M5 lifecycle/deletion cannot bypass M29 governance.
- Add M29-47…M29-50, clean-profile browser-first validation, and fresh evidence before changing any capability label.

**Done when:** personalization improves bounded retrieval/presentation categories without degrading cold-start/privacy/deletion behavior, and no inferred signal becomes authority or an undeclared durable fact.

## 12. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M29-A | Governance schema | Typed durable/preference/signal/packet envelopes with purpose, scope, TTL, consent, provenance, and deletion generation |
| M29-B | Preference authority | Explicit user preferences are inspectable, versioned, reversible, and cannot override safety/policy |
| M29-C | Signal minimization | Only bounded local signals; private/sensitive/cross-scope/covert sources excluded |
| M29-D | Scope/admission | M0–M6/M10/M26/M27 admission precedes ranking; no personalized bypass |
| M29-E | Deterministic ranking | Versioned allow-listed features, stable ordering, reason codes, native fallback |
| M29-F | Context packet | Explicit scope, budget, redaction, provenance, generation, included/excluded/blocked states |
| M29-G | Model privacy | Local-first; no remote profile/signal state without separate visible consent/policy |
| M29-H | Consent/deletion | Pause/reset/withdraw/delete invalidates derived caches/indexes and stale packets |
| M29-I | Retention | Signal TTL/decay and explicit preference/durable-memory retention remain distinct |
| M29-J | Injection resistance | Memory/profile/source/shared text remains untrusted data and cannot alter authority |
| M29-K | Evaluation | Frozen local corpus, category metrics, cold-start baseline, leakage/deletion/latency evidence |
| M29-L | Browser-first release | 50 fixtures, accessibility, private/offline/locked/degraded paths, clean-profile evidence |

M29 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and a clean-profile context journey is demonstrated. A ranker score, preference JSON, memory vector, proactive suggestion, or larger context window alone is `scaffold`/`code-present`, not governed personalization.

## 13. Implementation order and stop conditions

After M0–M28 contracts have fresh evidence:

1. Freeze fake-clock, synthetic-memory, fake-policy, fake-model, fake-connector, and deletion-generation fixtures.
2. Implement M29-A governance schemas and explicit preference lifecycle without adaptive signals.
3. Implement M29-B signal collection/TTL/deletion and scope intersection with ranking disabled by default.
4. Implement M29-C deterministic ranking and context packets over admitted candidates.
5. Implement M29-D controls, routing disclosure, remote-denial, lock/offline/private behavior, and accessibility.
6. Implement M29-E frozen evaluation and poisoning/deletion integration.
7. Enable only read-ordering/presentation adaptation first; keep proactive suggestions disabled until M29-D/E evidence passes.
8. Re-run M5 retention, M6 MCP, M10 Sidecar, M13 task promotion, M26 policy, M27 shared-scope, and M28 Flow-input paths.
9. Record exact evidence and remaining risks in the canonical progress mirrors.

Stop and do not widen scope if:

- a signal is collected from private, sensitive, cross-app, or unknown scope;
- a model/page/connector/shared object can create a durable preference or alter policy;
- a preference can grant permissions, choose secrets, approve actions, or widen context;
- ranking occurs before admission, deletion, tenant, or private-mode filters;
- a deleted/withdrawn signal or memory remains in a cache, vector, FTS result, packet, or Flow input;
- the system describes an inference as a factual user trait;
- remote routing receives profile/signal state without explicit destination consent and M26 policy;
- a ranker can return arbitrary candidates, hidden boosts, or unexplained sensitive reasons;
- context budget overflow silently widens the request or drops required citation evidence;
- adaptive behavior degrades cold-start quality or ordinary browser behavior;
- a proactive suggestion interrupts unknown context or triggers an external action;
- personalization data is used for model training/fine-tuning without a new approved purpose contract;
- M29 claims GDPR/CCPA compliance, DP/FL guarantees, Apple PCC guarantees, or universal deletion beyond measured evidence.

## 14. Explicitly deferred

- Cross-device/cloud profile synchronization and remote user embeddings.
- Federated learning, gradient uploads, local fine-tuning, DPO/RLHF on personal data, and model-weight personalization.
- Sensitive trait/emotion/health/finance/politics/identity inference.
- Cross-application screen/audio/keystroke/dwell surveillance.
- Advertising, engagement optimization, or third-party analytics based on Hive memory/signals.
- Personalized permissions, trust levels, action approvals, Flow policies, retention floors, or model-provider authority.
- Automatic durable memory promotion from inferred signals or model output.
- Public profile sharing, social graph inference, anonymous personalization links, or tenant-wide personal profiles.
- A universal erase guarantee for copied exports, OS backups, external clients, or previously decrypted plaintext.
- Training/downloading models as an M29 prerequisite.

## 15. Evidence references

Privacy, purpose limitation, and deletion:

- [Regulation (EU) 2016/679 — GDPR, Articles 5, 7, and 17](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [European Data Protection Board — General guidance](https://www.edpb.europa.eu/our-work-tools/general-guidance/documents_en)
- [NIST Privacy Framework](https://www.nist.gov/privacy-framework)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)

Local processing and model privacy:

- [Apple — Introducing Apple Foundation Models](https://machinelearning.apple.com/research/introducing-apple-foundation-models)
- [Apple — Private Cloud Compute security research](https://security.apple.com/blog/private-cloud-compute/)
- [Apple — Foundation Models framework](https://developer.apple.com/documentation/foundationmodels)

Retrieval evaluation and injection:

- [NIST Text REtrieval Conference (TREC)](https://trec.nist.gov/)
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-models/)
- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OpenAI — Designing agents to resist prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)

These sources establish privacy, local-processing, evaluation, and threat-model considerations. The M29 object schemas, precedence rules, signal TTLs, context packet, fixtures, gates, and browser-first boundaries are Hive-specific proposed contracts and require implementation evidence before any capability status changes.
