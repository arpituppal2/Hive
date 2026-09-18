import CCef
import Foundation

/// A snapshot of one file download's state, delivered through
/// ``CefBrowserDelegate/browser(_:decidePolicyForDownload:suggestedName:)``
/// and ``CefBrowserDelegate/browser(_:downloadDidProgress:)``.
public struct CefDownload: Sendable, Equatable {
    /// CEF's identifier for this download (stable across updates).
    public var id: UInt32
    /// The download URL.
    public var url: URL?
    /// Bytes received so far.
    public var receivedBytes: Int64
    /// Total bytes, or 0 when the server didn't say.
    public var totalBytes: Int64
    /// Whether the download finished successfully.
    public var isComplete: Bool
    /// Whether the download was canceled or interrupted.
    public var isCanceled: Bool
    /// Whether the download was paused via ``CefDownloadControl/pause()``.
    /// The authoritative reconcile signal for a pause/resume request.
    public var isPaused: Bool
    /// Where the file is being written, once a destination is known.
    public var fullPath: URL?

    public init(
        id: UInt32,
        url: URL?,
        receivedBytes: Int64,
        totalBytes: Int64,
        isComplete: Bool,
        isCanceled: Bool,
        isPaused: Bool = false,
        fullPath: URL?
    ) {
        self.id = id
        self.url = url
        self.receivedBytes = receivedBytes
        self.totalBytes = totalBytes
        self.isComplete = isComplete
        self.isCanceled = isCanceled
        self.isPaused = isPaused
        self.fullPath = fullPath
    }
}

/// Verdict for a download that is about to begin.
public enum CefDownloadDecision: Sendable {
    /// Proceed. `destination` is the full file path to write (including the
    /// file name); `nil` saves to `~/Downloads/<suggestedName>`.
    case allow(destination: URL?)
    /// Cancel the download.
    case deny
}

/// Resolves a ``CefDownloadDecision`` into a concrete destination path
/// (nil = canceled). Internal so tests can exercise the plumbing.
enum CefDownloadDestination {
    static func resolve(decision: CefDownloadDecision, suggestedName: String) -> URL? {
        switch decision {
        case .deny:
            return nil
        case .allow(let destination):
            if let destination { return destination }
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            // Never write outside the directory on a hostile suggested name.
            let safeName = (suggestedName as NSString).lastPathComponent
            return downloads.appendingPathComponent(safeName.isEmpty ? "download" : safeName)
        }
    }
}

extension CefDownload {
    /// Reads a snapshot out of a borrowed `cef_download_item_t`.
    init(item: UnsafeMutablePointer<cef_download_item_t>) {
        let urlString = CefStringUtil.takingUserFree(item.pointee.get_url?(item)) ?? ""
        let path = CefStringUtil.takingUserFree(item.pointee.get_full_path?(item)) ?? ""
        self.init(
            id: item.pointee.get_id?(item) ?? 0,
            url: URL(string: urlString),
            receivedBytes: item.pointee.get_received_bytes?(item) ?? 0,
            totalBytes: item.pointee.get_total_bytes?(item) ?? 0,
            isComplete: (item.pointee.is_complete?(item) ?? 0) != 0,
            isCanceled: (item.pointee.is_canceled?(item) ?? 0) != 0
                || (item.pointee.is_interrupted?(item) ?? 0) != 0,
            isPaused: (item.pointee.is_paused?(item) ?? 0) != 0,
            fullPath: path.isEmpty ? nil : URL(fileURLWithPath: path)
        )
    }
}

/// Live controller for one CEF file download. ``pause()``, ``resume()`` and
/// ``cancel()`` are fire-and-forget CEF commands: the authoritative outcome
/// arrives in the next ``CefDownload`` snapshot (its ``isPaused`` bit
/// reconciles a pause/resume request).
///
/// The wrapper owns the CEF download-item callback's reference and releases
/// it on deinit. Store it for the lifetime of the transfer; the delegate
/// stops delivering it once the download reaches a terminal state, so never
/// call through it after ``CefDownload.isComplete``/``isCanceled``.
public final class CefDownloadControl: @unchecked Sendable {
    nonisolated(unsafe) private var callback: UnsafeMutablePointer<cef_download_item_callback_t>?

    /// Takes ownership of the +1 reference delivered by `on_download_updated`.
    init(raw: UnsafeMutablePointer<cef_download_item_callback_t>) {
        callback = raw
    }

    deinit {
        releaseCallback()
    }

    /// Pauses the transfer. No-op after terminal state.
    public func pause() {
        callback?.pointee.pause?(callback)
    }

    /// Resumes a paused transfer.
    public func resume() {
        callback?.pointee.resume?(callback)
    }

    /// Cancels the transfer.
    public func cancel() {
        callback?.pointee.cancel?(callback)
    }

    private func releaseCallback() {
        guard let callback else { return }
        self.callback = nil
        cefRelease(UnsafeMutableRawPointer(callback))
    }
}
