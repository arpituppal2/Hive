import SwiftUI
import CefSwiftUI
import Foundation

// MARK: - HiveChromiumApp
//
// New Chromium-backed Hive browser entry point. This app is intentionally separate from
// the original WKWebView-based Hive target so we can build a real browser from scratch
// without carrying over the AI/archive-first surfaces. It uses CefSwiftUI for Chromium
// rendering and a native SwiftUI chrome shell.

@main
struct HiveChromiumApp: CefSwiftApp {

    /// Custom schemes registered in every CEF process. `hive://` serves the
    /// hand-drawn web chrome (start page) — see WebChromeHandler.swift.
    static var cefConfiguration: CefConfiguration {
        var config = CefConfiguration.default

        // The local smoke harness opts into an isolated CEF root. Chromium's
        // `--user-data-dir` is not mapped by CefSwift to `cef_settings_t`, so
        // the harness must configure CEF's root/cache paths explicitly. This
        // environment override is deliberately opt-in; normal launches keep
        // the production default under Application Support.
        let environment = ProcessInfo.processInfo.environment
        let isReadinessSmoke = environment["HIVE_EMIT_READINESS_MARKER"] == "1"
        if isReadinessSmoke {
            // The isolated CLI smoke process must not block on the user's
            // login keychain while CEF initializes. This is scoped strictly
            // to the readiness harness; normal launches retain CefSwift's
            // automatic secure-storage policy and real Keychain behavior.
            config.safeStorage = .mockKeychain
        }
        if isReadinessSmoke,
           let rootPath = environment["HIVE_CEF_ROOT_CACHE_PATH"],
           !rootPath.isEmpty {
            let root = URL(fileURLWithPath: rootPath, isDirectory: true).resolvingSymlinksInPath()
            let temporaryRoot = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            let rootPath = root.path
            let temporaryPath = temporaryRoot.path.hasSuffix("/")
                ? temporaryRoot.path
                : temporaryRoot.path + "/"
            // This override is exclusively for the local smoke harness. Keep
            // it inside the OS temporary directory and derive the log path so
            // inherited environment variables cannot redirect CEF output or
            // production data to an arbitrary location.
            if rootPath.hasPrefix(temporaryPath) {
                config.rootCachePath = root
                // Leave cachePath nil so CefSwift maps it to the same
                // canonicalized root path. Supplying a sibling URL here can
                // differ only by macOS's /var → /private/var resolution and
                // makes CEF reject an otherwise valid isolated cache.
                config.logFile = root.appendingPathComponent("cef.log", isDirectory: false)
            }
        }

        config.customSchemes = [
            // displayIsolated: hive:// content can only be displayed from
            // same-scheme pages — arbitrary sites cannot iframe the start
            // page (defense in depth on top of the bridge session token).
            CefCustomScheme(name: WebChromeBridge.schemeName,
                            options: [.standard, .secure, .corsEnabled, .fetchEnabled, .displayIsolated])
        ]
        // Debug builds expose DevTools on localhost so the web chrome can be
        // verified headlessly (and inspected) — never shipped enabled.
        #if DEBUG
        config.remoteDebuggingPort = 9223
        #endif
        return config
    }

    @State private var state = ChromiumBrowserState()
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "HiveHasSeenOnboarding")

    var body: some Scene {
        WindowGroup {
            ChromiumBrowserWindow()
                .environment(state)
                .frame(minWidth: 960, idealWidth: 1280, minHeight: 640, idealHeight: 800)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingSheet()
                        .environment(state)
                }
        }
        .commands {
            ChromiumBrowserCommands(state: state)
        }

        Settings {
            ChromiumSettingsView(state: state)
                .frame(width: 620, height: 440)
                .background(.background)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - ChromiumBrowserCommands

struct ChromiumBrowserCommands: Commands {
    @Bindable var state: ChromiumBrowserState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") { state.showFloatingURLBar(opensNewTab: true) }
                .keyboardShortcut("t", modifiers: .command)
            Button("Close Tab") { state.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
            Button("Reopen Closed Tab") { state.reopenLastClosed() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            // Cmd+1-9 tab switching — Chrome-compatible, uses visible tab order
            ForEach(1...min(9, state.visibleTabs.count), id: \.self) { i in
                Button("Tab \(i)") {
                    state.selectTab(id: state.visibleTabs[i-1].id)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i)")), modifiers: .command)
            }
            Divider()
            Button("New Private Tab") { state.newPrivateTab() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            if state.canUseWebPageActions {
                Button("Summarize Page") { state.summarizeCurrentPage() }
                    .keyboardShortcut("s", modifiers: [.option])
            }
            Button("Voice Mode") { state.toggleVoiceMode() }
                .keyboardShortcut("v", modifiers: [.shift, .option])
        }

        CommandGroup(after: .textEditing) {
            Button("Back") { state.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Forward") { state.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("Reload") { state.reload() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Stop") { state.stop() }
                .keyboardShortcut(".", modifiers: .command)
            Divider()
            Button("Show History") { state.isHistoryPanelOpen = true }
                .keyboardShortcut("y", modifiers: .command)
            Button("Show Downloads") { state.isDownloadsPanelOpen = true }
                .keyboardShortcut("j", modifiers: [.command, .shift])
            Divider()
            Button("Focus Address Bar") { state.showFloatingURLBar(prefill: state.activeModel?.url?.absoluteString ?? "", opensNewTab: false) }
                .keyboardShortcut("l", modifiers: .command)
        }

        CommandGroup(replacing: .sidebar) {
            Button("Toggle Tab Layout") { state.toggleLayout() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Toggle Compact Mode") { state.toggleCompactMode() }
                .keyboardShortcut("l", modifiers: [.command, .shift, .option])
            Button("Toggle Bookmarks Bar") { state.showBookmarksBar.toggle() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            Button("Bookmarks Manager") { state.openBookmarksManager() }
                .keyboardShortcut("b", modifiers: [.command, .option])
        }

        CommandGroup(after: .toolbar) {
            Button("Command Palette...") { state.openCommandPalette() }
                .keyboardShortcut("k", modifiers: .command)
            Button("Search Tabs...") { state.openTabSearch() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            if state.canUseWebPageActions {
                Button("Find in Page...") { state.openFindBar() }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                // Page zoom — Chrome/Edge/Safari parity (⌘+ / ⌘- / ⌘0).
                Button("Zoom In") { state.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { state.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { state.resetZoom() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Print...") { state.printCurrentPage() }
                    .keyboardShortcut("p", modifiers: .command)
            }
            Button("Enter Full Screen") { state.toggleFullscreen() }
                .keyboardShortcut("f", modifiers: [.control, .command])

        }

        CommandGroup(replacing: .windowList) {
            Button("Next Workspace") { state.nextWorkspace() }
                .keyboardShortcut("]", modifiers: [.command, .option])
            Button("Previous Workspace") { state.previousWorkspace() }
                .keyboardShortcut("[", modifiers: [.command, .option])
            Divider()
            // Direct-jump Space 1-9 (⌘⌥1-9) — Arc/Zen parity for workspace
            // switching, matching the gradient badges in the vertical sidebar.
            ForEach(Array(state.workspacesForCurrentProfile.enumerated()), id: \.element.id) { index, workspace in
                if index < 9 {
                    Button("Space \(index + 1): \(workspace.name)") {
                        state.switchWorkspace(to: workspace.id)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
                }
            }
            Divider()
            ForEach(state.profiles) { profile in
                Button("Profile: \(profile.name)") { state.switchProfile(to: profile.id) }
            }
            Divider()
            // Zen-parity split shortcuts. ⌃⌥V splits side-by-side (vertical
            // divider), ⌃⌥H splits top-and-bottom (horizontal divider),
            // ⌃⌥U unsplits. Both orientations persist across restarts.
            Button("Split View (Side by Side)") {
                state.splitWithNextTab(orientation: .sideBySide)
            }
            .keyboardShortcut("v", modifiers: [.control, .option])
            Button("Split View (Top and Bottom)") {
                state.splitWithNextTab(orientation: .topBottom)
            }
            .keyboardShortcut("h", modifiers: [.control, .option])
            Button("Unsplit") { state.unsplit() }
                .keyboardShortcut("u", modifiers: [.control, .option])
        }

        // Intercept Cmd+Q: save the session, flush hot memory, then quit cleanly.
        CommandGroup(replacing: .appTermination) {
            Button("Quit Hive") {
                Task { await state.saveNowAndQuit() }
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
