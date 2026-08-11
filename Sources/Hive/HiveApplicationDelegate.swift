import AppKit
import CloudKit
import Foundation
import HiveCore

/// AppKit lifecycle bridge for CloudKit database-subscription notifications.
///
/// SwiftUI owns the scene and BrowserState, while AppKit owns APNs delivery.
/// The delegate deliberately keeps only a MainActor-isolated async callback so
/// notification delivery never touches BrowserState off actor isolation.
@MainActor
final class HiveApplicationDelegate: NSObject, NSApplicationDelegate {
    private var syncHandler: (@MainActor () async -> Void)?
    private var pendingDatabaseNotification = false

    static let syncSubscriptionID = "hive-private-db-changes"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Local-only and ad-hoc bundles have no matching signed CloudKit
        // container, so do not advertise a remote-notification capability.
        // Configured releases may still degrade harmlessly if APNs is absent;
        // startup pull remains the fallback.
        guard CloudKitConfiguration.configuredContainer() != nil else { return }
        NSApplication.shared.registerForRemoteNotifications()
    }

    /// Binds the delegate after SwiftUI has created its shared BrowserState.
    /// The closure is replaced on every scene appearance and captures no
    /// AppKit objects.
    @MainActor
    func bind(state: BrowserState) {
        syncHandler = { @MainActor [weak state] in
            await state?.handleRemoteSyncNotification()
        }
        guard pendingDatabaseNotification else { return }
        pendingDatabaseNotification = false
        Task { @MainActor [weak self] in
            await self?.deliverPendingDatabaseNotification()
        }
    }

    @MainActor
    private func deliverPendingDatabaseNotification() async {
        await syncHandler?()
    }

    /// CloudKit database subscriptions arrive as silent remote notifications.
    /// macOS does not require a user-facing alert for this callback.
    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        guard let notification = CKNotification(
            fromRemoteNotificationDictionary: userInfo
        ), notification.notificationType == .database,
              notification.subscriptionID == Self.syncSubscriptionID else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.syncHandler != nil else {
                self.pendingDatabaseNotification = true
                return
            }
            await self.deliverPendingDatabaseNotification()
        }
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit owns the subscription-to-device-token mapping. The token is
        // intentionally not persisted or logged by Hive.
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Registration failure is non-fatal: sync still performs a startup
        // pull and flushes the encrypted outbox whenever CloudKit is available.
    }
}
