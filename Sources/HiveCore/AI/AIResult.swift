import Foundation

// MARK: - AIResult
//
// Common result type for all AI features in the Swarm pipeline.
// Every AI feature (model council, deep research, AI URL bar, briefing,
// agent actions) must surface one of these states so the UI can render
// consistently across all AI surfaces.
//
// Five states every AI feature must handle:
// 1. loading  — Operation in progress, show progress indicator
// 2. partial  — Partial results available, still waiting for more
// 3. success  — Complete results
// 4. error    — Operation failed, with retry action
// 5. degraded — Results available but with reduced quality (e.g., fewer models)
// 6. empty    — No results (e.g., no history, no bookmarks)

// MARK: - AIError

/// User-presentable AI error with recovery action.
struct AIError: Error, Identifiable {
    let id = UUID()
    /// Short title for the error banner (e.g., "Model timed out")
    let title: String
    /// Human-readable explanation (e.g., "The local MLX model took too long to respond. You can retry or switch to a cloud provider.")
    let message: String
    /// Suggested recovery action label
    let recoveryLabel: String
    /// Underlying error for logging (never shown to user)
    let underlyingError: Error?

    init(title: String, message: String, recoveryLabel: String = "Retry", underlyingError: Error? = nil) {
        self.title = title
        self.message = message
        self.recoveryLabel = recoveryLabel
        self.underlyingError = underlyingError
    }

    // MARK: Common AI Errors

    static func timeout(provider: String) -> AIError {
        AIError(
            title: "\(provider) timed out",
            message: "The \(provider) model took too long to respond. You can retry or the system will use available alternatives.",
            recoveryLabel: "Retry"
        )
    }

    static func networkError(provider: String) -> AIError {
        AIError(
            title: "Network error",
            message: "Could not reach \(provider). Check your internet connection and try again.",
            recoveryLabel: "Retry"
        )
    }

    static func modelUnavailable(provider: String) -> AIError {
        AIError(
            title: "\(provider) unavailable",
            message: "The \(provider) model is not available right now. Results are provided using available models.",
            recoveryLabel: "OK"
        )
    }

    static func insufficientMemory(provider: String) -> AIError {
        AIError(
            title: "Not enough memory",
            message: "The \(provider) model requires more memory than is currently available. Try closing other apps or switching to a smaller model.",
            recoveryLabel: "Switch to smaller model"
        )
    }

    static func noResults(query: String) -> AIError {
        AIError(
            title: "No results found",
            message: "No relevant results were found for \"\(query)\". Try rephrasing your question.",
            recoveryLabel: "Try again"
        )
    }
}

// MARK: - AIResult

/// A container for any AI operation result, covering all possible states.
/// All AI features in the Swarm pipeline produce one of these states.
enum AIResult<Value: Sendable>: Sendable {
    /// Operation is in progress. Progress is 0.0...1.0.
    case loading(progress: Double)

    /// Partial results are available while waiting for remaining providers.
    /// `remainingProviders` is the count of providers still processing.
    case partial(Value, remainingProviders: Int)

    /// Operation completed successfully.
    case success(Value)

    /// Operation failed with a user-presentable error and retry action.
    case error(AIError)

    /// Results available but with reduced quality.
    /// `explanation` tells the user what's degraded (e.g., "2 of 3 models responded").
    case degraded(Value, explanation: String)

    /// No results available (empty state — no data to show).
    case empty

    // MARK: - Convenience

    /// The value if in success, partial, or degraded state; nil otherwise.
    var value: Value? {
        switch self {
        case .success(let v), .partial(let v, _), .degraded(let v, _):
            return v
        case .loading, .error, .empty:
            return nil
        }
    }

    /// True if the operation is still in progress (loading or partial).
    var isInProgress: Bool {
        switch self {
        case .loading, .partial:
            return true
        case .success, .error, .degraded, .empty:
            return false
        }
    }

    /// A stable identifier for state tracking (useful for SwiftUI animations).
    var stateID: String {
        switch self {
        case .loading: return "loading"
        case .partial: return "partial"
        case .success: return "success"
        case .error: return "error"
        case .degraded: return "degraded"
        case .empty: return "empty"
        }
    }
}

// MARK: - AIResponse

/// Model council response from a single model provider.
struct AIProviderResponse: Sendable {
    /// Provider name (e.g., "MLX Local", "Tavily", "BYOK Claude")
    let provider: String
    /// The model's answer text
    let answer: String
    /// Confidence score 0.0...1.0
    let confidence: Double
    /// Citations from the model
    let citations: [AICitation]
    /// Time taken to generate in seconds
    let duration: TimeInterval
    /// Whether this provider succeeded or failed
    let status: ProviderStatus

    enum ProviderStatus: Sendable {
        case success
        case timeout
        case error(String)
    }
}

/// A citation from an AI response.
struct AICitation: Sendable, Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let snippet: String
}

// MARK: - AIResult + CustomStringConvertible

extension AIResult: CustomStringConvertible {
    var description: String {
        switch self {
        case .loading(let p):
            return "loading(\(Int(p * 100))%)"
        case .partial(_, let remaining):
            return "partial(\(remaining) providers remaining)"
        case .success:
            return "success"
        case .error(let e):
            return "error(\(e.title))"
        case .degraded(_, let explanation):
            return "degraded(\(explanation))"
        case .empty:
            return "empty"
        }
    }
}
