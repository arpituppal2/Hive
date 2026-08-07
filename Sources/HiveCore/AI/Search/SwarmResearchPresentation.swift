import Foundation

/// The small, UI-neutral projection needed to render one Swarm research run.
///
/// It intentionally carries source models rather than SwiftUI-specific citation
/// views. The browser target can map these sources to its own message model while
/// tests can verify content, loading, and terminal semantics in HiveCore.
public struct SwarmResearchPresentation: Sendable, Equatable {
    public let phase: SwarmResearchPhase
    public let content: String
    public let sources: [WebSearchSource]
    public let isLoading: Bool
    public let isTerminal: Bool

    public init(
        phase: SwarmResearchPhase,
        content: String,
        sources: [WebSearchSource],
        isLoading: Bool,
        isTerminal: Bool
    ) {
        self.phase = phase
        self.content = content
        self.sources = sources
        self.isLoading = isLoading
        self.isTerminal = isTerminal
    }
}

public extension SwarmResearchState {
    /// Projects reducer state into the minimal contract consumed by Swarm UI.
    ///
    /// Partial answers are preserved when a user stops a run. Failure notices
    /// remain visible through `renderedText`; an empty failure still gets an
    /// honest fallback instead of an empty assistant bubble.
    var presentation: SwarmResearchPresentation {
        let content: String
        switch phase {
        case .running, .completed:
            content = renderedText
        case .cancelled:
            content = renderedText.isEmpty
                ? "Search stopped before it completed."
                : renderedText + "\n\n[Search stopped before it completed.]"
        case .failed:
            content = renderedText.isEmpty
                ? "Couldn't complete web search."
                : renderedText
        }

        return SwarmResearchPresentation(
            phase: phase,
            content: content,
            sources: sources,
            isLoading: phase == .running && answer.isEmpty,
            isTerminal: phase != .running
        )
    }
}
