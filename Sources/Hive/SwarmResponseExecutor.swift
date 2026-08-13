import Foundation
import HiveCore

/// Result returned by the shared advisory response executor. UI callers decide
/// how to present it (chat replacement or spoken response); the executor never
/// owns message arrays or audio state.
@MainActor
struct SwarmResponseExecutionResult: Sendable {
    let text: String
    let providerLabel: String
    let diagnostics: ContextDiagnostics?
    let contextChanged: Bool

    static func contextChanged() -> Self {
        Self(
            text: "Context changed — please ask again in the current workspace.",
            providerLabel: "local",
            diagnostics: nil,
            contextChanged: true
        )
    }

}

/// Shared response implementation for advisory generic/page questions.
///
/// This is deliberately a browser-shell adapter: it assembles no new memory,
/// makes no policy decision, and performs no CEF automation. The caller owns
/// response lifecycle tokens and UI mutation, while this type owns the one
/// orchestration/direct-generation behavior shared by text and voice.
@MainActor
final class SwarmResponseExecutor {
    private let systemPrompt = "You are a helpful browser assistant. Answer concisely and helpfully."

    func perform(
        request: SwarmResponseRequest,
        scope: ContextScope,
        transitionID: UInt64,
        coordinator: ContextRequestCoordinator?,
        page: PageContext?,
        fullIntent: String,
        preferredProvider: ProviderPreference,
        responseID: UInt64,
        responseIsCurrent: @escaping @MainActor (UInt64) -> Bool,
        transitionIsCurrent: @escaping @MainActor (UInt64) -> Bool,
        pageSummary: String?
    ) async throws -> SwarmResponseExecutionResult {
        guard responseIsCurrent(responseID), !Task.isCancelled else {
            throw CancellationError()
        }
        guard transitionIsCurrent(transitionID) else {
            return .contextChanged()
        }

        let orchestrationResult: OrchestrationResult
        if let coordinator {
            do {
                orchestrationResult = try await coordinator.process(
                    scope: scope,
                    transitionID: transitionID,
                    intent: fullIntent,
                    page: page,
                    role: request.role,
                    preferredProvider: preferredProvider,
                    userIntent: request.intent
                )
            } catch ContextTransitionError.staleTransition {
                guard responseIsCurrent(responseID), !Task.isCancelled else {
                    throw CancellationError()
                }
                return .contextChanged()
            } catch {
                // Preserve the existing honest fallback: only a non-transition
                // orchestration failure may use direct generation, and the
                // result remains labeled from the actual provider response.
                guard transitionIsCurrent(transitionID) else {
                    return .contextChanged()
                }
                orchestrationResult = try await directGeneration(
                    request: request,
                    preferredProvider: preferredProvider,
                    responseID: responseID,
                    responseIsCurrent: responseIsCurrent
                )
            }
        } else {
            // No coordinator means direct generation is still bounded by the
            // browser transition that authorized this request. Do not spend
            // model work on a stale scope, even though the post-generation
            // guard would prevent UI publication later.
            guard transitionIsCurrent(transitionID) else {
                return .contextChanged()
            }
            orchestrationResult = try await directGeneration(
                request: request,
                preferredProvider: preferredProvider,
                responseID: responseID,
                responseIsCurrent: responseIsCurrent
            )
        }

        guard responseIsCurrent(responseID), !Task.isCancelled else {
            throw CancellationError()
        }
        let resolution = SwarmResponsePolicy.resolution(
            responseIsCurrent: responseIsCurrent(responseID),
            taskIsCancelled: Task.isCancelled,
            transitionIsCurrent: transitionIsCurrent(transitionID)
        )
        guard resolution != .drop else { throw CancellationError() }
        guard resolution == .apply else { return .contextChanged() }

        let diagnostics = SwarmResponsePolicy.diagnostics(
            for: orchestrationResult,
            pageSummary: pageSummary,
            pageTitle: page?.title,
            pageHost: page?.url?.host
        )
        return SwarmResponseExecutionResult(
            text: orchestrationResult.text,
            providerLabel: orchestrationResult.provider.rawValue,
            diagnostics: ContextDiagnostics(
                contextNodeCount: diagnostics.contextNodeCount,
                contextSummary: diagnostics.contextSummary,
                rankerProvider: diagnostics.rankerProvider,
                providerLabel: diagnostics.providerLabel,
                durationMS: diagnostics.durationMS,
                pageTitle: diagnostics.pageTitle,
                pageHost: diagnostics.pageHost
            ),
            contextChanged: false
        )
    }

    private func directGeneration(
        request: SwarmResponseRequest,
        preferredProvider: ProviderPreference,
        responseID: UInt64,
        responseIsCurrent: @escaping @MainActor (UInt64) -> Bool
    ) async throws -> OrchestrationResult {
        guard responseIsCurrent(responseID), !Task.isCancelled else {
            throw CancellationError()
        }
        do {
            let generated = try await Dispatcher.shared.generate(
                GenerateRequest(
                    role: request.role,
                    system: systemPrompt,
                    user: request.intent,
                    maxTokens: request.maxTokens
                ),
                preferredProvider: preferredProvider
            )
            return OrchestrationResult(
                text: generated.text,
                provider: generated.provider,
                modelLabel: generated.modelLabel,
                contextNodeCount: 0,
                contextSummary: "[Direct generation — context orchestration unavailable]",
                durationMS: 0
            )
        } catch {
            guard responseIsCurrent(responseID), !Task.isCancelled else {
                throw CancellationError()
            }
            if let inferenceError = error as? InferenceError {
                throw UserFacingSwarmResponseError(message: inferenceError.userMessage)
            }
            throw UserFacingSwarmResponseError(message: "Unexpected error")
        }
    }
}

struct UserFacingSwarmResponseError: Error {
    let message: String
}
