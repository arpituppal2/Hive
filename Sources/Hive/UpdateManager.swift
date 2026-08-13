import Foundation
import Sparkle

// MARK: - UpdateManager
//
// Wraps Sparkle's SPUStandardUpdaterController for automatic background update
// checks and the "Check for Updates…" menu item. The updater is created lazily
// so Sparkle doesn't block app launch — the first call to `shared` or the menu
// item triggers initialization.
//
// Sparkle reads its configuration from the app's Info.plist:
//   SUFeedURL          — the appcast URL (https://hivebrowser.com/appcast.xml)
//   SUEnableAutomaticChecks — defaults to true
//   SUScheduledCheckInterval — seconds between checks (default 86400 = daily)
//
// For ad-hoc / debug builds without a feed URL, the updater degrades
// gracefully: checkForUpdates() is a no-op and automatic checks are disabled.

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    /// Sparkle's standard updater controller. Nil when not configured (e.g.,
    /// ad-hoc builds with no SUFeedURL in Info.plist).
    private var updaterController: SPUStandardUpdaterController?

    /// Whether Sparkle found a valid feed URL and can check for updates.
    /// False for ad-hoc / debug builds — the "Check for Updates" menu item
    /// should be disabled when this is false.
    @Published private(set) var canCheckForUpdates = false

    private override init() {
        super.init()
        // Defer Sparkle init to the next run-loop turn so launch isn't blocked.
        DispatchQueue.main.async { [weak self] in
            self?.initializeSparkle()
        }
    }

    // MARK: - Initialization

    private func initializeSparkle() {
        guard let info = Bundle.main.infoDictionary else { return }

        // Sparkle requires SUFeedURL in Info.plist. Without it (ad-hoc /
        // debug builds), the updater never initializes — this is intentional.
        guard let feedURLString = info["SUFeedURL"] as? String,
              !feedURLString.isEmpty else {
            #if DEBUG
            print("[UpdateManager] No SUFeedURL in Info.plist — Sparkle disabled (debug/ad-hoc build)")
            #endif
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,   // begin automatic checks on init
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        canCheckForUpdates = true
    }

    // MARK: - Public API

    /// Opens the Sparkle update window. No-op when Sparkle is not configured
    /// (ad-hoc / debug builds without SUFeedURL).
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    /// The Sparkle updater instance, if configured. For Settings UI that
    /// wants to show last-check time or toggle automatic updates.
    var updater: SPUUpdater? {
        updaterController?.updater
    }
}
