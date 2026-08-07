import Foundation

/// Privacy-safe admission data for explicitly selected @tab references.
///
/// The summary counts only classifications. It never renders or stores the
/// tab identifiers, URLs, titles, page text, or model context.
public struct TabAttachmentSummary: Sendable, Equatable {
    public enum Classification: String, Sendable, Equatable {
        case admitted
        case excluded
        case privateContent
        case missing
        case unavailable
    }

    /// Metadata projection supplied by the browser state. It intentionally has
    /// no web content or URL string: the browser reduces URL eligibility to a
    /// boolean before this policy boundary.
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let profileID: String
        public let workspaceID: String
        public let isPrivate: Bool
        public let isActive: Bool
        public let hasUsableHTTPURL: Bool
        public let pageVisibility: HostContextPolicy.EffectiveState

        public init(
            id: String,
            profileID: String,
            workspaceID: String,
            isPrivate: Bool,
            isActive: Bool,
            hasUsableHTTPURL: Bool,
            pageVisibility: HostContextPolicy.EffectiveState = .allowed
        ) {
            self.id = id
            self.profileID = profileID
            self.workspaceID = workspaceID
            self.isPrivate = isPrivate
            self.isActive = isActive
            self.hasUsableHTTPURL = hasUsableHTTPURL
            self.pageVisibility = pageVisibility
        }
    }

    public struct Attachment: Sendable, Equatable, Identifiable {
        let internalID: String
        public let classification: Classification

        public var id: String { internalID }

        public init(id: String, classification: Classification) {
            self.internalID = id
            self.classification = classification
        }
    }

    /// Classifies selected IDs using the same profile/workspace/private policy
    /// as the request path. Active tabs are admitted through current-page scope;
    /// background tabs require usable HTTP(S) metadata for cross-tab context.
    public static func classify(
        selectedIDs: Set<String>,
        candidates: [Candidate],
        currentProfileID: String,
        currentWorkspaceID: String,
        isPrivateBrowsing: Bool,
        includesCurrentPage: Bool
    ) -> [Attachment] {
        let candidatesByID = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return selectedIDs.map { selectedID in
            guard let candidate = candidatesByID[selectedID] else {
                return Attachment(id: selectedID, classification: .missing)
            }
            if isPrivateBrowsing || candidate.isPrivate || candidate.pageVisibility == .privateBrowsing {
                return Attachment(id: selectedID, classification: .privateContent)
            }
            if candidate.pageVisibility == .blocked {
                return Attachment(id: selectedID, classification: .excluded)
            }
            if candidate.pageVisibility == .unavailable {
                return Attachment(id: selectedID, classification: .unavailable)
            }
            let admittedByPolicy = SwarmResponseContextPolicy.allowsReferencedTab(
                tabProfileID: candidate.profileID,
                tabWorkspaceID: candidate.workspaceID,
                currentProfileID: currentProfileID,
                currentWorkspaceID: currentWorkspaceID,
                isPrivateBrowsing: isPrivateBrowsing,
                tabIsPrivate: candidate.isPrivate,
                pageVisibility: candidate.pageVisibility
            )
            guard admittedByPolicy else {
                return Attachment(id: selectedID, classification: .excluded)
            }
            if candidate.isActive {
                let admitted = includesCurrentPage && candidate.hasUsableHTTPURL
                return Attachment(
                    id: selectedID,
                    classification: admitted ? .admitted : .unavailable
                )
            }
            return Attachment(
                id: selectedID,
                classification: candidate.hasUsableHTTPURL ? .admitted : .unavailable
            )
        }
    }

    public let selectedCount: Int
    public let admittedCount: Int
    public let excludedCount: Int
    public let privateCount: Int
    public let missingCount: Int
    public let detail: String
    public let warning: String?

    public init(
        selectedIDs: Set<String>,
        classifications: [Attachment],
        isPrivateBrowsing: Bool
    ) {
        let selected = selectedIDs
        selectedCount = selected.count

        guard !isPrivateBrowsing else {
            admittedCount = 0
            excludedCount = 0
            privateCount = 0
            missingCount = 0
            detail = selected.isEmpty ? "Attachments unavailable" : "Attachments unavailable in Private Browsing"
            warning = selected.isEmpty ? nil : "Selected tabs stay out of Swarm context"
            return
        }

        // A selected ID has one effective classification. The browser state
        // normally emits one record per ID, but this boundary remains
        // deterministic if a future caller supplies duplicates.
        var uniqueClassifications: [String: Classification] = [:]
        for attachment in classifications where selected.contains(attachment.internalID) {
            if uniqueClassifications[attachment.internalID] == nil {
                uniqueClassifications[attachment.internalID] = attachment.classification
            }
        }
        let classifiedIDs = Set(uniqueClassifications.keys)
        let missing = selected.subtracting(classifiedIDs).count
        let values = Array(uniqueClassifications.values)
        let admitted = values.filter { $0 == .admitted }.count
        let excluded = values.filter { $0 == .excluded }.count
        let privateContent = values.filter { $0 == .privateContent }.count
        let explicitMissing = values.filter { $0 == .missing }.count
        let unavailable = values.filter { $0 == .unavailable }.count

        admittedCount = admitted
        excludedCount = excluded
        privateCount = privateContent
        missingCount = missing + explicitMissing

        if selected.isEmpty {
            detail = "No selected tabs"
        } else if admitted == selected.count {
            detail = "\(admitted) admitted"
        } else if admitted > 0 {
            detail = "\(admitted) admitted · \(selected.count - admitted) not admitted"
        } else {
            detail = "No selected tabs admitted"
        }

        let warningParts: [String] = [
            excluded > 0 ? "\(excluded) outside this scope" : nil,
            privateContent > 0 ? "\(privateContent) private" : nil,
            unavailable > 0 ? "\(unavailable) unavailable" : nil,
            missingCount > 0 ? "\(missingCount) no longer available" : nil
        ].compactMap { $0 }
        warning = warningParts.isEmpty ? nil : warningParts.joined(separator: " · ")
    }
}
