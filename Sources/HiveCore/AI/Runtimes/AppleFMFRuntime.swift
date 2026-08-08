import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Foundation Models runtime — on-device (~3B) on macOS 26+.
///
/// Per ProviderPolicy (PITCH/ai-architecture.md), FMF is restricted to NARROW,
/// LOW-RISK tasks only:
///   • short extraction / refinement / formatting
///   • yes-no-confirm dialog transforms
///   • low-stakes tool-call wrappers
/// It is FORBIDDEN for orchestration, memory integrity, auditing, planning,
/// provenance-critical rewriting, system-trust, or multi-doc synthesis.
///
/// Below macOS 26, `generate` throws `.appleFMFUnavailable` and the runtime
/// layer falls back to MockRuntime (honestly labelled). Nothing silently
/// downgrades fidelity.
public struct AppleFMFRuntime: ModelRuntime {

    public static let allowedRoles: Set<ModelRole> = [
        .titleGenerator, .summarizer, .librarian, .retrievalRanker,
        .memoryCompressor, .intentClassifier
    ]

    public let roles: Set<ModelRole>

    public init(roles: Set<ModelRole> = AppleFMFRuntime.allowedRoles) {
        self.roles = roles.intersection(AppleFMFRuntime.allowedRoles)
    }

    public func isAvailable() async -> Bool {
        if #unavailable(macOS 26.0) { return false }
        return true
    }

    public func generate(_ request: GenerateRequest) async throws -> GenerateResult {
        guard roles.contains(request.role) else {
            throw InferenceError.roleUnsupported(request.role)
        }
        guard ModelManifest.entries[request.role]?.servingStrategy == .appleFMF
                || AppleFMFRuntime.allowedRoles.contains(request.role) else {
            throw InferenceError.roleUnsupported(request.role)
        }
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            throw InferenceError.appleFMFUnavailable
        }
        let session = LanguageModelSession(model: SystemLanguageModel.default)
        let prompt = request.system.isEmpty
            ? request.user
            : request.system + "\n\n" + request.user
        let response = try await session.respond(to: prompt)
        let text = response.content
        return GenerateResult(
            role: request.role, provider: .appleFMF, text: text,
            latencyMS: 0,    // caller stamps; FMF doesn't report cheaply
            tokensGenerated: text.split(separator: " ").count,
            modelLabel: "Apple Foundation Models (~3B on-device)")
        #else
        throw InferenceError.appleFMFUnavailable
        #endif
    }
}
