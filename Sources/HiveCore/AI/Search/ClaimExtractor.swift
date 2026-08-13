import Foundation

// MARK: - ClaimExtractor (SWARM-002 §7.3 step 5: claim extraction with quote/span references)

/// Deterministically extracts grounded Claims from a research answer and the
/// fetched source texts it cites. For every `[n]` citation marker in the
/// answer, the sentence carrying the marker is matched against the sentences
/// of the n-th source's extracted text by significant-word overlap; the best
/// matching source sentence becomes a Claim whose EvidenceSpan points at the
/// exact character range (UTF-16 offsets, NSRange-compatible) in the stored
/// extracted text.
///
/// Deterministic by design (AGENTS.md §15.4: memory and deterministic
/// retrieval before a model): no model is asked to invent spans — a claim is
/// only ever the VERBATIM sentence found in a stored source. When no sentence
/// clears the overlap threshold (or the source has no extracted text), the
/// citation is reported unmatched — never fabricated (§7.3 step 7: honest
/// limitations).
public struct ClaimExtractor: Sendable {

    /// One source's extracted text, aligned to the answer's citation order.
    /// `sourceID` is the Honeycomb node ID the EvidenceSpan points at.
    public struct SourceInput: Sendable, Equatable {
        public let sourceID: String
        public let extractedText: String?

        public init(sourceID: String, extractedText: String?) {
            self.sourceID = sourceID
            self.extractedText = extractedText
        }
    }

    public struct Extraction: Sendable, Equatable {
        /// Verbatim source sentences, each with an EvidenceSpan into its
        /// source's stored extracted text.
        public let claims: [Claim]
        /// Zero-based source indices whose citations could not be grounded —
        /// missing source text or no sentence cleared the overlap threshold.
        /// May contain -1 for a malformed `[0]` marker. Honest reporting: the
        /// answer's citation is real, but stored evidence does not back it.
        public let unmatchedCitationIndices: [Int]

        public init(claims: [Claim], unmatchedCitationIndices: [Int]) {
            self.claims = claims
            self.unmatchedCitationIndices = unmatchedCitationIndices
        }
    }

    /// Minimum number of shared significant words (length ≥ 3, punctuation
    /// stripped) for a source sentence to count as evidence. Below this,
    /// matching would be noise.
    public var minSharedSignificantWords: Int

    public init(minSharedSignificantWords: Int = 2) {
        self.minSharedSignificantWords = minSharedSignificantWords
    }

    public func extractClaims(
        answer: String,
        sources: [SourceInput],
        provenance: String = "swarm-research"
    ) -> Extraction {
        var claims: [Claim] = []
        // Keep one entry per citation occurrence, not a Set: repeated failed
        // markers such as `[1] [1]` are two unmatched citations to report.
        var unmatched: [Int] = []

        for marker in citationMarkers(in: answer) {
            let index = marker.number - 1
            guard index >= 0, index < sources.count else {
                unmatched.append(index)
                continue
            }
            let source = sources[index]
            guard let text = source.extractedText, !text.isEmpty else {
                unmatched.append(index)
                continue
            }
            guard let answerSentence = sentence(containing: marker.range, in: answer) else {
                unmatched.append(index)
                continue
            }
            let answerWords = significantWords(in: answerSentence.text)
            guard let best = bestSentence(in: text, matching: answerWords) else {
                unmatched.append(index)
                continue
            }
            let span = EvidenceSpan(
                sourceID: source.sourceID,
                startOffset: best.range.lowerBound.utf16Offset(in: text),
                endOffset: best.range.upperBound.utf16Offset(in: text),
                quote: best.text
            )
            claims.append(Claim(
                text: best.text,
                evidenceSpans: [span],
                provenance: provenance
            ))
        }
        return Extraction(
            claims: claims,
            unmatchedCitationIndices: unmatched.sorted()
        )
    }

    // MARK: - Internals

    private struct CitationMarker {
        let number: Int
        let range: Range<String.Index>
    }

    /// All `[n]` citation markers in the answer, with their positions.
    private func citationMarkers(in answer: String) -> [CitationMarker] {
        guard let regex = try? NSRegularExpression(pattern: "\\[(\\d+)\\]") else { return [] }
        let nsRange = NSRange(answer.startIndex..., in: answer)
        var markers: [CitationMarker] = []
        for match in regex.matches(in: answer, range: nsRange) {
            guard let full = Range(match.range, in: answer),
                  match.numberOfRanges > 1,
                  let numRange = Range(match.range(at: 1), in: answer),
                  let number = Int(answer[numRange])
            else { continue }
            markers.append(CitationMarker(number: number, range: full))
        }
        return markers
    }

    /// The sentence whose range contains the marker's position. Providers
    /// commonly place citations either before or after the sentence-ending
    /// punctuation (`claim [1].` or `claim. [1]`), so when the marker sits
    /// just after a sentence we attribute it to the immediately preceding
    /// sentence if only whitespace separates them.
    private func sentence(containing markerRange: Range<String.Index>, in text: String)
        -> (text: String, range: Range<String.Index>)?
    {
        let candidates = sentences(in: text)
        guard let containing = candidates.first(where: { $0.range.contains(markerRange.lowerBound) }) else {
            return nil
        }

        // If the marker is preceded only by whitespace/citation markers inside
        // its tokenizer range (`claim. [1] It also...` or `claim. [1][2]`), it
        // belongs to the preceding real sentence. If real prose precedes the
        // marker (`claim [1]`), keep the containing sentence.
        let prefix = text[containing.range.lowerBound..<markerRange.lowerBound]
        if !isCitationOnly(String(prefix)), !prefix.allSatisfy({ $0.isWhitespace }) {
            return containing
        }

        guard let preceding = candidates.last(where: { $0.range.upperBound <= containing.range.lowerBound }) else {
            return nil
        }
        let gap = text[preceding.range.upperBound..<containing.range.lowerBound]
        guard gap.allSatisfy({ $0.isWhitespace }) else { return nil }
        return preceding
    }

    private func isCitationOnly(_ text: String) -> Bool {
        let withoutMarkers = text.replacingOccurrences(
            of: "\\[\\d+\\]",
            with: "",
            options: .regularExpression
        )
        return withoutMarkers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The source sentence with the highest significant-word overlap with the
    /// answer sentence, or nil when nothing clears the threshold.
    private func bestSentence(in sourceText: String, matching answerWords: Set<String>)
        -> (text: String, range: Range<String.Index>)?
    {
        var best: (text: String, range: Range<String.Index>, score: Int)?
        for (sentence, range) in sentences(in: sourceText) {
            let shared = answerWords.intersection(significantWords(in: sentence)).count
            if shared > (best?.score ?? 0) {
                best = (sentence, range, shared)
            }
        }
        guard let best, best.score >= minSharedSignificantWords else { return nil }
        return (best.text, best.range)
    }

    /// Sentence enumeration: split on sentence-ending punctuation. Known
    /// limitation: abbreviations ("Dr.", "U.S.") split mid-sentence — fine for
    /// claim matching (the boundary is cosmetic; overlap scoring still finds
    /// the right sentence), and documented in tests.
    private func sentences(in text: String) -> [(text: String, range: Range<String.Index>)] {
        guard let regex = try? NSRegularExpression(pattern: "[^.!?]+[.!?]*") else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        var result: [(text: String, range: Range<String.Index>)] = []
        for match in regex.matches(in: text, range: nsRange) {
            guard let range = Range(match.range, in: text) else { continue }
            let raw = String(text[range])
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Adjust the range to the trimmed span so EvidenceSpan offsets and
            // the claim's quote text are exactly consistent.
            guard let trimmedRange = text.range(of: trimmed, range: range) else { continue }
            result.append((trimmed, trimmedRange))
        }
        return result
    }

    /// Lowercased Unicode-aware alphanumeric tokens of length ≥ 3. Using
    /// CharacterSet rather than an ASCII regex keeps accented and non-Latin
    /// source text eligible for deterministic grounding.
    private func significantWords(in text: String) -> Set<String> {
        var words: Set<String> = []
        var current = ""

        func flush() {
            guard current.count >= 3 else {
                current.removeAll(keepingCapacity: true)
                return
            }
            words.insert(current)
            current.removeAll(keepingCapacity: true)
        }

        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.append(String(scalar))
            } else {
                flush()
            }
        }
        flush()
        return words
    }
}
