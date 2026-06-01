import CryptoKit
import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

public enum ExtractionError: Error, LocalizedError, Sendable {
    case unsupported(URL)
    case unreadable(URL)
    case empty(URL)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let url): "Unsupported source type: \(url.lastPathComponent)"
        case .unreadable(let url): "Could not read source: \(url.lastPathComponent)"
        case .empty(let url): "No extractable content found: \(url.lastPathComponent)"
        }
    }
}

public struct Hashing {
    public static func sha256(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(file url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return sha256(data: data)
    }
}

public struct SourceTypeDetector {
    public static func kind(for url: URL) -> SourceKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "bmp": return .image
        case "mov", "mp4", "m4v", "avi", "mkv": return .video
        case "mp3", "m4a", "wav", "aiff", "flac": return .audio
        case "txt", "md", "markdown", "json", "csv", "tsv", "log", "html", "htm", "rtf": return .text
        default: return .genericFile
        }
    }

    public static func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "heic": return "image/heic"
        case "gif": return "image/gif"
        case "mov": return "video/quicktime"
        case "mp4", "m4v": return "video/mp4"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "md", "markdown": return "text/markdown"
        case "html", "htm": return "text/html"
        case "json": return "application/json"
        case "csv": return "text/csv"
        case "txt", "log": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}

public struct ExtractedDocument: Sendable {
    public var artifactType: String
    public var text: String
    public var confidence: Double
    public var requiresModel: Bool
    public var note: String

    public init(artifactType: String, text: String, confidence: Double, requiresModel: Bool, note: String) {
        self.artifactType = artifactType
        self.text = text
        self.confidence = confidence
        self.requiresModel = requiresModel
        self.note = note
    }
}

public struct LocalExtractor: Sendable {
    public init() {}

    public func extract(from url: URL, kind: SourceKind) throws -> ExtractedDocument {
        switch kind {
        case .text, .clipboardExport, .calendarExport, .taskExport:
            return try extractPlainText(from: url)
        case .pdf:
            return try extractPDF(from: url)
        case .image, .screenshot:
            return ExtractedDocument(
                artifactType: "image-metadata",
                text: "Image source: \(url.deletingPathExtension().lastPathComponent)",
                confidence: 0.35,
                requiresModel: true,
                note: "OCR/image understanding is queued for the local vision pipeline."
            )
        case .audio:
            return ExtractedDocument(
                artifactType: "audio-metadata",
                text: "Audio source: \(url.deletingPathExtension().lastPathComponent)",
                confidence: 0.25,
                requiresModel: true,
                note: "Transcription is queued for the local speech pipeline."
            )
        case .video:
            return ExtractedDocument(
                artifactType: "video-metadata",
                text: "Video source: \(url.deletingPathExtension().lastPathComponent)",
                confidence: 0.25,
                requiresModel: true,
                note: "Frame sampling and transcription are queued for local media pipelines."
            )
        case .genericFile, .attachment, .folder, .browserHistory, .browserBookmark:
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ExtractedDocument(
                    artifactType: "text",
                    text: text,
                    confidence: 0.65,
                    requiresModel: false,
                    note: "Decoded as UTF-8 text."
                )
            }
            return ExtractedDocument(
                artifactType: "metadata",
                text: "File source: \(url.deletingPathExtension().lastPathComponent)",
                confidence: 0.2,
                requiresModel: true,
                note: "Content extraction requires a specialized local parser or model."
            )
        }
    }

    private func extractPlainText(from url: URL) throws -> ExtractedDocument {
        let encodings: [String.Encoding] = [.utf8, .utf16, .ascii, .isoLatin1]
        for encoding in encodings {
            if let text = try? String(contentsOf: url, encoding: encoding),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ExtractedDocument(
                    artifactType: "text",
                    text: text,
                    confidence: 0.85,
                    requiresModel: false,
                    note: "Decoded text locally."
                )
            }
        }
        throw ExtractionError.unreadable(url)
    }

    private func extractPDF(from url: URL) throws -> ExtractedDocument {
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.unreadable(url)
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    pages.append(trimmed)
                }
            }
        }
        let text = pages.joined(separator: "\n\n")
        guard !text.isEmpty else {
            return ExtractedDocument(
                artifactType: "pdf-metadata",
                text: "PDF source: \(url.deletingPathExtension().lastPathComponent)",
                confidence: 0.3,
                requiresModel: true,
                note: "PDF contained no selectable text; OCR is required."
            )
        }
        return ExtractedDocument(
            artifactType: "pdf-text",
            text: text,
            confidence: 0.8,
            requiresModel: false,
            note: "Extracted selectable PDF text locally."
        )
        #else
        throw ExtractionError.unsupported(url)
        #endif
    }
}

public struct TextChunker: Sendable {
    public var targetCharacters: Int
    public var overlapCharacters: Int

    public init(targetCharacters: Int = 1200, overlapCharacters: Int = 160) {
        self.targetCharacters = targetCharacters
        self.overlapCharacters = overlapCharacters
    }

    public func chunks(for text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > targetCharacters else { return [trimmed] }

        var chunks: [String] = []
        var start = trimmed.startIndex
        while start < trimmed.endIndex {
            let targetEnd = trimmed.index(start, offsetBy: targetCharacters, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
            let end = nearestSentenceBoundary(in: trimmed, from: start, proposedEnd: targetEnd)
            let chunk = String(trimmed[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
            if end == trimmed.endIndex { break }
            let overlapStart = trimmed.index(end, offsetBy: -min(overlapCharacters, trimmed.distance(from: start, to: end)), limitedBy: trimmed.startIndex) ?? start
            start = overlapStart < end ? overlapStart : end
        }
        return chunks
    }

    private func nearestSentenceBoundary(in text: String, from start: String.Index, proposedEnd: String.Index) -> String.Index {
        guard proposedEnd < text.endIndex else { return text.endIndex }
        let searchRange = start..<proposedEnd
        if let boundary = text.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?\n"), options: .backwards, range: searchRange)?.upperBound {
            return boundary
        }
        return proposedEnd
    }
}

public enum SourceExtractionDepth: String, Codable, Equatable, Sendable {
    case normal
    case expanded

    public var chunkScanLimit: Int {
        switch self {
        case .normal:
            return 12
        case .expanded:
            return 48
        }
    }

    public var claimLimit: Int {
        switch self {
        case .normal:
            return 8
        case .expanded:
            return 28
        }
    }

    public var entityLimit: Int {
        switch self {
        case .normal:
            return 24
        case .expanded:
            return 48
        }
    }

    public var chunker: TextChunker {
        switch self {
        case .normal:
            return TextChunker()
        case .expanded:
            return TextChunker(targetCharacters: 900, overlapCharacters: 260)
        }
    }
}

public enum ExtractionQualityRules {
    public static let systemPrompt = """
    EXTRACTION RULES - FOLLOW EXACTLY:

    1. DEDUPLICATION: Before writing any claim, check if it is semantically equivalent to something already in the Colony. If yes, skip it. Do not write the same fact twice in different words.

    2. SIGNAL THRESHOLD: Only extract claims that would be useful to a person reviewing their own knowledge base 6 months from now. Ask yourself: "Would the user care about this specific fact in 6 months?" If no, discard it.
       - DISCARD: Age, generic demographic info ("user is 19 years old"), restatements of the document type ("this is a resume"), filler facts that could apply to any person.
       - DISCARD: Bare product, tool, framework, or technology names unless the source says what the user does with them. "Unreal Engine" alone is not a memory; "The user built a level prototype in Unreal Engine" is.
       - KEEP: Specific skills, specific projects with concrete outcomes, specific institutions, specific roles, specific technologies, specific achievements with measurable results.

    3. FRESHNESS: If a new source contradicts an existing Colony article claim, update the claim rather than creating a parallel duplicate entry.

    4. GRANULARITY: Each Hive memory node should represent ONE atomic fact or skill, not a paragraph. Maximum 2 sentences per node. If you have more to say, split into multiple nodes.

    5. NO META-COMMENTARY: Never write "The user uploaded a resume." Never write "This document contains information about X." Extract the information directly as first-person facts about the user.

    6. SOURCING: Every extracted claim must be traceable to a specific line in the source document. If you cannot point to where in the source a claim comes from, do not extract it.

    7. CLUTTER REDUCTION: Long pasted conversations, massive files, and web captures contain noise. Keep decisions, durable preferences, concrete skills, projects, commitments, corrections, and repeated patterns. Discard greetings, generic tool mentions, navigation text, boilerplate, ungrounded speculation, and one-off clutter.
    """
}

public enum ExtractionSignalPolicy {
    public static func isHighSignalClaim(_ value: String, sourceKind: SourceKind? = nil) -> Bool {
        discardReason(for: value, sourceKind: sourceKind) == nil
    }

    public static func discardReason(for value: String, sourceKind: SourceKind? = nil) -> String? {
        let normalized = SourcePresentationModel.cleanTitle(value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()
        guard normalized.count >= 24 else { return "too short to be useful later" }
        if normalized.count > 320 { return "too broad for one atomic memory" }
        if lower.contains("the user uploaded")
            || lower.contains("this document")
            || lower.contains("this resume")
            || lower.contains("contains information")
            || lower.contains("source:")
            || lower.contains("file source:")
            || lower.contains("image source:")
            || lower.contains("pdf source:") {
            return "meta commentary instead of a durable fact"
        }
        if lower.range(of: #"\b(user\s+is\s+)?[0-9]{1,2}\s+years?\s+old\b"#, options: .regularExpression) != nil
            || lower.range(of: #"\bage\s*[:\-]?\s*[0-9]{1,2}\b"#, options: .regularExpression) != nil {
            return "generic demographic noise"
        }
        let genericFragments = [
            "resume",
            "curriculum vitae",
            "contact information",
            "email address",
            "phone number",
            "linkedin profile",
            "github profile"
        ]
        if genericFragments.contains(where: { lower == $0 || lower.hasPrefix("\($0) ") }) {
            return "document boilerplate"
        }
        let tokens = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 })
        if !tokens.isDisjoint(with: highSignalTerms) {
            return nil
        }
        if normalized.range(of: #"\b[A-Z0-9][A-Za-z0-9+\-.#]{1,}\b"#, options: .regularExpression) != nil,
           normalized.contains(where: \.isUppercase) {
            return nil
        }
        if sourceKind == .browserHistory || sourceKind == .browserBookmark,
           normalized.contains("—"),
           !lower.contains("appearance alone") {
            return nil
        }
        if sourceKind == .browserHistory || sourceKind == .browserBookmark {
            return "browser trace needs repeated engagement before becoming memory"
        }
        return "below six-month signal threshold"
    }

    public static func canonicalKey(_ value: String) -> String {
        SourcePresentationModel.cleanTitle(value)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !dedupeStopwords.contains($0) }
            .joined(separator: " ")
    }

    private static let highSignalTerms: Set<String> = [
        "achievement", "algorithm", "app", "architecture", "award", "built", "certification",
        "client", "code", "competition", "course", "data", "debugging", "degree", "designed",
        "developed", "director", "engineering", "framework", "gpa", "implemented", "institution",
        "internship", "ios", "javascript", "lead", "led", "machine", "mathematics", "metal",
        "model", "performance", "project", "python", "react", "rendering", "research", "role",
        "shader", "skills", "software", "swift", "swiftui", "technology", "tournament", "ucla",
        "work", "workflow"
    ]

    private static let dedupeStopwords: Set<String> = [
        "and", "are", "but", "for", "from", "has", "have", "into", "the", "this", "that",
        "their", "with", "user", "users", "about", "source", "document", "information"
    ]
}

public struct DeterministicKnowledgeExtractor: Sendable {
    public init() {}

    public func claims(from chunks: [ChunkRecord], source: SourceRecord, depth: SourceExtractionDepth = .normal) -> [ClaimRecord] {
        var emitted = Set<String>()
        var results: [ClaimRecord] = []
        for chunk in chunks.prefix(depth.chunkScanLimit) {
            let candidates = source.kind == .browserHistory
                ? usefulLines(in: chunk.text)
                : usefulSentences(in: chunk.text)
            for sentence in candidates {
                guard ExtractionSignalPolicy.isHighSignalClaim(sentence, sourceKind: source.kind) else { continue }
                let key = ExtractionSignalPolicy.canonicalKey(sentence)
                guard !key.isEmpty, emitted.insert(key).inserted else { continue }
                results.append(ClaimRecord(
                    statement: String(sentence.prefix(300)),
                    claimType: source.kind == .browserHistory ? "browser-observation" : "source-observation",
                    sourceRefs: [source.id],
                    sourceSpanRefs: [chunk.id],
                    confidence: min(0.82, max(0.42, chunk.extractionConfidence)),
                    uncertaintyReason: source.kind == .browserHistory
                        ? "Browser evidence is not a preference signal without engagement feedback."
                        : "Extracted locally from source text and passed the Field signal threshold."
                ))
                if results.count >= depth.claimLimit { return results }
            }
        }
        return results
    }

    public func entities(from chunks: [ChunkRecord], source: SourceRecord, depth: SourceExtractionDepth = .normal) -> [EntityRecord] {
        let text = chunks.map(\.text).joined(separator: " ")
        let candidates = entityCandidates(in: text)
        return candidates.prefix(depth.entityLimit).map { name in
            EntityRecord(
                name: name,
                entityType: inferEntityType(name),
                aliases: [],
                sourceRefs: [source.id],
                confidence: 0.5
            )
        }
    }

    private func usefulSentences(in text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ".!?\n")
        let pieces = text.components(separatedBy: separators)
        var results: [String] = []
        for piece in pieces {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 24 {
                results.append(trimmed.count > 300 ? String(trimmed.prefix(300)) : trimmed)
            }
        }
        let fallback = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if results.isEmpty, fallback.count >= 24 {
            results.append(String(fallback.prefix(300)))
        }
        return results
    }

    private func usefulLines(in text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var results: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 24 {
                results.append(trimmed.count > 300 ? String(trimmed.prefix(300)) : trimmed)
            }
        }
        return results
    }

    private func entityCandidates(in text: String) -> [String] {
        let pattern = #"\b([A-Z][a-zA-Z0-9]+(?:\s+[A-Z][a-zA-Z0-9]+){0,3})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        var results: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard EntitySignalPolicy.isMeaningfulName(value) else { continue }
            if seen.insert(value.lowercased()).inserted {
                results.append(value)
            }
        }
        return results
    }

    private func isMeaningfulEntityCandidate(_ value: String) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let lower = normalized.lowercased()
        guard normalized.count >= 3, !stopWords.contains(lower) else { return false }
        let parts = lower.split(separator: " ").map(String.init)
        guard !parts.contains(where: { stopWords.contains($0) }) else { return false }
        if parts.count == 1 {
            let word = parts[0]
            if word.count < 4 { return false }
            if genericSingleWordCandidates.contains(word) { return false }
        }
        return true
    }

    private func inferEntityType(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("project") || lower.contains("roadmap") { return "project" }
        if lower.contains("meeting") || lower.contains("event") { return "event" }
        return "topic"
    }

    private var stopWords: Set<String> {
        [
            "the", "this", "that", "these", "those", "when", "where", "while",
            "from", "with", "into", "your", "their", "there", "here", "file",
            "image", "audio", "video", "source", "sources", "pdf", "question",
            "answer", "answers", "claim", "claims", "confirmed", "unresolved",
            "refused", "inference", "inferences", "project", "projects", "status",
            "summary", "goals", "tools", "entities", "relationship", "relationships",
            "memory", "seed", "format", "json", "output", "quality", "rules",
            "important", "normalize", "prefer", "preserve", "never", "return",
            "only", "after", "before", "exact", "allowed", "examples", "good",
            "true", "false", "high", "medium", "low", "active", "paused", "idea",
            "unclear"
        ]
    }

    private var genericSingleWordCandidates: Set<String> {
        [
            "are", "has", "have", "had", "was", "were", "who", "what", "why", "how",
            "does", "did", "can", "could", "should", "would", "will", "is", "it",
            "determines", "clarifies", "resolves", "distinguishes", "contains",
            "extract", "extracts", "importing", "building", "using", "based",
            "needs", "requires", "changes", "categorizes", "shows", "reads",
            "writes", "updates", "creates", "flags", "links"
        ]
    }
}
