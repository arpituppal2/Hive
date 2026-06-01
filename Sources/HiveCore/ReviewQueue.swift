import Foundation

public enum ReviewQueueTargetType: String, Codable, Sendable {
    case claim
    case source
    case graphNode
}

public struct ReviewQueueItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var targetType: ReviewQueueTargetType
    public var targetID: String
    public var title: String
    public var detail: String
    public var reason: String
    public var action: FeedbackAction?
    public var priority: Int
    public var createdAt: Date
    public var sourceRefs: [String]

    public init(
        id: String,
        targetType: ReviewQueueTargetType,
        targetID: String,
        title: String,
        detail: String = "",
        reason: String,
        action: FeedbackAction? = nil,
        priority: Int,
        createdAt: Date,
        sourceRefs: [String] = []
    ) {
        self.id = id
        self.targetType = targetType
        self.targetID = targetID
        self.title = title
        self.detail = detail
        self.reason = reason
        self.action = action
        self.priority = priority
        self.createdAt = createdAt
        self.sourceRefs = sourceRefs
    }
}

public struct ReviewQueueBuilder: Sendable {
    public static let approvalThreshold = 0.70

    public init() {}

    public func build(
        claims: [ClaimRecord],
        sources: [SourceRecord],
        feedback: [FeedbackRecord],
        now: Date = Date()
    ) -> [ReviewQueueItem] {
        var items: [String: ReviewQueueItem] = [:]
        let activeClaims = claims.filter { $0.status != .retracted }
        let claimsByID = Dictionary(uniqueKeysWithValues: activeClaims.map { ($0.id, $0) })
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let latestClaimFeedback = latestFeedbackActions(feedback.filter { $0.targetType == "claim" })

        for claim in activeClaims {
            if shouldSuppressSystemReview(latestAction: latestClaimFeedback[claim.id]) {
                continue
            }
            for item in claimItems(for: claim, sourcesByID: sourcesByID, now: now) {
                upsert(item, into: &items)
            }
        }

        for record in feedback {
            guard let item = feedbackItem(for: record, claimsByID: claimsByID, sourcesByID: sourcesByID) else {
                continue
            }
            upsert(item, into: &items)
        }

        return items.values.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func claimItems(
        for claim: ClaimRecord,
        sourcesByID: [String: SourceRecord],
        now _: Date
    ) -> [ReviewQueueItem] {
        guard !isPassiveBrowserClaim(claim, sourcesByID: sourcesByID) else {
            return []
        }
        let certainty = effectiveUnderstandingConfidence(for: claim, sourcesByID: sourcesByID)
        guard certainty < Self.approvalThreshold else { return [] }

        let confirmationDetail = confirmationDetail(for: claim)

        return [ReviewQueueItem(
            id: "claim:\(claim.id):needs-confirmation",
            targetType: .claim,
            targetID: claim.id,
            title: confirmationDetail,
            detail: confirmationPrompt(for: claim, sourcesByID: sourcesByID),
            reason: confirmationReason(for: claim, certainty: certainty, sourcesByID: sourcesByID),
            priority: reviewPriority(for: claim, certainty: certainty, sourcesByID: sourcesByID),
            createdAt: claim.createdAt,
            sourceRefs: claim.sourceRefs
        )]
    }

    private func feedbackItem(
        for feedback: FeedbackRecord,
        claimsByID: [String: ClaimRecord],
        sourcesByID: [String: SourceRecord]
    ) -> ReviewQueueItem? {
        let metadata: (reason: String, priority: Int)
        switch feedback.action {
        case .merge:
            metadata = ("Merge review requested", 92)
        case .split:
            metadata = ("Split review requested", 90)
        case .askLater:
            metadata = ("Asked for later review", 78)
        default:
            return nil
        }

        if feedback.targetType == "claim", let claim = claimsByID[feedback.targetID] {
            if feedback.action == .askLater,
               feedback.note.localizedCaseInsensitiveContains("self-healing found a possible contradiction"),
               claim.status == .active,
               claim.contradictionGroupID == nil {
                return nil
            }
            return ReviewQueueItem(
                id: "feedback:\(feedback.id)",
                targetType: .claim,
                targetID: feedback.targetID,
                title: confirmationDetail(for: claim),
                detail: "Review requested",
                reason: metadata.reason,
                action: feedback.action,
                priority: metadata.priority,
                createdAt: feedback.timestamp,
                sourceRefs: claim.sourceRefs
            )
        }

        return nil
    }

    private func upsert(_ item: ReviewQueueItem, into items: inout [String: ReviewQueueItem]) {
        let key = "\(item.targetType.rawValue):\(item.targetID)"
        guard var existing = items[key] else {
            items[key] = item
            return
        }
        let itemShouldOwnID = item.priority > existing.priority
            || (item.priority == existing.priority && item.createdAt > existing.createdAt)
        existing.reason = combinedReason(existing.reason, item.reason)
        existing.priority = max(existing.priority, item.priority)
        existing.createdAt = max(existing.createdAt, item.createdAt)
        existing.sourceRefs = stableUnion(existing.sourceRefs, item.sourceRefs)
        existing.title = existing.title.isEmpty ? item.title : existing.title
        existing.detail = existing.detail.isEmpty ? item.detail : existing.detail
        if itemShouldOwnID {
            existing.id = item.id
            existing.action = item.action
            if !item.detail.isEmpty {
                existing.detail = item.detail
            }
        } else if existing.action == nil, item.action != nil {
            existing.action = item.action
        }
        items[key] = existing
    }

    private func effectiveUnderstandingConfidence(
        for claim: ClaimRecord,
        sourcesByID: [String: SourceRecord]
    ) -> Double {
        var confidence = claim.confidence

        if claim.status == .suspect {
            confidence = min(confidence, 0.69)
        }
        if claim.status == .contradicted || claim.contradictionGroupID != nil {
            confidence = min(confidence, 0.62)
        }
        if isIncidentalBrowserClaim(claim, sourcesByID: sourcesByID) {
            confidence = min(confidence, 0.64)
        }
        if claim.sourceRefs.isEmpty && !isAuthoritativeUserClaim(claim) {
            confidence = min(confidence, 0.66)
        }

        return max(0, min(1, confidence))
    }

    private func isAuthoritativeUserClaim(_ claim: ClaimRecord) -> Bool {
        claim.createdBy == "user-wiki-edit"
            || claim.claimType == "user-authored-wiki"
            || (claim.status == .userCorrected && claim.confidence >= 0.999)
    }

    private func confirmationReason(
        for claim: ClaimRecord,
        certainty: Double,
        sourcesByID: [String: SourceRecord]
    ) -> String {
        if claim.status == .contradicted || claim.contradictionGroupID != nil {
            return "Conflicts with another memory"
        }
        if isIncidentalBrowserClaim(claim, sourcesByID: sourcesByID) {
            return "Browser history alone is not enough evidence"
        }
        if claim.status == .suspect || claim.sourceRefs.isEmpty {
            return "Hive needs stronger evidence"
        }
        if certainty >= 0.85 {
            return "Strong supporting evidence"
        }
        if certainty >= 0.7 {
            return "Moderate supporting evidence"
        }
        return "Needs human review"
    }

    private func confirmationPrompt(for claim: ClaimRecord, sourcesByID: [String: SourceRecord]) -> String {
        if claim.status == .contradicted || claim.contradictionGroupID != nil {
            return "Resolve which version should stay in the wiki."
        }
        if isIncidentalBrowserClaim(claim, sourcesByID: sourcesByID) {
            return "Use this browser item as meaningful knowledge?"
        }
        return "Add this understood detail to the wiki?"
    }

    private func confirmationDetail(for claim: ClaimRecord) -> String {
        var title = claim.statement
        if title.localizedLowercase.hasPrefix("incidental:") {
            title = String(title.dropFirst("INCIDENTAL:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parts = title
            .components(separatedBy: " — ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            let usefulExtras = parts.dropFirst(2).filter { part in
                let lower = part.localizedLowercase
                return !lower.contains("browser appearance alone")
                    && !lower.contains("not treated as preference")
                    && !lower.contains("browser evidence")
            }
            let suffix = usefulExtras.isEmpty ? "" : " · \(usefulExtras.joined(separator: " · "))"
            return "\(parts[0]) · \(parts[1])\(suffix)"
        }
        return title
    }

    private func reviewPriority(
        for claim: ClaimRecord,
        certainty: Double,
        sourcesByID: [String: SourceRecord]
    ) -> Int {
        var priority = Int(((Self.approvalThreshold - certainty) * 100).rounded()) + 70
        if claim.status == .contradicted || claim.contradictionGroupID != nil {
            priority += 20
        }
        if isIncidentalBrowserClaim(claim, sourcesByID: sourcesByID) {
            priority += 8
        }
        return min(99, max(1, priority))
    }

    private func isIncidentalBrowserClaim(_ claim: ClaimRecord, sourcesByID: [String: SourceRecord]) -> Bool {
        let uncertainty = claim.uncertaintyReason.localizedLowercase
        let statement = claim.statement.localizedLowercase
        let browserEvidence = hasBrowserEvidence(claim, sourcesByID: sourcesByID)
        return browserEvidence
            && (claim.status == .suspect
                || claim.confidence < 0.65
                || uncertainty.contains("incidental")
                || uncertainty.contains("browser")
                || statement.contains("incidental"))
    }

    private func isPassiveBrowserClaim(_ claim: ClaimRecord, sourcesByID: [String: SourceRecord]) -> Bool {
        guard hasBrowserEvidence(claim, sourcesByID: sourcesByID) else { return false }
        return claim.claimType == "browser-observation" || isIncidentalBrowserClaim(claim, sourcesByID: sourcesByID)
    }

    private func hasBrowserEvidence(_ claim: ClaimRecord, sourcesByID: [String: SourceRecord]) -> Bool {
        claim.sourceRefs.contains { sourceID in
            guard let source = sourcesByID[sourceID] else { return false }
            return source.kind == .browserHistory || source.kind == .browserBookmark || source.connector.contains("browser")
        }
    }

    private func combinedReason(_ left: String, _ right: String) -> String {
        let parts = (left.components(separatedBy: ", ") + right.components(separatedBy: ", "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return stableUnique(parts).joined(separator: ", ")
    }

    private func stableUnion(_ left: [String], _ right: [String]) -> [String] {
        stableUnique(left + right)
    }

    private func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    private func latestFeedbackActions(_ feedback: [FeedbackRecord]) -> [String: FeedbackAction] {
        var latest: [String: FeedbackRecord] = [:]
        for record in feedback {
            if let existing = latest[record.targetID], existing.timestamp >= record.timestamp {
                continue
            }
            latest[record.targetID] = record
        }
        return latest.mapValues(\.action)
    }

    private func shouldSuppressSystemReview(latestAction: FeedbackAction?) -> Bool {
        switch latestAction {
        case .some(.approve), .some(.deny), .some(.delete), .some(.incidental), .some(.matters), .some(.forget):
            return true
        case .some(.askLater), .some(.merge), .some(.split), .some(.edit), .none:
            return false
        }
    }
}
