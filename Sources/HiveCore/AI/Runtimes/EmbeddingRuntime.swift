import Foundation
import NaturalLanguage

/// On-device embedding endpoint. v1 baseline uses Apple's system
/// `NLEmbedding` (zero external dependency, zero download, always available on
/// macOS 10.15+). The manifest's nomic-embed-text-v2 is the documented MLX
/// upgrade path for higher-recall semantic search once that runtime lands.
///
/// This is deliberately NOT a `ModelRuntime` — embeddings produce vectors, not
/// text, so they get their own protocol. Honeycomb retrieval consumes it.
public protocol EmbeddingRuntime: Sendable {
    func embed(_ text: String) async throws -> [Double]
    var dimensionality: Int { get }
}

public enum EmbeddingError: Error, Sendable {
    case sentenceEmbeddingUnavailable
}

public actor SystemEmbeddingRuntime: EmbeddingRuntime {

    private let backing: NLEmbedding?

    public init() {
        self.backing = NLEmbedding.sentenceEmbedding(for: .english)
    }

    nonisolated public var dimensionality: Int { 512 }

    public func embed(_ text: String) async throws -> [Double] {
        guard let backing else { throw EmbeddingError.sentenceEmbeddingUnavailable }
        guard let v = backing.vector(for: text), !v.isEmpty else {
            throw EmbeddingError.sentenceEmbeddingUnavailable
        }
        return v
    }
}
