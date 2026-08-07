import Foundation
import HiveCore

// MARK: - ImportableBrowser
//
// Represents a browser the user can import bookmarks/history from during first-launch
// onboarding. Detection is conservative: we only list browsers whose default profile
// directory or app bundle exists on disk. The actual import is currently a realistic
// simulation (returns plausible counts) — a later slice can wire the real extraction
// from each engine's SQLite/plist files without changing the view contract.

struct ImportableBrowser: Identifiable, Equatable {
    let id: String
    let name: String
    let profilePath: String
    let appBundlePath: String?

    /// True when *either* the profile directory or the app bundle exists on this Mac.
    var isDetected: Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let fullProfile = (home as NSString).appendingPathComponent(profilePath)
        if fm.fileExists(atPath: fullProfile) { return true }
        if let bundle = appBundlePath,
           fm.fileExists(atPath: bundle) { return true }
        return false
    }

    /// Supported import sources in the order shown during onboarding.
    static let supportedBrowsers: [ImportableBrowser] = [
        .init(id: "safari",
              name: "Safari",
              profilePath: "Library/Safari/Bookmarks.plist",
              appBundlePath: "/Applications/Safari.app"),
        .init(id: "chrome",
              name: "Google Chrome",
              profilePath: "Library/Application Support/Google/Chrome/Default",
              appBundlePath: "/Applications/Google Chrome.app"),
        .init(id: "firefox",
              name: "Firefox",
              profilePath: "Library/Application Support/Firefox/Profiles",
              appBundlePath: "/Applications/Firefox.app"),
        .init(id: "edge",
              name: "Microsoft Edge",
              profilePath: "Library/Application Support/Microsoft Edge/Default",
              appBundlePath: "/Applications/Microsoft Edge.app"),
        .init(id: "brave",
              name: "Brave",
              profilePath: "Library/Application Support/BraveSoftware/Brave-Browser/Default",
              appBundlePath: "/Applications/Brave Browser.app"),
        .init(id: "arc",
              name: "Arc",
              profilePath: "Library/Application Support/Arc/User Data/Default",
              appBundlePath: "/Applications/Arc.app"),
    ]

    /// The browser preset that matches this browser's default settings (layout, density,
    /// search engine, bookmark bar, content blocker). Hive applies this automatically
    /// on import so the user feels instantly at home.
    var preset: BrowserPreset? {
        BrowserPreset.preset(for: id)
    }

    /// Human-readable description of what settings will be matched (e.g. "Arc-style
    /// compact vertical tabs"). Shown in the onboarding import step to build confidence.
    var presetLabel: String? {
        preset?.displayLabel(for: name)
    }

    /// Simulated import result for the current browser. In a full implementation this would
    /// read the actual profile databases; for the pitch demo it returns plausible counts.
    func performImport() async -> ImportResult {
        let (bookmarks, history) = BrowserImportEngine.importFrom(browserID: id)
        // Merge into ChromeUserPrefs via a callback set by the caller (OnboardingView).
        if let merge = Self.mergeHandler {
            merge(bookmarks, history)
        }
        return ImportResult(bookmarks: bookmarks.count, history: history.count)
    }

    /// Hook for the app layer to merge import results into ChromeUserPrefs.
    /// Set by OnboardingView before import begins.
    nonisolated(unsafe) static var mergeHandler: (([ImportedBookmark], [ImportedHistoryEntry]) -> Void)?
}

// MARK: - ImportResult

struct ImportResult: Equatable {
    let bookmarks: Int
    let history: Int

    var isEmpty: Bool { bookmarks == 0 && history == 0 }
}
