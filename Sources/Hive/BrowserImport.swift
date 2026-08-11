import Foundation
import HiveCore

// MARK: - BrowserImport
///
/// Parses bookmarks from installed browsers so Hive can import them on first launch
/// or when the user requests it. Supported: Chrome, Safari, Brave, Edge, Arc, Firefox, Zen.
///
/// Chrome/Edge/Brave/Arc store bookmarks as JSON at a known path.
/// Safari stores them in a binary plist.
/// Firefox/Zen store them in a SQLite places.sqlite database.

enum BrowserImport {

    // MARK: - Public API

    struct AvailableBrowser: Identifiable, Sendable {
        let id: String
        let name: String
        let icon: String
        let bookmarks: [ImportedBookmark]
        let history: [ImportedHistoryEntry]

        var bookmarkCount: Int { bookmarks.count }
        var historyCount: Int { history.count }
        var totalCount: Int { bookmarkCount + historyCount }
    }

    /// Detects installed browsers and reads both bookmark and history metadata
    /// from their read-only profile copies. The result is a value snapshot so
    /// each import action uses one consistent source database view.
    static func detectAvailableBrowsers() -> [AvailableBrowser] {
        [
            makeBrowser(id: "chrome", name: "Chrome", icon: "circle.fill"),
            makeBrowser(id: "safari", name: "Safari", icon: "safari.fill"),
            makeBrowser(id: "brave", name: "Brave", icon: "shield.fill"),
            makeBrowser(id: "edge", name: "Edge", icon: "e.square.fill"),
            makeBrowser(id: "arc", name: "Arc", icon: "arcade.stick.console.fill"),
            makeBrowser(id: "firefox", name: "Firefox", icon: "flame.fill"),
            makeBrowser(id: "zen", name: "Zen", icon: "wind")
        ].compactMap { $0 }
    }

    private static func makeBrowser(id: String, name: String, icon: String) -> AvailableBrowser? {
        let imported = BrowserImportEngine.importFrom(browserID: id)
        guard !imported.bookmarks.isEmpty || !imported.history.isEmpty else { return nil }
        let bookmarks = imported.bookmarks
        return AvailableBrowser(
            id: id,
            name: name,
            icon: icon,
            bookmarks: bookmarks,
            history: imported.history
        )
    }

    
}
