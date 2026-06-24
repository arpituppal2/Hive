import Foundation

/// Prompt 3b saturation loop + retirement modeled as a pure state machine.
///
/// The saturation loop repeatedly re-audits a pending source file, extracting
/// claims pass after pass. A source is considered *saturated* once it yields no
/// new claims for a configurable number of consecutive passes, at which point it
/// can be retired. This type carries no DB/IO — it only transforms immutable
/// value snapshots.

/// Lifecycle status of a pending source as it moves through the saturation loop.
public enum PendingSourceStatus: String, Codable, Hashable, Sendable {
    case pending
    case processing
    case saturated
    case retired
    case error
    case unsupportedType = "unsupported_type"
}

/// Immutable snapshot of a pending source's saturation progress.
public struct PendingSourceState: Codable, Hashable, Sendable {
    public var filePath: String
    public var fileHash: String
    public var status: PendingSourceStatus
    public var passCount: Int
    public var consecutiveEmptyPasses: Int
    public var totalClaimsExtracted: Int
    public var articlesTouched: Int

    public init(
        filePath: String,
        fileHash: String,
        status: PendingSourceStatus = .pending,
        passCount: Int = 0,
        consecutiveEmptyPasses: Int = 0,
        totalClaimsExtracted: Int = 0,
        articlesTouched: Int = 0
    ) {
        self.filePath = filePath
        self.fileHash = fileHash
        self.status = status
        self.passCount = passCount
        self.consecutiveEmptyPasses = consecutiveEmptyPasses
        self.totalClaimsExtracted = totalClaimsExtracted
        self.articlesTouched = articlesTouched
    }
}

/// Pure state machine driving the saturation + retirement loop for a source.
public struct SaturationLoop: Sendable {
    /// Number of consecutive empty passes required before a source is saturated.
    public let saturationThreshold: Int

    public init(saturationThreshold: Int = 2) {
        self.saturationThreshold = saturationThreshold
    }

    /// Records the result of a single re-audit pass and returns an updated copy.
    ///
    /// - When `newClaimsFound > 0` the empty-pass streak resets and the new
    ///   claims/articles are folded into the running totals.
    /// - When no new claims are found the consecutive-empty-pass counter advances.
    /// - Status becomes `.saturated` once the streak reaches the threshold,
    ///   otherwise `.processing`.
    public func recordPass(
        _ state: PendingSourceState,
        newClaimsFound: Int,
        articlesTouchedThisPass: Int
    ) -> PendingSourceState {
        var updated = state
        updated.passCount += 1

        if newClaimsFound > 0 {
            updated.consecutiveEmptyPasses = 0
            updated.totalClaimsExtracted += newClaimsFound
            updated.articlesTouched += articlesTouchedThisPass
        } else {
            updated.consecutiveEmptyPasses += 1
        }

        if updated.consecutiveEmptyPasses >= saturationThreshold {
            updated.status = .saturated
        } else {
            updated.status = .processing
        }

        return updated
    }

    /// Returns `true` when the source has gone empty for the threshold number of
    /// consecutive passes and is ready to be retired.
    public func shouldRetire(_ state: PendingSourceState) -> Bool {
        state.consecutiveEmptyPasses >= saturationThreshold
    }

    /// Returns a copy of `state` marked as retired.
    public func retired(_ state: PendingSourceState) -> PendingSourceState {
        var updated = state
        updated.status = .retired
        return updated
    }

    /// Emits a coverage warning when new stub creation outpaced enrichment of
    /// existing articles, signaling the colony may need broader coverage.
    public func enrichmentWarning(enrichments: Int, newStubs: Int) -> String? {
        guard newStubs > enrichments else { return nil }
        return "WARNING: new article creation (\(newStubs)) exceeded enrichment (\(enrichments)). Colony may need broader coverage."
    }

    /// Formats an ingest log line for the saturation loop journal.
    public func ingestLogLine(
        file: String,
        claimsExtracted: Int,
        enrichments: Int,
        newStubs: Int,
        now: Date = Date()
    ) -> String {
        let stamp = Self.timestampFormatter.string(from: now)
        return "## [\(stamp)] ingest | \(file) | \(claimsExtracted) claims extracted | \(enrichments) enriched | \(newStubs) created"
    }

    /// Formats a retirement log line recorded when a source is retired.
    public func retiredLogLine(
        filename: String,
        passCount: Int,
        totalClaims: Int,
        articlesTouched: Int,
        now: Date = Date()
    ) -> String {
        let stamp = Self.timestampFormatter.string(from: now)
        return "## [\(stamp)] retired | \(filename) | \(passCount) passes | \(totalClaims) claims | \(articlesTouched) articles touched"
    }

    // MARK: - Token chunking

    /// Splits `text` into chunks whose estimated token count (chars / 4) does not
    /// exceed `maxTokensPerChunk`, preferring to break on paragraph and then
    /// sentence boundaries. Used for the 2,000-token re-audit segmentation.
    public static func chunk(text: String, maxTokensPerChunk: Int = 2000) -> [String] {
        guard maxTokensPerChunk > 0 else { return text.isEmpty ? [] : [text] }
        let maxChars = maxTokensPerChunk * 4

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > maxChars else { return [trimmed] }

        var chunks: [String] = []
        var current = ""

        func flush() {
            let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { chunks.append(piece) }
            current = ""
        }

        let paragraphs = trimmed.components(separatedBy: "\n\n")
        for paragraph in paragraphs {
            let para = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if para.isEmpty { continue }

            if para.count > maxChars {
                // Paragraph itself is too large: fall back to sentence packing.
                flush()
                for sentenceChunk in splitOversized(para, maxChars: maxChars) {
                    chunks.append(sentenceChunk)
                }
                continue
            }

            let candidateCount = current.isEmpty ? para.count : current.count + 2 + para.count
            if candidateCount > maxChars {
                flush()
                current = para
            } else if current.isEmpty {
                current = para
            } else {
                current += "\n\n" + para
            }
        }

        flush()
        return chunks
    }

    /// Packs an oversized paragraph into chunks by sentence, hard-splitting any
    /// single sentence that still exceeds the character budget.
    private static func splitOversized(_ paragraph: String, maxChars: Int) -> [String] {
        var result: [String] = []
        var current = ""

        func flush() {
            let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { result.append(piece) }
            current = ""
        }

        for sentence in sentences(in: paragraph) {
            let sent = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if sent.isEmpty { continue }

            if sent.count > maxChars {
                flush()
                var remaining = Substring(sent)
                while !remaining.isEmpty {
                    let end = remaining.index(remaining.startIndex, offsetBy: maxChars, limitedBy: remaining.endIndex) ?? remaining.endIndex
                    result.append(String(remaining[remaining.startIndex..<end]))
                    remaining = remaining[end...]
                }
                continue
            }

            let candidateCount = current.isEmpty ? sent.count : current.count + 1 + sent.count
            if candidateCount > maxChars {
                flush()
                current = sent
            } else if current.isEmpty {
                current = sent
            } else {
                current += " " + sent
            }
        }

        flush()
        return result
    }

    /// Naively segments text into sentences on terminal punctuation.
    private static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" {
                result.append(current)
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(current)
        }
        return result
    }

    /// Stable `yyyy-MM-dd HH:mm` formatter (POSIX, gregorian) for log lines.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
