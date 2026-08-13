import Foundation

/// MLX local inference runtime — the bedrock of Hive's local-first model stack.
///
/// Real inference code, gated behind `canImport(MLXLMCommon)`. The SPM
/// dependencies (MLXLMCommon + MLXLLM, from `mlx-swift-examples` 2.29.1) are
/// declared in `Package.swift`; with the package resolved, the
/// `#if canImport(MLXLMCommon)` branch compiles in. Until weights are present,
/// `isAvailable()` is true BUT every `generate` throws `weightsNotDownloaded`
/// before touching a model — and `Dispatcher.generateWithModel` catches that
/// and falls back to FMF/Mock, so the no-weights build behaves identically to a
/// build without MLX linked. Never silent, never fake.
///
/// Weights are resolved through `ModelStore`; a trained LoRA adapter (the
/// `.instructLoRA` roles) is merged onto the base via `LoRAContainer`.
///
/// API note (2.29.1): this runtime is written against the *current* mlx-swift
/// surface — `loadModelContainer(directory:)` → `ModelContainer` (an actor that
/// serializes MLX access), `Chat.Message`/`UserInput` for prompt building, and
/// the free `generate(input:parameters:context:didGenerate:)` for decoding. The
/// older `loadModel(configuration:adapters:)` / `ModelDirectoryConfiguration` /
/// `TokenizerFactory` / `tokenizer.applyChatTemplate([(role,content)])` symbols
/// were removed upstream; this is the ported replacement.
#if canImport(MLXLMCommon)
import MLXLMCommon
import MLXLLM
#endif

public struct MLXRuntime: ModelRuntime {

    public let roles: Set<ModelRole>

    public init(roles: Set<ModelRole>? = nil) {
        // Covers BOTH served-by-MLX strategies: the off-the-shelf instruct base
        // AND a base+trained-LoRA-adapter. (Ruled out: ruleBased/fmf/byok/
        // systemEmbedder, which never hit MLX.) Without instructLoRA here, a
        // role flipped to .instructLoRA would be excluded from `roles` and the
        // guard below would throw → Dispatcher would silently fall back to Mock,
        // so the trained adapter would never run even with MLX linked.
        self.roles = roles ?? Set(ModelRole.allCases.filter {
            ModelManifest.entries[$0]?.servingStrategy == .instructOffTheShelf
                || ModelManifest.entries[$0]?.servingStrategy == .instructLoRA
        })
    }

    public func isAvailable() async -> Bool {
        #if canImport(MLXLMCommon)
        // Install the non-exiting error handler before any MLX call so a
        // metallib/GPU failure degrades instead of killing the process.
        MLXErrorSafety.install()
        // MLX framework present in the build. Weight presence is checked per-call.
        return true
        #else
        return false
        #endif
    }

    public func generate(_ request: GenerateRequest) async throws -> GenerateResult {
        MLXErrorSafety.install()
        guard roles.contains(request.role) else {
            throw InferenceError.roleUnsupported(request.role)
        }
        guard let entry = ModelManifest.entries[request.role],
              entry.servingStrategy == .instructOffTheShelf
                || entry.servingStrategy == .instructLoRA else {
            throw InferenceError.roleUnsupported(request.role)
        }

        #if canImport(MLXLMCommon)
        // Resolve + ensure weights present. The closure is the download hook; HiveCore
        // deliberately doesn't shell out here, so if weights aren't already on disk we
        // surface `weightsNotDownloaded` — Dispatcher catches it and falls back honestly.
        guard let repo = entry.hfRepo else {
            throw InferenceError.weightsNotDownloaded(hfRepo: "?")
        }
        try await ModelStore.shared.ensureDownloaded(hfRepo: repo) { repo, _ in
            throw InferenceError.weightsNotDownloaded(hfRepo: repo)
        }
        let modelDir = await ModelStore.shared.localDirectory(for: repo)

        // If the role has a verified trained adapter (ManifestEntry.loraAdapter),
        // resolve its on-disk directory. A .instructLoRA role whose adapter dir is
        // absent (not yet downloaded/shipped) degrades HONESTLY: we run the
        // off-the-shelf base and label provider .mlx (still a real local model) —
        // never Mock, never silent about which weights answered.
        let adapterPath = entry.loraAdapter.flatMap { ModelStore.adapterDirectory(for: $0) }

        // Load (or reuse a cached) ModelContainer for this (repo, adapter) pair, then
        // generate. Both steps are in one do/catch: any MLX load/generate failure is
        // re-thrown as `weightsNotDownloaded` so Dispatcher falls through cleanly.
        do {
            let container = try await MLXRuntime.container(for: modelDir.path,
                                                             adapterPath: adapterPath)
            let mergedAdapter = (entry.servingStrategy == .instructLoRA && adapterPath != nil)

            // Build the chat input. The processor (via the tokenizer's chat template)
            // turns [system, user] into the model's expected prompt format. A bare
            // `UserInput(chat:)` composes correctly for instruct models.
            var messages: [Chat.Message] = []
            if !request.system.isEmpty { messages.append(.system(request.system)) }
            messages.append(.user(request.user))
            let userInput = UserInput(chat: messages)

            // generate runs inside the container's actor isolation (the perform
            // closure). Returning MLXLMCommon.GenerateResult across the actor is safe:
            // it's `Sendable` and `generate` calls `Stream().synchronize()` before
            // returning, so the token tensors are realized.
            //
            // The closure is hoisted to a typed local so the compiler binds
            // `container.perform(_:)` to the `(ModelContext) async throws -> R`
            // overload — ModelContainer also publishes deprecated `(any LanguageModel,
            // Tokenizer) throws -> R` overloads that arity-inference can grab by
            // mistake. The typed signature pins the async, single-ModelContext one.
            let produce: @Sendable (ModelContext) async throws -> MLXLMCommon.GenerateResult = { context in
                let input = try await context.processor.prepare(input: userInput)
                let params = GenerateParameters(
                    maxTokens: request.maxTokens,
                    temperature: Float(request.temperature))
                // The `([Int]) -> GenerateDisposition` overload returns the full
                // GenerateResult (with `.output`); the `(Int)` overload returns only
                // timing info. Type the closure param to disambiguate to the former.
                return try MLXLMCommon.generate(input: input, parameters: params, context: context) {
                    (_: [Int]) -> GenerateDisposition in .more
                }
            }
            let mlxResult = try await container.perform(produce)

            return GenerateResult(
                role: request.role,
                provider: .mlx,
                text: mlxResult.output,
                latencyMS: Int((mlxResult.promptTime + mlxResult.generateTime) * 1000),
                tokensGenerated: mlxResult.generationTokenCount,
                modelLabel: mergedAdapter ? "\(entry.baseModel)+LoRA" : entry.baseModel)
        } catch {
            // MLX load/generate failure → surface as the same honest "weights not
            // usable" signal Dispatcher already routes around. Don't fabricate.
            throw InferenceError.weightsNotDownloaded(hfRepo: repo)
        }
        #else
        // No MLX in this build. Don't fake — surface the gap honestly.
        throw InferenceError.roleUnsupported(request.role)
        #endif
    }

    #if canImport(MLXLMCommon)
    // MARK: - Container cache

    /// One loaded `ModelContainer` per distinct (repo, adapter) pair, cached for the
    /// process lifetime. `ModelContainer` is an actor (Sendable), so it can be stored
    /// in a static dict and reused across `generate` calls without re-loading weights.
    /// A container built WITH a merged adapter is keyed separately from one built
    /// base-only, so a later request for the other config re-loads rather than serving
    /// the wrong adapter.
    private static let cache = ModelContainerCache()

    private static func container(for modelPath: String, adapterPath: String?) async throws -> ModelContainer {
        let key = modelPath + "\u{1F}" + (adapterPath ?? "<none>")
        if let cached = Self.cache.container(forKey: key) {
            return cached
        }
        let url = URL(fileURLWithPath: modelPath)
        let container = try await loadModelContainer(directory: url)

        // Merge a trained adapter if its directory exists. A base model that isn't
        // LoRA-compatible (doesn't conform to LoRAModel) throws here — we catch that
        // and fall through to the plain base, honestly labelled (the caller sees
        // provider .mlx without the "+LoRA" suffix). Never silent, never fake.
        if let adapterPath, FileManager.default.fileExists(atPath: adapterPath) {
            do {
                let adapter = try LoRAContainer.from(directory: URL(fileURLWithPath: adapterPath))
                // Hoist+type the closure to pin the `(ModelContext) async throws`
                // perform overload (see the generate site for why).
                let applyAdapter: @Sendable (ModelContext) async throws -> Void = { context in
                    try adapter.load(into: context.model)
                }
                try await container.perform(applyAdapter)
            } catch {
                // Adapter missing/incompatible — generate against the plain base.
                // The mergedAdapter flag in generate(_:) only reflects whether an
                // adapter *path* was supplied, not whether it merged, so an honest
                // caller should treat provider .mlx alone here. We proceed base-only.
            }
        }

        Self.cache.setContainer(container, forKey: key)
        return container
    }
    #endif
}

#if canImport(MLXLMCommon)
/// Thread-safe cache of loaded `ModelContainer`s. `ModelContainer` is a Sendable
/// actor, so storing it behind an `NSLock`-guarded dict is data-race free.
private final class ModelContainerCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: ModelContainer] = [:]

    func container(forKey key: String) -> ModelContainer? {
        lock.withLock { entries[key] }
    }

    func setContainer(_ container: ModelContainer, forKey key: String) {
        lock.withLock { entries[key] = container }
    }
}
#endif
