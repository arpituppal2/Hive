import Foundation
import UserNotifications

// MARK: - DownloadNotifier
//
// Posts macOS notifications when a download completes (Chrome parity: a
// finished download is announced even when Hive is in the background or the
// Downloads panel is closed). One notification per completed transfer —
// the identifier is the download's UUID, so re-delivery overwrites rather
// than stacks. Failures are quiet by design: notifications are best-effort
// and never block the download lifecycle.
//
// The UNUserNotificationCenter API is safe to call from any thread and its
// callbacks arrive on its own serial queue, so this type is deliberately
// nonisolated. The caller gates on its own MainActor-isolated preference
// before invoking `postCompletion`.

enum DownloadNotifier {

    /// Requests authorization lazily the first time a download completes.
    /// The system shows the permission prompt once; denial keeps downloads
    /// silent. Guarded so the request path is entered at most once per
    /// process lifetime.
    nonisolated(unsafe) private static var didRequestAuthorization = false

    static func postCompletion(
        fileName: String,
        downloadID: UUID,
        destinationURL: URL?
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                deliver(center: center, fileName: fileName, downloadID: downloadID, destinationURL: destinationURL)
            case .notDetermined:
                guard !didRequestAuthorization else { return }
                didRequestAuthorization = true
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    deliver(center: center, fileName: fileName, downloadID: downloadID, destinationURL: destinationURL)
                }
            case .denied, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    private static func deliver(
        center: UNUserNotificationCenter,
        fileName: String,
        downloadID: UUID,
        destinationURL: URL?
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = fileName
        content.sound = .default

        if let destinationURL {
            content.userInfo = ["hive.downloadURL": destinationURL.path]
        }

        let request = UNNotificationRequest(
            identifier: "hive.download.\(downloadID.uuidString)",
            content: content,
            trigger: nil // deliver now
        )
        center.add(request)
    }
}
