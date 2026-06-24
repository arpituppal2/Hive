import Foundation

/// Pure validation logic for the claim-extraction step of the ingestion pipeline
/// (Prompt 1, Step 2). Encodes the rules that govern which extracted statements
/// qualify as independently verifiable factual claims.
public struct ClaimValidator: Sendable {
    public init() {}

    /// System prompt used to instruct the extraction model. Kept here so the
    /// rule text lives alongside the validation logic that enforces it.
    public static let extractionSystemPrompt = "Extract only independently verifiable factual claims. Do not summarize. Do not paraphrase across sentences. Do not combine claims from different topics into one sentence."

    /// Leading connective phrases that indicate a statement depends on prior
    /// context, and therefore is not independently verifiable.
    public static let transitionalPrefixes: [String] = [
        "additionally",
        "furthermore",
        "moreover",
        "this means that",
        "in addition",
        "however",
        "therefore",
        "thus",
        "consequently",
        "on the other hand",
        "as a result",
        "that said",
        "in other words"
    ]

    /// Counts words by splitting on whitespace and newlines, discarding empties.
    public func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { !$0.isEmpty }
            .count
    }

    /// A claim is valid iff, once trimmed, it has between 15 and 100 words
    /// (inclusive), does not begin with a transitional prefix, and is not
    /// purely a question.
    public func isValidClaim(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let count = wordCount(trimmed)
        guard (15...100).contains(count) else { return false }

        let lowered = trimmed.lowercased()
        for prefix in Self.transitionalPrefixes {
            if lowered.hasPrefix(prefix) {
                return false
            }
        }

        if trimmed.hasSuffix("?") {
            return false
        }

        return true
    }

    /// Partitions claims into those that pass validation and a count of those
    /// rejected, supporting the spec requirement to "log the count of filtered
    /// claims".
    public func filterValidClaims(_ claims: [String]) -> (kept: [String], rejectedCount: Int) {
        var kept: [String] = []
        kept.reserveCapacity(claims.count)
        var rejectedCount = 0

        for claim in claims {
            if isValidClaim(claim) {
                kept.append(claim)
            } else {
                rejectedCount += 1
            }
        }

        return (kept, rejectedCount)
    }
}
