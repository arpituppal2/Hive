import Foundation

public struct CitedAnswer: Hashable, Sendable {
    public var answer: String
    public var citations: [SourceRecord]
    public var uncertainty: String
    public var suggestedActions: [String]

    public init(answer: String, citations: [SourceRecord], uncertainty: String, suggestedActions: [String]) {
        self.answer = answer
        self.citations = citations
        self.uncertainty = uncertainty
        self.suggestedActions = suggestedActions
    }
}

public enum ModelAvailabilityState: Hashable, Sendable {
    case localSynthesisAvailable
    case indexedMemoryOnly

    public var userVisibleLabel: String {
        switch self {
        case .localSynthesisAvailable:
            return "Local synthesis available"
        case .indexedMemoryOnly:
            return "Indexed memory only"
        }
    }
}

public struct ChatAnswerEngine: Sendable {
    private let localAssistant = LocalAssistant()

    public init() {}

    public func answer(
        query: String,
        sources: [SourceRecord],
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        reviewQueue: [ReviewQueueItem] = [],
        modelAvailability: ModelAvailabilityState = .indexedMemoryOnly,
        visibility: DerivedMemoryVisibility = .allowAll
    ) -> CitedAnswer {
        var answer = localAssistant.answer(
            query: query,
            sources: sources,
            claims: claims,
            wikiPages: wikiPages,
            reviewQueue: reviewQueue,
            visibility: visibility
        )
        if answer.uncertainty == ModelAvailabilityState.indexedMemoryOnly.userVisibleLabel || modelAvailability == .localSynthesisAvailable {
            answer.uncertainty = modelAvailability.userVisibleLabel
        }
        return answer
    }

    public static func modelAvailability(modelsDirectory: URL, fileManager: FileManager = .default) -> ModelAvailabilityState {
        let catalog = ModelCatalog().resolvingInstalledModels(in: modelsDirectory, fileManager: fileManager)
        return catalog.capabilities.contains { $0.task == "chat" && $0.installed }
            ? .localSynthesisAvailable
            : .indexedMemoryOnly
    }
}

public struct LocalAssistant: Sendable {
    public init() {}

    public func answer(
        query: String,
        sources: [SourceRecord],
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        reviewQueue: [ReviewQueueItem] = [],
        visibility: DerivedMemoryVisibility = .allowAll
    ) -> CitedAnswer {
        let tokens = searchTokens(query)
        guard !tokens.isEmpty else {
            return CitedAnswer(
                answer: "Ask about a source, topic, project, or claim in the local brain.",
                citations: [],
                uncertainty: "No query terms were available.",
                suggestedActions: ["Search Field", "Open The Colony"]
            )
        }

        let reviewItemsByTargetID = Dictionary(grouping: reviewQueue, by: \.targetID)
        let rankedClaims = claims
            .filter { claim in
                claim.status != .retracted
                    && visibility.shouldAnswerFromClaim(claim)
                    && claim.claimType != "browser-observation"
                    && claim.claimType != "browser-signal"
                    && claim.claimType != "browser-session-intent"
                    && claim.claimType != "graph-insight"
            }
            .map { claim -> (ClaimRecord, Int) in
                let claimTokens = searchTokens(claim.statement)
                let tierBoost = relevanceBoost(for: claim)
                let currentBoost = temporalBoost(for: claim)
                let score = claimTokens.intersection(tokens).count * 3
                    + (reviewItemsByTargetID[claim.id] == nil ? 1 : 0)
                    + (claim.confidence >= 0.75 ? 1 : 0)
                    + tierBoost
                    + currentBoost
                return (claim, score)
            }
            .filter { $0.1 > 0 }
            .sorted { left, right in
                if left.1 == right.1 { return left.0.confidence > right.0.confidence }
                return left.1 > right.1
            }
            .prefix(5)
            .map(\.0)

        if rankedClaims.isEmpty {
            let wikiHit = WikiSearchRouter()
                .searchWiki(query: query, pages: wikiPages, limit: 1, mode: .automatic)
                .first
            let sourceHits = rankedSourceHints(query: query, sources: sources)
            if !sourceHits.isEmpty {
                let titles = sourceHits
                    .prefix(3)
                    .map { SourcePresentationModel.cleanTitle($0.title) }
                    .joined(separator: ", ")
                return CitedAnswer(
                    answer: "Field has related source material: \(titles). Hive has not turned that into a settled Colony answer yet, so this needs review before it becomes memory.",
                    citations: Array(sourceHits.prefix(4)),
                    uncertainty: "Field evidence needs review",
                    suggestedActions: ["Review Field", "Open Field", "Ask a narrower question"]
                )
            }
            return CitedAnswer(
                answer: wikiHit.map {
                    "Indexed memory has related wiki context in \(SourcePresentationModel.cleanTitle($0.title)). The index points there first, but no specific maintained claim is strong enough to answer directly."
                } ?? "Indexed memory does not have a solid answer for that yet.",
                citations: [],
                uncertainty: "Indexed memory only",
                suggestedActions: ["Open The Colony", "Search The Hive", "Import more evidence"]
            )
        }

        let sourceIDs = Set(rankedClaims.flatMap(\.sourceRefs))
        let citedSources = sources
            .filter { source in
                sourceIDs.contains(source.id)
                    && source.kind != .browserHistory
                    && source.kind != .browserBookmark
            }
            .prefix(4)
        let answerText = proseAnswer(from: Array(rankedClaims), reviewItemsByTargetID: reviewItemsByTargetID)
        let averageConfidence = rankedClaims.map(\.confidence).reduce(0, +) / Double(rankedClaims.count)
        let matchedReviewItems = rankedClaims.flatMap { reviewItemsByTargetID[$0.id] ?? [] }
        let browserReviewCount = matchedReviewItems.filter { item in
            item.reason.localizedCaseInsensitiveContains("browser")
        }.count
        let uncertainty: String
        if !matchedReviewItems.isEmpty {
            uncertainty = browserReviewCount > 0
                ? "Some matching browser evidence needs confirmation before Hive treats it as preference."
                : "Some matching memory needs confirmation."
        } else if averageConfidence >= 0.75 {
            uncertainty = "Indexed memory only"
        } else {
            uncertainty = "Indexed memory has this, but it is not fully settled."
        }
        var actions = ["Open The Colony", "Show in The Hive", "Ask follow-up"]
        if !matchedReviewItems.isEmpty {
            actions.insert("Open Needs Confirmation", at: 0)
            if browserReviewCount > 0 {
                actions.insert("Mark incidental if irrelevant", at: 1)
            }
        }
        return CitedAnswer(
            answer: answerText,
            citations: Array(citedSources),
            uncertainty: uncertainty,
            suggestedActions: stableUnique(actions)
        )
    }

    private func rankedSourceHints(query: String, sources: [SourceRecord]) -> [SourceRecord] {
        let tokens = searchTokens(query)
        guard !tokens.isEmpty else { return [] }
        return sources
            .filter { source in
                source.deletionState == .active
                    && source.kind != .browserHistory
                    && source.kind != .browserBookmark
            }
            .map { source -> (SourceRecord, Int) in
                let haystack = "\(source.title) \(source.kind.rawValue) \(source.connector)".lowercased()
                let score = tokens.reduce(into: 0) { total, token in
                    if haystack.contains(token) {
                        total += 1
                    }
                }
                return (source, score)
            }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 { return $0.0.importedAt > $1.0.importedAt }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private func proseAnswer(from claims: [ClaimRecord], reviewItemsByTargetID: [String: [ReviewQueueItem]]) -> String {
        let settled = claims.prefix(4).map { claim -> String in
            let sentence = articleSentence(claim.statement)
            if reviewItemsByTargetID[claim.id]?.isEmpty == false {
                return "\(sentence) Hive has not fully sealed this yet."
            }
            return sentence
        }
        guard let first = settled.first else {
            return "Indexed memory does not have a solid answer for that yet."
        }
        let rest = settled.dropFirst().joined(separator: " ")
        return rest.isEmpty
            ? "Indexed memory points to this: \(first)"
            : "Indexed memory points to this: \(first) \(rest)"
    }

    private func articleSentence(_ statement: String) -> String {
        var cleaned = SourcePresentationModel.cleanTitle(statement)
        if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
            cleaned += "."
        }
        return cleaned
    }

    private func relevanceBoost(for claim: ClaimRecord) -> Int {
        switch claim.relevanceTier {
        case .canonical:
            return 8
        case .active:
            return 6
        case .supporting:
            return 3
        case .review, .incidental, .stale, .retracted, nil:
            return 0
        }
    }

    private func temporalBoost(for claim: ClaimRecord) -> Int {
        switch claim.temporalState?.kind {
        case .current, .deadline, .recurring:
            return 3
        case .historical:
            return 1
        case .oneOff, .stale:
            return -3
        case .unknown, nil:
            return 0
        }
    }

    private func searchTokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "about", "after", "alone", "and", "are", "because", "been", "browser", "claim", "from",
            "have", "history", "into", "local", "more", "not", "that", "the", "this", "with", "without"
        ]
        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stopwords.contains($0) }
        )
    }

    private func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

public final class ControlPlane: @unchecked Sendable {
    private let store: HiveStore
    private let paths: HivePaths
    private let fileManager: FileManager

    public init(store: HiveStore, paths: HivePaths, fileManager: FileManager = .default) {
        self.store = store
        self.paths = paths
        self.fileManager = fileManager
    }

    public func applyFeedback(_ feedback: FeedbackRecord) throws {
        try store.saveFeedback(feedback)
        switch feedback.action {
        case .delete where feedback.targetType == "claim":
            try store.retractClaim(id: feedback.targetID, reason: feedback.note.isEmpty ? "Deleted by user." : feedback.note)
        case .deny where feedback.targetType == "claim":
            try store.retractClaim(id: feedback.targetID, reason: feedback.note.isEmpty ? "Denied by user." : feedback.note)
        case .approve where feedback.targetType == "claim":
            try updateClaim(id: feedback.targetID) { claim in
                claim.status = .active
                claim.confidence = min(1, max(claim.confidence, 0.88))
                claim.uncertaintyReason = feedback.note.isEmpty ? "Approved by user." : feedback.note
                claim.correctionLineage.append(feedback.id)
            }
        case .incidental where feedback.targetType == "claim":
            try updateClaim(id: feedback.targetID) { claim in
                claim.status = .suspect
                claim.confidence = min(claim.confidence, 0.22)
                claim.uncertaintyReason = feedback.note.isEmpty ? "Marked incidental by user." : feedback.note
                claim.correctionLineage.append(feedback.id)
            }
        case .matters where feedback.targetType == "claim":
            try updateClaim(id: feedback.targetID) { claim in
                claim.status = .active
                claim.confidence = min(1, max(claim.confidence, 0.76))
                claim.uncertaintyReason = feedback.note.isEmpty ? "Marked important by user." : feedback.note
                claim.correctionLineage.append(feedback.id)
            }
        case .askLater where feedback.targetType == "claim":
            try updateClaim(id: feedback.targetID) { claim in
                claim.status = .suspect
                claim.uncertaintyReason = feedback.note.isEmpty ? "User asked Hive to revisit later." : feedback.note
                claim.correctionLineage.append(feedback.id)
            }
        case .forget where feedback.targetType == "source":
            try fullForgetSource(id: feedback.targetID)
        default:
            break
        }
    }

    @discardableResult
    public func replaceClaimWithCorrection(id: String, statement: String, note: String = "") throws -> ClaimRecord {
        let correctedStatement = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !correctedStatement.isEmpty else {
            throw HiveStoreError.missingRecord("non-empty correction for claim \(id)")
        }
        guard var original = try store.fetchClaim(id: id) else {
            throw HiveStoreError.missingRecord("claim \(id)")
        }
        let feedback = FeedbackRecord(
            targetType: "claim",
            targetID: id,
            action: .edit,
            note: note.isEmpty ? "User corrected claim." : note
        )
        try store.saveFeedback(feedback)

        original.status = .retracted
        original.uncertaintyReason = "Replaced by user correction."
        original.correctionLineage.append(feedback.id)
        try store.saveClaim(original)

        var replacement = ClaimRecord(
            statement: correctedStatement,
            claimType: original.claimType,
            sourceRefs: original.sourceRefs,
            sourceSpanRefs: original.sourceSpanRefs,
            confidence: min(1, max(original.confidence, 0.88)),
            uncertaintyReason: "User correction replacing \(original.id).",
            status: .userCorrected,
            createdBy: "user"
        )
        replacement.correctionLineage = original.correctionLineage + [original.id]
        try store.saveClaim(replacement)
        try store.appendAudit(AuditEventRecord(
            eventType: "claim.corrected",
            targetType: "claim",
            targetID: replacement.id,
            sourceRefs: replacement.sourceRefs,
            detail: "Replaced claim \(original.id)."
        ))
        return replacement
    }

    private func updateClaim(id: String, _ mutate: (inout ClaimRecord) -> Void) throws {
        guard var claim = try store.fetchClaim(id: id) else {
            throw HiveStoreError.missingRecord("claim \(id)")
        }
        mutate(&claim)
        try store.saveClaim(claim)
        try store.appendAudit(AuditEventRecord(
            eventType: "claim.updatedByFeedback",
            targetType: "claim",
            targetID: id,
            sourceRefs: claim.sourceRefs,
            detail: claim.uncertaintyReason
        ))
    }

    public func deleteRawOnly(sourceID: String) throws {
        let sourceBeforeDelete = try store.fetchSource(id: sourceID)
        let blobs = try store.fetchRawBlobs(sourceID: sourceID)
        for blob in blobs {
            let url = URL(fileURLWithPath: blob.localPath)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
        if let sourceBeforeDelete {
            try WikiVaultManager(paths: paths, fileManager: fileManager).removeRawMirror(for: sourceBeforeDelete)
        }
        try store.deleteRawBlobRecords(sourceID: sourceID)
        let scrubbed = try store.scrubRawExtractedText(sourceID: sourceID)
        guard var source = try store.fetchSource(id: sourceID) else { return }
        source.deletionState = .rawDeleted
        source.status = .deleted
        try store.saveSource(source)
        try store.appendAudit(AuditEventRecord(
            eventType: "source.rawDeleted",
            targetType: "source",
            targetID: sourceID,
            sourceRefs: [sourceID],
            detail: "Raw blob removed; scrubbed \(scrubbed.artifactCount) artifacts and \(scrubbed.chunkCount) chunks into minimal provenance capsules."
        ))
    }

    public func fullForgetSource(id: String) throws {
        let sourceBeforeForget = try store.fetchSource(id: id)
        let pagesBeforeForget = try store.fetchWikiPages().filter { page in
            page.sourceRefs.contains(id) || page.claimRefs.contains { claimID in
                (try? store.fetchClaim(id: claimID))?.sourceRefs.contains(id) == true
            }
        }
        let blobs = try store.fetchRawBlobs(sourceID: id)
        for blob in blobs {
            let url = URL(fileURLWithPath: blob.localPath)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
        let vault = WikiVaultManager(paths: paths, fileManager: fileManager)
        if let sourceBeforeForget {
            try vault.removeRawMirror(for: sourceBeforeForget)
        }
        for page in pagesBeforeForget {
            try vault.removePageFile(page)
        }
        try store.fullForgetSource(id: id)
    }

    @discardableResult
    public func fullForgetSources(kinds: Set<SourceKind>) throws -> Int {
        let targets = try store.fetchSources().filter {
            kinds.contains($0.kind) && $0.deletionState != .fullForgotten
        }
        for source in targets {
            try fullForgetSource(id: source.id)
        }
        return targets.count
    }

    @discardableResult
    public func purgeExpiredRawInputs(now: Date = Date()) throws -> Int {
        let sources = try store.fetchSources().filter {
            !$0.pinned && $0.retentionExpiresAt <= now && $0.deletionState == .active
        }
        for source in sources {
            try deleteRawOnly(sourceID: source.id)
            if var updated = try store.fetchSource(id: source.id) {
                updated.deletionState = .rawExpired
                try store.saveSource(updated)
            }
        }
        return sources.count
    }
}
