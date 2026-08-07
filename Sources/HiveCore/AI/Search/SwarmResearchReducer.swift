import Foundation

/// Terminal state for one visible web-research run.
public enum SwarmResearchPhase: String, Sendable, Codable, Equatable {
    case running
    case completed
    case failed
    case cancelled
}

/// Pure value state for one web-research response.
///
/// The browser view renders this state; it does not decide how provider events
/// are accumulated. This keeps source order, notices, completion, and failure
/// behavior deterministic and testable without SwiftUI or a live provider.
public struct SwarmResearchState: Sendable, Equatable {
    public private(set) var phase: SwarmResearchPhase
    public private(set) var answer: String
    public private(set) var sources: [WebSearchSource]
    public private(set) var relatedQuestions: [String]
    public private(set) var providerNotices: [String]

    public init(phase: SwarmResearchPhase = .running) {
        self.phase = phase
        self.answer = ""
        self.sources = []
        self.relatedQuestions = []
        self.providerNotices = []
    }

    /// Applies a provider event without allowing external content to change
    /// lifecycle authority. A provider notice is informational; it does not
    /// fail a run by itself.
    public mutating func apply(_ event: WebSearchStreamEvent) {
        guard phase == .running else { return }

        switch event {
        case .sources(let incoming):
            mergeSources(incoming)
        case .answerChunk(let chunk):
            guard !chunk.isEmpty else { return }
            answer.append(chunk)
        case .relatedQuestions(let incoming):
            mergeStrings(incoming, into: &relatedQuestions)
        case .error(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            mergeStrings([trimmed], into: &providerNotices)
        }
    }

    /// Commits the provider's final result. The final result is authoritative
    /// for fields the stream may have omitted, while streamed content is kept
    /// when it is already present to avoid duplicate text.
    public mutating func complete(with result: WebSearchResult) {
        guard phase == .running else { return }
        if answer.isEmpty { answer = result.answer }
        mergeSources(result.sources)
        mergeStrings(result.relatedQuestions, into: &relatedQuestions)
        phase = .completed
    }

    public mutating func cancel() {
        guard phase == .running else { return }
        phase = .cancelled
    }

    public mutating func fail(_ message: String? = nil) {
        guard phase == .running else { return }
        if let message {
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { mergeStrings([trimmed], into: &providerNotices) }
        }
        phase = .failed
    }

    /// Plain text for the dense Swarm message bubble. Notices and related
    /// questions remain visibly attributed instead of disappearing into logs.
    public var renderedText: String {
        var sections: [String] = []
        if !answer.isEmpty { sections.append(answer) }
        if !providerNotices.isEmpty {
            sections.append(providerNotices.map { "[Provider notice: \($0)]" }.joined(separator: "\n"))
        }
        if !relatedQuestions.isEmpty {
            sections.append("**Related**\n" + relatedQuestions.map { "• \($0)" }.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }

    private mutating func mergeSources(_ incoming: [WebSearchSource]) {
        var seen = Set(sources.map { canonicalURL($0.url) })
        for source in incoming {
            let key = canonicalURL(source.url)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            sources.append(source)
        }
    }

    private func canonicalURL(_ value: String) -> String {
        WebSearchSource.canonicalHTTPURLString(value) ?? ""
    }

    private func mergeStrings(_ incoming: [String], into destination: inout [String]) {
        var seen = Set(destination)
        for value in incoming {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            destination.append(trimmed)
        }
    }
}
