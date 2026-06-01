#if os(macOS)
import AppKit

@MainActor
public enum HiveMacWindowPresenter {
    public static func showMainWindow() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if bringForwardExistingMainWindow() {
            return
        }
        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
        DispatchQueue.main.async {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            _ = bringForwardExistingMainWindow()
        }
    }

    public static func showSettingsWindow() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    public static func presentFieldImportPanel(onSelect: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Import to Field"
        panel.prompt = "Import"
        panel.message = "Choose files or folders to add to Field."
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        onSelect(panel.urls)
    }

    public static func hideInteractiveWindowsKeepingMenuBar() {
        for window in NSApp.windows where isInteractiveWindow(window) {
            window.orderOut(nil)
        }
        NSApp.hide(nil)
    }

    @discardableResult
    private static func bringForwardExistingMainWindow() -> Bool {
        guard let window = NSApp.windows.first(where: { isMainHiveWindow($0) }) else {
            return false
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private static func isMainHiveWindow(_ window: NSWindow) -> Bool {
        guard isInteractiveWindow(window) else { return false }
        return !window.title.localizedCaseInsensitiveContains("settings")
    }

    private static func isInteractiveWindow(_ window: NSWindow) -> Bool {
        let typeName = String(describing: type(of: window))
        guard !typeName.localizedCaseInsensitiveContains("status") else { return false }
        guard !typeName.localizedCaseInsensitiveContains("popover") else { return false }
        return window.canBecomeMain || window.canBecomeKey
    }
}
#endif
