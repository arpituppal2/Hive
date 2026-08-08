import Foundation

// MARK: - IntentOrchestrator
//
// T0 deterministic intent classifier that routes user input to the correct
// Swarm Cell before any model sees it. This is the "Jarvis brain" — it
// understands whether the user is asking a question, requesting research,
// giving a command, or needing clarification.
//
// Architecture:
//   1. Rule-based pattern matching (keywords, URLs, commands) — instant, free
//   2. Falls back to the intentClassifier Cell (T0, ~100M, always resident)
//      when rules don't match with high confidence
//   3. The orchestrator Cell (T1) receives the classified intent and dispatches
//      to the correct downstream Cell
//
// This is NOT a model. It's a deterministic parser that gates model access —
// the same principle as actionGuard: rules before weights.

// MARK: - Intent Category

/// What kind of request the user is making. Drives Cell routing.
public enum IntentCategory: String, Sendable, Codable, CaseIterable {
    /// A general knowledge question answerable from the model's training data
    /// or the provided context. Routes to the librarian Cell.
    case genericQuestion

    /// "Search the web for X" or "Research Y topic." Routes to webResearch
    /// via the configured WebSearchProvider.
    case webResearch

    /// "What does this page say about X?" — grounded Q&A on the active tab.
    /// Routes to the pageQa Cell.
    case pageQuestion

    /// "Open github.com" or any URL-shaped input. Browser navigation action.
    case browserAction

    /// "Find the document about X in my archive." Routes to Honeycomb search.
    case memorySearch

    /// "Save this as a brief" / "Create a project called X." CRUD on the
    /// knowledge graph. Routes to brief/project actions.
    case knowledgeAction

    /// "Fix the bug in auth.swift" / "Write a function that..." — code
    /// generation or editing. Routes to the coder Cell (Studio mode).
    case codeAction

    /// "Close this tab" / "Open settings" / "Switch to space 2." Browser
    /// chrome commands that don't need a model at all.
    case systemCommand

    /// Ambiguous or incomplete input. The orchestrator asks a clarifying
    /// question instead of guessing.
    case clarification

    /// Speech-to-text input that may need disambiguation before routing.
    /// Treated as a passthrough — the voice pipeline handles classification.
    case voiceInput
}

// MARK: - Classified Intent

/// The output of the intent classifier: what the user wants, how confident
/// we are, any extracted parameters, and which Cell should handle it.
public struct ClassifiedIntent: Sendable, Equatable {

    public let category: IntentCategory
    /// 0.0–1.0 confidence. Rules that matched exactly get 1.0; keyword
    /// heuristics get 0.6–0.8; fallback gets 0.3.
    public let confidence: Double
    /// The original user input, preserved for downstream Cells.
    public let rawInput: String
    /// Extracted parameters (URLs, search queries, file paths, etc.).
    public let params: IntentParams
    /// Which ModelRole Cell should handle this intent. nil means no model
    /// is needed (the intent is handled by a rule-based action).
    public let suggestedCell: ModelRole?

    public init(
        category: IntentCategory,
        confidence: Double,
        rawInput: String,
        params: IntentParams = IntentParams(),
        suggestedCell: ModelRole? = nil
    ) {
        self.category = category
        self.confidence = confidence
        self.rawInput = rawInput
        self.params = params
        self.suggestedCell = suggestedCell
    }

    /// True when the orchestrator should ask a clarifying question rather
    /// than dispatch immediately.
    public var needsClarification: Bool {
        category == .clarification || confidence < 0.5
    }
}

// MARK: - Intent Params

/// Structured parameters extracted during classification. Every field is
/// optional — only the ones the classifier could extract are populated.
public struct IntentParams: Sendable, Equatable {
    /// A URL the user wants to navigate to (extracted from input).
    public var targetURL: URL?
    /// A search query extracted from the input.
    public var searchQuery: String?
    /// A file path or project root for code actions.
    public var filePath: String?
    /// A Honeycomb node ID referenced in the input.
    public var nodeID: String?
    /// A space/project name for workspace actions.
    public var spaceName: String?
    /// The command verb for system commands (e.g. "close", "open", "switch").
    public var commandVerb: String?
    /// Any sub-command or argument string.
    public var commandArg: String?

    public init(
        targetURL: URL? = nil,
        searchQuery: String? = nil,
        filePath: String? = nil,
        nodeID: String? = nil,
        spaceName: String? = nil,
        commandVerb: String? = nil,
        commandArg: String? = nil
    ) {
        self.targetURL = targetURL
        self.searchQuery = searchQuery
        self.filePath = filePath
        self.nodeID = nodeID
        self.spaceName = spaceName
        self.commandVerb = commandVerb
        self.commandArg = commandArg
    }
}

// MARK: - Intent Orchestrator

/// Deterministic intent classifier. Pure function — no state, no model, no
/// async. Runs in <1ms on the calling thread. Designed to be called before
/// any model dispatch in SwarmChatView.sendMessage().
public enum IntentOrchestrator {

    // MARK: - Classification

    /// Classifies user input into an intent category with confidence and
    /// extracted parameters. Pure function — safe to call from any context.
    /// - Parameter isWebScope: True when the user has explicitly selected web search scope.
    public static func classify(_ input: String, isWebScope: Bool = false) -> ClassifiedIntent {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ClassifiedIntent(
                category: .clarification,
                confidence: 1.0,
                rawInput: input,
                suggestedCell: nil
            )
        }

        // Phase 1: Exact pattern matches (confidence 1.0)

        // @this / @page — ask-on-page
        if let question = askOnPageQuestion(trimmed) {
            return ClassifiedIntent(
                category: .pageQuestion,
                confidence: 1.0,
                rawInput: question,
                params: IntentParams(searchQuery: question),
                suggestedCell: .pageQa
            )
        }

        // URL — browser navigation
        if let url = extractURL(trimmed) {
            return ClassifiedIntent(
                category: .browserAction,
                confidence: 1.0,
                rawInput: trimmed,
                params: IntentParams(targetURL: url),
                suggestedCell: nil  // no model needed for navigation
            )
        }

        // Phase 2: Keyword/command heuristics (confidence 0.7–0.9)

        // System commands
        if let command = classifySystemCommand(trimmed) {
            return command
        }

        // Web research patterns
        if let research = classifyWebResearch(trimmed) {
            return research
        }

        // Memory search patterns
        if let memory = classifyMemorySearch(trimmed) {
            return memory
        }

        // Knowledge actions (briefs, projects)
        if let knowledge = classifyKnowledgeAction(trimmed) {
            return knowledge
        }

        // Code action patterns
        if let code = classifyCodeAction(trimmed) {
            return code
        }

        // Phase 3: Scope-based routing

        // If the user explicitly selected web scope, treat as research
        if isWebScope {
            return ClassifiedIntent(
                category: .webResearch,
                confidence: 0.9,
                rawInput: trimmed,
                params: IntentParams(searchQuery: trimmed),
                suggestedCell: .librarian
            )
        }

        // Phase 4: Fallback — generic question to the librarian
        return ClassifiedIntent(
            category: .genericQuestion,
            confidence: 0.6,
            rawInput: trimmed,
            suggestedCell: .librarian
        )
    }

    // MARK: - Pattern Detectors

    /// Detects `@this <question>` or `@page <question>` pattern.
    private static func askOnPageQuestion(_ text: String) -> String? {
        let lower = text.lowercased()
        for prefix in ["@this ", "@page "] where lower.hasPrefix(prefix) {
            let rest = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty { return rest }
        }
        return nil
    }

    /// Extracts a valid http/https URL from the input. Matches bare URLs AND
    /// natural-language prefixes: "open X", "go to X", "navigate to X".
    private static func extractURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // Bare URL: http(s)://...
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https",
           url.host?.contains(".") == true {
            return url
        }

        // Natural-language prefixes: "open X", "go to X", "navigate to X"
        let lower = trimmed.lowercased()
        let prefixes = ["open ", "go to ", "navigate to ", "visit "]
        for prefix in prefixes where lower.hasPrefix(prefix) {
            let raw = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            // Try as-is URL first, then with https:// prepended
            if let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
               (scheme == "http" || scheme == "https"), url.host?.contains(".") == true {
                return url
            }
            let candidate = raw.contains(".") && !raw.contains(" ") ? "https://\(raw)" : raw
            if let url = URL(string: candidate),
               let scheme = url.scheme?.lowercased(),
               scheme == "https",
               url.host?.contains(".") == true {
                return url
            }
        }
        return nil
    }

    /// Detects system commands: close tab, open settings, switch space, new tab.
    private static func classifySystemCommand(_ text: String) -> ClassifiedIntent? {
        let lower = text.lowercased()

        // Tab commands
        if lower == "close tab" || lower == "close this tab" {
            return ClassifiedIntent(
                category: .systemCommand, confidence: 1.0, rawInput: text,
                params: IntentParams(commandVerb: "close", commandArg: "tab"),
                suggestedCell: nil
            )
        }
        if lower.hasPrefix("new tab") {
            let arg = text.dropFirst(7).trimmingCharacters(in: .whitespaces)
            return ClassifiedIntent(
                category: .systemCommand, confidence: 1.0, rawInput: text,
                params: IntentParams(commandVerb: "new", commandArg: arg.isEmpty ? "tab" : arg),
                suggestedCell: nil
            )
        }
        if lower.hasPrefix("switch to") || lower.hasPrefix("go to space") {
            let spaceName = text.replacingOccurrences(of: "switch to ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "go to space ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            return ClassifiedIntent(
                category: .systemCommand, confidence: 0.8, rawInput: text,
                params: IntentParams(spaceName: spaceName, commandVerb: "switch"),
                suggestedCell: nil
            )
        }

        // Settings
        if lower == "open settings" || lower == "settings" || lower == "preferences" {
            return ClassifiedIntent(
                category: .systemCommand, confidence: 1.0, rawInput: text,
                params: IntentParams(commandVerb: "open", commandArg: "settings"),
                suggestedCell: nil
            )
        }

        return nil
    }

    /// Detects web research patterns: "search for X", "research X", "find me X",
    /// "look up X", "what is the latest...", "/search X".
    private static func classifyWebResearch(_ text: String) -> ClassifiedIntent? {
        let lower = text.lowercased()

        // Explicit /search command
        if lower.hasPrefix("/search ") {
            let query = text.dropFirst(8).trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return nil }
            return ClassifiedIntent(
                category: .webResearch, confidence: 1.0, rawInput: query,
                params: IntentParams(searchQuery: query),
                suggestedCell: .librarian  // webSearchProvider handles
            )
        }

        // Research keywords
        let researchPrefixes = [
            "search for ", "search the web for ", "research ", "look up ",
            "find me ", "find information about ", "what is the latest ",
            "what's the latest ", "news about ", "trending "
        ]
        for prefix in researchPrefixes where lower.hasPrefix(prefix) {
            let query = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { continue }
            return ClassifiedIntent(
                category: .webResearch, confidence: 0.8, rawInput: query,
                params: IntentParams(searchQuery: query),
                suggestedCell: .librarian
            )
        }

        // "compare X and Y" — could be research or workspace
        if lower.hasPrefix("compare ") {
            let query = text.trimmingCharacters(in: .whitespaces)
            return ClassifiedIntent(
                category: .webResearch, confidence: 0.7, rawInput: query,
                params: IntentParams(searchQuery: query),
                suggestedCell: .librarian
            )
        }

        return nil
    }

    /// Detects memory/archive search: "find in my archive", "what do I have about",
    /// "remember", "search memory", "/find".
    private static func classifyMemorySearch(_ text: String) -> ClassifiedIntent? {
        let lower = text.lowercased()

        if lower.hasPrefix("/find ") {
            let query = text.dropFirst(6).trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return nil }
            return ClassifiedIntent(
                category: .memorySearch, confidence: 1.0, rawInput: query,
                params: IntentParams(searchQuery: query),
                suggestedCell: .retrievalRanker
            )
        }

        let memoryPrefixes = [
            "search memory for ", "find in my archive ", "find in archive ",
            "what do i have about ", "what do we have about ",
            "search my notes for ", "recall ", "remember "
        ]
        for prefix in memoryPrefixes where lower.hasPrefix(prefix) {
            let query = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { continue }
            return ClassifiedIntent(
                category: .memorySearch, confidence: 0.8, rawInput: query,
                params: IntentParams(searchQuery: query),
                suggestedCell: .retrievalRanker
            )
        }

        return nil
    }

    /// Detects knowledge actions: "save as brief", "create brief", "create project",
    /// "save this", "make a note".
    private static func classifyKnowledgeAction(_ text: String) -> ClassifiedIntent? {
        let lower = text.lowercased()

        // "summarize this page" — page question, not a knowledge action
        if lower.hasPrefix("summarize this page") || lower == "summarize" {
            return ClassifiedIntent(
                category: .pageQuestion, confidence: 0.8, rawInput: "Summarize this page",
                params: IntentParams(searchQuery: "Summarize this page"),
                suggestedCell: .pageQa
            )
        }

        // "explain this page" / "what does this page say" — page question
        if lower.hasPrefix("explain this page") || lower.hasPrefix("what does this page say") {
            let question = text.trimmingCharacters(in: .whitespaces)
            return ClassifiedIntent(
                category: .pageQuestion, confidence: 0.8, rawInput: question,
                params: IntentParams(searchQuery: question),
                suggestedCell: .pageQa
            )
        }

        // Brief actions
        if lower.hasPrefix("save as brief ") || lower.hasPrefix("create brief ") {
            return ClassifiedIntent(
                category: .knowledgeAction, confidence: 0.9, rawInput: text,
                params: IntentParams(commandVerb: "brief", commandArg: text),
                suggestedCell: nil  // handled by ChromeState.saveAsBrief
            )
        }

        // Project actions
        if lower.hasPrefix("create project ") || lower.hasPrefix("new project ") {
            let name = text.replacingOccurrences(of: "create project ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "new project ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            return ClassifiedIntent(
                category: .knowledgeAction, confidence: 0.9, rawInput: text,
                params: IntentParams(commandVerb: "project", commandArg: name),
                suggestedCell: nil
            )
        }

        // Summarize page → brief (moved to its own section above)
        return nil
    }

    /// Detects code action patterns: "fix X in Y", "write a function",
    /// "implement X", "/code X", file paths like "auth.swift".
    private static func classifyCodeAction(_ text: String) -> ClassifiedIntent? {
        let lower = text.lowercased()

        // /code command
        if lower.hasPrefix("/code ") {
            let query = text.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return ClassifiedIntent(
                category: .codeAction, confidence: 1.0, rawInput: query,
                params: IntentParams(searchQuery: query),
                suggestedCell: .librarian  // coder role routes through Studio
            )
        }

        // File path heuristics — ends with common code extensions
        let codeExtensions = [".swift", ".ts", ".js", ".py", ".rs", ".go", ".java", ".kt", ".c", ".cpp", ".h", ".m", ".mm"]
        let words = text.split(separator: " ")
        for word in words {
            let w = String(word)
            for ext in codeExtensions where w.hasSuffix(ext) {
                return ClassifiedIntent(
                    category: .codeAction, confidence: 0.7, rawInput: text,
                    params: IntentParams(filePath: w),
                    suggestedCell: .librarian
                )
            }
        }

        // Code action verbs
        let codeVerbs = ["fix ", "implement ", "refactor ", "write a function ",
                         "write a class ", "debug ", "optimize ", "add a test for ",
                         "rewrite "]
        for verb in codeVerbs where lower.hasPrefix(verb) {
            return ClassifiedIntent(
                category: .codeAction, confidence: 0.6, rawInput: text,
                suggestedCell: .librarian
            )
        }

        return nil
    }

    // MARK: - Clarification Generator

    /// When the orchestrator can't classify with confidence, it generates a
    /// clarifying question. This is the "ask, don't assume" behavior.
    public static func clarifyingQuestion(for intent: ClassifiedIntent) -> String {
        "I'm not sure what you'd like me to do with: \"\(intent.rawInput)\". " +
        "Could you clarify? For example:\n" +
        "• Ask a question about this page: @this [your question]\n" +
        "• Search the web: /search [query]\n" +
        "• Find in your archive: /find [query]\n" +
        "• Open a URL: just paste it\n" +
        "• Create a project: create project [name]"
    }

}
