import Foundation

// MARK: - BrowserDownload
//
// Lightweight, Codable/Sendable model for a single file download initiated from the browser.
// The live download is driven by a Hive app DownloadManager; this model is the observable
// snapshot shown in the UI and persisted in memory.

public enum DownloadState: String, Sendable, Codable, CaseIterable, Equatable {
    case pending
    case inProgress
    case paused
    case completed
    case failed
    case cancelled
}

public struct BrowserDownload: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let url: URL
    public var filename: String
    public var state: DownloadState
    public var progress: Double          // 0...1
    public var totalBytes: Int64?
    public var receivedBytes: Int64
    public var destinationURL: URL?
    public var startDate: Date
    public var endDate: Date?
    public var errorDescription: String?
    /// WebKit resume data, present only when the native download failed resumably.
    public var resumeData: Data?

    public init(id: String = UUID().uuidString,
                url: URL,
                filename: String = "",
                state: DownloadState = .pending,
                progress: Double = 0,
                totalBytes: Int64? = nil,
                receivedBytes: Int64 = 0,
                destinationURL: URL? = nil,
                startDate: Date = Date(),
                endDate: Date? = nil,
                errorDescription: String? = nil,
                resumeData: Data? = nil) {
        self.id = id
        self.url = url
        self.filename = filename
        self.state = state
        self.progress = progress
        self.totalBytes = totalBytes
        self.receivedBytes = receivedBytes
        self.destinationURL = destinationURL
        self.startDate = startDate
        self.endDate = endDate
        self.errorDescription = errorDescription
        self.resumeData = resumeData
    }

    /// Best-effort display name: filename if known, otherwise the URL's last path component.
    public var displayName: String {
        if !filename.isEmpty { return filename }
        let last = url.lastPathComponent
        return last.isEmpty ? url.host ?? "Untitled" : last
    }

    /// Formatted progress text, e.g. "1.2 MB of 3.4 MB" or "1.2 MB".
    public var progressText: String {
        let received = ByteCountFormatter.string(fromByteCount: receivedBytes, countStyle: .file)
        if let total = totalBytes, total > 0 {
            let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return "\(received) of \(totalStr)"
        }
        return received
    }
}
