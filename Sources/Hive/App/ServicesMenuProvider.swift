import AppKit
import SwiftUI
import HiveCore

// MARK: - ServicesMenuProvider
//
// Registers Hive as a macOS Services provider so users can:
//   - "Open URL in Hive" from any app (Text → Services → Open URL in Hive)
//   - "Search in Hive" from selected text in any app
//
// This is Phase 7 macOS integration — Hive becomes a first-class citizen
// in the macOS services ecosystem alongside Safari and Chrome.
//
// Registration happens in HiveApp.init() via NSApplication.shared.servicesProvider.

@MainActor
final class ServicesMenuProvider: NSObject {

    private weak var state: ChromeState?

    func register(with state: ChromeState) {
        self.state = state
        NSApp.servicesProvider = self
        // Register the service so it appears in the Services menu.
        NSUpdateDynamicServices()
    }

    // MARK: - Service handlers (called by macOS Services subsystem)

    /// "Open URL in Hive" — receives a URL string from any app.
    /// Registered as: NSServiceName = "Open URL in Hive"
    @objc func openInHive(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let state else {
            error.pointee = "Hive is not ready" as NSString
            return
        }

        // Try to read a URL string from the pasteboard
        guard let urlString = pasteboard.string(forType: .string),
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https" || url.scheme == "hive" else {
            return // Not a URL we can handle — silently return
        }

        state.newTab(url: url)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// "Search in Hive" — receives text from any app and opens a search.
    @objc func searchInHive(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let state else {
            error.pointee = "Hive is not ready" as NSString
            return
        }

        guard let query = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            return
        }

        // Route through the shared engine registry so Services follows the same configured
        // provider as the omnibar, start page, and command palette. Unknown legacy values
        // intentionally resolve to Google's product default rather than a privacy engine.
        let engine = SearchEngineKind.resolve(state.prefs.defaultSearchEngine)
        if let url = SearchEngine.searchURL(for: query, engine: engine) {
            state.newTab(url: url)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
