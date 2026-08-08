import Foundation

// MARK: - Model Tier

/// The resource/latency tier a role occupies. Mirrors PITCH/ai-architecture.md.
public enum ModelTier: String, Sendable, Codable, CaseIterable {
    /// Rule-based, deterministic. No weights. Always resident. ~0 footprint.
    case rule
    /// ~100M. Always loaded. <5ms target. Fast classifiers.
    case t0
    /// 300M–1.7B. Frequently resident (orchestrator, librarian). <50ms target.
    case t1
    /// 1.7B–4B. On-demand workers. <500ms target.
    case t2
    /// 4B–8B. Rare escalation (reasoner, coder, research synth). <5s target.
    case t3
    /// User-owned remote frontier. Opt-in add-on only; never load-bearing.
    case byok
    /// Apple Foundation Models, macOS 26+. Narrow low-risk tasks only.
    case fmf
}

// MARK: - Model Role (the canonical list of every AI Swarm needs)

/// Every AI Hive requires. Add here when a new agent role is introduced —
/// this is the single source of truth for the model roster.
public enum ModelRole: String, Sendable, Codable, CaseIterable {

    // --- T0 determinism: safety-critical, no weights ---
    /// Gatekeeps every privileged action's safety. Deterministic rules, no model,
    /// so it can never be socially-engineered by model output.
    case actionGuard

    // --- T0/Tiny classifiers (~100M, always resident, <5ms) ---
    /// Classifies user intent into a route (browse / ask / research / act / extend).
    case intentClassifier
    /// Detects spam / low-value / prompt-injection-laced input before routing.
    case spamDetector
    /// Scores message urgency for attention scheduling.
    case urgencyDetector
    /// Ranks candidate links/sources for retrieval before the reasoner sees them.
    case linkScorer

    // --- T0 scribe family (~100M, always resident) ---
    /// Capture→Honeycomb keep/skip + {facts,decisions,commitments} extraction +
    /// dedup. The §10.2 Automatic-Capture moat. Ships OTS (rule-rich×complex →
    /// expected NO_GAIN, like retrievalRanker). See capture_scribe.md.
    case captureScribe
    /// Grounded "ask on this page" Q&A over the tab's captured `dom_scout`
    /// excerpt — Arc/Comet parity. Ships OTS; distill-candidate pending a
    /// held-out verdict. See page_qa.md.
    case pageQa

    // --- T1 always/frequently-resident specialists (300M–1.7B, <50ms) ---
    /// Top-level router: intent → Cell dispatch + model selection.
    case orchestrator
    /// Entity/claim extraction, metadata tagging, doc typing from captures.
    case librarian
    /// Compression without loss of key claims. Backs memory compaction.
    case summarizer
    /// Reranks retrieved Honeycomb nodes for the reasoner.
    case retrievalRanker
    /// Generates short titles/labels for captures and tabs.
    case titleGenerator
    /// Re-summarizes Honeycomb deltas into the lean "daily memory" surface.
    case memoryCompressor

    // --- researcher family (1B tier gatherer; 8B synthesizer in T3 below) ---
    /// Fetches + pre-scores candidate research sources (the §7.3 fetch/extract
    /// front half of research) before the synthesizer writes the brief.
    case researchGatherer

    // --- T2 on-demand workers (1.7B–4B, <500ms) ---
    /// Contradiction/staleness/provenance auditing. Security-critical → needs quality.
    case auditor
    /// Multi-step plan generation + Cell topology before execution.
    case planner

    // --- T3 rare escalations (4B–8B, <5s) ---
    /// Multi-step local reasoning too complex for the orchestrator.
    case deepReasoner
    /// Repo-aware code generation/edit. Bounded execution.
    case coder
    /// Multi-source cited research synthesis → brief. Grounded, provenance-bound.
    case researchSynthesizer

    // --- Supporting (separate from the LM ladder) ---
    /// Outputs embeddings for Honeycomb semantic index + retrieval.
    case embedder
    /// Not a model — BYOK user-supplied frontier models routed on opt-in.
    case byokFrontier
    /// Apple Foundation Models — narrow low-risk transforms only (macOS 26+).
    case appleFMF

    // MARK: classification
    public var tier: ModelTier {
        switch self {
        case .actionGuard:             return .rule
        case .intentClassifier, .spamDetector, .urgencyDetector, .linkScorer,
             .captureScribe, .pageQa:
            return .t0
        case .orchestrator, .librarian, .summarizer, .retrievalRanker,
             .titleGenerator, .memoryCompressor:
            return .t1
        case .auditor, .planner, .researchGatherer:
            return .t2
        case .deepReasoner, .coder, .researchSynthesizer:
            return .t3
        case .embedder:                 return .t0   // encoder, always resident
        case .byokFrontier:             return .byok
        case .appleFMF:                 return .fmf
        }
    }

    /// Whether this role must run on-device (local-first law) or may use remote.
    public var localOnly: Bool {
        switch self {
        case .byokFrontier:                     return false
        case .actionGuard, .orchestrator, .auditor, .planner:
            // Never offloaded — these define trust, routing, and plan safety.
            return true
        default:                                return true
        }
    }

    /// Memory budget this role is allowed to occupy resident (MB). From ai-architecture.
    public var residentMemoryBudgetMB: Int {
        switch tier {
        case .rule: return 0
        case .t0:   return 300     // tiny classifiers + embedder
        case .t1:   return 800
        case .t2:   return 0       // on-demand, evicted when idle
        case .t3:   return 0       // rare escalation, fully evicted
        case .byok: return 0       // remote, zero local footprint
        case .fmf:  return 0       // system-managed
        }
    }

    public var displayLabel: String {
        switch self {
        case .actionGuard:           return "Action Guard"
        case .intentClassifier:      return "Intent Classifier"
        case .spamDetector:           return "Spam Detector"
        case .urgencyDetector:       return "Urgency Detector"
        case .linkScorer:            return "Link Scorer"
        case .captureScribe:         return "Capture Scribe"
        case .pageQa:               return "Page Q&A"
        case .orchestrator:          return "Orchestrator"
        case .librarian:             return "Librarian"
        case .summarizer:            return "Summarizer"
        case .retrievalRanker:       return "Retrieval Ranker"
        case .titleGenerator:        return "Title Generator"
        case .memoryCompressor:      return "Memory Compressor"
        case .auditor:               return "Auditor"
        case .planner:               return "Planner"
        case .researchGatherer:      return "Research Gatherer"
        case .deepReasoner:          return "Deep Reasoner"
        case .coder:                 return "Coder"
        case .researchSynthesizer:   return "Research Synthesizer"
        case .embedder:              return "Embedder"
        case .byokFrontier:          return "BYOK Frontier"
        case .appleFMF:              return "Apple Foundation Models"
        }
    }
}

// MARK: - Manifest entry (one base model per role + how it's served)

public struct ManifestEntry: Sendable, Codable {
    /// The role this entry serves.
    public let role: ModelRole
    /// Hugging Face repo id of the MLX-quantized weights, e.g.
    /// "mlx-community/Qwen3-0.6B-Instruct-4bit". Downloaded on first use.
    /// NOTE: verify repo exists on HF before first download (web search was
    /// unavailable at manifest authoring time).
    public let hfRepo: String?
    /// Base model family the weights derive from.
    public let baseModel: String
    /// Approximate on-disk size when quantized (MB).
    public let quantizedSizeMB: Int
    /// Open-source license of the base weights.
    public let license: String
    /// How this role is served in v1.
    public let servingStrategy: ServingStrategy
    /// Optional trained LoRA adapter for this role — the directory key under
    /// the on-disk adapter store (e.g. "urgency_detector"). Resolved by
    /// `ModelStore.adapterDirectory(for:)` and merged onto the base at load
    /// time when present. Nil = serve the off-the-shelf instruct base.
    ///
    /// Only set for roles with a VERIFIED held-out punch-up verdict
    /// (PUNCH_UP / MATCH, or LOSES-with-real-gain-over-base). Roles without a
    /// held-out eval stay nil → off-the-shelf base (honest default; never
    /// assert an adapter gain the eval never proved). See
    /// hive-train results/punch_up_*.json on Brev (gpu hive-gpu-1).
    public let loraAdapter: String?
    /// Max output tokens per call budget.
    public let maxOutputTokens: Int
    /// Latency target (ms) on the M1 Air 8GB floor.
    public let latencyTargetMS: Int

    /// Explicit memberwise init so `loraAdapter` can carry a `nil` default
    /// (a `let` with a property-level default is dropped from the synthesized
    /// init, which would reject call sites that pass it). All call sites use
    /// named args, so the 16 un-flipped roles simply omit `loraAdapter`.
    public init(role: ModelRole,
                hfRepo: String?,
                baseModel: String,
                quantizedSizeMB: Int,
                license: String,
                servingStrategy: ServingStrategy,
                loraAdapter: String? = nil,
                maxOutputTokens: Int,
                latencyTargetMS: Int) {
        self.role = role
        self.hfRepo = hfRepo
        self.baseModel = baseModel
        self.quantizedSizeMB = quantizedSizeMB
        self.license = license
        self.servingStrategy = servingStrategy
        self.loraAdapter = loraAdapter
        self.maxOutputTokens = maxOutputTokens
        self.latencyTargetMS = latencyTargetMS
    }

    public enum ServingStrategy: String, Sendable, Codable {
        /// Deterministic rules, no weights.
        case ruleBased
        /// Off-the-shelf instruct model, prompted + constrained JSON output.
        /// No fine-tune required for v1.
        case instructOffTheShelf
        /// Base instruct LoRA-fine-tuned on a Hive role dataset (post-v1 upgrade).
        case instructLoRA
        /// System embedding framework (NLEmbedding). Zero-dep, on-device.
        case systemEmbedder
        /// Apple Foundation Models, macOS 26+.
        case appleFMF
        /// User-supplied remote (BYOK). Never the default.
        case byokRemote
    }
}

// MARK: - The Manifest: role → entry

public enum ModelManifest {

    /// Canonical mapping. This is the answer to "what AIs does Swarm need."
    public static let entries: [ModelRole: ManifestEntry] = [
        .actionGuard: ManifestEntry(
            role: .actionGuard, hfRepo: nil, baseModel: "—", quantizedSizeMB: 0,
            license: "—", servingStrategy: .ruleBased, maxOutputTokens: 0,
            latencyTargetMS: 1),

        // T0/Tiny — share the Qwen2.5-0.5B-Instruct base (MLX 4-bit ≈ 300MB).
        // Base chosen to MATCH the trained LoRA adapters (CELL_TIER 100M →
        // Qwen/Qwen2.5-0.5B-Instruct), so the distillation fine-tunes load
        // onto these bases without a family mismatch (Qwen3↔Qwen2.5 LoRA
        // won't cross-load). The adapter path is now wired in MLXRuntime
        // (behind #if canImport(MLXLMCommon)); the THREE roles below with a
        // VERIFIED held-out punch-up verdict flip to .instructLoRA. The
        // adapter merge runs once the MLX SPM dependencies are uncommented in
        // Package.swift; until then both paths honestly fall back to the
        // off-the-shelf base (or Mock, honestly labelled). See
        // PITCH/ai-architecture.md and the verdicts below.
        //
        // Held-out verdicts (Brev /workspace/hive-train/results/punch_up_*.json,
        // disjoint held-out — anti-memoization):
        //   intent_router   base 0.53 → +LoRA 0.93  gen14 1.00  → LOSES-but-gain
        //                   (compact-ish + 6-way; LoRA adds the classification
        //                   the compact prompt lacks; ship local — beats base
        //                   by +0.40, near the 14B while free+private+fast)
        //   spam_detector   base 0.50 → +LoRA 1.00  gen14 1.00  → MATCH
        //                   (rule-rich × simple; LoRA adds reliable JSON +
        //                   fixes a base false-positive; 0.5B == 14B)
        //   urgency_detector base 0.33 → +LoRA 0.75 gen14 0.75  → MATCH
        //                   (compact × 3-way; the thesis working as MATCH)
        //   retrieval_ranker — kept .instructOffTheShelf: base 0.67, +LoRA
        //                   0.50 (LoRA HURTS — rule-rich × complex overfit).
        //   link_scorer — no held-out eval authored → .instructOffTheShelf
        //                   (honest default; flip only when eval proves gain).
        .intentClassifier: .init(role: .intentClassifier,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 300,
            license: "Apache-2.0", servingStrategy: .instructLoRA,
            loraAdapter: "intent_router",
            maxOutputTokens: 32, latencyTargetMS: 50),
        .spamDetector: .init(role: .spamDetector,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructLoRA,
            loraAdapter: "spam_detector",
            maxOutputTokens: 8, latencyTargetMS: 50),
        .urgencyDetector: .init(role: .urgencyDetector,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructLoRA,
            loraAdapter: "urgency_detector",
            maxOutputTokens: 8, latencyTargetMS: 50),
        .linkScorer: .init(role: .linkScorer,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 16, latencyTargetMS: 50),
        // T0 scribe family — capture_scribe (gap-7 Automatic-Capture moat) +
        // page_qa (gap-8 Arc/Comet "ask on this page" parity). Both ship
        // OFF-THE-SHELF, no loraAdapter (honest default — the
        // loraRolesHaveVerifiedHeldOutVerdict build gate forbids flipping
        // unverified roles; capture_scribe is rule-rich×complex → expected
        // NO_GAIN like retrievalRanker; page_qa is a held-out-distill
        // candidate that stays OTS until an eval proves gain). Share the
        // 0.5B base with the T0 classifier cohort. Prompt files:
        //   scribe/100m_capture_scribe.md, scribe/100m_page_qa.md
        // See PITCH/competitive-ai-gap-ledger.md (Directive B phase-6).
        .captureScribe: .init(role: .captureScribe,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 256, latencyTargetMS: 80),
        .pageQa: .init(role: .pageQa,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 128, latencyTargetMS: 30),

        // T1 — Orchestrator + Librarian share the resident 0.5B; CRU jobs
        // (summarize/rerank/title/compress) use the 1.5B on-demand. All bases
        // match the trained LoRA adapters (CELL_TIER 1B → Qwen/Qwen2.5-1.5B-
        // Instruct). orchestrator has NO trained adapter yet (missing
        // real_pairs) — runs off-the-shelf on the 1.5B until data exists.
        .orchestrator: .init(role: .orchestrator,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 900,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 64, latencyTargetMS: 80),
        .librarian: .init(role: .librarian,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 256, latencyTargetMS: 80),
        .summarizer: .init(role: .summarizer,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 512, latencyTargetMS: 200),
        .retrievalRanker: .init(role: .retrievalRanker,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 64, latencyTargetMS: 80),
        .titleGenerator: .init(role: .titleGenerator,
            hfRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            baseModel: "Qwen2.5-0.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 16, latencyTargetMS: 40),
        .memoryCompressor: .init(role: .memoryCompressor,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 256, latencyTargetMS: 200),

        // researcher family — the 1B-tier gatherer (fetch/extract/score front
        // half of §7.3 research) is an on-demand 1.5B worker like auditor/
        // planner; the 8B synthesizer writes the cited brief. Off-the-shelf:
        // no held-out gatherer verdict exists, so no loraAdapter. Prompt file:
        //   researcher/1b_research_gatherer.md
        .researchGatherer: .init(role: .researchGatherer,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 256, latencyTargetMS: 500),

        // T2 — on-demand workers, loaded when needed, evicted when idle.
        // Bases match trained LoRA adapters (CELL_TIER 1B → 1.5B).
        .auditor: .init(role: .auditor,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 900,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 512, latencyTargetMS: 500),
        .planner: .init(role: .planner,
            hfRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            baseModel: "Qwen2.5-1.5B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 768, latencyTargetMS: 500),

        // T3 — rare escalations. All three train on the 8B tier (CELL_TIER 8B →
        // Qwen/Qwen2.5-Coder-7B), so all three share the Coder-7B base — one
        // 4.3GB model loaded, adapter swapped per role. NOTE: using the coder
        // base for deep_reasoner/research_synthesizer is a training-config
        // artifact (the 8B tier routes through Coder-7B). If off-the-shelf
        // reasoning quality on non-code tasks suffers, a later retrain on
        // Qwen2.5-7B-Instruct would split the base. Adapters are the truth now.
        .deepReasoner: .init(role: .deepReasoner,
            hfRepo: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
            baseModel: "Qwen2.5-Coder-7B-Instruct", quantizedSizeMB: 4300,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 2048, latencyTargetMS: 4000),
        .researchSynthesizer: .init(role: .researchSynthesizer,
            hfRepo: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
            baseModel: "Qwen2.5-Coder-7B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 2048, latencyTargetMS: 4000),
        .coder: .init(role: .coder,
            hfRepo: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
            baseModel: "Qwen2.5-Coder-7B-Instruct", quantizedSizeMB: 0,
            license: "Apache-2.0", servingStrategy: .instructOffTheShelf,
            maxOutputTokens: 2048, latencyTargetMS: 4000),

        // Embeddings: system NLEmbedding baseline (zero-dep, on-device) for v1;
        // nomic-embed-text-v2 (MLX) is the documented upgrade path.
        .embedder: .init(role: .embedder,
            hfRepo: "mlx-community/nomic-embed-text-v2-Matryoshka-F16",
            baseModel: "nomic-embed-text-v2 (upgrade); NLEmbedding (v1)",
            quantizedSizeMB: 560,
            license: "MIT",
            servingStrategy: .systemEmbedder,
            maxOutputTokens: 0, latencyTargetMS: 10),

        .byokFrontier: .init(role: .byokFrontier, hfRepo: nil,
            baseModel: "user-supplied (NIM / DeepSeek / Kimi / Claude / GPT)",
            quantizedSizeMB: 0, license: "varies",
            servingStrategy: .byokRemote, maxOutputTokens: 8192,
            latencyTargetMS: 2000),

        .appleFMF: .init(role: .appleFMF, hfRepo: nil,
            baseModel: "Apple Foundation Models (~3B on-device, macOS 26+)",
            quantizedSizeMB: 0, license: "Apple",
            servingStrategy: .appleFMF, maxOutputTokens: 2048,
            latencyTargetMS: 300),
    ]

    /// Roles served by the same underlying weights share a load slot —
    /// the runtime keeps one loaded instance per distinct hfRepo.
    public static func sharedRepo(for role: ModelRole) -> [ModelRole] {
        guard let entry = entries[role], let repo = entry.hfRepo else { return [role] }
        return ModelRole.allCases.filter { entries[$0]?.hfRepo == repo }
    }

    /// Every distinct weight set that must live on disk. Ordered by load priority.
    public static var allWeightSets: [String] {
        Set(entries.values.compactMap { $0.hfRepo }).sorted()
    }
}
