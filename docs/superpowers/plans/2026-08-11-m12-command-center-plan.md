# Hive M12 — Command Center

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M12 Command center
> **Depends on:** M0 storage/recovery, M1 explicit capture, M2 Brief credibility, M3 candidate-only WISP, M4 source versions/diffs/trails/retrieval, M5 digest/retention, M6 read-only MCP/encryption decision, M10 Sidecar B1–B4, M11 Studio loop
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Related contracts:** `docs/superpowers/plans/2026-08-11-m10-sidecar-b1-b4-plan.md`, `docs/superpowers/plans/2026-08-11-m11-studio-loop-plan.md`
> **Primary code seams:** `Sources/HiveCore/Commands/CommandRegistry.swift`, `Sources/Hive/CommandPalette.swift`, `Sources/HiveCore/Browser/OverlayPresentationPolicy.swift`, `Sources/Hive/KeyboardShortcutsPanel.swift`, `Sources/HiveCore/Browser/SearchEngine.swift`, `Sources/HiveCore/Browser/BrowserPageActionPolicy.swift`, `Tests/HiveCoreTests/OverlayPresentationPolicyTests.swift`
>
> M12 makes Hive fast to operate without turning it into a noisy launcher. The Command Center is a local, typed command surface over browser, workspace, memory, and optional extensions. Every visible command has a stable identity, truthful availability, a real executor, a permission class, and an inspectable result. Search, snippets, quick links, and shortcuts are inputs to the same authority—not parallel ad hoc features.

## 0. Decision summary

M12 delivers one coherent command-center journey:

```text
summon command center
  → choose a mode or search local commands/content
    → inspect one typed result and its available actions
      → execute only if available and permitted
        → receive a truthful receipt
          → undo/retry/open details when the contract allows
```

| Slice | User value | Hard boundary |
|---|---|---|
| **C1 — Typed command authority** | Search one reliable catalog instead of a pile of callbacks | Every visible item maps to a stable typed command and registered executor; no no-op rows |
| **C2 — Local modes and ranking** | Find commands, tabs, sources, files, snippets, and links quickly | Prefix modes are explicit; local search is bounded and privacy-safe; no remote suggest by default |
| **C3 — Action panels and receipts** | Discover secondary actions and understand what happened | Actions are typed, availability-checked, permission-gated, and report success/failure from native state |
| **C4 — Shortcuts and invocation** | Build muscle memory without hijacking keys | Contextual shortcuts resolve deterministically; conflicts are surfaced and remappable where supported |
| **C5 — User assets and privacy** | Save quick links/snippets without leaking clipboard or telemetry data | User assets are validated, scoped, versioned, exportable/deletable, and never execute arbitrary pasted code |

M12 is not a general automation marketplace. It does not add unrestricted scripts, shell macros, arbitrary URL schemes, remote telemetry, secret-bearing snippets, blanket global keyboard interception, or automatic AI execution.

## 1. Current code truth

The repository has a substantial but split command surface.

| Existing surface | Current evidence/reuse | M12 gap or qualification |
|---|---|---|
| `CommandRegistry` / `BrowserCommand` | Typed enum and `CommandDefinition` with categories, keywords, shortcuts, slash aliases, collision-resistant alias lookup, and local search | Must become the single command catalog and include executor identity, availability, permission, action metadata, version, and receipt contract |
| `CommandPaletteOverlay` / `PaletteCommand` | Rich closure-built palette with browser actions, page-only gating, panels, profiles, workspaces, skills, split candidates, and custom links | Closure catalog can drift from core registry; must migrate to typed IDs and native executor dispatch; every row needs truthful availability and action metadata |
| `OverlayPresentationPolicy` | Prevents command palette/tab-search overlay collisions through pure state transitions | Must cover command center modes, nested action panels, focus, dismissal, and invocation source |
| `KeyboardShortcutDescriptor` | Codable cross-platform key/modifier descriptor | Needs canonical normalization, scope/context predicates, priority/precedence, conflict report, user override, and global-hotkey denial states |
| `KeyboardShortcutsPanel` | Searchable display reference | Currently states shortcuts cannot be remapped and can drift from actual registrations; M12 must derive it from the registry and show conflict/status |
| `SearchEngine` / `OmnibarInput` | Local-first URL/search resolution and blocked unsafe schemes | M12 quick links must use the same safe URL policy; command search must not accidentally navigate or send a query |
| `BrowserPageActionPolicy` | Pure page eligibility for actions on HTTP(S) pages | Availability must be attached to each command and re-evaluated immediately before execution |
| `SiteSettingsIndex`, `HoneycombStore`, `HotMemoryStore` | Local indexes and memory authorities | M12 must define bounded search adapters and never expose private/candidate/deleted data through a generic launcher result |
| `PolicyEngine` / `EventLedgerStore` | Typed action policy, consent, grants, and audit authority | Command invocation must route consequential actions through M10/M11 approval and ledger contracts; no second command permission system |

**Not verified:** one authoritative catalog driving palette rows, menu commands, slash aliases, shortcut reference, availability, execution, user assets, and receipts. Existing UI presence or a closure that calls a method does not prove a command is real.

## 2. Product contract

### 2.1 Browser-first behavior

- The Command Center is optional, dismissible, and fast. Closing it never alters the active page or loses the query unless the user explicitly dismisses a draft asset.
- `⌘K` is the in-app command-center default only when the app/window is active. A system-wide launcher hotkey is opt-in and must work gracefully when Accessibility/Input Monitoring permission is denied.
- The command surface remains useful with Swarm, Honeycomb, network, MCP, and model runtimes unavailable. Unavailable capabilities are either omitted or shown as clearly disabled with a reason; they are never fake success rows.
- Search and ranking happen locally by default. No keystroke is sent to a remote suggestion endpoint, telemetry service, or model unless a later explicit setting/flow grants it.
- The Command Center does not automatically read the clipboard, current page body, private tabs, or memory. Context attachment remains explicit under M10/M6 policies.
- A command invocation never silently falls through to web search. A separate, visibly labeled “Search the web” mode may construct a safe URL through `OmnibarInput` rules.

### 2.2 User-visible vocabulary

```text
available          — executable in the current scope
unavailable        — known capability cannot run; reason shown
requires_approval  — typed action awaits native approval
blocked            — policy denies execution
conflicted         — shortcut or asset has an unresolved conflict
draft              — user asset is unsaved or uncommitted
preview            — action details shown before execution
running            — native executor has accepted the action
succeeded          — native result verified
failed             — native result failed; no success implied
cancelled          — user/context stopped execution
stale              — result or availability was computed for an older context generation
unsupported        — capability intentionally outside M12 scope
```

No command may display a positive success treatment for `unavailable`, `blocked`, `conflicted`, `failed`, `cancelled`, `stale`, or `unsupported`.

## 3. C1 — Typed command authority

### 3.1 Command definition

`CommandRegistry` becomes the single source of truth for built-in and approved user commands:

```text
CommandDefinition {
  command_id: stable namespace + ID
  title: bounded user-facing title
  subtitle: bounded outcome description
  category: navigation | tab | workspace | memory | studio | utility | user_asset | system
  keywords: normalized local tokens
  icon: semantic icon ID
  executor_id: typed native executor reference
  availability: typed predicate ID + required context keys
  primary_action: typed action kind
  secondary_actions: [typed action IDs]
  permission_class: none | local_read | local_write | browser_act | privileged
  shortcut: ShortcutBinding?
  slash_aliases: unique aliases
  mode_visibility: [command | tab | source | file | snippet | link]
  version: integer
  status: active | deprecated | unsupported | migration_required
}
```

The model, page content, clipboard, and imported user text cannot create an executable `CommandDefinition`. User-defined commands in M12 are validated web quick links or non-executable snippets only; arbitrary native executors require a later extension/permission milestone.

### 3.2 Executor contract

A visible command resolves to a native executor through a stable ID:

```text
CommandExecutor {
  executor_id: stable ID
  accepts: typed argument schema
  availability(context) → Available | Unavailable(reason)
  preview(arguments, context) → CommandPreview
  invoke(arguments, context) → InvocationReceipt
  permission: declared class
  idempotency: idempotent | repeatable | destructive
  cancellation: supported | unsupported
  undo: available | unavailable | partial
}
```

The UI must not store arbitrary `BrowserState` closures as the long-term authority. A migration adapter may wrap existing closures, but each adapter must declare its stable command ID, availability predicate, permission class, and truthful receipt behavior. An adapter that cannot provide a real receipt is not eligible for the visible catalog.

### 3.3 Availability contract

Availability is evaluated in two phases:

1. **Index-time:** cheap, local predicate used for ranking/display.
2. **Invoke-time:** authoritative re-evaluation against current tab/profile/workspace/overlay/privacy generation.

An item whose state changed between display and invocation becomes `stale`, not an accidental action. Page-only commands reuse `BrowserPageActionPolicy`; Studio actions reuse M11 workspace/policy gates; memory actions reuse M0–M6 admission/deletion policy; Sidecar actions reuse M10 approval.

### 3.4 Command lifecycle

```text
registered
  → validated
  → available | unavailable | unsupported | deprecated
  → presented
  → selected
  → availability_recheck
  → preview | blocked | stale | unavailable
  → approved? → invoking
  → succeeded | failed | cancelled | partially_completed
  → receipt_saved
```

No command may be listed as active if its executor is missing, its action is a no-op, its required permission cannot be requested, or its target scope is unknown.

## 4. C2 — Local search and mode contract

### 4.1 Command-center query modes

The input parser exposes explicit modes; ordinary text never changes mode invisibly:

```text
plain text   → Commands + local entities (declared default)
> query      → Commands/actions only
@ query      → Tabs, workspaces, profiles, sources, projects (M10/M6 admission)
# query      → Tags/categories/filters where locally indexed
: query      → State filters (available, recent, private-safe, conflicts)
/alias args  → Exact unique slash command with typed argument parsing
```

`@` must not expose private titles/content or candidate/deleted memory. `#` and `:` are local filters, not remote searches. `/` resolves only a unique registry alias; collisions produce an explanation and no dispatch. Any mode may be dismissed with Escape without executing.

The existing omnibar `/alias` behavior and command-registry slash aliases are migrated to the same parser; duplicate independent parsers are not allowed.

### 4.2 Query model

```text
CommandQuery {
  raw_text: ephemeral local input
  mode: command | entity | tag | state | slash | default
  normalized_query: bounded normalized text
  arguments: typed values?
  active_scope: profile/workspace/tab context
  privacy_class: local_only | explicit_attached_context
  query_generation: UInt64
}
```

The parser never interprets arbitrary URL/query text as executable arguments. Slash arguments are typed and schema-validated; malformed or extra arguments produce a non-executable result.

### 4.3 Ranking

Ranking is deterministic and local:

1. exact command/alias match;
2. prefix match;
3. title/keyword token match;
4. recent successful invocation in the same scope;
5. explicit user pin/favorite;
6. category/context relevance;
7. stable command ID tie-breaker.

Recent use is local product state, not remote telemetry. Private browsing invocations must not reinforce persistent ranking unless the user explicitly opts in; M12 default is no persistence from private context.

The latency target is <50 ms for a warm local palette query on the stated baseline machine. If indexing is unavailable, show a bounded fallback catalog; never block the browser or fabricate search results.

### 4.4 Search adapters

Each local source is a typed adapter with a privacy predicate and bounded result shape:

```text
LocalSearchAdapter {
  adapter_id: commands | tabs | bookmarks | history | sources | workspaces | files | snippets | links
  searchable_fields: bounded metadata fields
  admission(scope) → allowed/blocked
  search(query, limit) → [SearchResult]
  provenance: local source + generation
  deletion_behavior: invalidates result IDs and cached previews
}
```

No generic “search everything” adapter may bypass source-specific admission. M6 MCP remains fixed-method read-only; it is not silently mixed into the launcher.

## 5. C3 — Action panels, previews, and receipts

### 5.1 Result model

```text
CommandResult {
  result_id: stable ID
  command_id: stable command ID
  title/subtitle/icon: bounded display fields
  category: category
  availability: available | unavailable(reason) | stale | blocked
  primary_action: typed invocation descriptor
  secondary_actions: [typed descriptors]
  source: command registry or local adapter
  scope_generation: UInt64
  privacy_label: local | attached | private-excluded
}
```

The primary action uses Enter. A secondary action panel uses a consistent keyboard path (Command-K/right arrow or platform-equivalent) and exposes only actions valid for that result. Action labels name outcomes, not internal tool calls.

### 5.2 Preview contract

Any action with browser mutation, file mutation, memory deletion, external navigation, or privileged permission shows a preview before execution:

```text
CommandPreview {
  command_id: stable ID
  action_id: stable ID
  target: typed bounded target
  scope: profile/workspace/tab/source scope
  expected_effect: bounded outcome
  payload_summary: redacted
  reversibility: reversible | partial | irreversible
  permission: none | approval | privileged
  evidence: IDs/provenance where relevant
  policy_reason: String
  generation: UInt64
}
```

M10/M11 approval and EventLedger are reused. A command center cannot create a second approval or grant system. User assets may require a local draft confirmation but never execute arbitrary code.

### 5.3 Receipt contract

Every invocation produces a truthful native receipt:

```text
InvocationReceipt {
  receipt_id: stable ID
  command_id: stable ID
  action_id: stable ID?
  invocation_source: palette | shortcut | slash | menu | global_hotkey
  started_at: Date
  finished_at: Date?
  state: succeeded | failed | blocked | cancelled | stale | requires_approval
  summary: bounded user-facing result
  affected_scope: bounded IDs/classes
  undo: available | unavailable | partial
  event_id: EventLedger ID?
  error_class: typed error?
  generation: UInt64
}
```

A closure returning `Void` is not proof of success. Commands that open UI should report `presented`, `already_open`, or a typed presentation failure. Commands that navigate should report accepted/blocked/stale; they must not claim page load completion unless the browser lifecycle observes it.

### 5.4 Action-panel state machine

```text
result_focused
  → action_panel_open
  → action_selected
  → preview_required | immediate_safe_action
  → awaiting_approval | invoking
  → succeeded | failed | blocked | cancelled | stale
  → receipt_detail | back_to_results
```

Escape closes the action panel before dismissing the entire Command Center. Focus returns to the result that opened it. Destructive or privileged actions default focus to the safe cancel/deny path.

## 6. C4 — Shortcut and invocation contract

### 6.1 Canonical shortcut binding

```text
ShortcutBinding {
  shortcut_id: stable ID
  command_id: stable command ID
  key: normalized key equivalent
  modifiers: normalized set
  scope: app | window | browser_surface | text_field | command_center | global
  when: typed context predicate
  priority: system | built_in | user | extension
  enabled: Bool
  display_label: localized keycaps
}
```

Modifier order and equivalent key representations normalize to one identity. A global shortcut is a separate capability from an in-app shortcut and requires an explicit permission/availability state.

### 6.2 Resolution precedence

Within a scope, resolution is deterministic:

1. explicit user override;
2. most-specific active context predicate;
3. command-center/modal local binding;
4. built-in browser binding;
5. global binding only when permitted;
6. no match.

A conflict never resolves by dictionary iteration or registration order. Equal-priority/equal-specificity conflicts become visible `conflicted` state and neither command silently wins.

### 6.3 Conflict report

```text
ShortcutConflict {
  normalized_shortcut: String
  scope: ShortcutScope
  contenders: [command IDs]
  winner: command ID?
  reason: user_override | specificity | priority | unresolved
  remediation: disable | remap | narrow_scope | permission_required
}
```

The shortcut panel is generated from this registry, shows active/conflicted/unavailable state, and offers remapping only for commands whose bindings are user-configurable. It must not promise remapping while the UI still says “Shortcuts can’t be remapped yet.”

### 6.4 Global hotkey behavior

- Default M12 scope is app/window; global hotkeys are opt-in and separately documented.
- If Accessibility/Input Monitoring permission is missing or registration fails, the app shows an actionable explanation and keeps the in-app `⌘K` path usable.
- Hive does not silently retry or steal a conflicting global shortcut.
- A global trigger never bypasses profile/private/workspace context or approval policy.
- Permission changes invalidate the hotkey registration state and produce a receipt/diagnostic, not a fake enabled toggle.

## 7. C5 — Snippets, quick links, and user assets

### 7.1 Quick-link contract

```text
QuickLink {
  link_id: stable UUID
  title: bounded display title
  url: normalized http(s) URL
  icon: semantic icon ID
  keywords: normalized tokens
  scope: global | profile | workspace
  created_at/updated_at: Date
  source: user_created | imported | system
  state: active | invalid | blocked | deleted
}
```

Rules:

- Only `http`/`https` quick links are executable in M12; user/password components, `javascript:`, `file:`, `data:`, `blob:`, custom schemes, and unsafe redirects are rejected.
- URLs are parsed and normalized, never concatenated into shell/process arguments.
- A quick link opens through the normal browser navigation policy and returns a navigation receipt.
- Imported links are untrusted data and require validation before presentation; malformed links remain inspectable as invalid, not executable.
- Deletion invalidates cached result IDs and local ranking references.

### 7.2 Snippet contract

```text
Snippet {
  snippet_id: stable UUID
  title: bounded title
  body: bounded plain text or inert markup
  trigger: optional local token
  scope: global | profile | workspace
  source: user_created | imported
  sensitivity: ordinary | sensitive_local
  state: active | blocked | deleted
}
```

M12 snippets are inert text. They cannot execute shell commands, scripts, AppleScript, URLs with hidden action payloads, or privileged operations. Clipboard insertion is explicit, visible, and does not read clipboard contents automatically. Sensitive local snippets are excluded from model context, telemetry, and private-to-persistent ranking by default.

### 7.3 Persistence and deletion

User assets use a versioned local store with atomic writes, schema version, export, deletion, and corruption recovery. Search indexes are rebuildable projections; deleting an asset removes it from results and ranking after the documented generation boundary. Private browsing does not create persistent quick links/snippets unless the user explicitly saves the asset through a labeled action.

## 8. Privacy, security, and authority rules

### 8.1 Authority separation

```text
User input / explicit selection
  → CommandQuery parser
    → CommandRegistry + local adapters
      → availability/policy evaluation
        → preview/approval where required
          → native executor
            → verified receipt + EventLedger evidence
```

Untrusted page text, source text, snippets, clipboard text, imported URLs, model output, and command titles cannot:

- create or modify executable command definitions;
- choose a broader search scope;
- grant Accessibility, file, network, or privileged permission;
- turn a quick link into a script or shell action;
- override shortcut conflict resolution;
- suppress a warning or receipt;
- cause telemetry or remote model transmission;
- approve a destructive action.

### 8.2 Clipboard and telemetry

- No automatic clipboard polling in M12.
- Explicit copy/paste actions disclose the destination and avoid logging the content.
- Invocation evidence stores command IDs, scope classes, result state, and stable local IDs—not raw query text, snippet bodies, clipboard contents, private paths, tokens, or full URLs with sensitive query parameters by default.
- No remote analytics or keystroke telemetry is required for ranking. Any future opt-in diagnostics must redact and state retention.

### 8.3 Deep links and external destinations

M12 quick links use validated HTTP(S) navigation only. Custom schemes and app deep links are unsupported unless a later platform contract establishes ownership, argument validation, and permission boundaries. External URLs are shown with host/safe destination before high-risk navigation; no command center item silently follows an untrusted redirect as if it were the original target.

## 9. Accessibility and interaction contract

- `⌘K` invocation focuses the query field; Escape closes action panel first, then palette, and restores focus to the trigger.
- Arrow keys move through results; Enter executes primary action; the secondary-action shortcut opens the action panel; Tab moves through predictable controls.
- Search result count and mode changes use polite accessibility announcements without announcing every keystroke.
- Every result exposes title, outcome, availability, category, shortcut, privacy label, and action state to VoiceOver.
- Disabled/unavailable commands expose the reason and do not respond as if executed.
- Conflict and permission states are semantic, not color-only.
- Diff/previews, receipts, errors, and undo status are keyboard reachable and have textual alternatives.
- Reduced Motion removes palette/action-panel spring transitions without removing mode or focus state.
- Dynamic type/large accessibility sizes preserve query, results, action panel, safe cancel, and receipt controls without clipping.
- High contrast and keyboard-only paths are supported; hover is enhancement only.
- Global-hotkey permission denial has an accessible explanation and an in-app fallback.

## 10. Failure matrix

M12 requires deterministic local fixtures and no real credentials, clipboard contents, remote telemetry, or production network.

| ID | Fixture | Required assertion |
|---|---|---|
| M12-1 | Registry definition with missing executor | Not presented as available; no invocation |
| M12-2 | Closure-backed palette item with no truthful receipt | Migration warning/hidden; no success claim |
| M12-3 | Page-only command on blank/internal page | Omitted or unavailable with reason; never no-op |
| M12-4 | Tab/profile/workspace changes after result display | Invoke-time recheck marks stale; no wrong-scope action |
| M12-5 | Duplicate command IDs | Registry rejects deterministic collision |
| M12-6 | Duplicate slash aliases | Alias becomes unresolved/conflicted; no dispatch |
| M12-7 | Malformed slash arguments | Non-executable validation error; no partial action |
| M12-8 | `>`/`@`/`#`/`:` mode switching | Mode is explicit, bounded, and query text does not execute |
| M12-9 | Private tab/source/candidate/deleted result | Excluded or labeled blocked; no private content leak |
| M12-10 | Search adapter unavailable | Other local modes remain usable; truthful degraded state |
| M12-11 | Warm local query latency | Palette query meets <50 ms target on baseline fixture corpus |
| M12-12 | Search tie | Stable ID tie-breaker gives deterministic ordering |
| M12-13 | Action panel secondary action unavailable | Omitted/disabled with reason; no dead row |
| M12-14 | Action requires browser/file/privileged permission | Preview and M10/M11 approval path required |
| M12-15 | Action payload changes after preview | Generation/hash mismatch; fresh preview required |
| M12-16 | Executor fails | Failed receipt; no green success or silent fallback |
| M12-17 | Executor is already open/already selected | Idempotent `already_in_state` receipt, not failure/no-op ambiguity |
| M12-18 | Command cancelled during execution | Cancelled receipt; stale completion suppressed |
| M12-19 | Quick link with `javascript:`, `file:`, `data:`, custom scheme, credentials, or unsafe URL | Rejected as invalid/blocked |
| M12-20 | Quick link redirect/host mismatch | Destination shown/blocked according to policy; no hidden redirect |
| M12-21 | Imported malformed quick link | Preserved as invalid data; not executable |
| M12-22 | Snippet contains shell/AppleScript payload | Inert text only; never executed |
| M12-23 | Snippet contains secret-shaped value | Sensitive classification; excluded from context/logging |
| M12-24 | Clipboard contains command or token | No automatic read; explicit paste does not log content |
| M12-25 | Conflicting equal-priority shortcuts | Visible unresolved conflict; no arbitrary winner |
| M12-26 | User override vs built-in shortcut | User override wins only in declared scope; receipt identifies binding |
| M12-27 | Global hotkey permission denied | In-app fallback works; no fake enabled state |
| M12-28 | Global shortcut registration collision | Registration fails visibly; no repeated stealing/retry loop |
| M12-29 | Shortcut panel vs registry drift | Contract test fails; one generated catalog remains authoritative |
| M12-30 | Query/asset contains private path or sensitive URL params | Evidence redacts by policy; no remote telemetry |
| M12-31 | EventLedger unavailable for consequential action | Action blocked; no execution without audit |
| M12-32 | Command center opens while tab search/approval modal is open | Overlay policy preserves focus and prevents stacked modal conflicts |
| M12-33 | Reduced Motion, VoiceOver, dynamic type, high contrast | All essential paths remain operable and understandable |
| M12-34 | Browser/Swarm/model/network unavailable | Core browser commands and local catalog remain usable |
| M12-35 | Corrupt user-asset store/index | Rebuild or safe empty state; no silent data loss |

The fixture matrix contains **35 cases**. New cases require an update to this plan and the progress mirrors.

## 11. Work packages after approval

### M12-A — Command authority and migration adapter

- Freeze `CommandDefinition`, executor IDs, availability/policy descriptors, action metadata, versions, and receipt schema.
- Make `CommandRegistry` authoritative for built-ins, menus, palette, slash aliases, and shortcut reference.
- Inventory every closure-built `PaletteCommand`; migrate or explicitly classify it as unavailable/unsupported before it remains visible.
- Add contract tests that every visible result maps to a registered executor and every executor returns a typed receipt.

### M12-B — Query modes and local adapters

- Freeze the shared query parser for default, `>`, `@`, `#`, `:`, and `/` modes.
- Reuse local SearchEngine/Omnibar safety rules without mixing navigation and command dispatch.
- Add bounded adapters for tabs, workspaces, sources, bookmarks/history, snippets, quick links, and files according to each source’s privacy/admission policy.
- Add deterministic ranking, generation invalidation, latency fixture, private-state exclusions, and unavailable-adapter behavior.

### M12-C — Action panels, previews, receipts, and overlay focus

- Define primary/secondary action descriptors and invoke-time availability rechecks.
- Reuse M10/M11 approval, PolicyEngine, ToolRegistry, EventLedger, and browser action policy.
- Define truthful open/already-open/blocked/stale/failure receipts and cancellation behavior.
- Unify action panel, command palette, tab search, approval, and focus-return policy.

### M12-D — Shortcut registry and conflict resolution

- Freeze normalized bindings, context predicates, precedence, conflict reports, user overrides, and app-vs-global scope.
- Generate KeyboardShortcutsPanel from the authoritative registry; remove “not remappable” copy unless actually true for each binding.
- Implement global hotkey permission-denied and collision fallback without blocking in-app invocation.
- Add shortcut resolution/debug fixtures and accessibility paths.

### M12-E — User assets and clean-profile validation

- Implement validated local quick links and inert snippets with scoped persistence, export/delete, redaction, and rebuildable indexes.
- Keep clipboard interaction explicit and content out of logs/telemetry.
- Run the complete clean-profile path: summon → mode → search → action panel → preview/approval → invocation → receipt/undo.
- Repeat with private browsing, corrupt asset store, blocked deep links, no model/network, denied global hotkey, conflicts, and overlay transitions.
- Record fresh evidence before changing any capability label to verified.

## 12. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M12-A | One typed registry drives visible commands, palette, aliases, menus, and shortcut reference; no no-op command is presented | registry/catalog conformance tests + inventory |
| M12-B | Every command has truthful availability and invoke-time revalidation | availability/action tests across page/profile/workspace states |
| M12-C | Query modes are explicit, local-first, privacy-safe, bounded, and deterministic | parser/adapter/ranking/privacy fixtures |
| M12-D | Warm local command search meets <50 ms baseline target without remote suggest/telemetry dependency | benchmark fixture and local profile run |
| M12-E | Action panels expose only valid typed secondary actions with previews where required | action descriptor/UI tests |
| M12-F | Consequential actions reuse M10/M11 policy, approval, cancellation, and EventLedger authority | admission-order and ledger tests |
| M12-G | Every invocation returns a truthful typed receipt; failed/blocked/stale/cancelled states never look successful | executor/receipt conformance tests |
| M12-H | Shortcut normalization, precedence, user overrides, and conflicts are deterministic and inspectable | shortcut resolver/conflict tests |
| M12-I | Global hotkey denial/collision preserves in-app fallback and never silently steals a shortcut | permission/registration fixtures |
| M12-J | Quick links are validated HTTP(S) navigation only; snippets are inert and safe | asset validation/security tests |
| M12-K | Asset persistence, deletion, export, corruption recovery, and index invalidation are correct | store/rebuild/lifecycle fixtures |
| M12-L | Keyboard, VoiceOver, reduced motion, high contrast, and dynamic-size paths work; clean-profile journey is demonstrated | accessibility matrix + manual evidence |

M12 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence. A palette with search, a shortcut catalog, a list of callbacks, or a fast local filter is `scaffold`/`code-present`, not a verified Command Center.

## 13. Implementation order and stop conditions

After M0–M6, M10, and M11 have fresh evidence:

1. Freeze synthetic command definitions, executor receipts, context states, user-asset, shortcut, and hostile-input fixtures.
2. Implement C1 authority and migrate the closure catalog without adding new capability breadth.
3. Implement C2 shared modes and bounded local adapters.
4. Implement C3 action panels, previews, receipts, cancellation, and overlay focus.
5. Implement C4 shortcut registry, conflicts, settings, and global-hotkey fallback.
6. Implement C5 quick links/snippets persistence and deletion/export.
7. Run M12-1…M12-18 before exposing all actions.
8. Run M12-19…M12-31 before enabling user-created assets or consequential commands.
9. Run M12-32…M12-35 on clean profiles and degraded configurations.
10. Re-run M10 Sidecar and M11 Studio journeys so Command Center invocation cannot bypass their authority.
11. Record exact results and remaining risks in the canonical progress log.

Stop and do not widen scope if:

- a visible command has no typed executor, availability predicate, or truthful receipt;
- a closure/no-op is hidden behind a confident title or shortcut;
- query mode silently widens context or sends keystrokes remotely;
- private/candidate/deleted content appears in generic results;
- a quick link can execute a script/custom scheme or conceal a redirect;
- a snippet can execute code or automatically read/write clipboard content;
- shortcut conflicts resolve by incidental ordering or global permission is faked;
- a command bypasses M10/M11 approval, EventLedger, or cancellation;
- failure, stale state, or cancellation is presented as success;
- the Command Center makes ordinary browsing depend on AI, network, or Accessibility permission.

## 14. Explicitly deferred

- Arbitrary scripts, shell macros, AppleScript, Shortcuts automation, and user-installed executable plugins.
- Remote extension/marketplace command providers and third-party code execution.
- Global hotkeys as a default requirement; Accessibility/Input Monitoring is opt-in only.
- Secret-bearing snippets, password-manager actions, clipboard history, and automatic clipboard polling.
- Remote search suggestions, keystroke analytics, ad ranking, or default cloud telemetry.
- Custom URI-scheme execution and unverified deep-link actions.
- Autonomous AI command selection or model-generated command definitions.
- Purchases, messages, account changes, destructive deletion, and OS-level actions.
- Full file-content search over private/candidate/retained memory without explicit source admission.

## 15. Evidence references

Command-center and keyboard patterns:

- [Raycast keyboard API](https://developers.raycast.com/api-reference/keyboard)
- [Raycast action panels](https://developers.raycast.com/api-reference/user-interface/actions)
- [VS Code keybindings](https://code.visualstudio.com/docs/configure/keybindings)
- [VS Code when-clause contexts](https://code.visualstudio.com/api/references/when-clause-contexts)
- [Chrome DevTools command menu](https://developer.chrome.com/docs/devtools/command-menu)
- [Notion keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts)
- [Alfred fallback searches](https://www.alfredapp.com/help/features/default-results/fallback-searches/)

macOS/accessibility:

- [Apple Human Interface Guidelines — Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
- [Apple Human Interface Guidelines — Keyboard](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [Apple Human Interface Guidelines — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple NSMenu](https://developer.apple.com/documentation/appkit/nsmenu)
- [Apple NSEvent](https://developer.apple.com/documentation/appkit/nsevent)
- [Apple accessibility](https://developer.apple.com/accessibility/)

Security/privacy:

- [RFC 8252 — OAuth native apps](https://www.rfc-editor.org/rfc/rfc8252)
- [OpenSSF Secure Software Development Fundamentals](https://best.openssf.org/secure-software-development-fundamentals/)
- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OWASP LLM02: Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm02-sensitive-information-disclosure/)
- [OpenAI — Designing agents to resist prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)

These sources establish product patterns, accessibility/platform constraints, and threat categories. The M12 command schema, executor/receipt contract, query modes, shortcut resolution, asset model, failure matrix, and exit gates are Hive-specific proposed contracts and require implementation evidence before capability labels change.
