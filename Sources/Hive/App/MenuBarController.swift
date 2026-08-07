import AppKit
import SwiftUI
import HiveCore

// MARK: - MenuBarController
//
// A lightweight menu bar item providing quick tab and space switching without
// requiring the main window to be frontmost. Inspired by Bartender and Raycast's
// menu bar utilities but scoped to Hive-only controls.
//
// The icon is a small hexagon (Hive's brand mark). The menu shows:
//   1. Active Space name (header, non-clickable)
//   2. Open tabs (title + favicon host, click to switch to that tab)
//   3. Separator
//   4. "New Tab" action
//   5. "Show Hive" action (brings main window to front)

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private var state: ChromeState?

    // MARK: - Lifecycle

    func install(with state: ChromeState) {
        guard statusItem == nil else { return }
        self.state = state

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "hexagon.fill",
                accessibilityDescription: "Hive Browser"
            )
            button.image?.isTemplate = true
        }
        statusItem?.isVisible = true

        // Build initial menu and rely on menuWillOpen for subsequent rebuilds.
        rebuildMenu()
    }

    func uninstall() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        state = nil
    }

    // MARK: - Menu building

    private func rebuildMenu() {
        guard let state else { return }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = true

        // Header: active space
        let headerItem = NSMenuItem()
        headerItem.title = state.activeSpace.name
        headerItem.isEnabled = false
        headerItem.attributedTitle = NSAttributedString(
            string: state.activeSpace.name,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(headerItem)
        menu.addItem(.separator())

        // Tab list (capped at 15)
        let visible = state.visibleTabs.prefix(15)
        if visible.isEmpty {
            let emptyItem = NSMenuItem()
            emptyItem.title = "No open tabs"
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for tab in visible {
                let item = NSMenuItem()
                let title = tab.displayTitle.isEmpty
                    ? (tab.url?.host ?? "New Tab")
                    : tab.displayTitle
                // Truncate long titles
                item.title = String(title.prefix(50))
                item.representedObject = tab.id
                item.action = #selector(selectTabFromMenu(_:))
                item.target = self

                // Show favicon host as tooltip
                if let host = tab.url?.host {
                    item.toolTip = host
                }

                // Indicate active tab
                if tab.id == state.activeTabID {
                    item.state = .on
                    item.attributedTitle = NSAttributedString(
                        string: item.title,
                        attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold)]
                    )
                }

                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Actions
        let newTabItem = NSMenuItem(
            title: "New Tab",
            action: #selector(newTabFromMenu(_:)),
            keyEquivalent: "t"
        )
        newTabItem.keyEquivalentModifierMask = .command
        newTabItem.target = self
        menu.addItem(newTabItem)

        let showItem = NSMenuItem(
            title: "Show Hive",
            action: #selector(showHiveFromMenu(_:)),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let quitItem = NSMenuItem(
            title: "Quit Hive",
            action: #selector(quitFromMenu(_:)),
            keyEquivalent: ""
        )
        // No keyboard modifier — Cmd+Q is owned by the system app menu.
        // Setting it here would conflict with the default quit shortcut.
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func selectTabFromMenu(_ sender: NSMenuItem) {
        guard let tabID = sender.representedObject as? String,
              let state else { return }
        state.selectTab(tabID)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func newTabFromMenu(_ sender: NSMenuItem) {
        guard let state else { return }
        state.newTab()
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showHiveFromMenu(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitFromMenu(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
