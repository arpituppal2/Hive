import SwiftUI
import CefSwiftUI
import Foundation

// MARK: - HiveApp
//
// The Hive Browser — Chromium-backed via CefSwiftUI, native SwiftUI chrome shell.
// Built from scratch around CEF 148 (Chromium 148.0.7778.218).

@main
struct HiveApp: CefSwiftApp {

    /// Custom schemes registered in every CEF process. `hive://` serves the
    /// hand-drawn web chrome (start page) — see WebChromeHandler.swift.
    static var cefConfiguration: CefConfiguration {
        var config = CefConfiguration.default

        let environment = ProcessInfo.processInfo.environment
        let isReadinessSmoke = environment["HIVE_EMIT_READINESS_MARKER"] == "1"
        if isReadinessSmoke {
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
            if rootPath.hasPrefix(temporaryPath) {
                config.rootCachePath = root
                config.logFile = root.appendingPathComponent("cef.log", isDirectory: false)
            }
        }

        config.customSchemes = [
            CefCustomScheme(name: WebChromeBridge.schemeName,
                            options: [.standard, .secure, .corsEnabled, .fetchEnabled, .displayIsolated])
        ]
        // DevTools (CDP) is a powerful unauthenticated control surface: any
        // process running as this user can connect to the loopback port and
        // drive the browser. The port is DEBUG-only AND explicitly opted into
        // via HIVE_DEBUG_CDP=1, so routine debug builds and ad-hoc validation
        // bundles stay closed by default.
        #if DEBUG
        if environment["HIVE_DEBUG_CDP"] == "1" {
            config.remoteDebuggingPort = 9223
        }
        #endif
        return config
    }

    @State private var state = BrowserState()
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "HiveHasSeenOnboarding")
    @State private var showCrashReport = false

    init() {
        CrashReporter.install()

        if UserDefaults.standard.bool(forKey: CrashReporter.optInKey),
           CrashReporter.previousCrashLog() != nil {
            _showCrashReport = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            BrowserWindow()
                .environment(state)
                .frame(minWidth: 960, idealWidth: 1280, minHeight: 640, idealHeight: 800)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingSheet()
                        .environment(state)
                }
                .alert("Crash Detected", isPresented: $showCrashReport) {
                    Button("Submit Report") {
                        if let url = CrashReporter.previousCrashLog() {
                            Task { _ = await CrashReporter.submitCrashLog(at: url) }
                        }
                        CrashReporter.clearLastCrash()
                    }
                    Button("Don't Send", role: .cancel) {
                        CrashReporter.clearLastCrash()
                    }
                } message: {
                    Text("Hive quit unexpectedly last time. A sanitized crash report is ready to help us fix the issue. No browsing data is included.")
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: Notification.Name("HiveRequestNewWindow")
                )) { _ in
                    NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
                }
        }
        .commands {
            BrowserCommands(state: state)
        }

        Settings {
            SettingsView(state: state)
                .frame(width: 620, height: 440)
                .background(.background)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - BrowserCommands

struct BrowserCommands: Commands {
    @Bindable var state: BrowserState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") { state.showFloatingURLBar(opensNewTab: true) }
                .keyboardShortcut("t", modifiers: .command)
            Button("Close Tab") { state.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
            Button("Reopen Closed Tab") { state.reopenLastClosed() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
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

        // Sparkle updates (disabled when no feed URL is configured —
        // e.g. ad-hoc / debug builds).
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                UpdateManager.shared.checkForUpdates()
            }
            .disabled(!UpdateManager.shared.canCheckForUpdates)
        }

        CommandGroup(replacing: .appTermination) {
            Button("Quit Hive") {
                Task { await state.saveNowAndQuit() }
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
