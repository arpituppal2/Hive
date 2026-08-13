# M23 — Mail + Calendar Modules Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M4 provenance/deletion, M5 proposal lifecycle, M6 encryption/Keychain boundary, M10 Sidecar scope/permission previews, M11 approval/workspace boundary, M12 Command Center, M13 Projects/Tasks, M19 Connectors v1, M21 wellness suppression.
> **Scope:** local-first mail indexing and read-only triage, plus a Calendar product module over M19’s read-only source contract; accessible views, provenance, offline states, and explicitly approved draft/mutation proposals.

## 1. Goal

M23 gives Hive a trustworthy local work surface for mail and calendar context. A user can connect a supported mail account through a least-privilege read-only path, search and inspect local message threads, see normalized calendar events, filter or triage work, and turn a source-backed insight into an explicit task or draft proposal without losing provenance.

The product goal is fast, focused triage—not a promise of full Gmail/Outlook/Apple Mail compatibility. “Superhuman-class triage” and “Fantastical-class natural-language parsing” are evaluation targets for bounded fixtures, not permission to send, delete, accept, or modify anything automatically.

M19 owns connector plumbing and read-only Calendar/filesystem source acquisition. M23 owns the mail/calendar product schema, local indexes, views, intent proposals, and user-facing workflows. M23 must not create a second credential or provenance authority.

## 2. Non-goals and explicit deferrals

M23 does not ship autonomous email sending, replying, deleting, moving, archiving, labeling, marking read, calendar creation/editing/deletion, invite acceptance/decline, attendee messaging, arbitrary provider OAuth scope, contact harvesting, full attachment syncing, cloud search as a hidden fallback, or a generic communication automation engine.

Deferred:

- full mailbox write-back and mutation outbox;
- arbitrary IMAP extensions and provider-specific APIs without a scope review;
- Gmail/Outlook restricted or broad mailbox scopes unless separately approved;
- attachment OCR, malware execution, macro interpretation, or remote document fetching;
- passive monitoring of every mailbox or calendar without an explicit account/scope;
- automatic task creation from incoming messages/events;
- model-generated health, legal, financial, or relationship advice from mail/calendar content;
- shared/team mailboxes, delegated accounts, multi-user collaboration, and enterprise retention policy beyond M6/M26 contracts;
- background sync guarantees when the OS, account, or permission state does not allow them.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository has M19’s planned connector lifecycle, Honeycomb `Source`/`Claim` provenance, EventLedger, local retrieval/index seams, Keychain-backed secret patterns, an opt-in/lazy EventKit path for the Morning Brief, task/project promotion contracts, and typed action/approval boundaries. It does not have a verified end-to-end mail account/index/module, a durable IMAP UIDVALIDITY/MODSEQ store, a full message/thread/attachment model, or an M23 mail/calendar UI.

The existing Morning Brief calendar adapter is a bounded opt-in input and is not proof of a complete Calendar module. Existing web-composer promise capture is limited to allow-listed writing surfaces and is not a mail account connector.

### 3.2 Authority table

| Concern | Authority | M23 rule |
|---|---|---|
| Account identity and scopes | M19 connector authority extended by M23 mail account contract | Stable account ID is separate from email address/provider IDs. |
| Credentials/tokens | M6 versioned Keychain authority | Never store tokens in Honeycomb, logs, prompts, URLs, or UserDefaults. |
| Mail sync | MailSyncState/IMAP adapter | UIDVALIDITY, cursor, generation, checkpoint, retry, and deletion are explicit. |
| Calendar sync | M19 Calendar connector | EventKit authorization/change reconciliation remains authoritative. |
| Local index | M23 read model over approved local storage | Index is rebuildable; source/provenance remains canonical. |
| Message/event content | Honeycomb Source/artifact objects | External content is untrusted data, never instructions. |
| Triage/extraction | Deterministic policy + advisory Cell | Proposals cite sources and cannot mutate accounts or tasks silently. |
| Task/project promotion | M13 | Explicit user promotion with source lineage. |
| Draft/send/mutation | M10/M11/M16/M17 typed policy and approval | No send or external mutation from a summary, model output, or menu click alone. |
| Deletion/revocation | M0/M4/M6/M19 lifecycle | Disconnect and forget scopes are separate and reportable. |
| Evidence | EventLedger | Minimal IDs/classes/status; no raw message body or token by default. |
| Browser continuity | Main Hive browser | Account/index failure never blocks browsing or local memory. |

## 4. Account and data-scope model

### 4.1 Mail account identity

A mail account has stable local identity independent from its display address:

```text
account_id: stable UUID
provider_kind: imap | approved_provider_adapter
server_identity_hash: redacted provider/host identity
account_identity_hash: redacted account identity; never used as a secret
mailbox_scope: selected mailbox IDs/names, not implicit all-mail
read_scope: headers | bounded_body | selected_attachment_metadata
write_scope: none in M23 read-only path
credential_ref: Keychain alias only
status: proposed | awaiting_auth | active | paused | stale | revoked | error | deleted
schema_version / scope_version
created_at / updated_at / last_success_at / last_attempt_at
last_error_class / stale_reason / retention_class
```

The default account path is read-only headers plus bounded message text for explicitly selected mailboxes. A user must see mailbox scope, body retention, attachment policy, provider, last sync, and remote-model policy before enabling it.

### 4.2 Calendar product scope

M23 consumes M19 Calendar source objects and adds product views and parsing proposals. It does not request a second Calendar permission or silently expand M19’s selected calendars/fields.

Calendar display scope includes selected calendars, time range, private-event handling, notes/attendee/location classes, timezone behavior, and stale status. Calendar records remain read-only unless a future mutation contract is separately approved.

### 4.3 Content classes

Mail and calendar data are classified before indexing or model context:

```text
metadata: sender/recipient classes, subject/title, dates, flags, provider IDs
body: bounded plain text or sanitized rendered text
attachment_metadata: name/type/size/hash, no body by default
attachment_content: explicit user request and scope only
secret_or_credential: reject/redact
private_or_restricted: policy-controlled, excluded by default from remote context
untrusted_instruction: data label; never authority
```

A user can narrow scope after connection. Narrowing blocks future reads and marks existing content for the selected deletion/retention policy; it does not silently broaden or reinterpret prior consent.

## 5. Mail synchronization and local index

### 5.1 IMAP state contract

For each selected mailbox, persist a typed state:

```text
mailbox_id, account_id, provider_mailbox_identity
uid_validity, uid_next, highest_modseq_optional
last_uid, last_modseq_optional, sync_generation
phase: planned | selecting | fetching | indexing | checkpointing | complete | paused | failed | cancelled
items_seen/created/updated/deleted/skipped
last_success_at / last_progress_at / next_retry_at
last_error_class / retry_count / stale_reason
```

`UIDVALIDITY` is part of message identity. If it changes, cached UIDs for that mailbox are invalidated or quarantined and a bounded full reconciliation is required. UIDs are never treated as globally unique across mailboxes/accounts.

When supported, CONDSTORE/QRESYNC/MODSEQ-style deltas may reduce work, but their availability and server behavior are capability-checked. Unsupported or invalid delta state falls back to an honest bounded reconciliation, not a guessed incremental result.

### 5.2 Transaction and checkpoint behavior

A sync batch commits normalized message metadata, source/version links, FTS rows, and the next checkpoint atomically within the local authority. A crash may replay a batch; account/mailbox/UIDVALIDITY/UID/content-version identity makes replay idempotent.

The cursor never advances past content that was neither admitted nor durably quarantined with a recoverable reason. Cancellation preserves the last committed checkpoint and reports partial progress. Only one writer runs per account/mailbox; concurrent requests coalesce or queue deterministically.

### 5.3 Thread and message model

A normalized message includes:

```text
message_id: stable local ID
account_id / mailbox_id / uid_validity / uid
provider_message_id: optional Message-ID, namespaced
thread_id: deterministic local thread identity
from/to/cc/bcc classes, subject, sent/received dates, flags
body_part_refs, attachment_metadata_refs
source_id + source_version, content_hash, retrieved_at
privacy_class, deletion/tombstone state
```

Threads use `In-Reply-To` and `References` headers first, then a documented normalized-subject fallback. Missing or malformed headers produce an explicit “thread uncertain” state; they never silently merge unrelated conversations.

### 5.4 MIME and attachment safety

MIME parsing is streaming and bounded. It supports a documented subset of multipart/alternative, multipart/mixed, and multipart/related with limits on message size, part count, nesting depth, decoded text size, attachment size, and total account work per run.

HTML bodies are sanitized before rendering. Remote images, scripts, forms, tracking pixels, active content, and unsafe external navigation are disabled or explicitly disclosed. Attachments are metadata-only by default, stored outside the index when explicitly retained, content-hashed, and never executed. Macro/installable/script-like types are quarantined or refused.

## 6. Calendar module and natural-language parsing

### 6.1 Read-only Calendar view

The Calendar module renders M19-normalized events in bounded agenda/day/week views, search, source scope, and project context. It preserves event source/version, calendar identity, timezone, all-day semantics, recurrence summary, private-field policy, and stale/deleted states.

EventKit change notifications are treated as invalidation signals. M23 requests a fresh bounded snapshot/reconciliation through M19 rather than claiming an exact delta token when the platform does not provide one. A removed or permission-revoked event becomes a tombstone/excluded source according to M19 lifecycle rules.

### 6.2 Natural-language parser as proposal generator

The NL parser converts a user-authored request such as “find a time next week for the design review” into a typed, explainable proposal:

```text
intent: search_availability | summarize_schedule | draft_event | other
time_window: explicit instants/timezone or unresolved
participants: user-selected entities or unresolved
constraints: typed predicates
candidate_slots: bounded list with source/event IDs
warnings: timezone/conflict/permission/staleness
requires_mutation: Bool
```

Parsing is advisory. Ambiguous dates, timezones, participants, recurrence, or “next week” boundaries remain unresolved with a clarification path. The parser cannot create, edit, cancel, accept, or notify attendees. A future mutation path requires a typed preview, exact target scope, explicit approval, fresh conflict check, and EventLedger receipt.

### 6.3 Calendar/mail cross-context

A mail thread may be linked to a calendar event only through deterministic provider IDs, explicit headers/URLs, or a user-confirmed relation. Subject/time similarity is a candidate relation, not authority. A model cannot silently join sensitive messages to private events or widen either source scope.

## 7. Triage and advisory intelligence

M23 may offer local, advisory triage:

- unread/important candidate ranking with deterministic tie-breaks;
- thread summarization with source message IDs and stale labels;
- action/proposal extraction such as “reply,” “schedule,” or “review attachment”;
- calendar conflict and preparation suggestions;
- explicit task proposals linked to a message/event source;
- user-authored intent filters over typed metadata.

Triage must distinguish observed facts, inferred proposals, and unresolved ambiguity. It must not mark mail read, move/delete messages, send/reply, accept invites, create tasks, or change calendar state without a separate approved action.

Incoming mail/event content is an indirect prompt-injection surface. The model receives delimited, classified data with source IDs and no authority. Instructions in subjects, bodies, HTML, attachments, signatures, or calendar descriptions cannot change the user’s request, policy, scope, tool registry, or approval state.

## 8. Draft, send, and mutation boundary

### 8.1 Read-only default

The first M23 product path has no outbound mutation. “Reply” and “send” are unavailable or proposal-only. The UI must not display a send button that looks live when the capability is not wired.

### 8.2 Future draft/send shape

If a later milestone admits drafts or send, it must use typed envelopes:

```text
action_id
account_id + mailbox/thread target
recipient set + unresolved recipient warnings
subject/body/attachment references
source/provenance IDs
privacy classification
preview hash and approval_scope_key
send state: proposed | approved | queued | submitted | confirmed | failed | cancelled
```

A draft is not a send. A send requires explicit recipient/body/attachment preview, current account and permission validation, a single-use approval, confirmation/receipt from the provider, duplicate-send protection, and a clear failure/retry state. Calendar mutation follows the same rule and additionally requires conflict/revision checks and attendee disclosure.

No model output, email instruction, calendar invite, or menu-bar preset can approve itself or expand its target.

## 9. Privacy, revocation, and deletion

Disconnecting an account stops reads, invalidates credential references, cancels sync, and prevents automatic reconnect. Forgetting imported data is a separate explicit scope that removes/tombstones messages, events, threads, source/version objects, FTS/vector indexes, caches, attachment blobs, proposals, and pending jobs according to M0/M4/M19 retention policy.

User-authored tasks, briefs, or notes may survive with provenance-degraded markers when the user chooses to retain them; they must not retain hidden message bodies or deleted event content. Revoked source content is excluded from retrieval immediately even if physical cleanup is pending.

Tokens and credentials are Keychain-only. Logs, EventLedger, model context, exports, diagnostics, and UI receipts contain redacted classes/IDs, never raw tokens, passwords, full authentication headers, or unbounded private message bodies.

## 10. Offline, stale, and browser-first behavior

Offline mode provides local search and inspection of the last successful generation with a visible stale timestamp/reason. It never implies that an outbound action succeeded. If a sync is paused, permission denied, UIDVALIDITY changed, or the account is revoked, the user sees the exact state and recovery path.

Calendar/mail failures never block startup, browsing, capture, Sheets, projects, or existing local memory. The module is progressively disclosed from an explicit account/project/calendar action; no first-launch account or Calendar permission prompt is allowed.

## 11. Accessibility and interaction contract

Mail and Calendar views are complete only when keyboard navigation, VoiceOver, Dynamic Type, Increase Contrast, Reduce Motion, and reduced transparency work across empty, loading, stale, denied, error, and large-data states.

Requirements:

- thread rows announce sender/subject/unread/importance/stale state without exposing redacted bodies;
- message headers, body, attachments, source links, and triage proposals have semantic order;
- calendar events announce title/timezone/start/end/conflict/source state and all-day semantics;
- date navigation has stable keyboard shortcuts and visible focus;
- attachment type/size/quarantine state is textually available;
- “proposal,” “draft,” “read-only,” “stale,” and “permission denied” are explicit labels;
- no essential action depends on color, hover, animation, or a collapsed disclosure;
- private/redacted fields remain inaccessible through VoiceOver, copy, previews, and exports;
- long subjects, localized dates, large text, and empty accounts do not clip recovery or scope controls.

## 12. Work packages

### M23-A — Account, schema, and sync authority

Define mail account identity, mailbox/message/thread/attachment models, Calendar product references, UIDVALIDITY/cursor/checkpoint state, scope/version/retention, Keychain references, deletion/tombstone policy, and EventLedger receipts.

**Done when:** two accounts/mailboxes cannot collide, credential data never enters ordinary storage, UIDVALIDITY invalidation is explicit, and read-only scope is enforceable.

### M23-B — Read-only local mail index

Implement bounded IMAP/provider adapter, mailbox selection, local transaction/checkpointing, MIME/thread parsing, FTS/search, stale/offline state, attachment metadata, cancellation, and accessible read-only inbox/thread views.

**Done when:** selected mailboxes can sync idempotently into a local index, restart/replay is safe, hostile MIME/content is bounded/sanitized, and browser operation is unaffected by failure.

### M23-C — Calendar product module

Build agenda/day/week/search views over M19 Calendar sources, timezone/recurrence/private-field display, EventKit invalidation/reconciliation, source inspection, and advisory NL schedule proposals.

**Done when:** a user can inspect selected Calendar data and receive explainable unresolved/candidate-slot proposals without event mutation or scope expansion.

### M23-D — Triage, task proposals, and future draft boundary

Add deterministic metadata filters and advisory summaries/proposals with source citations, prompt-injection fencing, explicit M13 task promotion, and inert future draft/send envelopes. Keep live send/mutate paths unavailable until a separate approval contract exists.

**Done when:** no incoming content can alter authority or mutate mail/calendar/tasks; every proposal identifies facts, inference, uncertainty, source IDs, and target revision/scope.

### M23-E — Integrated privacy, revocation, accessibility, and browser-first validation

Validate account consent, Keychain boundary, mailbox/calendar scope, sync replay, UIDVALIDITY reset, MIME attacks, prompt injection, stale/offline behavior, deletion/revocation, VoiceOver, keyboard, large content, and ordinary browsing with M23 disabled/unavailable.

**Done when:** one bounded read-only mail path and one M19-backed Calendar path work end to end, with no false send/mutation affordance and no cross-account data leakage.

## 13. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M23-01 | First launch | No mail/Calendar permission or account prompt |
| M23-02 | Mail account proposed | Scope/provider/retention preview before auth |
| M23-03 | Mail auth denied | Paused account; browser usable; no prompt loop |
| M23-04 | Two accounts same address label | Stable account IDs prevent collision |
| M23-05 | Credential in log/context | Redacted/rejected; Keychain alias only |
| M23-06 | Mailbox scope selected | Only selected mailboxes sync |
| M23-07 | UIDVALIDITY unchanged | Incremental UID sync applies once |
| M23-08 | UIDVALIDITY changed | Cache invalidated/quarantined; bounded full reconcile |
| M23-09 | MODSEQ supported | Delta path used and checkpointed |
| M23-10 | Delta unsupported/invalid | Honest bounded reconciliation |
| M23-11 | Crash during checkpoint | Last committed state retained; replay idempotent |
| M23-12 | Concurrent mailbox sync | One writer; deterministic coalesce/queue |
| M23-13 | Cancellation | Checkpoint preserved; partial progress visible |
| M23-14 | Duplicate message replay | One stable source/version result |
| M23-15 | Malformed reply headers | Thread uncertain; no silent merge |
| M23-16 | Subject-only thread fallback | Documented fallback; confidence/uncertainty shown |
| M23-17 | Multipart alternative | Plain/sanitized body selection deterministic |
| M23-18 | HTML script/form/remote image | Sanitized/blocked; no active content |
| M23-19 | Oversized MIME/attachment | Bounded refusal/metadata-only state |
| M23-20 | Nested MIME depth attack | Parser stops safely with warning |
| M23-21 | Macro/executable attachment | Quarantined/refused; never executed |
| M23-22 | Attachment metadata search | Searchable metadata without body disclosure |
| M23-23 | Mail body prompt injection | Data-only; no tool/permission effect |
| M23-24 | Calendar selected scope | M19 scope reused; no expansion |
| M23-25 | EventKit change notification | Bounded reconciliation, not fabricated delta token |
| M23-26 | Calendar permission revoked | Stale/paused state; no read |
| M23-27 | Timezone/all-day event | Original timezone and explicit instant semantics |
| M23-28 | Ambiguous “next week” | Unresolved parser proposal; clarification path |
| M23-29 | Calendar conflict proposal | Candidate slots cite event IDs; no mutation |
| M23-30 | Mail/event inferred relation | Candidate relation, not authoritative join |
| M23-31 | Unread triage ranking | Deterministic metadata ranking; no mark-read mutation |
| M23-32 | Intent filter rule | Typed metadata predicate; bounded and local |
| M23-33 | Model summary | Source IDs, stale state, uncertainty included |
| M23-34 | Model proposes task | M13 promotion preview; no silent task |
| M23-35 | Model proposes reply | Inert proposal/unavailable send; no outbound call |
| M23-36 | Incoming message asks command | Remains inert untrusted content |
| M23-37 | Account disconnect | Sync stops; credential reference invalidated |
| M23-38 | Forget account data | Source/index/cache/attachment/proposal deletion report |
| M23-39 | Retain user task after forget | Provenance degraded; deleted content not retained |
| M23-40 | Offline local search | Last generation searchable with stale label |
| M23-41 | Offline send attempt | Clearly unavailable; never claimed successful |
| M23-42 | Revoked source retrieval | Immediate exclusion, cleanup may be pending |
| M23-43 | VoiceOver thread view | Headers/body/attachments/source state announced |
| M23-44 | Keyboard calendar navigation | Dates/events/source inspection reachable |
| M23-45 | Large text/localized dates | Scope/recovery/mutation labels remain reachable |
| M23-46 | Private/redacted field copy | Blocked or scope-confirmed; no leak |
| M23-47 | M23 disabled | Browser, memory, Sheets, projects unaffected |
| M23-48 | Calendar/mail provider unavailable | Honest unavailable state; no fake data |

## 14. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M23-A | Account/scope/credential boundary | Keychain alias, account isolation, scope/revocation tests |
| M23-B | Mail sync truthfulness | UIDVALIDITY/cursor/checkpoint/replay/cancellation evidence |
| M23-C | MIME/thread safety | Bounded parser, sanitization, attachment quarantine fixtures |
| M23-D | Local index/search | Transactional FTS/index, stale/offline, rebuild evidence |
| M23-E | Calendar product module | M19-backed scope, reconciliation, timezone/recurrence/source evidence |
| M23-F | NL parser honesty | Typed proposals, ambiguity/locale/timezone/conflict fixtures |
| M23-G | Triage advisory boundary | No mark/delete/send/mutate from model or content |
| M23-H | Provenance | Message/event/source/version/task proposal lineage |
| M23-I | Prompt-injection isolation | Mail/calendar/attachment content cannot change authority/tools |
| M23-J | Revocation/deletion | Credentials, source/index/blob/cache/proposal cascade evidence |
| M23-K | Accessibility/privacy | Keyboard, VoiceOver, redaction, contrast, dynamic size |
| M23-L | Browser-first/truthful status | Clean-profile path with module disabled and no false send/mutation claim |

## 15. Implementation order and handoff

Implement M23-A before syncing either mail or Calendar product data. Reuse M19’s Calendar connector rather than creating a second EventKit authority. Implement mail read-only indexing before triage or draft proposals. Keep send, reply, calendar mutation, and account write-back unavailable until a separate typed action/approval plan covers provider semantics, duplicate-send protection, conflict checks, and rollback/irreversibility.

The next smallest safe implementation slice is **M23-A: typed mail account/mailbox/message/thread schemas, UIDVALIDITY-aware sync state, Keychain references, and lifecycle fixtures**, with no live provider credentials or background sync. No model training or autonomous communication is part of M23.
