import Foundation

/// A factual claim together with its embedding vector and provenance, used as
/// the unit of cross-source deduplication (Prompt 1, Step 3).
public struct EmbeddingClaim: Hashable, Sendable {
    public var id: String
    public var text: String
    public var sourceFileID: String
    public var supportingSourceIDs: [String]
    public var embedding: [Double]

    public init(
        id: String,
        text: String,
        sourceFileID: String,
        supportingSourceIDs: [String] = [],
        embedding: [Double] = []
    ) {
        self.id = id
        self.text = text
        self.sourceFileID = sourceFileID
        self.supportingSourceIDs = supportingSourceIDs
        self.embedding = embedding
    }
}

/// Collapses near-duplicate claims that originate from different source files
/// by comparing embedding cosine similarity against a threshold.
public struct EmbeddingClaimDeduplicator: Sendable {
    public let threshold: Double

    public init(threshold: Double = 0.91) {
        self.threshold = threshold
    }

    /// Standard cosine similarity. Returns 0 when either vector is empty or has
    /// zero norm; the result is clamped to [-1, 1] to absorb floating-point drift.
    public static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty, !b.isEmpty, a.count == b.count else { return 0 }

        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        guard normA > 0, normB > 0 else { return 0 }

        let similarity = dot / (normA.squareRoot() * normB.squareRoot())
        return Swift.min(1.0, Swift.max(-1.0, similarity))
    }

    /// The result of a deduplication pass.
    public struct Outcome: Sendable {
        /// New claims that were unique enough to be inserted.
        public var insertedClaims: [EmbeddingClaim]
        /// For each collapsed claim, the existing claim it merged into plus the
        /// new source file id that should be appended to its supporting sources.
        public var mergedIntoExisting: [(existingID: String, newSourceFileID: String)]
        /// Number of new claims collapsed into an existing claim.
        public var collapsedCount: Int

        public init(
            insertedClaims: [EmbeddingClaim] = [],
            mergedIntoExisting: [(existingID: String, newSourceFileID: String)] = [],
            collapsedCount: Int = 0
        ) {
            self.insertedClaims = insertedClaims
            self.mergedIntoExisting = mergedIntoExisting
            self.collapsedCount = collapsedCount
        }
    }

    /// Deduplicates `newClaims` against `existing`. A new claim is collapsed
    /// only when it is highly similar to a claim from a *different* source file;
    /// otherwise it is inserted and becomes part of the comparison set for
    /// subsequent new claims. Processing order is deterministic (input order).
    public func deduplicate(
        newClaims: [EmbeddingClaim],
        against existing: [EmbeddingClaim]
    ) -> Outcome {
        var comparisonSet = existing
        var outcome = Outcome()

        for newClaim in newClaims {
            var mergeTarget: EmbeddingClaim?
            var bestSimilarity = -Double.greatestFiniteMagnitude

            for candidate in comparisonSet where candidate.sourceFileID != newClaim.sourceFileID {
                let similarity = Self.cosineSimilarity(candidate.embedding, newClaim.embedding)
                if similarity > threshold && similarity > bestSimilarity {
                    bestSimilarity = similarity
                    mergeTarget = candidate
                }
            }

            if let target = mergeTarget {
                outcome.mergedIntoExisting.append((existingID: target.id, newSourceFileID: newClaim.sourceFileID))
                outcome.collapsedCount += 1
            } else {
                outcome.insertedClaims.append(newClaim)
                comparisonSet.append(newClaim)
            }
        }

        return outcome
    }
}
