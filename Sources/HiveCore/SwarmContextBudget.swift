import Foundation

/// Pure, deterministic token budgeting and context trimming for Swarm prompts.
///
/// The budget estimates token usage from character counts and trims assembled
/// context sections in a fixed priority order until the estimated total fits a
/// caller-supplied token limit. It performs no logging and has no side effects.
public struct SwarmContextBudget: Sendable {
    /// Estimates the token count of a string using a 4-characters-per-token
    /// approximation, rounded up.
    public static func estimatedTokens(_ text: String) -> Int {
        Int((Double(text.count) / 4.0).rounded(.up))
    }

    /// The assembled context sections, ordered by trimming priority.
    public struct Sections: Sendable {
        /// Conversation history entries, oldest first.
        public var conversationHistory: [String]
        /// Colony context blocks, most relevant first.
        public var colonyBlocks: [String]
        /// Hive claim blocks, most relevant first.
        public var hiveClaimBlocks: [String]
        /// Web retrieval blocks, highest ranked first.
        public var webBlocks: [String]

        public init(
            conversationHistory: [String] = [],
            colonyBlocks: [String] = [],
            hiveClaimBlocks: [String] = [],
            webBlocks: [String] = []
        ) {
            self.conversationHistory = conversationHistory
            self.colonyBlocks = colonyBlocks
            self.hiveClaimBlocks = hiveClaimBlocks
            self.webBlocks = webBlocks
        }
    }

    /// The combined estimated token count across all sections.
    public static func combinedTokenCount(_ sections: Sections) -> Int {
        var total = 0
        for entry in sections.conversationHistory { total += estimatedTokens(entry) }
        for block in sections.colonyBlocks { total += estimatedTokens(block) }
        for block in sections.hiveClaimBlocks { total += estimatedTokens(block) }
        for block in sections.webBlocks { total += estimatedTokens(block) }
        return total
    }

    /// Minimum number of conversation-history entries to always retain.
    private static let minimumHistoryEntries = 4

    /// Trims context sections in the spec's priority order until the estimated
    /// total fits `limit`. If trimming alone cannot fit the budget, the
    /// remaining text is hard-truncated proportionally.
    public static func trim(_ sections: Sections, toTokenLimit limit: Int) -> Sections {
        var working = sections

        if combinedTokenCount(working) <= limit { return working }

        // (1) Drop oldest conversation history, keeping the most recent entries.
        if working.conversationHistory.count > minimumHistoryEntries {
            working.conversationHistory = Array(working.conversationHistory.suffix(minimumHistoryEntries))
            if combinedTokenCount(working) <= limit { return working }
        }

        // (2) Reduce colony blocks 5 → 3.
        if working.colonyBlocks.count > 3 {
            working.colonyBlocks = Array(working.colonyBlocks.prefix(3))
            if combinedTokenCount(working) <= limit { return working }
        }

        // (3) Reduce hive claim blocks 20 → 10.
        if working.hiveClaimBlocks.count > 10 {
            working.hiveClaimBlocks = Array(working.hiveClaimBlocks.prefix(10))
            if combinedTokenCount(working) <= limit { return working }
        }

        // (4) Reduce colony blocks 3 → 1.
        if working.colonyBlocks.count > 1 {
            working.colonyBlocks = Array(working.colonyBlocks.prefix(1))
            if combinedTokenCount(working) <= limit { return working }
        }

        // (5) Keep only the highest (first) web block.
        if working.webBlocks.count > 1 {
            working.webBlocks = Array(working.webBlocks.prefix(1))
            if combinedTokenCount(working) <= limit { return working }
        }

        // Final safeguard: hard-truncate remaining text proportionally so the
        // estimated total fits within the limit.
        return hardTruncate(working, toTokenLimit: limit)
    }

    /// Proportionally shrinks every remaining string so the combined estimated
    /// token count fits `limit`.
    private static func hardTruncate(_ sections: Sections, toTokenLimit limit: Int) -> Sections {
        guard limit > 0 else {
            return Sections()
        }

        let total = combinedTokenCount(sections)
        guard total > limit else { return sections }

        let ratio = Double(limit) / Double(total)
        var truncated = sections
        truncated.conversationHistory = sections.conversationHistory.map { truncate($0, ratio: ratio) }
        truncated.colonyBlocks = sections.colonyBlocks.map { truncate($0, ratio: ratio) }
        truncated.hiveClaimBlocks = sections.hiveClaimBlocks.map { truncate($0, ratio: ratio) }
        truncated.webBlocks = sections.webBlocks.map { truncate($0, ratio: ratio) }
        return truncated
    }

    /// Truncates a string to a fraction of its character count.
    private static func truncate(_ text: String, ratio: Double) -> String {
        guard ratio < 1.0 else { return text }
        let keepCount = Int((Double(text.count) * ratio).rounded(.down))
        guard keepCount < text.count else { return text }
        guard keepCount > 0 else { return "" }
        return String(text.prefix(keepCount))
    }
}
