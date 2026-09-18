# BRIDGE-SPEC v2 — the JS↔Swift contract (W1 gate)

One page. The chrome (web) and the shell (native) speak only this. The bridge
contract test enforces both directions; nothing ships that isn't here.

## Transport

- Scheme: `hive://` served by `HiveSchemeHandler` (AppKit-registered via
  `CefRuntime.registerSchemeHandler`, replayed per request-context by vendored CefSwift).
- RPC: `window.hive.call(method, payload) → Promise<Result<JSON>>` — thin shim defined
  in the chrome's own app.js over CefSwift's `cefswift://bridge` transport
  (`bridge.autoInjectsShim = false`; only hive:// pages carry the shim).
- Events (native → web): web polls `hive.events.get {cursor}` every 100ms while
  visible. Response `{cursor, events:[{id, type, payload}]}`. Server keeps a 500-event
  ring buffer per connection audience; events delivered once per cursor advance.

## Envelope

Every request carries `{ token, id?, ...payload }`. Every response is either
`{ ok: true, data }` or `{ ok: false, err: { code, message } }`. One shared error
shape; codes: `unauthorized`, `badPayload`, `notFound`, `invalidURL`, `storeError`,
`busy`, `unknownMethod`.

Auth: two tokens generated per launch, injected into served HTML.
`shellToken` — sidebar chrome document. `pageToken` — app pages loaded as tab content
(`hive://start`, reader view). Mismatched/missing token ⇒ `unauthorized`. Arbitrary
web content can never obtain either (displayIsolated + no shim injection off-origin).

## Methods (dot-delimited, complete list)

| Method | Payload | Result | Notes |
|---|---|---|---|
| `tabs.create` | `{url?}` (http/https/hive-app-routes only) | `{tab}` | activates new tab |
| `tabs.select` | `{id}` | `{tab}` | |
| `tabs.close` | `{id}` | `{ok:true}` | closes window when last tab closes |
| `tabs.list` | `{}` | `{tabs:[{id,url,title,pinned,active}], activeId}` | |
| `nav.go` | `{url}` active tab | `{ok:true}` | http/https whitelist; internal routes explicit |
| `nav.back` / `nav.forward` / `nav.reload` | `{}` | `{ok:true}` | no-op-safe at history edges |
| `omnibox.submit` | `{text}` | `{action:"navigate"|"search", url?}` | URL-detect vs search fallback (search = captures+history query route) |
| `omnibox.suggest` | `{query}` | `{suggestions:[{kind:"history"|"capture"|"bookmark"|"url", title, url}]}` | top 6 |
| `bookmark.add` | `{url,title?}` | `{bookmark}` | persists in SQLite |
| `bookmark.list` | `{}` | `{bookmarks}` | newest first |
| `bookmark.remove` | `{url}` | `{ok:true}` | |
| `capture.request` | `{tabId?}` (default active) | `{status:"started"}` | native runs Readability.js in page context |
| events: `capture.captured` | `{captureId,url,title,wordCount,confidence}` | | pushed event |
| events: `capture.failed` | `{reason:"extraction-empty"\|"timeout", rawFallback?:{text}}` | | UI offers raw-text capture; failed extractions never enter corpus |
| `capture.rawSave` | `{url,title,text}` | `{captureId}` | explicit user-approved raw fallback |
| `ask.request` | `{question}` | `{askId}` | starts grounded streaming answer |
| events: `ask.chunk` | `{askId, delta}` | | streamed tokens |
| events: `ask.done` | `{askId, answer, citations:[{spanId,captureId,quote}], droppedClaims:[...]}` | | terminal |
| events: `ask.refused` | `{askId, flavor:"empty-corpus"\|"no-support", message}` | | terminal |
| `ask.cancel` | `{askId}` | `{ok:true}` | generation must be cancellable |
| `settings.get` | `{keys?}` | `{settings:{...}}` | railCollapsed, tabOrientation, askPanelOpen, telemetryOptIn |
| `settings.set` | `{patch}` | `{settings}` | persisted immediately |
| `session.restore` | `{}` | `{restored:bool, tabs:n}` | replayed after chrome load; tabs persisted in SQLite |
| `events.get` | `{cursor}` | `{cursor, events}` | see Transport |

## State sync

Native pushes `state.changed` events (tabs/title/active changed, capture progress,
model status) instead of web guessing. Web re-fetches the relevant `*.list` on receipt.

## Contract test

`WebChromeBridgeContractTests`: regex-scan `Sources/Hive/WebChrome/app.js` for every
`hive.*` call site AND every `hive.events.get` event-type reference; assert each maps
to a handler registered in `Sources/Hive/Bridge/*.swift` and vice versa. Both
directions, CI merge gate.

## Non-goals

No privileged actions beyond navigation/capture/store/query. No file access, no
downloads API, no extension surface. The ask pipeline cannot fetch URLs or execute tools.
