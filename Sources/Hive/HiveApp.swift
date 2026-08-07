import SwiftUI
import HiveCore

// The Hive Browser — single macOS product. Multi-window + restoration arrives later.
// Swarm is integrated inside Hive (home, sidebar, omnibar modes)
// but the agent layer is the owner's lane — the browser never blocks on it.

@main
struct HiveApp: App {

    // The window's observable chrome state. Created once, persisted to disk via ChromePrefsStore
    // (atomic writes, corrupt-file quarantine — never silently discards user data). A fresh
    // install starts with one "New Tab"; the user's prefs (layout, density, search engine) are
    // restored immediately, before the first paint, so layout never "snaps".
    @State private var state: ChromeState
    private let menuBarController = MenuBarController()
    private let servicesProvider = ServicesMenuProvider()

    init() {
        // Load durable prefs synchronously before the UI mounts so the first frame's layout is
        // correct (no "snap" from default to the user's saved layout). loadSync is nonisolated
        // + non-throwing (corrupt files are quarantined; a missing file returns defaults).
        let prefs = ChromePrefsStore.loadSync()
        // Session restore (design doc §9): load the full session the same way — synchronously,
        // before the first paint, so restored tabs/spaces are present immediately. Three
        // outcomes the store distinguishes so Hive never SILENTLY starts fresh over an
        // unreadable session (the crash-only trust contract):
        //   .restored → bring the saved session back; paint it on frame zero.
        //   .none     → no session file (first launch / cleared); seed one new tab.
        //   .corrupt  → unreadable → quarantine it, try the rolling backup, set a recovery
        //               notice so BrowserWindow surfaces "Restore last session vs Start fresh".
        var recovery: SessionRecoveryNotice = .none
        var restoredSession: BrowserSession? = nil
        switch BrowserSessionStore.loadSync() {
        case .restored(let session, _): restoredSession = session
        case .none:                  break
        case .corrupt(_, let backup, _):
            if let backup { restoredSession = backup; recovery = .recoveredFromBackup }
            else { recovery = .lostNoBackup }
        }
        // Open (or create) the durable knowledge + audit stores. These live on disk in
        // the user's Application Support folder and survive across launches.
        let appSupportDir: URL? = {
            guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Hive", isDirectory: true) else { return nil }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }()
        let honeycomb: HoneycombStore? = {
            guard let dir = appSupportDir else { return nil }
            return try? HoneycombStore(path: dir.appendingPathComponent("honeycomb.sqlite").path)
        }()
        let eventLedger: EventLedgerStore? = {
            guard let dir = appSupportDir else { return nil }
            return try? EventLedgerStore(path: dir.appendingPathComponent("event_ledger.sqlite").path)
        }()
        // Locate the Swarm Cell prompt directory. The directory is declared as a SwiftPM
        // resource in Package.swift, so it is copied into the module's resource bundle. A
        // packaged macOS app also keeps it in the main bundle's Resources. We check those
        // first, then fall back to repo-root / executable-relative paths for dev workflows.
        // If no directory is found, the loader stays nil and generation falls back to a bare
        // role prompt (still honest, just less specific).
        let cellPromptLoader: CellPromptLoader? = {
            let candidates: [URL] = [
                // 1. SwiftPM module resource bundle (swift run / Xcode run)
                Bundle.module.url(forResource: "Swarm_System_Prompts", withExtension: nil),
                // 2. Packaged app Resources directory
                Bundle.main.url(forResource: "Swarm_System_Prompts", withExtension: nil),
                // 3. Running from the repo root (legacy dev layout)
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("Swarm_System_Prompts", isDirectory: true),
                // 4. Next to the built executable
                Bundle.main.executableURL?.deletingLastPathComponent()
                    .appendingPathComponent("Swarm_System_Prompts", isDirectory: true),
                // 5. Inside the app bundle Resources directory (legacy path)
                Bundle.main.resourceURL?.appendingPathComponent("Swarm_System_Prompts", isDirectory: true),
            ].compactMap { $0 }
            for candidate in candidates {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                    return CellPromptLoader(promptsDir: candidate)
                }
            }
            return nil
        }()

        let secretStore = KeychainSecretStore()
        let s = ChromeState(prefs: prefs,
                            prefsStore: ChromePrefsStore(),
                            sessionStore: BrowserSessionStore(),
                            honeycomb: honeycomb,
                            eventLedger: eventLedger,
                            secretStore: secretStore,
                            cellPromptLoader: cellPromptLoader)
        if let session = restoredSession, !session.windows.isEmpty {
            s.restore(from: session, recovery: recovery)
        }
        // Always leave the window instantly usable: restore handles the no/empty-session case,
        // but guard any path where restore didn't seed a tab.
        if s.tabs.isEmpty { s.newTab() }
        _state = State(initialValue: s)

        // Wire BYOK if the user has configured a remote model. This is async and must happen
        // after the secret store is available; it updates the shared Dispatcher singleton.
        // refreshBYOKDispatcher is @MainActor because it reads prefs from the observable state.
        Task { @MainActor in await s.refreshBYOKDispatcher() }

        // Compile the built-in content blocker at launch (privacy-first, non-blocking).
        // If compilation fails, the blocker is inert — no blocking, no breakage.
        // The result is cached by WKContentRuleListStore; subsequent launches recompile
        // only after app updates (the store tracks identifier + version).
        Task {
            if s.prefs.contentBlockerEnabled {
                try? await ContentBlockerController.shared.compileBuiltInRules()
            }
        }

        // Install the menu bar item for quick tab/space switching.
        menuBarController.install(with: s)

        // Register macOS Services menu handlers (Open URL in Hive, Search in Hive).
        servicesProvider.register(with: s)

        // Refresh the safe browsing blocklist on launch.
        Task { await SafeBrowsingController.shared.refreshBlocklist() }

        // Schedule the first automatic update check (Sparkle handles scheduling;
        // this is a manual trigger in case Sparkle is not yet linked).
        if UpdateManager.shared.automaticallyChecksForUpdates {
            Task { UpdateManager.shared.checkForUpdates() }
        }

        // Register for memory-pressure notifications to evict panel webviews.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationMemoryPressure"),
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in WebPanelManager.shared.evictAll() }
        }

        // Register for app termination to flush the session synchronously.
        // This ensures tabs/spaces/state are persisted before the process exits,
        // so the next launch can restore exactly where the user left off.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [s] _ in
                MainActor.assumeIsolated { s.flushSessionSync() }
        }
    }

    var body: some Scene {
        WindowGroup {
            BrowserWindow()
                .environment(state)
                .environment(\.hiveChromeState, state)
                .environment(\.webPanelManager, WebPanelManager.shared)
                .preferredColorScheme(state.resolvedColorScheme)
                .frame(minWidth: 960, idealWidth: 1200, minHeight: 640, idealHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            BrowserCommands()
        }

        Settings {
            HiveSettingsView(state: state)
                .preferredColorScheme(state.resolvedColorScheme)
                .frame(width: 600, height: 500)
                .background(Color.hiveBackground)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - BrowserCommands (keyboard parity)
//
// The full switcher-parity keyboard surface so anyone from Chrome/Safari/Arc/Zen/Brave/Firefox
// feels at home on day one. Every shortcut below is also discoverable from the menu bar.
//
//   Tab/window   ⌘T new  •  ⌘W close  •  ⌘⇧T reopen  •  ⌘1–⌘9 select-by-ordinal
//   Navigation   ⌘[ back  •  ⌘] forward  •  ⌘R reload  •  ⌘. stop  •  ⌘L focus address
//   Layout       ⌘⇧L toggle H↔V  •  ⌘⇧[ prev tab  •  ⌘⇧] next tab
//   Find         ⌘F find-in-page overlay bar
//
// ChromeState (non-isolated @Observable) is reached by reading it from the Environment inside
// the Commands body (so we don't stash a non-Sendable class in a struct that crosses isolation).

struct BrowserCommands: Commands {
    var body: some Commands {
        // New Tab / Close / Reopen — flank the existing File menu.
        CommandGroup(after: .newItem) {
            envButton("New Tab", key: "t", mods: .command) { $0.newTab() }
            envButton("New Private Tab", key: "n", mods: [.command, .shift]) { $0.newTab(isPrivate: true) }
            Divider()
            envButton("Close Tab", key: "w", mods: .command) {
                if let id = $0.activeTabID { $0.closeTab(id) }
            }
            envButton("Reopen Closed Tab", key: "t", mods: [.command, .shift]) { $0.reopenLastClosed() }
        }

        // Navigation — back / forward / reload / stop / focus address.
        CommandGroup(after: .textEditing) {
            envButton("Back", key: "[", mods: .command) { $0.requestNav(.back) }
            envButton("Forward", key: "]", mods: .command) { $0.requestNav(.forward) }
            envButton("Reload Page", key: "r", mods: .command) { $0.requestNav(.reload) }
            envButton("Stop", key: ".", mods: .command) { $0.requestNav(.stop) }
            Divider()
            envButton("Focus Address Bar", key: "l", mods: .command) { $0.focusOmnibar() }
        }

        // Spaces — prev/next (⌘⌥[ / ⌘⌥]) and direct-jump by index (⌘⌥1-9).
        CommandGroup(replacing: .sidebar) {
            envButton("Show Previous Space", key: "[", mods: [.command, .option]) { $0.cycleSpaces(forward: false) }
            envButton("Show Next Space", key: "]", mods: [.command, .option]) { $0.cycleSpaces(forward: true) }
            Divider()
            ForEach(1..<10) { idx in
                envButton("Space \(idx)", key: String(idx), mods: [.command, .option]) { state in
                    guard state.spaces.count > idx - 1 else { return }
                    state.switchSpace(to: state.spaces[idx - 1].id)
                }
            }
            Divider()
            envButton("Toggle Tab Layout", key: "l", mods: [.command, .shift]) { $0.toggleLayout() }
            Divider()
            envButton("Capture Page to Hive", key: "s", mods: [.command, .shift]) { $0.captureActivePage() }
            envButton("Toggle Reader Mode", key: "r", mods: [.command, .shift]) { $0.toggleReaderMode() }
            envButton("Toggle Downloads", key: "j", mods: [.command, .shift]) { $0.toggleDownloadsPanel() }
            envButton("Toggle Reading List", key: "l", mods: [.command, .shift]) { $0.toggleReadingListPanel() }
            Divider()
            envButton("Show History", key: "y", mods: .command) { $0.executeCommand(.showHistory) }
            envButton("Toggle Bookmark Bar", key: "b", mods: [.command, .shift]) { $0.executeCommand(.toggleBookmarkBar) }
            envButton("Print Page…", key: "p", mods: .command) { $0.executeCommand(.printPage) }
        }
    }

    // Button that reads ChromeState from the app's commands environment and runs `body($0)`.
    // SwiftUI Commands build on the main actor, so the menu-action closure is main-actor —
    // safe to mutate the observable.
    @ViewBuilder
    fileprivate func envButton(_ title: String, key: String, mods: EventModifiers,
                               _ body: @escaping (ChromeState) -> Void) -> some View {
        Button(title) {
            guard let state = stateEnv else { return }
            body(state)
        }
        .keyboardShortcut(KeyEquivalent(Character(key)), modifiers: mods)
        .environment(\.hiveChromeState, stateEnv)
    }

    @Environment(\.hiveChromeState) fileprivate var stateEnv
}

// MARK: - Environment passthrough for the commands scene
//
// `Commands` is a value type built at scene-init time; it can't legally hold a non-Sendable
// @Observable across its lifetime in a strict-concurrency world. So we thread the shared
// ChromeState through a custom EnvironmentKey that the App seeds once in `.commands { }`.

private struct HiveChromeStateKey: EnvironmentKey {
    static let defaultValue: ChromeState? = nil
}

extension EnvironmentValues {
    var hiveChromeState: ChromeState? {
        get { self[HiveChromeStateKey.self] }
        set { self[HiveChromeStateKey.self] = newValue }
    }
}

// MARK: - WebPanelManager environment key

private struct WebPanelManagerKey: EnvironmentKey {
    static let defaultValue: WebPanelManager = WebPanelManager.shared
}

extension EnvironmentValues {
    var webPanelManager: WebPanelManager {
        get { self[WebPanelManagerKey.self] }
        set { self[WebPanelManagerKey.self] = newValue }
    }
}
