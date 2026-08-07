import Foundation
import HiveCore

// MARK: - DownloadManager
//
// Manages the browser's in-progress and completed downloads. Backed by an actor so all
// mutable state (the downloads array, active tasks, and callbacks) is serialized.
// Downloads are written to the user's Downloads folder by default.

final actor DownloadManager {
    static let shared = DownloadManager()

    private var downloads: [BrowserDownload] = []
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var continuations: [String: AsyncStream<BrowserDownload>.Continuation] = [:]

    // MARK: - Public API

    /// Begins a download from a URL. Returns the initial `BrowserDownload` snapshot.
    func startDownload(from url: URL, suggestedFilename: String? = nil) -> BrowserDownload {
        let filename = suggestedFilename ?? url.lastPathComponent
        var download = BrowserDownload(url: url, filename: filename, state: .pending)
        downloads.append(download)

        let request = URLRequest(url: url)
        let downloadID = download.id
        let task = URLSession.shared.downloadTask(with: request) { [weak self] localURL, response, error in
            Task {
                await self?.handleCompletion(id: downloadID, localURL: localURL, response: response, error: error)
            }
        }

        tasks[download.id] = task
        task.resume()

        // The task is now in progress from the user's perspective.
        download.state = .inProgress
        update(download)

        // Wire progress observation. We can't easily get per-byte progress with the simple
        // downloadTask closure, so we poll the task's count-of-bytes until completion.
        beginProgressPolling(for: download.id)

        return download
    }

    /// Returns a snapshot of all downloads, most-recent first.
    func allDownloads() -> [BrowserDownload] {
        downloads.sorted { $0.startDate > $1.startDate }
    }

    /// Returns a single download by id.
    func download(withID id: String) -> BrowserDownload? {
        downloads.first { $0.id == id }
    }

    /// Registers a native WebKit download before destination selection.
    func registerWebKitDownload(id: String, url: URL, filename: String) -> BrowserDownload {
        let download = BrowserDownload(id: id, url: url, filename: filename, state: .inProgress)
        downloads.append(download)
        notify(download)
        return download
    }

    /// Records the destination chosen for a native WebKit download.
    func setDestination(_ destination: URL, for id: String) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].destinationURL = destination
        notify(downloads[index])
    }

    /// Reconciles a native WebKit download failure. Resume data is retained for an explicit retry.
    func markWebKitFailed(id: String, error: Error, resumeData: Data?) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .failed
        downloads[index].errorDescription = error.localizedDescription
        downloads[index].resumeData = resumeData
        downloads[index].endDate = Date()
        notify(downloads[index])
    }

    /// Marks a native WebKit download as retrying after resume data was accepted.
    func markWebKitRetrying(id: String) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .inProgress
        downloads[index].errorDescription = nil
        downloads[index].resumeData = nil
        downloads[index].endDate = nil
        notify(downloads[index])
    }

    /// Marks a native WebKit download complete.
    func markWebKitFinished(id: String) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .completed
        downloads[index].progress = 1
        downloads[index].endDate = Date()
        downloads[index].resumeData = nil
        notify(downloads[index])
    }

/// Records a native cancellation. A later WebKit failure callback cannot overwrite it.
  func markWebKitCancelled(id: String) {
    guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
    downloads[index].state = .cancelled
    downloads[index].endDate = Date()
    notify(downloads[index])
  }

  /// Records a native pause.
  func markWebKitPaused(id: String) {
    guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
    downloads[index].state = .paused
    downloads[index].endDate = Date()
    notify(downloads[index])
  }

  /// Records a native resume.
  func markWebKitResumed(id: String) {
    guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
    downloads[index].state = .inProgress
    downloads[index].endDate = nil
    notify(downloads[index])
  }

    /// Returns the next collision-safe path in the user's Downloads folder.
    func destinationURL(for filename: String) -> URL {
        let directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        let safe = DownloadFilenamePolicy.sanitizedFilename(filename)
        let unique = DownloadFilenamePolicy.uniqueFilename(safe, existingNames: existing)
        return directory.appendingPathComponent(unique, isDirectory: false)
    }

    /// Cancels an in-progress URLSession download.
    func cancelDownload(id: String) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        downloads[idx].state = .cancelled
        downloads[idx].endDate = Date()
        notify(downloads[idx])
    }

    /// Clears completed/cancelled/failed downloads from the list.
    func clearFinished() {
        downloads.removeAll { $0.state == .completed || $0.state == .cancelled || $0.state == .failed }
    }

    /// Returns a live stream of download changes and a token for cleanup.
    func observe() -> (stream: AsyncStream<BrowserDownload>, token: String) {
        let (stream, continuation) = AsyncStream<BrowserDownload>.makeStream()
        let token = UUID().uuidString
        continuations[token] = continuation
        return (stream, token)
    }

    /// Ends observation for the given token.
    func finishObservation(_ token: String) {
        continuations[token]?.finish()
        continuations.removeValue(forKey: token)
    }

    // MARK: - Internals

    private func update(_ download: BrowserDownload) {
        guard let idx = downloads.firstIndex(where: { $0.id == download.id }) else { return }
        downloads[idx] = download
        notify(download)
    }

    private func notify(_ download: BrowserDownload) {
        for continuation in continuations.values {
            continuation.yield(download)
        }
    }

    private func handleCompletion(id: String, localURL: URL?, response: URLResponse?, error: Error?) async {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        tasks.removeValue(forKey: id)

        var download = downloads[idx]

        if let error {
            download.state = .failed
            download.errorDescription = error.localizedDescription
            download.endDate = Date()
        } else if let localURL = localURL {
            do {
                let dest = try moveToDownloads(localURL: localURL, filename: download.filename)
                download.destinationURL = dest
                download.state = .completed
                download.progress = 1.0
                download.endDate = Date()
            } catch {
                download.state = .failed
                download.errorDescription = error.localizedDescription
                download.endDate = Date()
            }
        } else {
            download.state = .failed
            download.errorDescription = "No response"
            download.endDate = Date()
        }

        update(download)
    }

    private func moveToDownloads(localURL: URL, filename: String) throws -> URL {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let dest = downloadsURL.appendingPathComponent(filename)
        // If a file already exists, append a counter before the extension.
        var finalDest = dest
        var counter = 1
        while FileManager.default.fileExists(atPath: finalDest.path) && counter < 1000 {
            let ext = dest.pathExtension
            let base = (dest.lastPathComponent as NSString).deletingPathExtension
            let suffix = ext.isEmpty ? "" : ".\(ext)"
            finalDest = downloadsURL.appendingPathComponent("\(base) (\(counter))\(suffix)")
            counter += 1
        }
        try FileManager.default.moveItem(at: localURL, to: finalDest)
        return finalDest
    }

    private func beginProgressPolling(for id: String) {
        Task {
            while let task = tasks[id], task.state == .running || task.state == .suspended {
                guard let idx = downloads.firstIndex(where: { $0.id == id }) else { break }

                var download = downloads[idx]
                let total = task.countOfBytesExpectedToReceive
                let received = task.countOfBytesReceived
                download.totalBytes = total > 0 ? total : nil
                download.receivedBytes = received
                if total > 0 {
                    download.progress = Double(received) / Double(total)
                }
                if total > 0 || received > 0 {
                    update(download)
                }

                if task.state == .completed || task.state == .canceling {
                    break
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            }
        }
    }
}
