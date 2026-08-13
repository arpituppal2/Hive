import Foundation
import AppKit
import HiveCore

// MARK: - Safety Check (Chrome chrome://settings/safetyCheck parity)
//
// One surface that reports on saved passwords, Safe Browsing, extensions,
// updates, notification permissions, and the HTTPS-only preference. The pure
// HiveCore SafetyCheckPolicy does the classification and copy; this extension
// feeds it live state and routes each row to the most relevant panel.

extension BrowserState {
    /// Runs the check against live state and returns the report rows in
    /// Chrome's order (passwords first).
    func safetyCheckItems() -> [SafetyCheckItem] {
        SafetyCheckPolicy.report(
            passwords: savedPasswords.map { (site: $0.site, password: $0.password) },
            safeBrowsingConfigured: KeychainSecretStore.read(key: GoogleSafeBrowsingClient.apiKeyAccount) != nil,
            extensionCount: installedExtensions.count,
            canCheckForUpdates: UpdateManager.shared.canCheckForUpdates,
            notificationGrantCount: sitePermissions.filter { $0.kind == .notifications && $0.state == .allow }.count,
            httpsOnlyEnabled: isHTTPSOnlyEnabled
        )
    }

    /// Opens the panel most relevant to a report row. Safe Browsing and
    /// HTTPS-only live in the macOS Settings scene (no in-window sheet state),
    /// so those rows open the Settings window and let the user pick the
    /// Privacy tab.
    func openSafetyCheckTarget(_ kind: SafetyCheckItem.Kind) {
        switch kind {
        case .passwords:
            isPasswordsManagerOpen = true
        case .safeBrowsing, .https:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case .extensions:
            isExtensionsManagerOpen = true
        case .permissions:
            isSiteSettingsPanelOpen = true
        case .updates:
            UpdateManager.shared.checkForUpdates()
        }
    }
}
