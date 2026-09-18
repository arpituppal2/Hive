import SwiftUI
import CefSwiftUI
import HiveCore

@main
struct HiveApp: CefSwiftApp {
    @NSApplicationDelegateAdaptor(HiveAppDelegate.self) private var delegate

    static var cefConfiguration: CefConfiguration {
        var config = CefConfiguration.default
        config.customSchemes = [
            CefCustomScheme(name: HiveSchemeHandler.schemeName,
                            options: [.standard, .secure, .corsEnabled, .fetchEnabled, .displayIsolated])
        ]
        #if DEBUG
        if ProcessInfo.processInfo.environment["HIVE_DEBUG_CDP"] == "1" {
            config.remoteDebuggingPort = 9223
        }
        #endif
        return config
    }

    @State private var controller = AppController()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(controller: controller)
                .frame(minWidth: 960, idealWidth: 1280, minHeight: 640, idealHeight: 800)
                .task { await controller.bootstrap() }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            BrowserCommands(controller: controller)
        }
    }
}

@MainActor
final class HiveAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppController.shared?.flushSession()
        return .terminateNow
    }
}

// MARK: - Root layout
//
// One chrome layer: a single left column (hive://chrome ?pane=shell) holding the
// omnibox row + tab list; content fills the remainder; the ask pane is a right
// column of the same document family (?pane=ask), docked, 380px.

struct RootView: View {
    let controller: AppController

    var body: some View {
        HStack(spacing: 0) {
            CefWebView(model: controller.chromeModel)
                .frame(width: controller.railCollapsed ? 34 : 260)
            ZStack {
                ForEach(controller.tabs, id: \.id) { tab in
                    let isActive = tab.id == controller.activeTabId
                    CefWebView(model: tab.model)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if controller.askOpen {
                CefWebView(model: controller.askModel)
                    .frame(width: 380)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: controller.railCollapsed)
        .animation(.easeInOut(duration: 0.2), value: controller.askOpen)
        .environment(controller)
    }
}

// MARK: - Menu-bar keyboard commands (CHROME-SPEC keyboard map)

struct BrowserCommands: Commands {
    let controller: AppController

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") { controller.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Close Tab") { controller.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button("Focus Omnibox") { controller.focusOmnibox() }
                .keyboardShortcut("l", modifiers: .command)
            Button("Reload") { controller.reloadActive() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Back") { controller.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Forward") { controller.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("Bookmark This Page") { controller.toggleBookmarkActive() }
                .keyboardShortcut("d", modifiers: .command)
            Button("Capture Page") { controller.captureActiveTab() }
                .keyboardShortcut("e", modifiers: .command)
            Button("Toggle Ask Panel") { controller.toggleAsk() }
                .keyboardShortcut("k", modifiers: .command)
            Button("Toggle Rail") { controller.toggleRail() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
        }
    }
}
