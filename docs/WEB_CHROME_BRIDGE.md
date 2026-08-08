# Web Chrome Bridge (`hive.*`)

The web chrome (`Sources/Hive/WebChrome/`) talks to the native browser through a
token-gated JS ⇄ Swift bridge. **The `api(name, params)` signature is a stable
contract** — extensions and future surfaces build on it. Renaming or removing a
registered method on the Swift side while the JS still calls it silently kills
the feature; `WebChromeBridgeContractTests` guards that direction.

## How it works

1. `Sources/Hive/WebChromeHandler.swift` registers handlers with
   `bridge.register("hive.<domain>.<action>") { (request: SomeDTO) async throws -> Output in ... }`.
2. The web chrome calls `api('hive.<domain>.<action>', params)` → `window.cefSwift.invoke`.
3. Every request carries a `token` validated against the session before any side
   effect runs. Handlers are typed (Codable + Sendable request DTOs) and async.

## Adding a method

1. Define the request DTO (and output type) in the "Bridge DTOs" section of
   `WebChromeHandler.swift`.
2. `bridge.register("hive.yourDomain.yourAction") { ... }`.
3. Call it from the JS as `api('hive.yourDomain.yourAction', { ... })`.
4. Add the name to the `critical` (or tool) set in `WebChromeBridgeContractTests`
   if it is feature-critical.
5. Run `swift test --filter WebChromeBridgeContract`.

## Surface inventory (69 methods)

### AI — council, agent, action

| Method | Purpose |
| --- | --- |
| `hive.conveneCouncil` | Run the model council on a query |
| `hive.dismissCouncilVerdict` | Dismiss the rendered verdict |
| `hive.action` | General action dispatch |
| `hive.agent.run` | Run the agent pipeline (ask box / deep research) |
| `hive.agent.cancel` | Cancel the running agent task |
| `hive.agent.navigate` | Agent-controlled navigation |
| `hive.agent.click` / `fill` / `type` | Agent DOM interaction |
| `hive.agent.read` / `grep` / `evaluate` | Agent page inspection |
| `hive.agent.snapshot` / `screenshot` / `scroll` / `wait` | Agent observation + pacing |
| `hive.agent.reload` | Agent-triggered reload |

### Tabs, groups, workspaces

| Method | Purpose |
| --- | --- |
| `hive.newTab` / `hive.newPrivateTab` | Open a tab (private tabs always land on the start page) |
| `hive.selectTab` / `closeTab` / `closeOtherTabs` / `duplicateTab` | Tab lifecycle |
| `hive.pinTab` / `togglePin` / `toggleEssential` | Tab state |
| `hive.reorderTab` / `toggleSplit` / `reopenClosedTab` | Tab arrangement + recovery |
| `hive.createTabGroup` / `deleteTabGroup` / `renameTabGroup` / `toggleTabGroup` / `moveTabToGroup` / `setTabGroupColor` | Grouping |
| `hive.switchWorkspace` / `createWorkspace` / `deleteWorkspace` | Workspaces |
| `hive.setLayout` | Vertical ⇄ horizontal chrome |

### Navigation

| Method | Purpose |
| --- | --- |
| `hive.navigate` | Load a URL / address-bar submission |
| `hive.back` / `goBack` / `forward` / `goForward` | History |
| `hive.reload` / `stop` | Load control |

### Shell & settings

| Method | Purpose |
| --- | --- |
| `hive.setPanel` / `setChromeDimension` / `toggleCompact` / `toggleFullscreen` | Chrome geometry |
| `hive.newWindow` / `closeWindow` | Window lifecycle |
| `hive.setAccent` | Accent color |
| `hive.openSettingsWeb` / `openSettingsNative` / `openBookmarksManager` | Surface opens |

### Search, omnibox, data

| Method | Purpose |
| --- | --- |
| `hive.getStartData` | Start-page payload (top sites, briefcard) |
| `hive.submit` / `suggest` | Omnibox submit + suggestions |
| `hive.searchHistory` | History search |

### Bookmarks, downloads, sessions

| Method | Purpose |
| --- | --- |
| `hive.toggleBookmark` / `removeBookmark` / `copyLink` | Bookmarks |
| `hive.clearHistory` | History wipe |
| `hive.listDownloads` / `openDownload` | Downloads |
| `hive.snapshotSession` / `restoreSession` / `listSessions` / `deleteSession` | Session control |
