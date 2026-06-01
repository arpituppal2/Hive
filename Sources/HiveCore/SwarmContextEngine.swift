import Foundation
#if canImport(ImageIO) && canImport(Vision)
import ImageIO
import Vision
#endif

public enum SwarmAttachmentExtractionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case queued
    case extracting
    case extracted
    case failed
    case cancelled

    public var displayTitle: String {
        switch self {
        case .queued:
            return "Queued"
        case .extracting:
            return "Extracting"
        case .extracted:
            return "Ready"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

public struct SwarmDraftAttachment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var fileURL: URL
    public var displayName: String
    public var kind: SourceKind
    public var status: SwarmAttachmentExtractionStatus
    public var summary: String
    public var chunkCount: Int
    public var tokenEstimate: Int
    public var errorMessage: String?

    public init(
        id: UUID,
        fileURL: URL,
        displayName: String,
        kind: SourceKind,
        status: SwarmAttachmentExtractionStatus,
        summary: String = "",
        chunkCount: Int = 0,
        tokenEstimate: Int = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.kind = kind
        self.status = status
        self.summary = summary
        self.chunkCount = chunkCount
        self.tokenEstimate = tokenEstimate
        self.errorMessage = errorMessage
    }
}

public struct SwarmAttachmentExtractionResult: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var fileURL: URL
    public var displayName: String
    public var kind: SourceKind
    public var extractedText: String
    public var summary: String
    public var chunks: [String]
    public var tokenEstimate: Int
    public var requiresModel: Bool
    public var extractionNote: String

    public init(
        id: UUID,
        fileURL: URL,
        displayName: String,
        kind: SourceKind,
        extractedText: String,
        summary: String,
        chunks: [String],
        tokenEstimate: Int,
        requiresModel: Bool,
        extractionNote: String
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.kind = kind
        self.extractedText = extractedText
        self.summary = summary
        self.chunks = chunks
        self.tokenEstimate = tokenEstimate
        self.requiresModel = requiresModel
        self.extractionNote = extractionNote
    }
}

public struct SwarmTokenEstimator: Sendable {
    public init() {}

    public func estimate(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return max(1, Int(ceil(Double(trimmed.count) / 4.0)))
    }

    public func estimate(_ texts: [String]) -> Int {
        texts.reduce(0) { $0 + estimate($1) }
    }
}

public actor SwarmAttachmentPipeline {
    public typealias ExtractionHandler = @Sendable (URL, SourceKind, UUID) async throws -> SwarmAttachmentExtractionResult

    private struct PipelineEntry: Sendable {
        var draft: SwarmDraftAttachment
        var task: Task<SwarmAttachmentExtractionResult, Error>?
        var result: SwarmAttachmentExtractionResult?
    }

    private var drafts: [UUID: [UUID: PipelineEntry]] = [:]
    private let extractionHandler: ExtractionHandler

    public init(
        extractor: LocalExtractor = LocalExtractor(),
        chunker: TextChunker = TextChunker(targetCharacters: 1400, overlapCharacters: 180),
        tokenEstimator: SwarmTokenEstimator = SwarmTokenEstimator()
    ) {
        self.extractionHandler = { url, kind, attachmentID in
            try Task.checkCancellation()
            let document: ExtractedDocument
            if (kind == .image || kind == .screenshot), let recognizedText = Self.recognizedImageText(from: url) {
                document = ExtractedDocument(
                    artifactType: "image-ocr",
                    text: recognizedText,
                    confidence: 0.72,
                    requiresModel: false,
                    note: "Recognized image text locally."
                )
            } else {
                document = try extractor.extract(from: url, kind: kind)
            }
            try Task.checkCancellation()
            let chunks = chunker.chunks(for: document.text)
            let summary = Self.summary(for: document.text, fallback: url.deletingPathExtension().lastPathComponent)
            return SwarmAttachmentExtractionResult(
                id: attachmentID,
                fileURL: url,
                displayName: url.lastPathComponent,
                kind: kind,
                extractedText: document.text,
                summary: summary,
                chunks: chunks,
                tokenEstimate: tokenEstimator.estimate(document.text),
                requiresModel: document.requiresModel,
                extractionNote: document.note
            )
        }
    }

    public init(extractionHandler: @escaping ExtractionHandler) {
        self.extractionHandler = extractionHandler
    }

    @discardableResult
    public func enqueue(url: URL, forDraft draftID: UUID) -> SwarmDraftAttachment {
        let attachmentID = UUID()
        let kind = SourceTypeDetector.kind(for: url)
        let draft = SwarmDraftAttachment(
            id: attachmentID,
            fileURL: url,
            displayName: url.lastPathComponent,
            kind: kind,
            status: .extracting
        )
        var entry = PipelineEntry(draft: draft, task: nil, result: nil)
        let task = Task.detached(priority: .utility) { [extractionHandler] in
            try await extractionHandler(url, kind, attachmentID)
        }
        entry.task = task
        drafts[draftID, default: [:]][attachmentID] = entry

        Task { [weak self] in
            let outcome = await task.result
            await self?.finish(draftID: draftID, attachmentID: attachmentID, outcome: outcome)
        }
        return draft
    }

    public func snapshot(forDraft draftID: UUID) -> [SwarmDraftAttachment] {
        let entries = drafts[draftID] ?? [:]
        return entries.values
            .map(\.draft)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func remove(attachmentID: UUID, fromDraft draftID: UUID) {
        guard var draftEntries = drafts[draftID], let entry = draftEntries[attachmentID] else { return }
        entry.task?.cancel()
        draftEntries.removeValue(forKey: attachmentID)
        if draftEntries.isEmpty {
            drafts.removeValue(forKey: draftID)
        } else {
            drafts[draftID] = draftEntries
        }
    }

    public func cancelDraft(_ draftID: UUID) {
        let entries = drafts[draftID] ?? [:]
        for entry in entries.values {
            entry.task?.cancel()
        }
        drafts.removeValue(forKey: draftID)
    }

    public func commitCompleted(forDraft draftID: UUID) async -> [SwarmAttachmentExtractionResult] {
        guard let entries = drafts[draftID] else { return [] }
        var committed: [SwarmAttachmentExtractionResult] = []
        for entry in entries.values {
            if let result = entry.result {
                committed.append(result)
                continue
            }
            guard let task = entry.task else { continue }
            if case .success(let result) = await task.result {
                committed.append(result)
            }
        }
        drafts.removeValue(forKey: draftID)
        return committed.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func finish(draftID: UUID, attachmentID: UUID, outcome: Result<SwarmAttachmentExtractionResult, Error>) {
        guard var draftEntries = drafts[draftID], var entry = draftEntries[attachmentID] else { return }
        switch outcome {
        case .success(let result):
            entry.result = result
            entry.draft.status = .extracted
            entry.draft.summary = result.summary
            entry.draft.chunkCount = result.chunks.count
            entry.draft.tokenEstimate = result.tokenEstimate
            entry.draft.errorMessage = nil
        case .failure(let error):
            if (error as? CancellationError) != nil || Task.isCancelled {
                entry.draft.status = .cancelled
            } else {
                entry.draft.status = .failed
                entry.draft.errorMessage = error.localizedDescription
            }
        }
        draftEntries[attachmentID] = entry
        drafts[draftID] = draftEntries
    }

    private static func summary(for text: String, fallback: String) -> String {
        let cleaned = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !cleaned.isEmpty else { return fallback }
        return String(cleaned.prefix(260))
    }

    private static func recognizedImageText(from url: URL) -> String? {
        #if canImport(ImageIO) && canImport(Vision)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            let text = request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.isEmpty == false ? text : nil
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

public struct SwarmModelProfile: Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var maxContextTokens: Int
    public var compactionTrigger: Double
    public var recentTurnsToKeep: Int
    public var preferredColonyChunks: Int
    public var minimumRelevanceScore: Double
    public var maximumAttachmentShare: Double

    public init(
        id: String,
        displayName: String,
        maxContextTokens: Int,
        compactionTrigger: Double = 0.78,
        recentTurnsToKeep: Int = 5,
        preferredColonyChunks: Int = 6,
        minimumRelevanceScore: Double = 0.18,
        maximumAttachmentShare: Double = 0.60
    ) {
        self.id = id
        self.displayName = displayName
        self.maxContextTokens = maxContextTokens
        self.compactionTrigger = compactionTrigger
        self.recentTurnsToKeep = recentTurnsToKeep
        self.preferredColonyChunks = preferredColonyChunks
        self.minimumRelevanceScore = minimumRelevanceScore
        self.maximumAttachmentShare = maximumAttachmentShare
    }
}

public struct SwarmModelProfileRegistry: Sendable {
    public static let indexedWiki = SwarmModelProfile(
        id: "indexed-wiki",
        displayName: "Indexed Wiki",
        maxContextTokens: 4096,
        compactionTrigger: 0.70,
        recentTurnsToKeep: 4,
        preferredColonyChunks: 4,
        minimumRelevanceScore: 0.22
    )

    public static let appleIntelligence = SwarmModelProfile(
        id: "apple-intelligence",
        displayName: "Local AI",
        maxContextTokens: 8192,
        compactionTrigger: 0.78,
        recentTurnsToKeep: 5,
        preferredColonyChunks: 7,
        minimumRelevanceScore: 0.18
    )

    public static let cloud = SwarmModelProfile(
        id: "cloud-key",
        displayName: "Cloud key",
        maxContextTokens: 12000,
        compactionTrigger: 0.82,
        recentTurnsToKeep: 5,
        preferredColonyChunks: 8,
        minimumRelevanceScore: 0.17
    )

    public init() {}

    public func profile(for id: String?) -> SwarmModelProfile {
        switch id {
        case Self.appleIntelligence.id:
            return Self.appleIntelligence
        case Self.cloud.id:
            return Self.cloud
        default:
            return Self.indexedWiki
        }
    }
}

public struct SwarmRetrievedColonyChunk: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var pageID: String
    public var pageTitle: String
    public var text: String
    public var score: Double
    public var tokenEstimate: Int

    public init(id: String, pageID: String, pageTitle: String, text: String, score: Double, tokenEstimate: Int) {
        self.id = id
        self.pageID = pageID
        self.pageTitle = pageTitle
        self.text = text
        self.score = score
        self.tokenEstimate = tokenEstimate
    }
}

public struct SwarmContextBudgetAllocation: Codable, Hashable, Sendable {
    public var totalAvailableTokens: Int
    public var userPromptTokens: Int
    public var attachmentTokens: Int
    public var colonyTokens: Int
    public var recentHistoryTokens: Int
    public var remainingTokens: Int

    public init(
        totalAvailableTokens: Int,
        userPromptTokens: Int,
        attachmentTokens: Int,
        colonyTokens: Int,
        recentHistoryTokens: Int,
        remainingTokens: Int
    ) {
        self.totalAvailableTokens = totalAvailableTokens
        self.userPromptTokens = userPromptTokens
        self.attachmentTokens = attachmentTokens
        self.colonyTokens = colonyTokens
        self.recentHistoryTokens = recentHistoryTokens
        self.remainingTokens = remainingTokens
    }
}

public struct SwarmContextPlan: Codable, Hashable, Sendable {
    public var modelProfile: SwarmModelProfile
    public var attachments: [SwarmAttachmentExtractionResult]
    public var colonyChunks: [SwarmRetrievedColonyChunk]
    public var budget: SwarmContextBudgetAllocation
    public var compactionMemory: String?

    public init(
        modelProfile: SwarmModelProfile,
        attachments: [SwarmAttachmentExtractionResult],
        colonyChunks: [SwarmRetrievedColonyChunk],
        budget: SwarmContextBudgetAllocation,
        compactionMemory: String? = nil
    ) {
        self.modelProfile = modelProfile
        self.attachments = attachments
        self.colonyChunks = colonyChunks
        self.budget = budget
        self.compactionMemory = compactionMemory
    }
}

public struct SwarmColonyContextRetriever: Sendable {
    private let chunker: TextChunker
    private let tokenEstimator: SwarmTokenEstimator

    public init(
        chunker: TextChunker = TextChunker(targetCharacters: 1000, overlapCharacters: 120),
        tokenEstimator: SwarmTokenEstimator = SwarmTokenEstimator()
    ) {
        self.chunker = chunker
        self.tokenEstimator = tokenEstimator
    }

    public func retrieve(
        prompt: String,
        attachments: [SwarmAttachmentExtractionResult],
        pages: [WikiPageRecord],
        recentHistory: [SwarmContextMessage] = [],
        profile: SwarmModelProfile
    ) -> SwarmContextPlan {
        let promptTokens = tokenEstimator.estimate(prompt)
        let attachmentCap = max(0, Int(Double(profile.maxContextTokens) * profile.maximumAttachmentShare))
        let rawAttachmentTokens = attachments.reduce(0) { $0 + $1.tokenEstimate }
        let attachmentTokens = min(rawAttachmentTokens, attachmentCap)
        let recentHistoryTokens = min(
            tokenEstimator.estimate(recentHistory.suffix(profile.recentTurnsToKeep * 2).map(\.text)),
            max(0, Int(Double(profile.maxContextTokens) * 0.18))
        )
        let colonyBudget = max(0, profile.maxContextTokens - promptTokens - attachmentTokens - recentHistoryTokens)

        let queryText = ([prompt] + attachments.map(\.summary) + attachments.flatMap { $0.chunks.prefix(2) }).joined(separator: "\n")
        let queryTokens = Self.tokens(in: queryText)
        let candidates = rankCandidates(queryTokens: queryTokens, pages: pages)

        var selected: [SwarmRetrievedColonyChunk] = []
        var usedColonyTokens = 0
        for candidate in candidates where candidate.score >= profile.minimumRelevanceScore {
            guard selected.count < profile.preferredColonyChunks else { break }
            guard usedColonyTokens + candidate.tokenEstimate <= colonyBudget else { continue }
            selected.append(candidate)
            usedColonyTokens += candidate.tokenEstimate
        }

        let remaining = max(0, profile.maxContextTokens - promptTokens - attachmentTokens - usedColonyTokens - recentHistoryTokens)
        return SwarmContextPlan(
            modelProfile: profile,
            attachments: attachments,
            colonyChunks: selected,
            budget: SwarmContextBudgetAllocation(
                totalAvailableTokens: profile.maxContextTokens,
                userPromptTokens: promptTokens,
                attachmentTokens: attachmentTokens,
                colonyTokens: usedColonyTokens,
                recentHistoryTokens: recentHistoryTokens,
                remainingTokens: remaining
            )
        )
    }

    private func rankCandidates(queryTokens: Set<String>, pages: [WikiPageRecord]) -> [SwarmRetrievedColonyChunk] {
        guard !queryTokens.isEmpty else { return [] }
        let queryVector = Self.hashedVector(for: queryTokens)
        var candidates: [SwarmRetrievedColonyChunk] = []
        for page in pages where page.kind != .log && page.kind != .index {
            let chunks = chunker.chunks(for: page.markdown.isEmpty ? page.summary : page.markdown)
            let pageSummaryTokens = Self.tokens(in: page.summary)
            let pageTitleTokens = Self.tokens(in: page.title)
            for (offset, chunk) in chunks.enumerated() {
                let chunkTokens = Self.tokens(in: chunk)
                let titleScore = overlapScore(queryTokens, pageTitleTokens)
                let summaryScore = overlapScore(queryTokens, pageSummaryTokens)
                let bodyScore = overlapScore(queryTokens, chunkTokens)
                let keywordScore = min(1.0, titleScore * 0.46 + summaryScore * 0.34 + bodyScore * 0.20)
                guard keywordScore > 0 else { continue }
                let candidateVector = Self.hashedVector(for: pageTitleTokens.union(pageSummaryTokens).union(chunkTokens))
                let vectorScore = Self.cosineSimilarity(queryVector, candidateVector)
                let score = min(1.0, keywordScore * 0.62 + vectorScore * 0.38)
                guard score > 0 else { continue }
                candidates.append(SwarmRetrievedColonyChunk(
                    id: "\(page.id)#\(offset)",
                    pageID: page.id,
                    pageTitle: page.title,
                    text: chunk,
                    score: score,
                    tokenEstimate: tokenEstimator.estimate(chunk)
                ))
            }
        }
        return candidates.sorted { left, right in
            if left.score == right.score {
                return left.tokenEstimate < right.tokenEstimate
            }
            return left.score > right.score
        }
    }

    private func overlapScore(_ queryTokens: Set<String>, _ candidateTokens: Set<String>) -> Double {
        guard !queryTokens.isEmpty, !candidateTokens.isEmpty else { return 0 }
        let overlap = queryTokens.intersection(candidateTokens).count
        return Double(overlap) / Double(max(1, min(queryTokens.count, candidateTokens.count)))
    }

    private static func tokens(in text: String) -> Set<String> {
        let stop: Set<String> = [
            "about", "after", "again", "also", "and", "are", "ask", "based", "but", "can",
            "for", "from", "has", "have", "how", "into", "just", "not", "that", "the",
            "their", "this", "use", "using", "what", "when", "where", "with", "your"
        ]
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stop.contains($0) }
        return Set(words)
    }

    private static func hashedVector(for tokens: Set<String>, dimensions: Int = 96) -> [Double] {
        guard dimensions > 0 else { return [] }
        var vector = Array(repeating: 0.0, count: dimensions)
        for token in tokens {
            let hash = abs(token.hashValue)
            let index = hash % dimensions
            let sign = (hash / dimensions).isMultiple(of: 2) ? 1.0 : -1.0
            vector[index] += sign
        }
        return vector
    }

    private static func cosineSimilarity(_ left: [Double], _ right: [Double]) -> Double {
        guard left.count == right.count, !left.isEmpty else { return 0 }
        var dot = 0.0
        var leftMagnitude = 0.0
        var rightMagnitude = 0.0
        for index in left.indices {
            dot += left[index] * right[index]
            leftMagnitude += left[index] * left[index]
            rightMagnitude += right[index] * right[index]
        }
        guard leftMagnitude > 0, rightMagnitude > 0 else { return 0 }
        return max(0, dot / (sqrt(leftMagnitude) * sqrt(rightMagnitude)))
    }
}

public enum SwarmContextRole: String, Codable, Hashable, Sendable {
    case system
    case user
    case assistant
}

public struct SwarmContextMessage: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var role: SwarmContextRole
    public var text: String

    public init(id: String, role: SwarmContextRole, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct SwarmCompactionResult: Codable, Hashable, Sendable {
    public var didCompact: Bool
    public var memoryChunk: String?
    public var compactedMessages: [SwarmContextMessage]
    public var removedMessageIDs: [String]
    public var tokenRatioBeforeCompaction: Double

    public init(
        didCompact: Bool,
        memoryChunk: String?,
        compactedMessages: [SwarmContextMessage],
        removedMessageIDs: [String],
        tokenRatioBeforeCompaction: Double
    ) {
        self.didCompact = didCompact
        self.memoryChunk = memoryChunk
        self.compactedMessages = compactedMessages
        self.removedMessageIDs = removedMessageIDs
        self.tokenRatioBeforeCompaction = tokenRatioBeforeCompaction
    }
}

public struct SwarmContextCompactor: Sendable {
    private let tokenEstimator: SwarmTokenEstimator

    public init(tokenEstimator: SwarmTokenEstimator = SwarmTokenEstimator()) {
        self.tokenEstimator = tokenEstimator
    }

    public func compactIfNeeded(
        messages: [SwarmContextMessage],
        plan: SwarmContextPlan,
        profile: SwarmModelProfile
    ) -> SwarmCompactionResult {
        let currentTokens = tokenEstimator.estimate(messages.map(\.text))
            + plan.budget.userPromptTokens
            + plan.budget.attachmentTokens
            + plan.budget.colonyTokens
        let ratio = Double(currentTokens) / Double(max(1, profile.maxContextTokens))
        guard ratio >= profile.compactionTrigger else {
            return SwarmCompactionResult(
                didCompact: false,
                memoryChunk: nil,
                compactedMessages: messages,
                removedMessageIDs: [],
                tokenRatioBeforeCompaction: ratio
            )
        }

        let systemMessages = messages.filter { $0.role == .system }
        let activeMessages = messages.filter { $0.role != .system }
        let recentCount = min(activeMessages.count, profile.recentTurnsToKeep * 2)
        let oldMessages = Array(activeMessages.dropLast(recentCount))
        guard !oldMessages.isEmpty else {
            return SwarmCompactionResult(
                didCompact: false,
                memoryChunk: nil,
                compactedMessages: messages,
                removedMessageIDs: [],
                tokenRatioBeforeCompaction: ratio
            )
        }

        let compactCount = max(1, Int(ceil(Double(oldMessages.count) * 0.30)))
        let compactedSlice = Array(oldMessages.prefix(compactCount))
        let remainingOld = Array(oldMessages.dropFirst(compactCount))
        let recent = Array(activeMessages.suffix(recentCount))
        let memoryChunk = Self.memoryChunk(from: compactedSlice)
        let memoryMessage = SwarmContextMessage(
            id: "memory-\(UUID().uuidString)",
            role: .system,
            text: memoryChunk
        )
        let compactedMessages = systemMessages + [memoryMessage] + remainingOld + recent
        return SwarmCompactionResult(
            didCompact: true,
            memoryChunk: memoryChunk,
            compactedMessages: compactedMessages,
            removedMessageIDs: compactedSlice.map(\.id),
            tokenRatioBeforeCompaction: ratio
        )
    }

    private static func memoryChunk(from messages: [SwarmContextMessage]) -> String {
        let bullets = messages.prefix(12).map { message in
            let label = message.role == .user ? "User" : "Swarm"
            let compact = message.text
                .split(whereSeparator: \.isNewline)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "- \(label): \(String(compact.prefix(180)))"
        }
        return """
        Memory Chunk
        Core insights, decisions, and preferences from older chat context:
        \(bullets.joined(separator: "\n"))
        """
    }
}

public struct SwarmContextPromptBuilder: Sendable {
    public init() {}

    public func buildPrompt(
        userPrompt: String,
        selectedReferences: [String],
        plan: SwarmContextPlan,
        recentHistory: [SwarmContextMessage],
        routingDecision: SwarmRequestDecision? = nil
    ) -> String {
        var sections: [String] = []
        sections.append(userPrompt)
        if let routingDecision {
            sections.append("""
            Swarm routing:
            Intent: \(routingDecision.intent.rawValue)
            Reason: \(routingDecision.reason)
            Use Colony context: \(routingDecision.shouldUseColonyContext ? "yes" : "no")
            Use online source: \(routingDecision.shouldUseOnlineSource ? "yes" : "no")
            Write to memory: \(routingDecision.shouldWriteToMemory ? "yes" : "no")
            """)
        }
        if let memory = plan.compactionMemory, !memory.isEmpty {
            sections.append("Swarm compressed memory:\n\(memory)")
        }
        if !selectedReferences.isEmpty {
            sections.append("Explicit @ context:\n\(selectedReferences.prefix(8).joined(separator: "\n"))")
        }
        if !plan.attachments.isEmpty {
            sections.append("Active attachments:\n\(attachmentContext(plan.attachments, tokenLimit: plan.budget.attachmentTokens))")
        }
        if !plan.colonyChunks.isEmpty {
            let colony = plan.colonyChunks.map { chunk in
                "[\(chunk.pageTitle), score \(String(format: "%.2f", chunk.score))]\n\(chunk.text)"
            }
            sections.append("High-relevance Colony context:\n\(colony.joined(separator: "\n\n"))")
        }
        let recent = recentHistory.suffix(plan.modelProfile.recentTurnsToKeep * 2)
        if !recent.isEmpty {
            sections.append("Recent chat history:\n\(recent.map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n"))")
        }
        sections.append("Context budget: prompt \(plan.budget.userPromptTokens), attachments \(plan.budget.attachmentTokens), Colony \(plan.budget.colonyTokens), recent chat \(plan.budget.recentHistoryTokens), remaining \(plan.budget.remainingTokens).")
        return sections.joined(separator: "\n\n")
    }

    private func attachmentContext(_ attachments: [SwarmAttachmentExtractionResult], tokenLimit: Int) -> String {
        let estimator = SwarmTokenEstimator()
        var used = 0
        var lines: [String] = []
        for attachment in attachments {
            let header = "- \(attachment.displayName): \(attachment.summary)"
            lines.append(header)
            for chunk in attachment.chunks.prefix(4) {
                let estimate = estimator.estimate(chunk)
                guard used + estimate <= tokenLimit else { break }
                lines.append("  \(String(chunk.prefix(900)))")
                used += estimate
            }
            if attachment.requiresModel {
                lines.append("  Extraction note: \(attachment.extractionNote)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
