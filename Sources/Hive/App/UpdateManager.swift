import Foundation
import AppKit

#if canImport(Sparkle)
import Sparkle
#endif

// MARK: - UpdateManager
//
// Manages automatic updates for The Hive Browser via Sparkle 2.
// Sparkle provides signed, delta-updated, notarized app updates.
//
// Integration checklist (Phase 9) — owner/pre-ship steps:
//
//   BLOCKER (must exist first): Sparkle 2 reads SUFeedURL/SUPublicEDKey from the
//   app bundle's Info.plist and installs an Autoupdate XPC helper into
//   Contents/Library/LaunchServices/. Hive is currently a bare SPM
//   `executableTarget` — there is NO Info.plist and NO .app bundle in the repo.
//   So before anything below, establish a bundling pipeline (an Xcode app target
//   or an SPM→.app packager) that produces Hive.app with a real Info.plist.
//   Until that exists, linking Sparkle is dead weight; this stub degrades
//   honestly to a no-op (prefs/channel UI still work, notice shown below).
//
//   1. Add Sparkle 2 SPM dependency to Package.swift (product `Sparkle`).
//   2. Establish the .app bundle + Info.plist (the BLOCKER above).
//   3. Set SUFeedURL, SUPublicEDKey, SUEnableAutomaticChecks in Info.plist.
//   4. Port the stub's SUUpdater-1 calls below to Sparkle-2's
//      SPUStandardUpdaterController / SPUUpdater (the Sparkle-1 symbols used
//      here are placeholders until then).
//   5. Sign appcast with EdDSA (sparkle:generate_keys) — the secret is owner-
//      generated; `publicEdDSAKey` below is a documented placeholder, NOT real.
//   6. Notarize updates via xcrun notarytool.
//
// This stub provides the configuration surface and Sparkle wiring hooks
// without requiring Sparkle as a hard dependency. When Sparkle is linked,
// the `#if canImport(Sparkle)` path activates real update checking.
//
// Sparkle documentation: https://sparkle-project.org/

@MainActor
final class UpdateManager {

    static let shared = UpdateManager()

    /// Whether automatic update checks are enabled.
    var automaticallyChecksForUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") }
        set { UserDefaults.standard.set(newValue, forKey: "SUEnableAutomaticChecks") }
    }

    /// Whether to automatically download updates in the background.
    var automaticallyDownloadsUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate") }
        set { UserDefaults.standard.set(newValue, forKey: "SUAutomaticallyUpdate") }
    }

    /// The update channel: "stable", "beta", or "nightly".
    var updateChannel: String {
        get { UserDefaults.standard.string(forKey: "HiveUpdateChannel") ?? "stable" }
        set { UserDefaults.standard.set(newValue, forKey: "HiveUpdateChannel") }
    }

    /// Last time an update check was performed.
    var lastUpdateCheck: Date? {
        get { UserDefaults.standard.object(forKey: "HiveLastUpdateCheck") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "HiveLastUpdateCheck") }
    }

    /// Whether an update is currently downloading.
    private(set) var isUpdating = false

    /// The latest available version, if any.
    private(set) var latestVersion: String?

    /// The release notes for the latest version.
    private(set) var latestReleaseNotes: String?

    private init() {
        // Default Sparkle preferences
        if UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") == nil {
            automaticallyChecksForUpdates = true
        }
        if UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") == nil {
            automaticallyDownloadsUpdates = false
        }
    }

    // MARK: - Public API

    /// Checks for updates. In production (with Sparkle linked), this delegates to
    /// SUUpdater.shared().checkForUpdates(). Without Sparkle, this is a no-op.
    func checkForUpdates() {
        #if canImport(Sparkle)
        SUUpdater.shared().checkForUpdates(nil)
        #else
        lastUpdateCheck = Date()
        // Sparkle not linked — silent no-op. The settings UI still works
        // and preferences are persisted for when Sparkle is wired.
        #endif
    }

    /// Opens the Sparkle update settings pane (if Sparkle is linked).
    func showUpdateSettings() {
        #if canImport(Sparkle)
        SUUpdater.shared().checkForUpdates(nil)
        #endif
    }

    /// Returns the current app version from the bundle.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0"
    }

    /// Returns the current build number.
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "0"
    }

    /// The Sparkle appcast feed URL, adjusted for the selected update channel.
    var appcastURL: URL? {
        let baseURL = "https://updates.hivebrowser.com/appcast"
        let channelSuffix = updateChannel == "stable" ? "" : "-\(updateChannel)"
        return URL(string: "\(baseURL)\(channelSuffix).xml")
    }

    /// EdDSA public key for appcast signature verification.
    /// Generated via: sparkle/bin/generate_keys
    /// Replace this placeholder with the real key before shipping updates.
    var publicEdDSAKey: String {
        "REPLACE_WITH_REAL_EDDSA_PUBLIC_KEY"
    }
}

// MARK: - UpdateSettingsView

import SwiftUI

/// Preferences panel for update management. Shows current version,
/// update channel selector, and check-now button. When Sparkle is not
/// linked, shows a clear notice that auto-updates are pending wiring.
struct UpdateSettingsView: View {

    @Environment(ChromeState.self) private var state
    @State private var isChecking = false

    private var updater: UpdateManager { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s24) {
            // Current version
            versionCard

            // Update controls
            updateControls

            // Sparkle status
            sparkleStatusCard
        }
    }

    // MARK: - Version Card

    private var versionCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            Text("Current Version")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            HStack(spacing: HiveSpacing.s12) {
                Image(systemName: "app.badge")
                    .font(.system(size: 28))
                    .foregroundStyle(.hiveAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("The Hive Browser")
                        .hiveType(.body)
                        .foregroundStyle(.hiveInk)
                    Text("Version \(updater.currentVersion) (Build \(updater.currentBuild))")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                }
            }
            .padding(HiveSpacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveSurfaceElevated)
            )
        }
    }

    // MARK: - Update Controls

    private var updateControls: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            Text("Updates")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            VStack(alignment: .leading, spacing: HiveSpacing.s12) {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))

                Toggle("Automatically download updates", isOn: Binding(
                    get: { updater.automaticallyDownloadsUpdates },
                    set: { updater.automaticallyDownloadsUpdates = $0 }
                ))

                Divider().overlay(Color.hiveBorderSubtle)

                Picker("Update Channel", selection: Binding(
                    get: { updater.updateChannel },
                    set: { updater.updateChannel = $0 }
                )) {
                    Text("Stable").tag("stable")
                    Text("Beta").tag("beta")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Text("Stable updates are thoroughly tested. Beta gives you early access to new features with occasional rough edges.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .lineLimit(3)

                Divider().overlay(Color.hiveBorderSubtle)

                HStack(spacing: HiveSpacing.s12) {
                    Button {
                        isChecking = true
                        updater.checkForUpdates()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isChecking = false
                        }
                    } label: {
                        Label(
                            isChecking ? "Checking…" : "Check Now",
                            systemImage: isChecking ? "hourglass" : "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(isChecking)
                    .buttonStyle(.borderedProminent)
                    .tint(.hiveAccent)

                    if let lastCheck = updater.lastUpdateCheck {
                        Text("Last checked: \(lastCheck, style: .relative) ago")
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                    }
                }
            }
            .padding(HiveSpacing.s16)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Sparkle Status

    private var sparkleStatusCard: some View {
        #if canImport(Sparkle)
        AnyView(EmptyView())
        #else
        AnyView(
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.hiveAccent)
                    Text("Sparkle Update Framework")
                        .hiveType(.body)
                        .foregroundStyle(.hiveInk)
                }

                Text("Auto-updates are configured but the Sparkle framework is not yet linked. Once Sparkle is added as a dependency, Hive will automatically check for, download, and install updates in the background. All updates are cryptographically signed and notarized by Apple.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .lineLimit(5)

                Text("Your update preferences (channel, auto-check) are saved and will take effect once Sparkle is wired.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveAccent)
            }
            .padding(HiveSpacing.s16)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveAccent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveAccent.opacity(0.15), lineWidth: 1)
            )
        )
        #endif
    }
}
