# Hive M10 — Browser-Native Sidecar B1–B4

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M10 Sidecar B1–B4
> **Depends on:** M0 storage/recovery, M1 explicit capture, M2 Brief credibility, M3 candidate-only WISP, M4 source versions/diffs/trails/retrieval, M5 digest/retention, M6 read-only local MCP/encryption decision
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Existing Sidecar references:** `docs/superpowers/plans/2026-08-11-hive-memory-megaphase.md` Phase B; `docs/superpowers/plans/2026-08-11-hive-memory-tech-notes.md` §6
> **Primary code seams:** `Sources/Hive/GeminiSidePanel+Input.swift`, `Sources/Hive/BrowserState+Gemini.swift`, `Sources/Hive/BrowserState+Research.swift`, `Sources/Hive/GeminiSidePanel+Messages.swift`, `Sources/HiveCore/AI/Search/SwarmResearchSession.swift`, `Sources/HiveCore/AI/Search/CitationFormatter.swift`, `Sources/Hive/ActionApprovalView.swift`, `Sources/Hive/BrowserState+Approval.swift`
>
> M10 is the first browser-native action surface built on the memory wedge. It makes Swarm useful beside the page without granting it ambient authority. The sidecar shows exactly what context is attached, which sources support an answer, what the system is doing, and what action requires approval. It remains safe and useful when memory, models, MCP, network, or the browser page are unavailable.

## 0. Decision summary

M10 delivers four tightly coupled browser-sidecar capabilities:

| Slice | User value | Hard boundary |
|---|---|---|
| **B1 — Explicit tab references** | Ask about selected tabs without copy/paste | Only explicitly attached tabs/sources enter the request; no silent all-tabs expansion |
| **B3 — Citation hardening** | Trust an answer because each citation resolves to a retained Source | A citation token is not rendered as verified until it resolves to stored provenance |
| **B2 — Step disclosure + kill switch** | Understand and stop long-running research/action sessions | Stop is an infrastructure cancellation/revocation path, not a conversational request |
| **B4 — Permission preview cards** | See and approve the exact browser/file/code action | No consequential action executes before policy, preview, and durable consent |

The implementation order is intentionally **B1 → B3 → B2 → B4**:

1. Define the context attachment contract before adding more sidecar behavior.
2. Make citations resolve to stored Sources before displaying research confidence.
3. Add disclosure and cancellation around an already scoped, grounded session.
4. Add permission cards only after the sidecar can show the exact context and evidence behind an action.

M10 is not a general autonomous computer-use milestone. It does not add arbitrary shell/file tools, external desktop control, all-tabs ambient memory, MCP writes, automatic task promotion, or hidden browser automation.

## 1. Current code truth

The existing repository contains partial state plumbing and approval primitives, not a verified M10 journey.

| Existing surface | Current evidence/reuse | M10 gap or qualification |
|---|---|---|
| `BrowserState.deepResearchStep` | Existing research state exposes phases and is carried through WebChrome DTOs | Must become a complete, cancellable, accessible sidecar timeline with terminal states |
| `SwarmResearchSession` | Existing research/session abstraction | Must bind every session to request, context, storage, policy, and cancellation generations |
| `submitGeminiQuery` | Existing submission path in `BrowserState+Gemini.swift` | Must require explicit attachment/scope data; no implicit widening from current tabs or history |
| `tabPill` | Existing sidecar input UI in `GeminiSidePanel+Input.swift` | Must represent server-owned tab/source attachments and removal/inspection states |
| `ContextScope` | Existing profile/workspace/project/private admission policy | Must be serialized as a preview-safe request scope and intersected with attachments |
| `ContextRedactor` | Existing secret redaction, truncation, sensitivity labels, instruction fencing | Must run on sidecar-visible excerpts and citation evidence before rendering or model transfer |
| `CitationFormatter` | Existing search/citation formatting seam | Must resolve citation IDs to stored Source/SourceVersion provenance, not parse labels alone |
| `SourceAndClaim` / Honeycomb | Existing source and claim authority | Must provide an explicit resolved/unverified/deleted citation state |
| `ResponseLifecycleToken` | Existing response supersession token | Must be joined with context/session/cancellation generations before output or action execution |
| `BrowserState+Approval` | Existing typed action approval, EventLedger decision recording, session grants | Must add per-kind preview renderers, exact scope keys, kill-switch revocation, and no ghost pending state |
| `ActionApprovalView` | Existing T0–T5 cards and diff/check previews | Must display evidence, target scope, reversibility, policy reason, and accessible focus behavior per action kind |
| `EventLedgerStore` | Existing audit/consent event authority | M10 must define idempotent sidecar session, cancellation, citation, approval, and revocation event taxonomy |

**Not verified:** a full `@tab → scope preview → grounded answer → resolved citation → disclosed steps → stop/revoke → permission preview → approved action` path. Source presence and mock research output do not satisfy M10.

## 2. Product contract

### 2.1 Browser-first behavior

- The sidecar is optional and dismissible. Closing it never closes tabs or cancels unrelated browser navigation.
- With Swarm disabled, the browser continues navigation, tabs, private browsing, imports, and ordinary start-page behavior.
- If the model, Honeycomb, EventLedger, MCP, or network is unavailable, the sidecar reports a typed unavailable/degraded state and never invents a citation, step, completion, or action result.
- A sidecar request does not automatically capture a page. Explicit capture remains M1’s user-authored durability boundary.
- A tab mention attaches a bounded context reference. It does not grant permission to navigate, click, fill, download, execute, or read unrelated tabs.

### 2.2 User-visible vocabulary

The UI must distinguish these states:

```text
attached       — selected and eligible for this request
excluded        — user removed or policy excluded
private        — private content is not available to this request
unavailable    — page/source cannot be read or has no retained evidence
candidate      — review-only candidate; not model-admissible by default
unverified     — citation or claim has no retained source proof
resolved       — citation maps to a retained Source/SourceVersion
stale          — source exists but the requested version/generation changed
cancelled      — user or context transition stopped the session
blocked        — policy or storage denied the operation
complete       — terminal success with evidence and output state
```

Never use a green success treatment for `unverified`, `unavailable`, `cancelled`, `blocked`, or `deletion_pending`.

## 3. B1 — Explicit tab references and scope preview

### 3.1 Input syntax and attachment model

The sidecar input may support `@` autocomplete for open tabs, captured Sources, and explicitly granted workspace/project scopes. The parser is a UI convenience; the authoritative attachment is a typed value created only after selection.

```text
TabAttachment {
  attachment_id: stable UUID
  tab_id: browser tab ID
  profile_id: profile ID
  workspace_id: workspace ID
  project_id: project ID?
  observed_url: redacted URL metadata
  source_id: retained Source ID?
  source_version_id: retained SourceVersion ID?
  title: bounded redacted title
  privacy: public | private | blocked | unavailable
  capture_state: not_captured | captured | candidate | deleted | unavailable
  selected_at: Date
}
```

Rules:

- The parser never treats arbitrary text after `@` as an attachment. Only a selected chip creates an attachment.
- Attachment IDs are not sufficient authorization; the native side validates that the tab still belongs to the active profile/workspace and that the source remains admissible.
- A tab may be attached with metadata only when no retained Source exists. The UI must label it `not captured`; the request cannot claim source-grounded memory evidence from it.
- A captured Source attachment must pass M1/M4/M5 admission before body text or evidence is assembled.
- A candidate, private, audit-incomplete, forgotten, deleted, or unknown-policy Source may be displayed as unavailable/withheld but cannot enter model context.
- A tab attachment is scoped to one request generation. It is not a persistent grant and cannot be reused by a later request without revalidation.
- Attachments preserve observed and canonical provenance where M4 has both; URL display remains redacted by the existing source policy.

### 3.2 Parser state machine

```text
plain_text
  → mention_query
  → candidate_list
  → selected_attachment
  → attachment_validation
  → attached | excluded | unavailable
```

Required transitions:

- `mention_query → candidate_list`: debounce and filter only currently visible, eligible tab/source metadata.
- `candidate_list → selected_attachment`: user selects a concrete item; keyboard and VoiceOver activation are equivalent.
- `selected_attachment → attachment_validation`: native state validates identity, scope, privacy, capture, and current generation.
- `attachment_validation → attached`: all required checks pass.
- `attachment_validation → excluded/unavailable`: reason is shown without leaking private content or hidden IDs.
- Removing a chip invalidates that attachment for this request and updates the preview before submission.

### 3.3 Scope preview contract

Before submission, the sidecar renders a scope preview that contains categories and counts, not raw page text:

```text
SidecarScopePreview {
  request_generation: UInt64
  profile_label: safe display label
  workspace_label: safe display label
  project_label: safe display label?
  attachments: [AttachmentPreview]
  included_classes: [current_page | retained_source | brief | task | promise_review]
  excluded_classes: [private | candidate | deleted | unavailable | unselected_tab]
  source_count: Int
  evidence_count: Int
  private_content_included: false
  context_budget: {characters: Int, sources: Int}
  policy_revision: String
  state: ready | changed | blocked
}
```

The preview must answer, before submit:

1. Which exact tabs/sources are attached?
2. Which memory classes are included?
3. What is excluded and why?
4. Is any private content included? M10 default: no.
5. What will happen if a source is unavailable or stale?
6. Can the user remove an attachment or clear all context?

The submit path sends the preview’s typed scope and attachment IDs, not the UI’s raw text interpretation. Native validation runs again immediately before context assembly. A preview is informative, not a permission grant.

### 3.4 B1 acceptance gates

- `@` autocomplete shows only concrete, current candidates and never exposes private titles/content in a global list.
- Selecting a tab creates a removable chip with title, host/safe label, privacy state, and capture state.
- A request with no attachments uses the declared default scope only; it does not silently attach the current tab unless the UI explicitly shows that default.
- A request with attachments includes exactly the validated attachment set, modulo deterministic policy exclusions shown in the preview.
- Switching profile/workspace, closing a tab, entering private browsing, deleting a Source, or changing page policy invalidates/revalidates chips before submit.
- Scope preview contains no raw credentials, secret-shaped values, private URLs, hidden IDs, or unbounded page text.
- The request ledger records attachment IDs and scope class, not raw page content.

## 4. B3 — Citation hardening and Source resolution

B3 comes before step/action polish because the sidecar must not visually overstate trust.

### 4.1 Citation authority

A citation marker such as `[1]` is presentation syntax only. A citation is verified only when it resolves to a stored Source or SourceVersion with:

```text
ResolvedCitation {
  citation_id: stable response-local ID
  source_id: retained Source ID
  source_version_id: retained version ID?
  evidence_span_id: exact span ID?
  label: bounded display title/host
  observed_url: redacted URL
  canonical_url: redacted URL?
  retrieved_at: Date
  content_hash: hash
  capture_method: explicit | import | approved_candidate_promotion | other
  source_state: resolved | stale | deleted | unavailable | withheld
  provenance_state: grounded | metadata_only | unverified
  resolver_revision: String
}
```

Rules:

- The response renderer may not convert a numeric marker into a trusted chip by position alone.
- The research/session result must carry citation identity or an explicit unresolved marker; parsing arbitrary model prose is not sufficient evidence.
- `source_id`, version, hash, and evidence span are resolved through typed Honeycomb/Source APIs, never by opening a database path or trusting a URL supplied by model output.
- A resolved citation without an evidence span may be labeled `source resolved; exact span unavailable`; it cannot claim sentence-level proof.
- A URL/title that resembles a source but has no stored identity renders as `unverified`, not as a normal citation.
- Deleted, forgotten, private, candidate, audit-incomplete, stale, or unavailable sources do not render as grounded evidence.
- Citation clicks open the stored Source/Knowledge detail or an explicit unavailable explanation. They do not silently navigate to a live URL and imply current truth.
- The UI distinguishes discovered, read, cited, and retained states.

### 4.2 Resolution pipeline

```text
model/session output
  → parse typed citation references
  → resolve Source/SourceVersion IDs
  → check lifecycle/admission/privacy/deletion generation
  → attach evidence span if retained
  → redact display fields
  → render resolved/unverified/withheld state
  → record citation-resolution summary
```

Resolution is fail-closed for trust labels. If the resolver is unavailable, the answer may remain visible as model output only if the UI clearly marks citations unavailable and no action card treats them as evidence.

### 4.3 Citation interaction

Each citation control must:

- have an accessible name containing source number/label and state;
- be keyboard activatable with Enter/Space;
- expose retrieval time and provenance in a detail popover/panel;
- distinguish `Source`, `Source version`, and `Evidence span` when available;
- return focus to the citation trigger after closing its detail surface;
- never place raw private path/query/credential content into accessibility labels.

### 4.4 B3 acceptance gates

- Every displayed grounded citation resolves to a stored Source ID.
- A spoofed `[1]`, fake title, fake URL, or source-like prose from a page cannot create a resolved citation.
- Source deletion or M5 purge prevents the old citation from rendering as grounded after restart.
- A stale version is labeled stale and links to the retained version detail, not silently upgraded.
- Resolution failures produce a visible warning state and a structured audit result.
- Citation chips are keyboard and VoiceOver usable and remain legible under increased contrast/reduced motion.
- Citation output never widens context or triggers an action.

## 5. B2 — Step disclosure and infrastructure kill switch

### 5.1 Session authority

A Sidecar session has independent generations:

```text
SidecarSession {
  session_id: UUID
  request_generation: UInt64
  context_generation: UInt64
  cancellation_generation: UInt64
  scope_snapshot_hash: String
  policy_revision: String
  state: idle | validating | checking_sources | reading | extracting | synthesizing | awaiting_approval | complete | cancelled | blocked | failed
  active_step: SidecarStep?
  started_at: Date
  finished_at: Date?
}
```

The existing `ResponseLifecycleToken` prevents stale visible responses; M10 must add or compose a session cancellation generation that also invalidates pending research/tool work. `ContextTransitionToken` advances on profile/workspace/tab/privacy transitions. A result is renderable only if all relevant generations still match.

### 5.2 Step model

```text
SidecarStep {
  step_id: stable UUID
  ordinal: Int
  kind: check_scope | check_sources | read_source | extract_claims | synthesize | resolve_citations | request_approval | execute_approved_action
  label: user-facing outcome label
  state: pending | active | complete | skipped | blocked | cancelled | failed
  source_ids: opaque retained IDs only
  started_at: Date?
  finished_at: Date?
  output_summary: bounded safe summary?
  error_class: safe error category?
}
```

Default research disclosure is outcome-oriented:

1. Check scope
2. Check sources
3. Read retained evidence
4. Extract claims
5. Synthesize answer
6. Resolve citations

Tool/action sessions add `Request approval` and `Execute approved action` only when those phases actually occur. The sidecar must not display simulated steps, fake token progress, or an action phase that never ran.

### 5.3 Step disclosure UI

- The active step is visually distinct but not dependent on color alone.
- Completed steps show a concise result and source count where safe.
- A step can expand to show safe metadata, not hidden prompts, credentials, raw page text, or arbitrary shell output.
- Errors identify the failed phase and recovery path: retry, narrow scope, inspect source, or stop.
- The UI distinguishes “waiting for user approval” from “running” and “cancelled.”
- Live updates use polite accessibility announcements and do not interrupt an active VoiceOver utterance for every token.
- Reduced motion removes or simplifies timeline transitions.

### 5.4 Kill-switch contract

The Stop control is not submitted as a model message. It is a native, focusable control that performs this ordered operation:

```text
stop(request)
  1. atomically mark SidecarSession cancellation_generation advanced
  2. cancel the owning Swift task / provider stream
  3. revoke or invalidate pending session-scoped action grants for this session
  4. prevent new tool/action admission for the session
  5. close/abort transport work owned by the session where possible
  6. discard stale response chunks and pending side effects
  7. append minimal cancellation/revocation ledger evidence
  8. publish terminal `cancelled` state
```

Rules:

- The kill switch must work even if the model is ignoring or emitting text.
- A cancelled session cannot resume silently; retry creates a new session and revalidates scope.
- An already committed external side effect cannot be undone by cancellation; the UI must state `stopped after last verified side effect` and expose rollback where the action contract provides it.
- Stop is idempotent. Repeated activation does not create duplicate action records or resurrect work.
- Cancellation must win races against queued execution: the worker checks the session generation immediately before every side effect.
- Revoking a session grant does not delete memory; it prevents further use of the grant.

### 5.5 B2 acceptance gates

- A fixture research run displays only real sequential steps and reaches a truthful terminal state.
- Stop during each active phase prevents later response rendering and tool admission.
- Stop during approval leaves the action unexecuted and records cancellation/denial state.
- Stop during execution prevents the next side effect; already completed effects remain visible with rollback status.
- Tab/profile/workspace/private transitions cancel or invalidate incompatible work and prevent ghost UI in the new context.
- Repeated Stop is safe and idempotent.
- VoiceOver, keyboard, reduced motion, and focus-return paths pass.

## 6. B4 — Permission preview cards

B4 reuses the typed `ToolInvocation`, `PendingAction`, `PolicyEngine`, `ApprovalQueue`, `ActionApprovalView`, and EventLedger seams. It does not introduce a second approval system.

### 6.1 Action preview contract

Every action card must be derived from a typed invocation with:

```text
SidecarActionPreview {
  action_id: UUID
  session_id: UUID
  kind: navigate | tab_group | tab_move | source_open | file_write | code_apply | project_check
  target: bounded typed target
  scope: profile/workspace/project/tab identifiers
  preview: diff | URL transition | tab layout | command + cwd | source detail
  evidence_ids: resolved Source/SourceVersion IDs?
  reversibility: reversible | rollback_available | partially_reversible | irreversible
  trust_level: T0…T5
  policy_decision: allowed | requires_confirmation | denied | escalated
  approval_state: pending | approved | denied | cancelled | expired
  consent_event_id: EventLedger ID?
  policy_revision: String
}
```

No card may be created from a free-form natural-language command alone. The model can propose a typed invocation; native policy validates it before the card is shown.

### 6.2 Per-kind previews

| Action | Preview must show | Default M10 behavior |
|---|---|---|
| Open source | Source label, retained/live distinction, destination, privacy state | T1 or T2 depending on navigation; no hidden live redirect |
| Navigate tab | exact redacted URL/host, current tab, new tab state | confirmation if navigation changes user context or crosses a sensitive host |
| Tab group/move | tab IDs/count, destination group, reversible operation | confirmation; no unlisted tabs included |
| File/code edit | project root, relative path, unified diff, backup/rollback | explicit T3 approval; no write before approval |
| Project check | exact command, bounded working directory, timeout, network policy, expected output | explicit approval unless a future grant explicitly permits the exact scope |
| Source-backed action | evidence IDs and citation resolution state | unresolved citations cannot authorize an action |

Sensitive destinations, authentication forms, purchases, messages, account changes, destructive commands, and OS-level actions are denied or escalated in M10; they are not made safe by a prettier card.

### 6.3 Approval lifecycle

```text
proposed
  → policy_validating
  → denied | escalated | pending_confirmation
  → approved | denied | cancelled | expired
  → executing
  → succeeded | failed | partially_completed | rolled_back
```

Rules:

- EventLedger consent is recorded before execution, as the existing approval path requires.
- Approval is exact: action kind, target, scope, payload hash, policy revision, and session generation are bound to the decision.
- A different URL, path, command, workspace, or payload requires a new card and decision.
- Session grants may only narrow repeated confirmation for an exact structured scope; they never override policy denial, cancellation, or a changed payload.
- Deny, dismiss, close, timeout, revoke, and Stop are distinct states but all prevent execution.
- An approval card never claims success before the bounded executor returns a verified result.
- If EventLedger is unavailable, the action remains pending/blocked and nothing runs.

### 6.4 B4 acceptance gates

- Every action card shows exact target, scope, preview, trust level, policy reason, evidence state, reversibility, and expected side effects.
- A model cannot bypass the card by embedding a command in page text, a citation, or a response token.
- Approval is idempotently recorded before execution.
- Changed payload/path/target/session generation invalidates a prior approval.
- Denied/cancelled/expired actions never reach the executor.
- Action result, failure, partial completion, and rollback state are visible and ledger-linked.
- Accessibility and focus behavior satisfy the same rules as the existing approval panel, including safe initial focus and focus return.

## 7. Cross-cutting context and privacy rules

### 7.1 Admission order

Every Sidecar request follows this order:

1. Parse user input and selected attachment references.
2. Resolve concrete attachments from current browser state.
3. Construct a server/native-owned `ContextScope`.
4. Validate private mode, host policy, profile/workspace/project identity, and tab generation.
5. Resolve retained Sources/SourceVersions through typed stores.
6. Apply M1/M3/M4/M5 `MemoryRetrievalAdmission` and deletion/retention filters.
7. Redact and bound context with `ContextRedactor`.
8. Freeze `scope_snapshot_hash` and context/session generations.
9. Run the model/research session.
10. Resolve citations against stored authorities.
11. Re-check generations and policy before rendering or proposing an action.
12. Require B4 policy/approval before any consequential side effect.

Filtering after ranking or after model generation is insufficient if the excluded data already entered context.

### 7.2 Prompt-injection boundary

Page text, source evidence, titles, citation labels, DOM content, and research results are untrusted data. They may be quoted and attributed but cannot:

- alter the user request;
- select a broader attachment set;
- grant a tool/action permission;
- cause the sidecar to reveal hidden scope or credentials;
- turn an unverified citation into a trusted source;
- disable the kill switch;
- change the approval state;
- request a model/provider escalation.

The sidecar must preserve an explicit separation between user intent, native policy, model proposal, external content, and execution result.

### 7.3 Persistence and audit minimization

Sidecar audit events record stable IDs, scope class, attachment IDs, method/step/action kind, policy decision, result state, and generation metadata. They do not store raw page text, full query text, credentials, hidden prompts, screenshots, or arbitrary command output by default.

Conversation persistence is separate from source durability. A sidecar response may be discarded without deleting a captured Source; deleting a Source must invalidate its citations and dependent sidecar evidence.

## 8. Accessibility and interaction contract

M10 follows Apple HIG, WAI-ARIA/APG, and WCAG-compatible behavior for the sidecar surface:

- The sidecar has a labeled region and a predictable keyboard toggle.
- A transient overlay moves focus to a safe first control and returns focus to its trigger on close; a persistent panel remains in logical navigation order.
- Stop is keyboard reachable, has an accessible name, and is not represented only by an icon or color.
- Step updates use polite live announcements; streaming tokens do not interrupt every screen-reader utterance.
- Citation chips are keyboard activatable and announce source label/state.
- Permission cards expose a clear heading, target, preview, risk/trust label, and Approve/Deny controls.
- Destructive confirmation defaults focus to the safe action and traps focus when modal.
- Reduced Motion disables spring/timeline animation or replaces it with a simple state change.
- Increased contrast does not rely on opacity-only distinctions for attached/excluded/resolved/blocked states.
- Dynamic type or large accessibility sizes preserve access to Stop, source details, and approval buttons without clipping.
- Escape cancels an active session where policy defines it as Stop; otherwise it closes a transient surface without approving anything.

## 9. Failure matrix

M10 requires deterministic fixtures and failure injection. No real credentials, user history, or production network is needed.

| ID | Fixture | Required assertion |
|---|---|---|
| M10-1 | Mention text without selecting a chip | No attachment is created; no tab enters context |
| M10-2 | Selected tab closes before submit | Attachment becomes unavailable; submit revalidates and excludes it |
| M10-3 | Profile/workspace changes after preview | Old preview invalidated; new scope required |
| M10-4 | Private/blocked/unknown-policy tab mention | No private body/title enters context; visible excluded reason |
| M10-5 | Candidate/audit-incomplete/deleted Source attachment | Excluded by shared admission; no retrieval or model context |
| M10-6 | Hostile title/URL/metadata | Redacted/bounded; no secret-shaped value in preview or audit |
| M10-7 | Hidden prompt injection in attached page | Treated as untrusted data; no tool/action/permission change |
| M10-8 | Attachment count/context budget overflow | Deterministic rejection or user-visible truncation; no silent widening |
| M10-9 | Fake `[1]` citation with no Source ID | Warning/unverified state; never grounded |
| M10-10 | Citation points to deleted Source | Deleted/withheld state; no live URL substitution |
| M10-11 | Citation points to stale SourceVersion | Stale state with retained provenance; no silent upgrade |
| M10-12 | Resolver unavailable | Answer marked citation-unavailable; no verified claim/action evidence |
| M10-13 | Real Source ID with spoofed title/URL | Stored provenance wins; spoofed display metadata rejected |
| M10-14 | Research step emits no real work | No simulated completion; truthful unavailable/blocked state |
| M10-15 | Stop during source check | Session cancelled; no later step or stale output |
| M10-16 | Stop during streaming synthesis | Provider/task cancelled; stale chunks discarded |
| M10-17 | Stop during approval | Action remains unexecuted; cancellation/denial recorded |
| M10-18 | Stop races queued executor | Session generation check blocks side effect |
| M10-19 | Stop after one side effect | Later work stops; completed effect and rollback state remain visible |
| M10-20 | Repeated Stop | Idempotent; no duplicate execution or audit confusion |
| M10-21 | Tab switch during response | Context generation invalidates old response; no render in new scope |
| M10-22 | Policy denies action | No card execution; denial evidence recorded |
| M10-23 | EventLedger unavailable before approval | Nothing runs; action remains blocked/pending |
| M10-24 | Changed command/path/URL after approval | Approval hash mismatch; new approval required |
| M10-25 | Page text requests bypass/hidden grant | Native policy ignores content instruction |
| M10-26 | Accessibility keyboard-only path | Attach, preview, cite, Stop, approve, deny, and close all work without pointer |
| M10-27 | Reduce Motion enabled | No required spring/timeline animation; state remains understandable |
| M10-28 | Restore/delete generation changes during response | Old citations/cursors/results rejected or marked deletion-pending |
| M10-29 | Model unavailable | Honest unavailable/degraded response; no fake streaming or citations |
| M10-30 | Browser disabled / sidecar unavailable | Navigation and ordinary browser flows remain usable |

The fixture matrix contains **30 cases**. New cases require an update to this plan and the progress mirror.

## 10. Work packages after approval

### M10-A — B1 attachment and scope contract

- Freeze `TabAttachment`, `SidecarScopePreview`, parser, validation, and request-ledger schemas.
- Reuse existing `tabPill`, `ContextScope`, `ContextScopeSummary`, `ContextRedactor`, and browser profile/workspace state.
- Add no new capture path; use explicit Source IDs and current page metadata only.
- Add B1 privacy, scope, budget, keyboard, and transition fixtures.

### M10-B — B3 citation resolution

- Freeze typed response citation references and `ResolvedCitation` state.
- Implement/verify `CitationFormatter.resolvedCitations` against Source/SourceVersion authorities.
- Define discovered/read/cited/retained state display and deletion/stale behavior.
- Add citation spoofing, resolver failure, keyboard, VoiceOver, and reduced-motion fixtures.

### M10-C — B2 session disclosure and kill switch

- Map actual `SwarmResearchSession`/`deepResearchStep` state to SidecarStep without fabricated phases.
- Compose response, context, and cancellation generations.
- Define native Stop ordering, pending grant invalidation, provider/task cancellation, stale-output rejection, and ledger events.
- Add stop-race, context-transition, restart, and accessibility fixtures.

### M10-D — B4 permission cards

- Extend the existing typed approval surface with per-kind previews, evidence state, reversibility, exact payload hash, and sidecar session identity.
- Reuse `PolicyEngine`, `ToolRegistry`, `PendingAction`, `ApprovalQueue`, `ActionApprovalView`, `EventLedgerStore`, and existing session-grant behavior.
- Keep M10 actions narrow: source open, navigation, tab grouping/move, code edit/check previews only where an existing bounded workspace supports them.
- Add no shell, arbitrary file, purchase, message, account, or desktop-control capability.

### M10-E — Integrated clean-profile validation

- Run the complete B1→B3→B2→B4 path with synthetic retained Sources and an explicit user approval.
- Repeat with private browsing, deletion, restore-generation change, model unavailable, EventLedger unavailable, and browser-disabled modes.
- Verify every visible citation resolves, every step is real, Stop is infrastructure-level, and every action is previewed/audited.
- Record exact runtime evidence before changing any status to verified.

## 11. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M10-A | Attachments are explicit typed references; no silent tab/history/context expansion | parser/admission tests + clean-profile path |
| M10-B | Scope preview is accurate, bounded, privacy-safe, removable, and invalidates on context transitions | scope preview fixtures + UI test |
| M10-C | Every grounded citation resolves to retained Source/SourceVersion provenance or visibly reports unresolved state | citation resolver/conformance tests |
| M10-D | Steps disclose actual work only and expose truthful terminal states | session replay + DTO/UI tests |
| M10-E | Stop cancels/revokes at infrastructure/session level and blocks stale output/side effects | cancellation race tests + manual kill path |
| M10-F | Permission cards show exact target, scope, preview, risk, evidence, reversibility, and policy reason | per-kind preview tests |
| M10-G | Consent is durable before execution; changed payloads require new approval | EventLedger and approval hash tests |
| M10-H | Private, candidate, deleted, stale, unknown, and audit-incomplete content cannot become grounded context/citation/action evidence | adversarial admission fixtures |
| M10-I | Prompt injection cannot widen scope, change permissions, spoof citations, or disable Stop | hostile-page fixtures |
| M10-J | Keyboard, VoiceOver, reduced-motion, contrast, and dynamic-size paths work | accessibility test matrix |
| M10-K | Model/storage/network/provider failures degrade honestly without fake steps/citations/results | failure injection + clean profile |
| M10-L | Browser remains useful with Sidecar disabled, cancelled, blocked, or unavailable | clean-profile browser regression |

M10 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and the full compound path is manually demonstrated. A sidecar mock, a citation parser that only reads `[n]`, a visible Stop button that does not revoke/cancel work, or an approval card disconnected from the executor is `scaffold` or `code-present`, not verified.

## 12. Implementation order and stop conditions

After M0–M6 gates are genuinely evidenced:

1. Freeze synthetic Source/SourceVersion fixtures, tab/profile/workspace fixtures, and hostile-page fixtures.
2. Implement B1 attachment and preview contracts without changing durable capture behavior.
3. Implement B3 resolution and render only stored-source provenance.
4. Implement B2 real step mapping and infrastructure-level cancellation/revocation.
5. Implement B4 per-kind approval previews using the existing policy/approval authority.
6. Run M10-1…M10-14 before enabling any action proposal.
7. Run M10-15…M10-25 before enabling long-running or consequential Sidecar flows.
8. Run M10-26…M10-30 on clean profile and degraded configurations.
9. Run the complete browser regression and evidence path.
10. Record exact results and unsupported claims in the canonical progress log.

Stop and do not widen scope if:

- a request can read an unselected tab or history item;
- an attachment chip is treated as permission without native validation;
- a citation is called grounded without Source identity;
- a Stop request relies on model cooperation or only changes UI state;
- a stale response can render after a tab/profile/workspace transition;
- an action executes before durable approval evidence;
- page text can alter policy, attachments, citations, grants, or Stop behavior;
- a failed resolver, store, provider, or model is presented as success;
- Sidecar implementation makes ordinary browsing depend on Swarm availability.

## 13. Explicitly deferred

- Ambient all-tabs capture or automatic prompt context expansion.
- Screenshot/OCR/VLM capture as a prerequisite for B1–B4.
- MCP write tools or remote MCP clients.
- Shell/file/desktop-control actions beyond existing bounded approval seams.
- Purchases, messages, account changes, password filling, or irreversible actions.
- Background autonomous workflows and scheduled agent execution.
- Automatic task/promise/fact promotion.
- A general browser-extension permission model.
- Sidecar transport changes that require loopback HTTP or a persistent helper.

## 14. Evidence references

Product and browser patterns:

- [Arc Max](https://resources.arc.net/hc/en-us/articles/19335160678679-Arc-Max-Boost-Your-Browsing-with-AI)
- [Claude in Chrome](https://support.claude.com/en/articles/12012173-get-started-with-claude-in-chrome)
- [Perplexity Comet](https://www.perplexity.ai/comet)
- [OpenAI Atlas announcement](https://openai.com/index/introducing-chatgpt-atlas/)
- [Dia](https://www.diabrowser.com/)

Accessibility and interaction:

- [Apple HIG — Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [WAI-ARIA Dialog Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialogmodal/)
- [WAI-ARIA Disclosure Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/)
- [WAI-ARIA Live Regions](https://www.w3.org/WAI/ARIA/apg/practices/live-regions/)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)

Security:

- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OWASP LLM02: Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm02-sensitive-information-disclosure/)
- [OWASP LLM09: Misinformation](https://genai.owasp.org/llmrisk/llm09-misinformation/)
- [OpenAI — Designing agents to resist prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)
- [Anthropic — Computer use](https://docs.anthropic.com/en/docs/agents-and-tools/computer-use)

Coding-agent and permission patterns:

- [Claude Code overview](https://code.claude.com/docs/en/overview)
- [Cursor rules](https://cursor.com/docs/rules)
- [Cline auto-approve](https://docs.cline.bot/features/auto-approve)
- [Aider configuration](https://aider.chat/docs/config.html)
- [GitHub Copilot custom instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)

These sources establish product patterns, accessibility/security guidance, or competitor-reported behavior. The B1–B4 state machines, attachment contracts, citation authority, kill-switch ordering, permission preview schema, failure matrix, and exit gates are Hive-specific proposed contracts and require runtime evidence before capability labels change.
