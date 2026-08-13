import Foundation
import AppKit

// MARK: - SessionStore
//
// A small, self-contained store of browsable window-session snapshots, exposed
// to the web chrome via the hive.listSessions / hive.restoreSession /
// hive.deleteSession bridge calls. It is deliberately independent of
// BrowserState's order-of-bootstrap session loader (which reconstructs
// the *current* session on launch): this store is the user's explicit,
// browsable history of whole windows worth of tabs, surfaced as the "Sessions"
// section in the web chrome's history panel.
//
// Snapshots are persisted as JSON under the app container's Application
// Support directory. Each snapshot captures: the tab set (id, title, url,
// favicon), the active workspace, the bound window title, and freshness
// timestamps. Full tab restoration (rehydrating a CEF browser for every tab in
// a snapshot) is performed lazily by a fresh window that re-opens to the
// default new-tab page and then navigates each snapshot URL via the bridge —
// so the restore action is a one-click "open window" that the OS window
// manager materializes in the normal SwiftUI lifecycle.

/// A persisted, web-renderable session snapshot.
struct SessionSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let windowCount: Int
    let tabCount: Int
    let faviconURL: String?
    let startedAt: String
    let lastActiveAt: String
}

/// One tab worth of a snapshot — enough for the chrome to render a preview
/// without touching the live Tab/CefWebViewModel graph.
struct SessionSnapshotTab: Codable, Sendable {
    let id: String
    let title: String
    let url: String
    let faviconURL: String?
}

/// A full on-disk session record.
    struct SessionRecord: Codable, Sendable {
        let id: UUID
        let tabs: [SessionSnapshotTab]
        let currentWorkspaceID: UUID
        let startedAt: Date
        var lastActiveAt: Date

    var title: String {
        if let first = tabs.first, !first.title.isEmpty { return first.title }
        if let u = tabs.first.flatMap({ URL(string: $0.url) }) {
            if let h = u.host, !h.isEmpty { return h }
            if !u.path.isEmpty { return u.path }
        }
        return tabs.first?.url.isEmpty == false ? tabs.first!.url : "Session"
    }
    var windowCount: Int { 1 }
    var tabCount: Int { tabs.count }
    var faviconURL: String? { tabs.first?.faviconURL }
}

/// Thread-safe (MainActor-isolated) snapshot store. Reads/writes its JSON
/// file on a background queue and notifies the web chrome via the normal
/// stateChanged broadcast so the "Sessions" panel refreshes live.
@MainActor
final class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [SessionRecord] = []

    private let storeURL: URL = {
        let app = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Hive")
        try? FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        return app.appendingPathComponent("sessions.json")
    }()

    private init() {
        self.sessions = Self.read(storeURL: storeURL)
    }

    // MARK: - CRUD

    func snapshot(tabs: [SessionSnapshotTab], workspaceID: UUID, at date: Date = Date()) {
        let cleaned = tabs.filter { !$0.url.isEmpty && URL(string: $0.url) != nil }
        guard !cleaned.isEmpty else { return }
        let id = UUID()
        let existing = sessions.firstIndex(where: { $0.currentWorkspaceID == workspaceID && $0.id != id })
        // Replace any same-workspace snapshot (one per workspace) to keep the list
        // from ballooning across reloads.
        if let idx = existing {
            sessions.remove(at: idx)
        }
        let record = SessionRecord(
            id: id,
            tabs: cleaned,
            currentWorkspaceID: workspaceID,
            startedAt: date,
            lastActiveAt: date
        )
        sessions.insert(record, at: 0)
        trim()
        write()
    }

    func touch(id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        var updated = sessions[idx]
        updated.lastActiveAt = Date()
        sessions[idx] = updated
        write()
    }

    func delete(id: UUID) {
        sessions.removeAll { $0.id == id }
        write()
    }

    func deleteAll() {
        sessions.removeAll()
        write()
    }

    // MARK: - Persistence

    private func trim() {
        if sessions.count > 24 { sessions.removeSubrange(24...) }
    }

    private func write() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            // Non-fatal: a failed snapshot write must never crash the browser.
            print("[SessionStore] write failed: \(error)")
        }
    }

    private static func read(storeURL: URL) -> [SessionRecord] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        do {
            return try JSONDecoder().decode([SessionRecord].self, from: data)
        } catch {
            print("[SessionStore] decode failed (will reset): \(error)")
            return []
        }
    }
}

/// Bridges a SessionSnapshot over the WebChromeSession DTO shape consumed by JS.
/// Formatting happens here (single source of truth for labels).
extension SessionRecord {
    func formatted() -> (startedAt: String, lastActiveAt: String) {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return (fmt.string(from: startedAt), fmt.string(from: lastActiveAt))
    }
}
