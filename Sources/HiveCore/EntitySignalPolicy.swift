import Foundation

public enum EntitySignalPolicy {
    public static func isMeaningfulName(_ value: String) -> Bool {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let lower = normalized.lowercased()
        guard normalized.count >= 3, !stopWords.contains(lower) else { return false }
        guard !metadataFragments.contains(where: { lower.contains($0) }) else { return false }
        let parts = lower.split(separator: " ").map(String.init)
        if let first = parts.first, leadingStopWords.contains(first) { return false }
        if parts.count == 1 {
            let word = parts[0]
            if word.count < 4 { return false }
            if genericSingleWordCandidates.contains(word) { return false }
        }
        return true
    }

    private static let stopWords: Set<String> = [
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
        "unclear", "work", "personal", "background", "professional", "creative",
        "analytical", "school", "education", "finance", "hardware", "health",
        "family", "workflow", "research", "shopping", "apps", "app",
        "applications", "captured", "generated", "privacy", "scope"
    ]

    private static let metadataFragments: Set<String> = [
        "browser entries scanned",
        "chat prompts scanned",
        "non short watch pages found",
        "privacy:",
        "generated:",
        "local context evidence",
        "app identity and usage metadata"
    ]

    private static let genericSingleWordCandidates: Set<String> = [
        "are", "has", "have", "had", "was", "were", "who", "what", "why", "how",
        "does", "did", "can", "could", "should", "would", "will", "is", "it",
        "determines", "clarifies", "resolves", "distinguishes", "contains",
        "extract", "extracts", "importing", "building", "using", "based",
        "needs", "requires", "changes", "categorizes", "shows", "reads",
        "writes", "updates", "creates", "flags", "links"
    ]

    private static let leadingStopWords: Set<String> = [
        "is", "are", "has", "have", "had", "was", "were", "who", "what", "why", "how",
        "does", "did", "can", "could", "should", "would", "will", "determines",
        "clarifies", "resolves", "distinguishes", "contains", "based", "needs",
        "requires", "changes", "shows"
    ]
}
