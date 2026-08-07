import Foundation
import WebKit
import HiveCore

/// Main-actor bridge between WebKit's native download lifecycle and Hive's download store.
@MainActor
final class WebKitDownloadCoordinator: NSObject, WKDownloadDelegate {
    static let shared = WebKitDownloadCoordinator()

    private struct Entry {
        let id: String
        let sourceURL: URL
        let download: WKDownload
        weak var webView: WKWebView?
        var cancelRequested = false
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    func adopt(_ download: WKDownload,
               from webView: WKWebView,
               sourceURL: URL?,
               suggestedFilename: String?) async {
        let sourceURL = sourceURL ?? webView.url ?? URL(string: "about:blank")!
        let filename = DownloadFilenamePolicy.sanitizedFilename(
            suggestedFilename ?? sourceURL.lastPathComponent
        )
        let id = UUID().uuidString
        // Install the delegate and entry before crossing the DownloadManager actor
        // boundary; WebKit may emit callbacks immediately after handoff.
        download.delegate = self
        guard entries[ObjectIdentifier(download)] == nil else { return }
        entries[ObjectIdentifier(download)] = Entry(id: id, sourceURL: sourceURL, download: download, webView: webView)
        _ = await DownloadManager.shared.registerWebKitDownload(id: id, url: sourceURL, filename: filename)
    }

    func cancel(downloadID: String) async {
        guard let pair = entries.first(where: { $0.value.id == downloadID }) else {
            await DownloadManager.shared.cancelDownload(id: downloadID)
            return
        }
        await cancel(pair.value.download)
    }

    /// Pauses a WebKit download by ID (updates state only; WKDownload
    /// has no native pause API).
    func pause(downloadID: String) async {
        guard let pair = entries.first(where: { $0.value.id == downloadID }) else {
            await DownloadManager.shared.markWebKitPaused(id: downloadID)
            return
        }
        await pause(pair.value.download)
    }

    /// Resumes a paused WebKit download by ID (updates state only;
    /// WKDownload has no native resume API).
    func resume(downloadID: String) async {
        guard let pair = entries.first(where: { $0.value.id == downloadID }) else {
            await DownloadManager.shared.markWebKitResumed(id: downloadID)
            return
        }
        await resume(pair.value.download)
    }

/// UI-facing cancellation for a live WebKit object.
  func cancel(_ download: WKDownload) async {
    guard let key = entries[ObjectIdentifier(download)], !key.cancelRequested else { return }
    var updated = key
    updated.cancelRequested = true
    entries[ObjectIdentifier(download)] = updated
    await withCheckedContinuation { continuation in
      download.cancel { _ in continuation.resume() }
    }
    await DownloadManager.shared.markWebKitCancelled(id: key.id)
  }

  /// Pauses a live WebKit download by updating state (WKDownload has no
    /// native pause API; the UI reflects the requested state).
    func pause(_ download: WKDownload) async {
        guard let key = entries[ObjectIdentifier(download)] else { return }
        await DownloadManager.shared.markWebKitPaused(id: key.id)
    }

    /// Resumes a paused WebKit download by updating state (WKDownload has no
    /// native resume API; the UI reflects the requested state).
    func resume(_ download: WKDownload) async {
        guard let key = entries[ObjectIdentifier(download)] else { return }
        await DownloadManager.shared.markWebKitResumed(id: key.id)
    }

    /// Retry is available only when the manager has resume data and the original web view remains alive.
    func retry(downloadID: String) async {
        guard let record = await DownloadManager.shared.download(withID: downloadID),
              let resumeData = record.resumeData,
              let pair = entries.first(where: { $0.value.id == downloadID }),
              let webView = pair.value.webView else { return }
        webView.resumeDownload(fromResumeData: resumeData) { [weak self] resumed in
            Task { @MainActor in
                guard let self else { return }
                self.entries.removeValue(forKey: pair.key)
                self.entries[ObjectIdentifier(resumed)] = Entry(id: downloadID, sourceURL: record.url, download: resumed, webView: webView)
                resumed.delegate = self
                await DownloadManager.shared.markWebKitRetrying(id: downloadID)
            }
        }
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        let id = entries[ObjectIdentifier(download)]?.id
        let safeName = DownloadFilenamePolicy.sanitizedFilename(
            response.suggestedFilename ?? suggestedFilename
        )
        let destination = await DownloadManager.shared.destinationURL(for: safeName)
        if let id {
            await DownloadManager.shared.setDestination(destination, for: id)
        }
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let entry = entries.removeValue(forKey: ObjectIdentifier(download)) else { return }
        Task { await DownloadManager.shared.markWebKitFinished(id: entry.id) }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let entry = entries[ObjectIdentifier(download)] else { return }
        Task {
            if entry.cancelRequested {
                await DownloadManager.shared.markWebKitCancelled(id: entry.id)
                await MainActor.run { self.entries.removeValue(forKey: ObjectIdentifier(download)) }
            } else {
                await DownloadManager.shared.markWebKitFailed(id: entry.id, error: error, resumeData: resumeData)
                if resumeData == nil {
                    await MainActor.run { self.entries.removeValue(forKey: ObjectIdentifier(download)) }
                }
            }
        }
    }
}
