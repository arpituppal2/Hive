import Foundation

/// Describes how strongly a single topic dominates the current knowledge base
/// (Prompt 1, Step 4).
public struct TopicDominanceReport: Codable, Hashable, Sendable {
    public var topic: String
    public var claimCount: Int
    public var totalClaims: Int
    /// claimCount / totalClaims.
    public var frequency: Double

    public init(topic: String, claimCount: Int, totalClaims: Int, frequency: Double) {
        self.topic = topic
        self.claimCount = claimCount
        self.totalClaims = totalClaims
        self.frequency = frequency
    }
}

/// Normalizes per-claim topic tags into frequencies and detects when a single
/// topic dominates the knowledge base beyond an acceptable threshold.
public struct TopicSignalNormalizer: Sendable {
    public let threshold: Double

    public init(threshold: Double = 0.15) {
        self.threshold = threshold
    }

    /// Maps each unique topic to the fraction of claims that mention it. A topic
    /// counts once per claim regardless of how many times it appears in that
    /// claim's tag list.
    public func normalize(topicTagsPerClaim: [[String]]) -> [String: Double] {
        let totalClaims = topicTagsPerClaim.count
        guard totalClaims > 0 else { return [:] }

        var counts: [String: Int] = [:]
        for tags in topicTagsPerClaim {
            for topic in Set(tags) {
                counts[topic, default: 0] += 1
            }
        }

        var frequencies: [String: Double] = [:]
        frequencies.reserveCapacity(counts.count)
        for (topic, count) in counts {
            frequencies[topic] = Double(count) / Double(totalClaims)
        }
        return frequencies
    }

    /// Returns the most frequent topic when its frequency exceeds the threshold,
    /// otherwise nil. Ties are broken deterministically by topic name.
    public func dominantTopic(topicTagsPerClaim: [[String]]) -> TopicDominanceReport? {
        let totalClaims = topicTagsPerClaim.count
        guard totalClaims > 0 else { return nil }

        let frequencies = normalize(topicTagsPerClaim: topicTagsPerClaim)
        guard let best = frequencies.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        }) else {
            return nil
        }

        guard best.value > threshold else { return nil }

        let claimCount = topicTagsPerClaim.filter { $0.contains(best.key) }.count
        return TopicDominanceReport(
            topic: best.key,
            claimCount: claimCount,
            totalClaims: totalClaims,
            frequency: best.value
        )
    }

    /// User-facing warning describing the dominance situation.
    public func warningMessage(for report: TopicDominanceReport) -> String {
        "One topic is dominating your knowledge base: \(report.topic) (\(report.claimCount) claims, \(Int((report.frequency*100).rounded()))% of total). This may skew Swarm's answers. Consider adding sources on other topics."
    }
}
