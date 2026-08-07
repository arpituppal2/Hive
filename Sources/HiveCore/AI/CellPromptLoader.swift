import Foundation

// MARK: - Cell Prompt Loader

/// Bridges the Swarm Cell system-prompt library (`Swarm_System_Prompts/`) to
/// the HiveCore model runtime. Reads Cell `.md` files, extracts the role-
/// defining sections as system prompts, maps Cell file names to `ModelRole`
/// values, and produces `GenerateRequest` values with the Cell's distilled
/// rules injected as the system prompt.
///
/// Each Cell `.md` file contains ~12 template sections. The loader extracts:
///   - Job (one sentence) → the Cell's identity
///   - Non-goals → what this Cell must NOT do
///   - Outputs (strict schema) → the JSON schema the Cell must emit
///   - Determinism rules → temperature/output discipline
///   - Stop / done conditions → when the Cell declares completion
///   - Distilled rules → the operational rules from source prompts
///
/// Sections omitted from the system prompt (handled by runtime, not model):
///   - RAM / latency budget
///   - Council escalation
///   - Frontier gap checklist
///   - Eval hooks
public struct CellPromptLoader: Sendable {

    /// Root directory containing `Swarm_System_Prompts/`.
    public let promptsDir: URL

    public init(promptsDir: URL) {
        self.promptsDir = promptsDir
    }

    // MARK: - Cell → ModelRole mapping

    /// Maps each Cell file to its `ModelRole`. This is the canonical bridge
    /// between the Swarm Cell taxonomy and the HiveCore model registry.
    ///
    /// Every ModelRole that has a corresponding `.md` prompt file in
    /// `Swarm_System_Prompts/` is listed here. Roles without prompt files
    /// (embedder, byokFrontier, appleFMF, retrievalRanker, titleGenerator,
    /// memoryCompressor) use bare model calls or system frameworks.
    ///
    /// Multi-tier roles (planner, coder, auditor, librarian) map to their
    /// primary tier variant; the dispatch layer routes up-tier when needed.
    public static let cellRoleMapping: [ModelRole: (subdir: String, fileName: String)] = [
        // T0 rule — deterministic guard, no model
        .actionGuard:          ("guard",        "rule_action_guard"),

        // T0 tiny classifiers — all share the 0.6B Qwen base
        .intentClassifier:     ("router",       "100m_intent_router"),
        .spamDetector:         ("router",       "100m_spam_detector"),
        .urgencyDetector:      ("router",       "100m_urgency_detector"),
        .linkScorer:           ("router",       "1b_link_scorer"),

        // T0 scribe family — capture→Honeycomb triage + grounded page Q&A
        .captureScribe:        ("scribe",       "100m_capture_scribe"),
        .pageQa:              ("scribe",       "100m_page_qa"),

        // T1 always/frequently resident
        .orchestrator:         ("orchestrator", "1b_orchestrator"),
        .librarian:            ("librarian",    "100m_librarian"),
        .summarizer:           ("summarizer",   "1b_compressor"),
        .retrievalRanker:      ("router",       "100m_retrieval_ranker"),
        .titleGenerator:       ("summarizer",   "100m_title_generator"),
        .memoryCompressor:     ("summarizer",   "1b_memory_compressor"),

        // T2 on-demand workers
        .auditor:              ("auditor",      "1b_auditor"),
        .planner:              ("planner",      "1b_planner"),

        // T3 rare escalations
        .deepReasoner:         ("reasoner",     "8b_deep_reasoner"),
        .coder:                ("coder",        "1b_coder"),
        .researchGatherer:     ("researcher",   "1b_research_gatherer"),
        .researchSynthesizer:  ("researcher",   "8b_research_synthesizer"),
    ]

    /// Returns the `(subdir, fileName)` tuple for a role, or nil if unmapped.
    public static func cellFile(for role: ModelRole) -> (subdir: String, fileName: String)? {
        cellRoleMapping[role]
    }

    // MARK: - Tier-specific overrides

    /// For multi-tier roles, returns the higher-tier prompt file if available.
    /// The orchestrator calls this when dispatching to 8B tier cells.
    public static func upTierFile(for role: ModelRole) -> (subdir: String, fileName: String)? {
        switch role {
        case .coder:                return ("coder",        "8b_coder")
        case .auditor:              return ("auditor",      "8b_auditor")
        case .planner:              return ("planner",      "8b_planner")
        case .librarian:            return ("librarian",    "1b_librarian")
        // researchSynthesizer: standard mapping already uses the 8B variant
        // No distinct higher tier exists.
        default:                    return nil
        }
    }

    // MARK: - Prompt loading

    /// Loads the system prompt for a Cell by reading its `.md` file and
    /// extracting the role-defining sections. Returns nil if the file doesn't
    /// exist or can't be read.
    ///
    /// - Parameter upTier: if true, looks for the higher-tier variant first.
    ///   Falls back to standard mapping if no up-tier file exists.
    public func loadSystemPrompt(for role: ModelRole, upTier: Bool = false) -> String? {
        let tuple: (subdir: String, fileName: String)?
        if upTier, let up = Self.upTierFile(for: role) {
            tuple = up
        } else {
            tuple = Self.cellFile(for: role)
        }
        guard let (subdir, fileName) = tuple else { return nil }
        let path = promptsDir
            .appendingPathComponent(subdir, isDirectory: true)
            .appendingPathComponent("\(fileName).md")
        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return nil
        }
        return extractPrompt(from: content, role: role)
    }

    /// Builds a `GenerateRequest` with the Cell's system prompt injected.
    /// If the prompt file isn't available, falls back to an empty system
    /// prompt — the model still receives the role + user input.
    public func buildRequest(
        for role: ModelRole,
        userInput: String,
        jsonSchema: JSONValue? = nil,
        upTier: Bool = false
    ) -> GenerateRequest {
        let system = loadSystemPrompt(for: role, upTier: upTier) ?? ""
        return GenerateRequest(role: role, system: system, user: userInput,
                               jsonSchema: jsonSchema)
    }

    /// Returns the canonical filename for a Cell role. Used by diagnostics.
    public static func displayFilename(for role: ModelRole) -> String {
        if let (subdir, file) = cellFile(for: role) {
            return "\(subdir)/\(file).md"
        }
        return role.displayLabel
    }

    // MARK: - Section extraction

    /// Extracts the role-defining sections from the Cell's markdown content.
    private func extractPrompt(from markdown: String, role: ModelRole) -> String {
        var parts: [String] = []

        // Header — identity
        parts.append("You are a specialist \(role.displayLabel) Cell in the Hive Swarm runtime.")

        // Job
        if let section = extractSection(named: "Job (one sentence)", from: markdown) {
            parts.append("## Job\n\(section)")
        }

        // Non-goals
        if let section = extractSection(named: "Non-goals (explicit)", from: markdown) {
            parts.append("## Non-Goals\n\(section)")
        }

        // Outputs schema — critical: the model must emit this exact shape
        if let section = extractSection(named: "Outputs (strict schema)", from: markdown) {
            parts.append("## Output Schema — YOU MUST EMIT EXACTLY THIS JSON SHAPE\n\(section)")
        }

        // Determinism rules
        if let section = extractSection(named: "Determinism rules", from: markdown) {
            parts.append("## Determinism\n\(section)")
        }

        // Stop / done conditions
        if let section = extractSection(named: "Stop / done conditions", from: markdown) {
            parts.append("## Stop Conditions\n\(section)")
        }

        // Distilled rules — the operational contract
        if let section = extractSection(named: "Distilled rules (from source prompts)", from: markdown) {
            parts.append("## Operational Rules\n\(section)")
        }

        return parts.joined(separator: "\n\n")
    }

    /// Extracts the content between `## <name>` and the next `## ` section
    /// header (or end of file). Returns the section body with leading/trailing
    /// whitespace trimmed.
    private func extractSection(named header: String, from markdown: String) -> String? {
        let searchPrefix = "## \(header)"
        guard let headerRange = markdown.range(of: searchPrefix) else {
            // Try with the short form (some Cells use "## Job" not "## Job (one sentence)")
            let shortHeader = String(header.prefix(while: { $0 != "(" }).trimmingCharacters(in: .whitespaces))
            guard shortHeader != header,
                  let shortRange = markdown.range(of: "## \(shortHeader)") else {
                return nil
            }
            return extractBody(after: shortRange.upperBound, in: markdown)
        }
        return extractBody(after: headerRange.upperBound, in: markdown)
    }

    private func extractBody(after startIndex: String.Index, in markdown: String) -> String? {
        let rest = markdown[startIndex...]

        // Find the next section boundary: "## " or "---"
        let endIndex: String.Index = rest.range(of: "\n## ")?.lowerBound
            ?? rest.range(of: "\n---")?.lowerBound
            ?? rest.endIndex

        let body = rest[..<endIndex]
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip the first line if it's blank (the newline after the ## header)
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        let startLine = lines.first?.trimmingCharacters(in: .whitespaces).isEmpty ?? true ? 1 : 0
        let contentLines = lines.dropFirst(startLine)

        let result = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

// MARK: - Dispatcher integration

extension Dispatcher {

    /// Generates a response using a Cell's system prompt loaded from disk.
    /// Falls back to bare role-based generation if the prompt file is missing
    /// or no loader is provided.
    ///
    /// - Parameter upTier: if true, loads the higher-tier prompt variant
    ///   (e.g., 8b_coder instead of 1b_coder) when available.
    public func generateWithCellPrompt(
        for role: ModelRole,
        userInput: String,
        jsonSchema: JSONValue? = nil,
        loader: CellPromptLoader? = nil,
        upTier: Bool = false
    ) async throws -> GenerateResult {
        let system = loader?.loadSystemPrompt(for: role, upTier: upTier) ?? ""
        let request = GenerateRequest(role: role, system: system,
                                      user: userInput, jsonSchema: jsonSchema)
        return try await generate(request)
    }

    /// Streams token deltas using a Cell's system prompt loaded from disk.
    /// Falls back to streaming the mock response as a single chunk when no
    /// real model is available.
    ///
    /// - Parameter upTier: if true, loads the higher-tier prompt variant when available.
    public func streamGenerateWithCellPrompt(
        for role: ModelRole,
        userInput: String,
        jsonSchema: JSONValue? = nil,
        loader: CellPromptLoader? = nil,
        upTier: Bool = false
    ) async -> AsyncThrowingStream<String, Error> {
        let system = loader?.loadSystemPrompt(for: role, upTier: upTier) ?? ""
        let request = GenerateRequest(role: role, system: system,
                                      user: userInput, jsonSchema: jsonSchema)
        return await streamGenerate(request)
    }
}
