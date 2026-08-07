import Foundation

// MARK: - RetrievalRankerFilter
//
// Pure, validated parsing of the RetrievalRanker Cell's output into an ordered
// hot-node allow-list. This is the security boundary of the ranker step: the
// model may ONLY narrow the assembled context, never expand it. Unknown or
// fabricated IDs are dropped by intersection with the assembled set, and
// malformed output degrades to nil (the caller keeps the full raw context) so
// a confused model can never shrink the user's memory to nothing.
//
// Two accepted shapes (the Cell's real contract and a simple fallback):
//
//   1. Production Cell contract (Swarm_System_Prompts/router/100m_retrieval_ranker.md):
//      a JSON object with `ranks: [{ "source_id": "<id exactly as given>",
//      "score": 0.0-1.0, ... }]` ordered most-relevant-first. The allow-list is
//      the source_ids in the Cell's own order.
//   2. A bare JSON array of node IDs (e.g. `["node-1","node-2"]`), optionally
//      inside a ```json fence.
//
// Anything else — prose, `{"ids": [...]}` wrappers, invalid JSON — is
// malformed and degrades to nil.

public enum RetrievalRankerFilter {

    /// Parses the ranker's output into an ordered allow-list validated against
    /// the assembled hot-node IDs.
    ///
    /// - Returns: the validated allow-list (a strict subset of `assembledIDs`,
    ///   ordered by the ranker, deduplicated), or `nil` when the output does not
    ///   match either contract (malformed — caller degrades to the raw context).
    ///   An empty allow-list is honored: it means the model found no hot node
    ///   relevant to the intent.
    public static func parseAllowList(_ output: String, from assembledIDs: [String]) -> [String]? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = Self.stripCodeFence(trimmed)
        guard let data = candidate.data(using: .utf8) else { return nil }
        let assembled = Set(assembledIDs)

        // Shape 1: bare JSON array of IDs — simple contract.
        if let ids = try? JSONDecoder().decode([String].self, from: data) {
            return Self.validate(ids, assembled: assembled)
        }

        // Shape 2: the production Cell contract — a JSON object with
        // `ranks: [{ "source_id": ... }]`, ordered most-relevant-first.
        struct RankedOutput: Decodable {
            struct Rank: Decodable {
                let sourceID: String
                enum CodingKeys: String, CodingKey { case sourceID = "source_id" }
            }
            let ranks: [Rank]?
        }
        if let ranked = try? JSONDecoder().decode(RankedOutput.self, from: data),
           let ranks = ranked.ranks {
            return Self.validate(ranks.map { $0.sourceID }, assembled: assembled)
        }

        return nil
    }

    /// Intersects candidate IDs with the assembled set, preserving first-seen
    /// order and dropping duplicates. The allow-list can never expand the
    /// context — only narrow it.
    private static func validate(_ ids: [String], assembled: Set<String>) -> [String] {
        var seen = Set<String>()
        return ids.filter { assembled.contains($0) && seen.insert($0).inserted }
    }

    /// Removes a ```json ... ``` or ``` ... ``` fence wrapper if present.
    private static func stripCodeFence(_ text: String) -> String {
        guard text.hasPrefix("```") else { return text }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first, first.hasPrefix("```") else { return text }
        lines.removeFirst()
        if var last = lines.last, last.hasSuffix("```") {
            last.removeLast(3)
            lines[lines.count - 1] = last
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
