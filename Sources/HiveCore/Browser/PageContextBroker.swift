import Foundation

/// Lightweight snapshot of a tab's extracted page content. Returned by
/// `PageContextBroker.request(for:)` so Swarm can ground answers in the actual page text.
public struct PageContext: Sendable {
    public let tabID: String
    public let url: URL?
    public let title: String
    public let text: String
    /// Private-window provenance travels with the snapshot so downstream context
    /// assembly cannot accidentally treat private content as ordinary page text.
    public let privateBrowsing: Bool
    /// Per-tab user consent for Swarm page inspection. False means the page can
    /// still be browsed and manually captured, but not sent to model context.
    public let aiContextAllowed: Bool
    public init(tabID: String, url: URL?, title: String, text: String,
                privateBrowsing: Bool = false, aiContextAllowed: Bool = true) {
        self.tabID = tabID
        self.url = url
        self.title = title
        self.text = text
        self.privateBrowsing = privateBrowsing
        self.aiContextAllowed = aiContextAllowed
    }
}

/// Thread-safe bridge between async Swarm requests for page text and the
/// `.captureReady` WebViewUpdate that fulfills them.
///
/// `request` is async and can be awaited from the main actor. `fulfill` and `cancel`
/// are synchronous so they can be called from synchronous webview delegate callbacks.
public final class PageContextBroker: @unchecked Sendable {
    public init() {}

    private var continuations: [String: CheckedContinuation<PageContext?, Never>] = [:]
    private let lock = NSLock()

    /// Registers a continuation for `tabID` and resumes with `nil` if no result
    /// arrives within `timeout`. The caller is responsible for bumping the
    /// per-tab capture counter so the Coordinator knows to extract.
    public func request(for tabID: String, timeout: Duration = .seconds(5)) async -> PageContext? {
        await withCheckedContinuation { (continuation: CheckedContinuation<PageContext?, Never>) in
            lock.lock()
            // If a previous caller is still waiting for this tab, fail it cleanly
            // rather than leaving it to hang when the new request finishes.
            if let previous = continuations.removeValue(forKey: tabID) {
                previous.resume(returning: nil)
            }
            continuations[tabID] = continuation
            lock.unlock()
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.resume(tabID: tabID, with: nil)
            }
        }
    }

    /// Fulfills the pending continuation for `context.tabID`, if any. Private or
    /// explicitly disallowed snapshots are canceled at this boundary as defense in
    /// depth, so no future caller can bypass the browser's context admission policy.
    public func fulfill(_ context: PageContext) {
        guard !context.privateBrowsing, context.aiContextAllowed else {
            cancel(for: context.tabID)
            return
        }
        resume(tabID: context.tabID, with: context)
    }

    /// Cancels the pending continuation for `tabID`, resuming it with `nil`.
    public func cancel(for tabID: String) {
        resume(tabID: tabID, with: nil)
    }

    private func resume(tabID: String, with value: PageContext?) {
        lock.lock()
        let continuation = continuations.removeValue(forKey: tabID)
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
