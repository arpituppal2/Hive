import Foundation

// MARK: - ChromiumHibernationAdapter

/// Bridges the CEF browser shell to the pure hibernation rules without making
/// HiveCore depend on CEF. This intentionally models only state Chromium owns:
/// workspace membership, tab protection flags, page presence, access time, and
/// live activity sets. Collapsed-group membership is passed as an explicit set
/// because the Chromium group model owns the persisted group records.
public enum ChromiumHibernationAdapter {

    /// Returns whether a group may be collapsed without hiding the active tab.
    /// The browser shell uses this pure rule before mutating persisted UI state.
    public static func canCollapseGroup(memberTabIDs: Set<String>, activeTabID: String?) -> Bool {
        guard let activeTabID else { return true }
        return !memberTabIDs.contains(activeTabID)
    }

    /// MRU is a renderer keepalive optimization, not a stronger user intent
    /// than an explicit group collapse. Collapsed members reach `evaluate` so
    /// the adapter can apply the fold decision while retaining its safety guards.
    public static func shouldIncludeInCandidateSet(
        tabID: String,
        isMRU: Bool,
        collapsedGroupTabIDs: Set<String>
    ) -> Bool {
        !isMRU || collapsedGroupTabIDs.contains(tabID)
    }

    /// Normalizes persisted collapse state before the first render. A session
    /// may have been saved while a group was collapsed and then resumed with
    /// one of its members as the active tab; the active page must win.
    public static func restoredCollapseState(
        isCollapsed: Bool,
        memberTabIDs: Set<String>,
        activeTabID: String?
    ) -> Bool {
        isCollapsed && canCollapseGroup(memberTabIDs: memberTabIDs, activeTabID: activeTabID)
    }

    /// Internal/utility schemes that must never auto-hibernate. Chromium
    /// protects chrome://, about:, and extension pages from automatic discard;
    /// Hive adds its own hive:// chrome surface for the same reason (reloading
    /// an internal page from a blank stub gains nothing).
    public static let protectedSchemes: Set<String> = [
        "hive", "about", "chrome", "chrome-extension", "chrome-untrusted", "devtools"
    ]

    /// Returns true when a tab's scheme is an internal/utility scheme that must
    /// never be hibernated automatically. Nil or unknown schemes are not
    /// protected; `https`/`http`/`file` tabs remain eligible.
    public static func isProtectedScheme(_ scheme: String?) -> Bool {
        guard let scheme else { return false }
        return protectedSchemes.contains(scheme.lowercased())
    }

    public struct TabCandidate: Sendable, Equatable {
        public let id: String
        public let workspaceID: UUID
        public let isPinned: Bool
        public let isEssential: Bool
        public let hasPage: Bool
        /// Defense in depth for callers that pass a broad snapshot: a cold tab
        /// is already in the desired state and must never be selected again.
        public let isHibernated: Bool
        public let lastAccessed: Date
        /// WebRTC / screen / camera / microphone capture is a hard blocker:
        /// hibernating a capturing tab can sever a live call or recording
        /// (Chrome LIVE_STATE_CAPTURING / Firefox WebRTC protection).
        public let isCapturingMedia: Bool
        /// Unsaved user form entry is a hard blocker (Chrome
        /// LIVE_STATE_FORM_ENTRY / Edge "active form inputs").
        public let hasFormEntry: Bool
        /// The tab's URL scheme; internal schemes are never auto-hibernated.
        public let urlScheme: String?

        public init(
            id: String,
            workspaceID: UUID,
            isPinned: Bool = false,
            isEssential: Bool = false,
            hasPage: Bool,
            isHibernated: Bool = false,
            lastAccessed: Date,
            isCapturingMedia: Bool = false,
            hasFormEntry: Bool = false,
            urlScheme: String? = nil
        ) {
            self.id = id
            self.workspaceID = workspaceID
            self.isPinned = isPinned
            self.isEssential = isEssential
            self.hasPage = hasPage
            self.isHibernated = isHibernated
            self.lastAccessed = lastAccessed
            self.isCapturingMedia = isCapturingMedia
            self.hasFormEntry = hasFormEntry
            self.urlScheme = urlScheme
        }
    }

    /// Chooses the URL that must survive a renderer teardown. A transiently
    /// unavailable or blank live model URL falls back to an existing saved URL,
    /// but a blank page is never a valid wake destination.
    public static func effectiveWakeURL(currentURL: URL?, savedURL: URL?) -> URL? {
        if let currentURL, currentURL.absoluteString != "about:blank" {
            return currentURL
        }
        guard let savedURL, savedURL.absoluteString != "about:blank" else { return nil }
        return savedURL
    }

    /// Returns CEF tab IDs that may be hibernated now.
    ///
    /// This shares the media/download safety predicate with `HibernationPolicy`
    /// and uses the same active/inactive workspace thresholds. Explicitly
    /// collapsed-group members are eligible immediately, after the safety
    /// guards, just as in the pure HiveCore policy.
    public static func evaluate(
        tabs: [TabCandidate],
        activeTabID: String?,
        activeWorkspaceID: UUID?,
        mediaPlayingTabIDs: Set<String>,
        activeDownloadTabIDs: Set<String>,
        collapsedGroupTabIDs: Set<String> = [],
        recentlyAudibleTabIDs: Set<String> = [],
        now: Date,
        thresholds: HibernationPolicy.Thresholds = .defaults
    ) -> Set<String> {
        var hibernate: Set<String> = []

        for tab in tabs {
            guard !tab.isHibernated, tab.hasPage else { continue }
            guard !tab.isPinned && !tab.isEssential else { continue }
            // Hard blockers from the cross-browser research contract: media
            // capture (WebRTC/screen/camera/mic), unsaved form entry, and
            // internal schemes never auto-hibernate, exactly like pinned and
            // essential tabs.
            guard !tab.isCapturingMedia, !tab.hasFormEntry,
                  !isProtectedScheme(tab.urlScheme) else { continue }
            guard tab.id != activeTabID else { continue }
            guard !HibernationPolicy.shouldDefer(
                tabID: tab.id,
                audioPlayingTabIDs: mediaPlayingTabIDs,
                activeDownloadTabIDs: activeDownloadTabIDs,
                recentlyAudibleTabIDs: recentlyAudibleTabIDs
            ) else { continue }

            // A collapsed group is an explicit rest gesture. It bypasses age
            // thresholds, but never the active/pinned/essential/media/download
            // protections above.
            if collapsedGroupTabIDs.contains(tab.id) {
                hibernate.insert(tab.id)
                continue
            }

            let threshold = tab.workspaceID == activeWorkspaceID
                ? thresholds.bgActiveSpaceSec
                : thresholds.inactiveSpaceSec
            if now.timeIntervalSince(tab.lastAccessed) >= threshold {
                hibernate.insert(tab.id)
            }
        }

        return hibernate
    }
}
