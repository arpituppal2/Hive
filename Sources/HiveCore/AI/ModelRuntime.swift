import Foundation

// MARK: - JSON value (Sendable payload for structured-output schemas)

/// A recursive, `Sendable`, `Codable` JSON value.
///
/// Exists for one reason: `[String: Any]` and `Any` are not `Sendable`, so a
/// `jsonSchema: [String: Any]?` field breaks Swift 6 strict concurrency on
/// `GenerateRequest`. `JSONValue` is the Sendable container we hand runtimes
/// when a caller wants a structured (JSON-schema-shaped) response. No runtime
/// has to accept `Any`; none has to fight the borrow checker to be a `Sendable`.
public indirect enum JSONValue: Sendable, Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null
}

// MARK: - Generate request

/// Stateless inference request. No session, no UI, no retained state.
/// Each call is independent. "Stateless headless whatever" — exactly so.
public struct GenerateRequest: Sendable {
    public let role: ModelRole
    public let system: String
    public let user: String
    public let maxTokens: Int
    /// When non-nil, the runtime must return parseable JSON matching this shape.
    /// `JSONValue` (not `[String: Any]`) so the whole request is `Sendable`.
    public let jsonSchema: JSONValue?
    /// Sampling temperature (0 = deterministic).
    public let temperature: Double

    public init(role: ModelRole,
                system: String,
                user: String,
                maxTokens: Int? = nil,
                jsonSchema: JSONValue? = nil,
                temperature: Double = 0.0) {
        self.role = role
        self.system = system
        self.user = user
        self.maxTokens = maxTokens
            ?? ModelManifest.entries[role]?.maxOutputTokens ?? 512
        self.jsonSchema = jsonSchema
        self.temperature = temperature
    }
}

// MARK: - Generate result

public struct GenerateResult: Sendable {
    public let role: ModelRole
    public let provider: Provider
    public let text: String
    /// Wall-clock ms of inference, for the latency ledger.
    public let latencyMS: Int
    public let tokensGenerated: Int
    public let modelLabel: String

    public init(role: ModelRole,
                provider: Provider,
                text: String,
                latencyMS: Int,
                tokensGenerated: Int,
                modelLabel: String) {
        self.role = role
        self.provider = provider
        self.text = text
        self.latencyMS = latencyMS
        self.tokensGenerated = tokensGenerated
        self.modelLabel = modelLabel
    }

    /// Which subsystem produced this output. Honest labeling = AGENTS §6.4 rule.
    public enum Provider: String, Sendable, Codable {
        case mlx           // local MLX inference (real weights)
        case appleFMF      // Apple Foundation Models
        case byokRemote    // user-supplied remote
        case mock          // honest mock — no real weights present
        case rule          // deterministic, no model
    }

    /// True when this output came from a real local model, not a mock.
    public var isRealInference: Bool {
        switch provider {
        case .mock, .rule: return false
        default: return true
        }
    }
}

// MARK: - Runtime protocol

/// A stateless inference endpoint for one or more roles.
/// Implementations load weights lazily, run one request fully, and return.
/// No retained conversation state across calls — HiveCore owns context, not models.
public protocol ModelRuntime: Sendable {
    /// Roles this runtime can serve.
    var roles: Set<ModelRole> { get }
    /// Whether the runtime's weights are present and ready on this device.
    func isAvailable() async -> Bool
    /// Run a single request fully. Streaming is a separate protocol below.
    func generate(_ request: GenerateRequest) async throws -> GenerateResult
}

/// Optional streaming for chat surfaces. Stateful only within one call.
public protocol StreamingModelRuntime: ModelRuntime {
    /// Yields token deltas. The final element's `.text` is the complete output.
    func generateStream(_ request: GenerateRequest) -> AsyncThrowingStream<String, Error>
}

// MARK: - Errors

public enum InferenceError: Error, Sendable {
    case roleUnsupported(ModelRole)
    case weightsNotDownloaded(hfRepo: String)
    case generationFailed(String)
    case appleFMFUnavailable          // pre-macOS 26
    case byokNotConfigured(role: ModelRole)
}
