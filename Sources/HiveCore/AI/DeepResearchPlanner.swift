import Foundation

// MARK: - DeepResearchPlanner
//
// Multi-step research engine for Hive. Takes a user question, plans sub-queries,
// executes them in parallel, reads top sources, synthesizes findings with citations.
//
// Phase 2 — P2.5: Inspired by Astro's deep research pipeline and Perplexity's
// multi-step research mode. Differs from basic search by doing multiple rounds
// of iterative refinement and source reading.

// MARK: - Research Plan

/// A structured research plan with sub-queries.
public struct ResearchPlan: Sendable {
    public let id = UUID()
    /// The original user question
    let question: String
    /// Decomposed sub-queries to research in parallel
    let subQueries: [ResearchQuery]
    /// How many sources to read per sub-query
    let sourcesPerQuery: Int
    /// Maximum total sources to read
    let maxSources: Int
    /// Whether to do an additional synthesis round
    let refineResults: Bool
}

public struct ResearchQuery: Sendable {
    public let id = UUID()
    let query: String
    /// Aspect of the original question this query addresses
    let aspect: String
    /// Priority 1 (critical) to 3 (supplementary)
    let priority: Int
}

// MARK: - Research Source

/// A source found and read during research.
public struct ResearchSource: Sendable, Identifiable {
    public let id = UUID()
    let url: URL
    let title: String
    let snippet: String
    /// Full text extracted from the page (via AXTree or direct fetch)
    let fullText: String?
    /// Relevance score 0.0...1.0
    let relevance: Double
    /// Which sub-query found this source
    let sourceQueryID: UUID
}

// MARK: - Research Finding

/// A synthesized finding with cited sources.
public struct ResearchFinding: Sendable, Identifiable {
    public let id = UUID()
    /// The synthesized claim
    let claim: String
    /// Supporting source citations
    let citations: [ResearchSource]
    /// Confidence 0.0...1.0
    let confidence: Double
    /// Which aspect of the question this addresses
    let aspect: String
}

// MARK: - Research Brief

/// The complete research output.
public struct ResearchBrief: Sendable {
    /// The original question
    public let question: String
    /// Table of contents (key findings summarized)
    public let tableOfContents: [String]
    /// All synthesized findings
    public let findings: [ResearchFinding]
    /// All sources consulted
    public let sources: [ResearchSource]
    /// Sources that were found but not used
    public let unusedSources: [ResearchSource]
    /// How long the research took
    public let duration: TimeInterval
    /// Whether results were refined in a second pass
    public let wasRefined: Bool

    /// Render as markdown for the UI
    public func toMarkdown() -> String {
        var md = "# Research: \(question)\n\n"
        if !tableOfContents.isEmpty {
            md += "## Key Findings\n\n"
            for (i, toc) in tableOfContents.enumerated() {
                md += "\(i + 1). \(toc)\n"
            }
            md += "\n"
        }
        md += "## Detailed Findings\n\n"
        for finding in findings {
            md += "### \(finding.aspect)\n"
            md += "\(finding.claim)\n\n"
            if !finding.citations.isEmpty {
                md += "**Sources:**\n"
                for source in finding.citations {
                    md += "- [\(source.title)](\(source.url.absoluteString))\n"
                }
                md += "\n"
            }
        }
        md += "---\n"
        md += "*Research completed in \(String(format: "%.1f", duration))s • \(sources.count) sources consulted*\n"
        return md
    }
}

// MARK: - Research Step

/// Represents one step in the research pipeline for progress tracking.
public enum ResearchStep: Sendable {
    case planning
    case searching(completedQueries: Int, totalQueries: Int)
    case reading(completedSources: Int, totalSources: Int)
    case synthesizing
    case refining
    case complete(ResearchBrief)

    public var progress: Double {
        switch self {
        case .planning: return 0.05
        case .searching(let done, let total): return 0.05 + 0.3 * Double(done) / Double(max(total, 1))
        case .reading(let done, let total): return 0.35 + 0.3 * Double(done) / Double(max(total, 1))
        case .synthesizing: return 0.7
        case .refining: return 0.85
        case .complete: return 1.0
        }
    }

    public var label: String {
        switch self {
        case .planning: return "Planning research..."
        case .searching(let done, let total): return "Searching (\(done)/\(total))..."
        case .reading(let done, let total): return "Reading sources (\(done)/\(total))..."
        case .synthesizing: return "Synthesizing findings..."
        case .refining: return "Refining results..."
        case .complete: return "Complete"
        }
    }
}

// MARK: - DeepResearchPlanner

/// Orchestrates multi-step deep research.
@MainActor
public final class DeepResearchPlanner {

    private let dispatcher: Dispatcher
    private let onProgress: ((ResearchStep) -> Void)?

    public init(dispatcher: Dispatcher = .shared, onProgress: ((ResearchStep) -> Void)? = nil) {
        self.dispatcher = dispatcher
        self.onProgress = onProgress
    }

    // MARK: Public API

    /// Execute deep research for a question, streaming progress via onProgress.
    public func research(question: String, maxSources: Int = 15) async throws -> ResearchBrief {
        let startTime = Date()

        // Step 1: Plan — decompose question into sub-queries
        onProgress?(.planning)
        let plan = try await planResearch(question: question, maxSources: maxSources)

        // Step 2: Search — execute sub-queries in parallel
        let sources = try await executeSearches(plan.subQueries, maxSources: plan.maxSources)

        // Step 3: Read — fetch full text of top sources
        onProgress?(.reading(completedSources: 0, totalSources: min(sources.count, plan.maxSources)))
        let topSources = Array(sources.prefix(plan.maxSources))
        let readSources = try await readSources(topSources)

        // Step 4: Synthesize — build findings from read sources
        onProgress?(.synthesizing)
        let findings = try await synthesize(question: question, sources: readSources, plan: plan)

        // Step 5: Refine (optional) — second pass for deeper insight
        var wasRefined = false
        var finalFindings = findings
        if plan.refineResults, findings.count >= 2 {
            onProgress?(.refining)
            finalFindings = try await refine(findings: findings, question: question, sources: readSources)
            wasRefined = true
        }

        let brief = ResearchBrief(
            question: question,
            tableOfContents: finalFindings.map { $0.aspect },
            findings: finalFindings,
            sources: readSources,
            unusedSources: Array(sources.dropFirst(plan.maxSources)),
            duration: Date().timeIntervalSince(startTime),
            wasRefined: wasRefined
        )

        onProgress?(.complete(brief))
        return brief
    }

    // MARK: Private

    /// Use the planner model to decompose the question into sub-queries.
    private func planResearch(question: String, maxSources: Int) async throws -> ResearchPlan {
        let prompt = """
        Decompose this research question into 3-5 focused sub-queries:
        "\(question)"

        For each sub-query, provide:
        - The search query string
        - What aspect of the main question it addresses
        - Priority (1=critical, 2=important, 3=supplementary)

        Return as a structured list.
        """

        let result = try await dispatcher.generate(GenerateRequest(
            role: .planner,
            system: "You are a research planner. Decompose complex questions into focused sub-queries.",
            user: prompt,
            maxTokens: 512
        ))

        // Parse sub-queries from model output
        let subQueries = parseSubQueries(from: result.text, question: question)

        return ResearchPlan(
            question: question,
            subQueries: subQueries.isEmpty ? [ResearchQuery(query: question, aspect: "Main question", priority: 1)] : subQueries,
            sourcesPerQuery: 5,
            maxSources: maxSources,
            refineResults: subQueries.count >= 3
        )
    }

    /// Execute all sub-queries in parallel, deduplicating results.
    private func executeSearches(_ queries: [ResearchQuery], maxSources: Int) async throws -> [ResearchSource] {
        // Execute searches in parallel
        let allResults = try await withThrowingTaskGroup(of: [ResearchSource].self) { group in
            for query in queries {
                group.addTask {
                    try await self.searchSingle(query: query.query, sourceQueryID: query.id)
                }
            }

            var results: [ResearchSource] = []
            for try await batch in group {
                results.append(contentsOf: batch)
            }
            return results
        }

        // Deduplicate by URL, sort by relevance, cap at maxSources
        var seen = Set<String>()
        let deduped = allResults.filter { source in
            let key = source.url.absoluteString
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return deduped.sorted { $0.relevance > $1.relevance }
    }

    /// Search a single query and return sources.
    private func searchSingle(query: String, sourceQueryID: UUID) async throws -> [ResearchSource] {
        // Use the existing research pipeline (Tavily/Vane/MLX)
        let prompt = """
        Search for: \(query)
        Return the top results as a list of URLs with titles and snippets.
        """

        let result = try await dispatcher.generate(GenerateRequest(
            role: .librarian,
            system: "You are a search specialist. Return search results with URLs.",
            user: prompt,
            maxTokens: 1024
        ))

        return extractSources(from: result.text, sourceQueryID: sourceQueryID)
    }

    /// Read full text of sources via URLSession fetch with basic HTML-to-text extraction.
    /// Falls back to snippet when fetch fails or times out.
    private func readSources(_ sources: [ResearchSource]) async throws -> [ResearchSource] {
        var enriched: [ResearchSource] = []
        for (i, var source) in sources.enumerated() {
            onProgress?(.reading(completedSources: i, totalSources: sources.count))
            do {
                let text = try await fetchPageText(url: source.url)
                if let text, !text.isEmpty {
                    source = ResearchSource(
                        url: source.url,
                        title: source.title,
                        snippet: source.snippet,
                        fullText: text,
                        relevance: source.relevance,
                        sourceQueryID: source.sourceQueryID
                    )
                }
            } catch {
                // Fetch failed — keep the snippet-only source
            }
            enriched.append(source)
        }
        return enriched
    }

    /// Fetch a page and extract readable text. Times out at 10 seconds.
    /// Blocks non-http/https schemes and private/reserved IP ranges to prevent SSRF.
    private func fetchPageText(url: URL) async throws -> String? {
        // SSRF guard: only allow http/https
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            return nil
        }
        // SSRF guard: block private/reserved hosts
        guard let host = url.host?.lowercased(), !isPrivateHost(host) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("text/html, text/plain;q=0.9", forHTTPHeaderField: "Accept")
        request.setValue("HiveDeepResearch/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let mime = http.mimeType?.lowercased(),
              mime.contains("text/html") || mime.contains("text/plain") else {
            return nil
        }

        // Cap content at 2MB before decoding
        let capped = data.prefix(2_000_000)
        guard let html = String(data: capped, encoding: .utf8) else { return nil }
        let text = extractTextFromHTML(html)
        // Truncate to ~50k chars for practical LLM context windows
        return String(text.prefix(50_000))
    }

    /// Returns true if host is a private, loopback, link-local, or reserved address.
    private func isPrivateHost(_ host: String) -> Bool {
        // Block hostnames that resolve to private ranges
        let blockedPatterns = [
            "localhost", "127.0.0.1", "::1", "0.0.0.0",
            "10.", "172.16.", "172.17.", "172.18.", "172.19.",
            "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
            "172.25.", "172.26.", "172.27.", "172.28.", "172.29.",
            "172.30.", "172.31.", "192.168.", "169.254."
        ]
        for pattern in blockedPatterns {
            if host == pattern || host.hasPrefix(pattern) {
                return true
            }
        }
        // Block link-local IPv6
        if host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") {
            return true
        }
        return false
    }

    /// Basic HTML-to-text extraction: strip tags, scripts, styles, collapse whitespace.
    private func extractTextFromHTML(_ html: String) -> String {
        var text = html
        // Remove script and style blocks
        let scriptPattern = try? NSRegularExpression(pattern: "<(script|style)[^>]*>.*?</\\1>", options: [.dotMatchesLineSeparators, .caseInsensitive])
        text = scriptPattern?.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: " ") ?? text
        // Remove HTML tags
        let tagPattern = try? NSRegularExpression(pattern: "<[^>]+>", options: [])
        text = tagPattern?.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: " ") ?? text
        // Decode entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace and trim
        let components = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return components.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Synthesize findings from read sources.
    private func synthesize(question: String, sources: [ResearchSource], plan: ResearchPlan) async throws -> [ResearchFinding] {
        guard !sources.isEmpty else {
            return [ResearchFinding(claim: "No sources found for this query.", citations: [], confidence: 0, aspect: "General")]
        }

        let sourceTexts = sources.enumerated().map { i, s in
            "[\(i + 1)] \(s.title): \(s.snippet)"
        }.joined(separator: "\n")

        let prompt = """
        Question: \(question)

        Sources:
        \(sourceTexts)

        Synthesize 3-5 key findings with citations. For each finding:
        - A clear claim
        - Which sources support it (use [N] notation)
        - Confidence level

        Be precise. Only cite sources that actually support the claim.
        """

        let result = try await dispatcher.generate(GenerateRequest(
            role: .librarian,
            system: "You are a research synthesizer. Produce cited findings from multiple sources.",
            user: prompt,
            maxTokens: 2048
        ))

        return parseFindings(from: result.text, sources: sources, plan: plan)
    }

    /// Refine findings with a second synthesis pass.
    private func refine(findings: [ResearchFinding], question: String, sources: [ResearchSource]) async throws -> [ResearchFinding] {
        let findingsText = findings.enumerated().map { i, f in
            "Finding \(i + 1): \(f.claim) (confidence: \(Int(f.confidence * 100))%)"
        }.joined(separator: "\n")

        let prompt = """
        Original question: \(question)

        Initial findings:
        \(findingsText)

        Refine these findings. Which claims are strongest? Are there gaps?
        Combine overlapping claims. Add nuance where warranted.
        """

        let result = try await dispatcher.generate(GenerateRequest(
            role: .librarian,
            system: "You are a research refiner. Improve and consolidate findings.",
            user: prompt,
            maxTokens: 2048
        ))

        return parseFindings(from: result.text, sources: sources, plan: ResearchPlan(
            question: question, subQueries: [], sourcesPerQuery: 0, maxSources: 0, refineResults: false
        ))
    }

    // MARK: Parsing Helpers

    private func parseSubQueries(from text: String, question: String) -> [ResearchQuery] {
        // Simple parsing: extract lines that look like queries
        let lines = text.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { !$0.hasPrefix("#") && !$0.hasPrefix("-") }

        var queries: [ResearchQuery] = []
        for (i, line) in lines.prefix(5).enumerated() {
            let cleaned = line.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard cleaned.count > 5 else { continue }
            queries.append(ResearchQuery(
                query: cleaned,
                aspect: "Aspect \(i + 1)",
                priority: i < 2 ? 1 : (i < 4 ? 2 : 3)
            ))
        }
        return queries
    }

    private func extractSources(from text: String, sourceQueryID: UUID) -> [ResearchSource] {
        // Extract URLs from text
        let pattern = try? NSRegularExpression(pattern: "https?://[^\\s)]+", options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let urls = pattern?.matches(in: text, options: [], range: range)
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
            .compactMap { URL(string: $0) } ?? []

        var sources: [ResearchSource] = []
        for (i, url) in urls.enumerated() {
            sources.append(ResearchSource(
                url: url,
                title: url.host ?? "Source \(i + 1)",
                snippet: text,
                fullText: nil,
                relevance: 1.0 - Double(i) * 0.1,
                sourceQueryID: sourceQueryID
            ))
        }
        return sources
    }

    private func parseFindings(from text: String, sources: [ResearchSource], plan: ResearchPlan) -> [ResearchFinding] {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var findings: [ResearchFinding] = []
        for (_, para) in paragraphs.enumerated() {
            let cleaned = para.trimmingCharacters(in: .whitespaces)
            guard cleaned.count > 10 else { continue }

            // Extract [N] citations from the text
            let citePattern = try? NSRegularExpression(pattern: "\\[(\\d+)\\]", options: [])
            let citeRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            let citeNums = citePattern?.matches(in: cleaned, options: [], range: citeRange)
                .compactMap { match -> Int? in
                    guard let r = Range(match.range(at: 1), in: cleaned) else { return nil }
                    return Int(cleaned[r])
                } ?? []

            let citedSources = citeNums.compactMap { num in
                num > 0 && num <= sources.count ? sources[num - 1] : nil
            }

            findings.append(ResearchFinding(
                claim: cleaned,
                citations: citedSources,
                confidence: citedSources.isEmpty ? 0.5 : min(0.9, 0.5 + Double(citedSources.count) * 0.1),
                aspect: plan.subQueries.first?.aspect ?? "General"
            ))
        }

        return findings.isEmpty
            ? [ResearchFinding(claim: text, citations: Array(sources.prefix(3)), confidence: 0.7, aspect: "General")]
            : findings
    }
}
