import Foundation

// MARK: - WebViewSessionBroker
//
// Holds the opaque serialized webview state (`WKWebView.interactionState`) for tabs whose live
// WKWebView has been hibernated — dropped from the view tree to free RAM (SPEC §28 +
// Appendix D). The blob is `id` on the platform (`@property (nullable, copy) id`), so we store
// it here as `Any?` untouched: capture hands us whatever the webview produced, restore hands it
// straight back to a fresh webview. No interpretation, no fidelity loss; the broker is a bag.
//
// Isolation: a non-Sendable reference type (nonisolated, like `ChromeState`), touched only from
// the main thread by construction — `WebViewContainer.Coordinator`'s capture/restore are
// `@MainActor`, `ChromeState`'s close/wake run from main-actor Command + UI code, and the
// hibernation timer publishes on `.main`. Keeping it nonisolated (rather than @MainActor) lets
// `ChromeState` hold one as a default property value, since `ChromeState` itself is nonisolated
// (it must be: HiveApp.init() constructs it in a nonisolated launch context). Main-thread-safety
// is by convention, exactly as `ChromeState`'s other mutable state already is.
//
// Lifecycle invariants:
//   • A tab captures EXACTLY ONCE when it hibernates (overwrite is allowed but the controller
//     hibernates → drops the webview, so a second capture before a wake can't happen).
//   • A tab restores EXACTLY ONCE when it wakes, and the blob is drained on restore (a woken
//     tab is live again; holding its stale blob would resurrect the wrong state on a later
//     hibernate). `clear` is the safety net: close drops the blob so a tab id can be reused
//     without inheriting a prior tab's page state.

public final class WebViewSessionBroker {

    /// The opaque webview-state blobs, keyed by tab id. `nil` blob = nothing captured yet.
    private var stash: [String: Any] = [:]

    public init() {}

    /// Records the serialized form of a tab's webview so its live WKWebView may be discarded.
    /// Overwrites a prior capture for the same id (the controller drops the webview right
    /// after, so no live + blob race).
    public func capture(tabID: String, state: Any?) {
        guard let state else { return }   // a nil-state tab (never loaded) leaves no trail
        stash[tabID] = state
    }

    /// Returns + drains the captured blob for a tab, so a waking webview restores from it and
    /// the stale snapshot can't survive a later re-hibernate. nil if nothing was captured.
    public func restore(tabID: String) -> Any? {
        stash.removeValue(forKey: tabID)
    }

    /// Peeks without draining — used to decide whether a waking tab has a sprite to restore
    /// from, before the webview is rebuilt.
    public func hasBlob(for tabID: String) -> Bool { stash[tabID] != nil }

    /// Drops the blob for a tab (called when the tab is closed; frees a stale sprite so a
    /// recycled id doesn't resurrect a dead page).
    public func clear(tabID: String) { stash.removeValue(forKey: tabID) }

    /// The count of hibernated tabs whose blobs are held. Diagnostic + test aid.
    public var count: Int { stash.count }

    /// True iff no blobs are held (fresh broker / every tab awake).
    public var isEmpty: Bool { stash.isEmpty }

    /// The tab ids with a captured sprite. Test/diagnostic aid; don't mutate via this.
    public var tabIDs: [String] { Array(stash.keys) }
}
