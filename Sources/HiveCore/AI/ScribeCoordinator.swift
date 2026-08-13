import Foundation

// MARK: - ScribeCoordinator
//
// The invocation layer for the two T0 scribe Cells (`captureScribe`, `pageQa`) — the
// differentiating "Automatic Capture" moat (PITCH/competitive-ai-gap-ledger gap 7) and
// the Arc/Comet "ask on this page" parity (gap 8).
//
// `captureScribe` + `pageQa` were registry-complete (enum + manifest + loader + mock)
// but had NO invoker — no route emitted a request for either role. This coordinator is
// that missing route. See PITCH/backend-completion.md Track A.
//
// Design (mirrors the scribe prompts' own contract):
//   - PURE — invokes the Cells via `Dispatcher.shared`, parses their strict-JSON output
//     into typed Sendable structs, and RETURNS them. It does NOT touch Honeycomb. The
//     scribe prompts mandate "emit write-ops, don't directly mutate Honeycomb"; the
//     caller (ChromeState, which owns the honeycomb handle) applies the writes under the
//     permission ladder. This keeps a 100M-tier Cell from ever holding a write handle
//     and keeps the coordinator unit-testable without a DB.
//   - HONEST degradation: with MLX not linked, `Dispatcher` falls back to `MockRuntime`,
//     whose scribe bodies are schema-shaped JSON labelled `mock`. The parser accepts those
//     (the verdict is `skip`/`page_does_not_say`), so the path is complete and correct
//     for non-private content; private content is denied before model invocation.
//     with OR without local inference — never silent, never fabricated.
//   - Injection-mirror: page content is an injection vector (the capture_scribe prompt
//     non-goal). The coordinator never treats page claims as authoritative beyond passing
//     them to the Cell for triage; `PageQaAnswer.answerType == .pageDoesNotSay` is the
//     honest answer when the page doesn't contain the answer — never a training guess.
//
// Output parsing is deliberately TOLERANT: it accepts BOTH the prompts' strict schema
// (e.g. `skip_reason`, `extracted.facts`) AND the MockRuntime's flatter shape (`reason`,
// top-level `facts`). A real model should emit the strict schema; the tolerance is so
// the mock fallback and slightly-off real outputs parse rather than throwing.

public enum ScribeCoordinator {

    // MARK: - Capture triage (captureScribe)

    /// The triaged verdict for one captured browse artifact. The caller writes the
    /// `keep`d facts/decisions/commitments as Honeycomb `claim`/`decision`/`task`
    /// nodes (linked to the already-stored Source+Capture) and records a `skip` in
    /// the EventLedger audit (no node) — exactly the write-ops the Cell "emits".
    public struct CaptureVerdict: Sendable, Equatable {
        public let verdict: Outcome
        public let keepConfidence: Double
        public let skipReason: SkipReason?
        public let deduplication: Deduplication
        public let extracted: Extracted
        /// Which provider answered — honest labeling (mock vs mlx vs byok). The caller
        /// stamps this on the EventLedger entry so "this triage was a mock" is auditable.
        public let providerLabel: String

        public enum Outcome: String, Sendable, Codable, Equatable { case keep, skip }
        public enum SkipReason: String, Sendable, Codable, Equatable {
            case transient, duplicate, injectionFlagged, lowSignal, captureNotOptedIn,
                 privateBrowsing, aiContextDisabled, parseError, unknown
        }
        public struct Deduplication: Sendable, Equatable {
            public let isDuplicate: Bool
            public let supersedes: [String]   // existing nodes this artifact is a newer/better version of
            public let duplicatesOf: [String] // existing nodes that already cover this (→ skip)
        }
        public struct Extracted: Sendable, Equatable {
            public struct Fact: Sendable, Equatable { public let claim: String; public let sourceSpan: String?; public let confidence: Double }
            public struct Decision: Sendable, Equatable { public let decision: String; public let decidedBy: String; public let sourceSpan: String?; public let confidence: Double }
            public struct Commitment: Sendable, Equatable { public let commitment: String; public let sourceSpan: String?; public let confidence: Double }
            public let facts: [Fact]
            public let decisions: [Decision]
            public let commitments: [Commitment]
        }
    }

    /// Run the capture-scribe triage over a captured page.
    /// - Parameters:
    ///   - pageContext: the live page text (from `ChromeState.extractPageContext`).
    ///   - loader: the Cell-prompt loader (loads the `scribe/100m_capture_scribe` system prompt).
    ///   - boundedDedupContext: the last N (≤20) Honeycomb facts/decisions for this URL/entity,
    ///     serialized as the `dedup_context` input the prompt expects. Empty when unavailable.
    public static func autoCaptureTriage(
        pageContext: PageContext,
        loader: CellPromptLoader?,
        boundedDedupContext: String = ""
    ) async -> CaptureVerdict {
        // Defense in depth: callers outside ChromeState must not be able to send private
        // page provenance to a model. The browser ingress rejects it first, but this pure
        // coordinator boundary is the last line before model invocation.
        guard PageCaptureAdmission.evaluate(isPrivate: pageContext.isPrivateBrowsing).isAllowed else {
            return CaptureVerdict(
                verdict: .skip,
                keepConfidence: 0,
                skipReason: .privateBrowsing,
                deduplication: .empty,
                extracted: .empty,
                providerLabel: "policy-denied"
            )
        }
        guard pageContext.aiContextAllowed else {
            return CaptureVerdict(
                verdict: .skip,
                keepConfidence: 0,
                skipReason: .aiContextDisabled,
                deduplication: .empty,
                extracted: .empty,
                providerLabel: "policy-denied"
            )
        }
        // The artifact the prompt expects as input. Captured text is bounded to the
        // 4KB excerpt the prompt specifies; PageContext.text is already a captured excerpt.
        let scopedText = BrowserContextPolicy.scopePage(pageContext)?.text ?? ""
        let artifact: [String: JSONValue] = [
            "url": .string(pageContext.url?.absoluteString ?? ""),
            "title": .string(pageContext.title),
            "captured_text": .string(String(scopedText.prefix(4096))),
            "source_type": .string("page"),
            "dedup_context": .string(boundedDedupContext)
        ]
        let userInput = ScribeCoordinator.encodeAsJSONString(artifact)

        let result = await invoke(.captureScribe, userInput: userInput, loader: loader)
        return parseCaptureVerdict(text: result.text, providerLabel: result.provider.rawValue)
    }

    // MARK: - Page Q&A (pageQa)

    /// A grounded answer to a user question about the current page. When the page
    /// doesn't contain the answer, `answerType == .pageDoesNotSay` — never a guess
    /// from training (the pageQa prompt's core honesty rule). Private content is a
    /// separate `.privateBrowsing` policy outcome, never conflated with page absence.
    public struct PageQaAnswer: Sendable, Equatable {
        public let answer: String
        public let answerType: AnswerType
        public let basis: [BasisSpan]
        public let pageClaimUnverified: Bool
        public let confidence: Double
        public let providerLabel: String   // honest labeling (mock vs mlx)

        public enum AnswerType: String, Sendable, Codable, Equatable {
            case found, pageDoesNotSay, pageClaimUnverified, privateBrowsing, aiContextDisabled, parseError
        }
        public struct BasisSpan: Sendable, Equatable { public let span: String; public let role: String }

        public init(answer: String, answerType: AnswerType, basis: [BasisSpan],
                    pageClaimUnverified: Bool, confidence: Double, providerLabel: String) {
            self.answer = answer; self.answerType = answerType; self.basis = basis
            self.pageClaimUnverified = pageClaimUnverified
            self.confidence = confidence; self.providerLabel = providerLabel
        }
    }

    /// Answer a question grounded in the current page's captured text.
    public static func askOnPage(
        question: String,
        pageContext: PageContext,
        loader: CellPromptLoader?
    ) async -> PageQaAnswer {
        // Private page content is denied before prompt construction or model invocation.
        // This remains enforced here even when a future caller bypasses ChromeState.
        guard PageCaptureAdmission.evaluate(isPrivate: pageContext.isPrivateBrowsing).isAllowed else {
            return PageQaAnswer(
                answer: "",
                answerType: .privateBrowsing,
                basis: [],
                pageClaimUnverified: false,
                confidence: 0,
                providerLabel: "policy-denied"
            )
        }
        guard pageContext.aiContextAllowed else {
            return PageQaAnswer(
                answer: "",
                answerType: .aiContextDisabled,
                basis: [],
                pageClaimUnverified: false,
                confidence: 0,
                providerLabel: "policy-denied"
            )
        }
        // pageQa prompt input: the user question + the current page's ≤8KB captured text.
        let scopedText = BrowserContextPolicy.scopePage(pageContext)?.text ?? ""
        let input: [String: JSONValue] = [
            "question": .string(question),
            "page": .object([
                "url": .string(pageContext.url?.absoluteString ?? ""),
                "title": .string(pageContext.title),
                "captured_text": .string(String(scopedText.prefix(8192)))
            ])
        ]
        let userInput = ScribeCoordinator.encodeAsJSONString(input)

        let result = await invoke(.pageQa, userInput: userInput, loader: loader)
        return parsePageQaAnswer(text: result.text, providerLabel: result.provider.rawValue)
    }

    // MARK: - Invocation

    private static func invoke(
        _ role: ModelRole,
        userInput: String,
        loader: CellPromptLoader?
    ) async -> GenerateResult {
        // The strict schema is enforced by the prompt itself; jsonSchema is a hint for
        // real runtimes. Mock returns schema-shaped JSON regardless. A parse failure
        // downstream surfaces as an honest `parseError` verdict/answer — never silent.
        do {
            return try await Dispatcher.shared.generateWithCellPrompt(
                for: role, userInput: userInput, loader: loader)
        } catch {
            // Dispatcher throws on roleUnsupported / weightsNotDownloaded. We surface
            // that honestly as a parse-error-shaped verdict so the caller still records
            // an auditable "triage did not run" entry rather than crashing the load.
            return GenerateResult(role: role, provider: .mock,
                                  text: "", latencyMS: 0, tokensGenerated: 0,
                                  modelLabel: "dispatcher-error")
        }
    }

    // MARK: - JSON helpers (JSONValue → String for the user input)

    private static func encodeAsJSONString(_ value: [String: JSONValue]) -> String {
        // JSONValue is Codable; encode via JSONEncoder. Fallback to a minimal hand-built
        // string if encoding ever fails (it won't for these flat inputs).
        if let data = try? JSONEncoder().encode(value),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    // MARK: - Tolerant parsing (strict schema OR mock's flatter shape)

    private static func parseCaptureVerdict(text: String, providerLabel: String) -> CaptureVerdict {
        guard let data = text.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CaptureVerdict(verdict: .skip, keepConfidence: 0,
                                 skipReason: .parseError, deduplication: .empty,
                                 extracted: .empty, providerLabel: providerLabel)
        }
        let outcome = (raw["verdict"] as? String).flatMap { CaptureVerdict.Outcome(rawValue: $0) } ?? .skip
        let keepConf = (raw["keep_confidence"] as? Double) ?? Double(raw["keep_confidence"] as? Int ?? 0)
        let skipReason = (raw["skip_reason"] as? String ?? raw["reason"] as? String)
            .flatMap { CaptureVerdict.SkipReason(rawValue: $0.replacingOccurrences(of: " ", with: "_").lowercased()) }
            ?? (outcome == .skip ? .unknown : nil)

        let dedup = (raw["dedup"] as? [String: Any]) ?? [:]
        let isDup = (dedup["is_duplicate"] as? Bool) ?? false
        let supersedes = (dedup["supersedes"] as? [String]) ?? []
        let duplicatesOf = (dedup["duplicates_of"] as? [String]) ?? []

        // Tolerance: facts/decisions/commitments may be top-level (mock) or nested under `extracted`.
        let extracted = (raw["extracted"] as? [String: Any]) ?? raw
        let facts = parseFacts(extracted["facts"] as? [[String: Any]])
        let decisions = parseDecisions(extracted["decisions"] as? [[String: Any]])
        let commitments = parseCommitments(extracted["commitments"] as? [[String: Any]])

        return CaptureVerdict(
            verdict: outcome, keepConfidence: keepConf, skipReason: skipReason,
            deduplication: .init(isDuplicate: isDup, supersedes: supersedes, duplicatesOf: duplicatesOf),
            extracted: .init(facts: facts, decisions: decisions, commitments: commitments),
            providerLabel: providerLabel)
    }

    private static func parsePageQaAnswer(text: String, providerLabel: String) -> PageQaAnswer {
        guard let data = text.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return PageQaAnswer(answer: "", answerType: .parseError, basis: [],
                                pageClaimUnverified: false, confidence: 0, providerLabel: providerLabel)
        }
        let answer = (raw["answer"] as? String) ?? ""
        let typeRaw = (raw["answer_type"] as? String) ?? "page_does_not_say"
        let answerType: PageQaAnswer.AnswerType = {
            switch typeRaw.lowercased() {
            case "found": return .found
            case "page_does_not_say": return .pageDoesNotSay
            case "page_claim_unverified": return .pageClaimUnverified
            default: return .pageDoesNotSay
            }
        }()
        let basis = (raw["basis"] as? [[String: Any]])?.compactMap { d -> PageQaAnswer.BasisSpan? in
            guard let span = d["span"] as? String else { return nil }
            return .init(span: span, role: (d["role"] as? String) ?? "")
        } ?? []
        let unverified = (raw["page_claim_unverified"] as? Bool) ?? false
        let conf = (raw["confidence"] as? Double) ?? Double(raw["confidence"] as? Int ?? 0)
        return PageQaAnswer(answer: answer, answerType: answerType, basis: basis,
                            pageClaimUnverified: unverified, confidence: conf, providerLabel: providerLabel)
    }

    private static func parseFacts(_ raw: [[String: Any]]?) -> [CaptureVerdict.Extracted.Fact] {
        (raw ?? []).compactMap { d in
            guard let claim = d["claim"] as? String else { return nil }
            return .init(claim: claim, sourceSpan: d["source_span"] as? String,
                         confidence: (d["confidence"] as? Double) ?? 0)
        }
    }
    private static func parseDecisions(_ raw: [[String: Any]]?) -> [CaptureVerdict.Extracted.Decision] {
        (raw ?? []).compactMap { d in
            guard let decision = d["decision"] as? String else { return nil }
            return .init(decision: decision, decidedBy: (d["decided_by"] as? String) ?? "unknown",
                         sourceSpan: d["source_span"] as? String,
                         confidence: (d["confidence"] as? Double) ?? 0)
        }
    }
    private static func parseCommitments(_ raw: [[String: Any]]?) -> [CaptureVerdict.Extracted.Commitment] {
        (raw ?? []).compactMap { d in
            guard let commitment = (d["commitment"] as? String) else { return nil }
            return .init(commitment: commitment, sourceSpan: d["source_span"] as? String,
                         confidence: (d["confidence"] as? Double) ?? 0)
        }
    }
}

// MARK: - Empty defaults for verdicts (parse-error / dispatcher-error)

private extension ScribeCoordinator.CaptureVerdict.Deduplication {
    static let empty = ScribeCoordinator.CaptureVerdict.Deduplication(isDuplicate: false, supersedes: [], duplicatesOf: [])
}
private extension ScribeCoordinator.CaptureVerdict.Extracted {
    static let empty = ScribeCoordinator.CaptureVerdict.Extracted(facts: [], decisions: [], commitments: [])
}
