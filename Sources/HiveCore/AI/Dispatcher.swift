import Foundation

// MARK: - Provider Preference

/// User-facing AI provider preference (Comet-style model toggle in the
/// assistant panel header). `.auto` keeps the default chain; a concrete
/// preference tries that runtime first and falls back honestly — the
/// response's `provider` label always reflects who actually answered.
public enum ProviderPreference: String, Sendable, CaseIterable {
    case auto = "auto"
    case mlx = "mlx"
    case appleFMF = "appleFMF"
    case byokRemote = "byokRemote"
}

// MARK: - Dispatcher

/// Routes a `GenerateRequest` to the right `ModelRuntime` per the role's tier
/// and the user's configuration. The Dispatcher picks the *provider*; it never
/// decides the *action* (that's the action guard + policy, elsewhere).
///
/// Selection order (per role):
///   1. rule-based roles never hit a model.
///   2. `.instructOffTheShelf` roles → MLX (if available) → Apple FMF (narrow
///      roles, macOS 26+) → Mock (honestly labelled).
///   3. `.byokRemote` role → BYOK (only if configured; otherwise Mock).
///
/// No silent fidelity downgrade: every output carries a `provider` label so
/// Swarm's UI can show "real local model" vs "no local model yet" honestly.
public actor Dispatcher {

    public static let shared = Dispatcher()

    private let mlx: MLXRuntime
    private let fmf: AppleFMFRuntime
    private let mock: MockRuntime
    private var byok: BYOKRuntime?

    public init(byok: BYOKRuntime? = nil) {
        self.mlx = MLXRuntime()
        self.fmf = AppleFMFRuntime()
        self.mock = MockRuntime()
        self.byok = byok
    }

    public func setBYOK(_ runtime: BYOKRuntime?) { self.byok = runtime }

    /// Returns the provider that can actually serve this role right now.
    /// Configuration alone is not availability: BYOK must resolve its Keychain
    /// alias, and local providers must have usable weights/capability.
    public func availableProvider(for role: ModelRole) async -> GenerateResult.Provider? {
        guard let entry = ModelManifest.entries[role] else { return nil }
        switch entry.servingStrategy {
        case .ruleBased:
            return .rule
        case .byokRemote:
            guard let byok else { return nil }
            return await byok.isAvailable() ? .byokRemote : nil
        case .instructOffTheShelf, .instructLoRA, .appleFMF:
            if await mlx.isAvailable(),
               await ModelStore.shared.isPresentOrPendingSupported(role) {
                return .mlx
            }
            if await fmf.isAvailable(), ModelRole.appleFMFAllowed.contains(role) {
                return .appleFMF
            }
            return nil
        }
    }

    /// Returns a provider only when the selected runtime can produce a stream.
    /// Local MLX/Foundation Models currently expose one-shot generation, so
    /// callers must use `generate` for them rather than route them through the
    /// mock streaming fallback.
    public func availableStreamingProvider(for role: ModelRole) async -> GenerateResult.Provider? {
        guard let provider = await availableProvider(for: role) else { return nil }
        switch provider {
        case .byokRemote:
            return byok == nil ? nil : provider
        default:
            return nil
        }
    }

    // MARK: - Generate

    public func generate(
        _ request: GenerateRequest,
        preferredProvider: ProviderPreference = .auto
    ) async throws -> GenerateResult {
        let entry = ModelManifest.entries[request.role]
        switch entry?.servingStrategy {
        case .ruleBased:
            return try await mock.generate(request)
        case .instructOffTheShelf, .instructLoRA, .appleFMF:
            return try await generateWithModel(request, preferredProvider: preferredProvider)
        case .byokRemote:
            if let byok, await byok.isAvailable() {
                return try await byok.generate(request)
            }
            return try await mock.generate(request)
        case nil:
            return try await mock.generate(request)
        }
    }

    /// Streams token deltas for chat surfaces. Falls back to emitting the
    /// complete non-streaming response as a single chunk when the selected
    /// runtime does not support streaming.
    ///
    /// This method is `async` so the runtime can be chosen while still on the
    /// actor; the returned stream closure only captures the chosen runtime (a
    /// `Sendable` value), not the actor's isolated state.
    public func streamGenerate(_ request: GenerateRequest) async -> AsyncThrowingStream<String, Error> {
        enum Source: Sendable {
            case streaming(any StreamingModelRuntime, GenerateRequest)
            case mock(MockRuntime, GenerateRequest)
        }

        let entry = ModelManifest.entries[request.role]
        let source: Source
        switch entry?.servingStrategy {
        case .byokRemote:
            if let byok = self.byok, await byok.isAvailable() {
                source = .streaming(byok, request)
            } else {
                source = .mock(self.mock, request)
            }
        case .instructOffTheShelf, .instructLoRA, .appleFMF:
            // Prefer a streaming local runtime when available; otherwise
            // emit the full non-streaming response as one chunk.
            if await self.mlx.isAvailable(),
               await ModelStore.shared.isPresentOrPendingSupported(request.role),
               let streaming = self.mlx as? StreamingModelRuntime {
                source = .streaming(streaming, request)
            } else if await self.fmf.isAvailable(),
                      ModelRole.appleFMFAllowed.contains(request.role),
                      let streaming = self.fmf as? StreamingModelRuntime {
                source = .streaming(streaming, request)
            } else {
                source = .mock(self.mock, request)
            }
        default:
            source = .mock(self.mock, request)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    switch source {
                    case .streaming(let runtime, let request):
                        for try await chunk in runtime.generateStream(request) {
                            try Task.checkCancellation()
                            continuation.yield(chunk)
                        }
                    case .mock(let mock, let request):
                        for try await chunk in mock.generateStream(request) {
                            try Task.checkCancellation()
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func generateWithModel(
        _ request: GenerateRequest,
        preferredProvider: ProviderPreference = .auto
    ) async throws -> GenerateResult {
        // 0. User-selected provider first (Comet-style model toggle). Falls
        //    through honestly to the default chain on any failure.
        switch preferredProvider {
        case .mlx:
            if await mlx.isAvailable(),
               await ModelStore.shared.isPresentOrPendingSupported(request.role) {
                do { return try await mlx.generate(request) } catch { /* fall through */ }
            }
        case .appleFMF:
            if await fmf.isAvailable(),
               ModelRole.appleFMFAllowed.contains(request.role) {
                do { return try await fmf.generate(request) } catch { /* fall through */ }
            }
        case .byokRemote:
            if let byok, await byok.isAvailable() {
                do { return try await byok.generate(request) } catch { /* fall through */ }
            }
        case .auto:
            break
        }
        // 1. Real local MLX — the v1 baseline. Highest fidelity, local-first.
        if await mlx.isAvailable(),
           await ModelStore.shared.isPresentOrPendingSupported(request.role) {
            do {
                return try await mlx.generate(request)
            } catch {
                // MLX load failure is non-fatal — fall through to FMF/Mock honestly.
            }
        }
        // 2. Apple Foundation Models — narrow low-risk roles only, macOS 26+.
        //    ProviderPolicy forbids FMF for orchestrator/auditor/planner/coder/research.
        if await fmf.isAvailable(),
           ModelRole.appleFMFAllowed.contains(request.role) {
            do {
                return try await fmf.generate(request)
            } catch {
                // FMF unavailable or role not permitted — fall through to honest mock.
            }
        }
        // 3. Mock — honest fallback. provider == .mock, so nothing pretends.
        return try await mock.generate(request)
    }
}

// MARK: - Apple FMF policy surface

extension ModelRole {
    /// Roles for which FMF is a permitted fallback (narrow, low-risk only).
    /// Orchestrator/auditor/planner/coder/research are FORBIDDEN on FMF
    /// per ProviderPolicy — those must go local MLX or BYOK.
    static let appleFMFAllowed: Set<ModelRole> = AppleFMFRuntime.allowedRoles
}

// MARK: - ModelStore presence helpers

extension ModelStore {
    /// True if the role's weights are present locally OR the role doesn't need
    /// downloaded weights (rule/fmf/byok).
    func isPresentOrPendingSupported(_ role: ModelRole) async -> Bool {
        guard let entry = ModelManifest.entries[role] else { return true }
        guard let repo = entry.hfRepo else { return true }
        return isPresent(hfRepo: repo)
    }
}
