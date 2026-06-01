import Foundation
import SQLite3

public enum WikiSearchBackend: String, Codable, Hashable, Sendable {
    case nativeIndex = "native-index"
    case coreMLRerank = "coreml-rerank"
    case qmdCLI = "qmd-cli"
    case indexFallback = "index-fallback"
}

public enum WikiSearchMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case lexical
    case semantic
    case hybrid
    case qmdOptional
}

public struct WikiSearchResult: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(backend.rawValue)-\(pageID)" }
    public var pageID: String
    public var title: String
    public var summary: String
    public var snippet: String
    public var score: Double
    public var backend: WikiSearchBackend
    public var matchedFields: [String]

    public init(
        pageID: String,
        title: String,
        summary: String,
        snippet: String,
        score: Double,
        backend: WikiSearchBackend,
        matchedFields: [String] = []
    ) {
        self.pageID = pageID
        self.title = title
        self.summary = summary
        self.snippet = snippet
        self.score = score
        self.backend = backend
        self.matchedFields = matchedFields
    }
}

public struct WikiSearchHit: Hashable, Sendable {
    public var pageID: String
    public var title: String
    public var summary: String
    public var snippet: String
    public var filePath: String?
    public var score: Double
    public var backend: WikiSearchBackend

    public init(
        pageID: String,
        title: String,
        summary: String,
        snippet: String,
        filePath: String?,
        score: Double,
        backend: WikiSearchBackend
    ) {
        self.pageID = pageID
        self.title = title
        self.summary = summary
        self.snippet = snippet
        self.filePath = filePath
        self.score = score
        self.backend = backend
    }
}

public struct QMDCommandPlan: Hashable, Sendable {
    public var collectionName: String
    public var addCollection: [String]
    public var addContext: [String]
    public var updateIndex: [String]
    public var embedIndex: [String]
    public var keywordSearchPrefix: [String]
    public var vectorSearchPrefix: [String]
    public var queryPrefix: [String]
    public var hybridSearchPrefix: [String]
    public var getDocumentPrefix: [String]
    public var multiGetDocumentPrefix: [String]
    public var status: [String]
    public var mcpServer: [String]
    public var mcpHTTPServer: [String]
    public var mcpHTTPDaemon: [String]
    public var mcpStop: [String]
    public var httpHealthURL: String
    public var httpMCPURL: String

    public init(
        collectionName: String,
        addCollection: [String],
        addContext: [String],
        updateIndex: [String],
        embedIndex: [String],
        keywordSearchPrefix: [String],
        vectorSearchPrefix: [String],
        queryPrefix: [String],
        hybridSearchPrefix: [String],
        getDocumentPrefix: [String],
        multiGetDocumentPrefix: [String],
        status: [String],
        mcpServer: [String],
        mcpHTTPServer: [String],
        mcpHTTPDaemon: [String],
        mcpStop: [String],
        httpHealthURL: String,
        httpMCPURL: String
    ) {
        self.collectionName = collectionName
        self.addCollection = addCollection
        self.addContext = addContext
        self.updateIndex = updateIndex
        self.embedIndex = embedIndex
        self.keywordSearchPrefix = keywordSearchPrefix
        self.vectorSearchPrefix = vectorSearchPrefix
        self.queryPrefix = queryPrefix
        self.hybridSearchPrefix = hybridSearchPrefix
        self.getDocumentPrefix = getDocumentPrefix
        self.multiGetDocumentPrefix = multiGetDocumentPrefix
        self.status = status
        self.mcpServer = mcpServer
        self.mcpHTTPServer = mcpHTTPServer
        self.mcpHTTPDaemon = mcpHTTPDaemon
        self.mcpStop = mcpStop
        self.httpHealthURL = httpHealthURL
        self.httpMCPURL = httpMCPURL
    }
}

public struct QMDWikiSearchTool: Sendable {
    public var executableName: String
    public var collectionName: String

    public init(executableName: String = "qmd", collectionName: String = "hive-wiki") {
        self.executableName = executableName
        self.collectionName = collectionName
    }

    public func commandPlan(vaultWikiURL: URL) -> QMDCommandPlan {
        let wikiPath = vaultWikiURL.path
        return QMDCommandPlan(
            collectionName: collectionName,
            addCollection: [executableName, "collection", "add", wikiPath, "--name", collectionName, "--mask", "**/*.md"],
            addContext: [
                executableName,
                "context",
                "add",
                "qmd://\(collectionName)",
                "Hive Colony: maintained wiki articles, answer pages, frontmatter, backlinks, and daily audit history."
            ],
            updateIndex: [executableName, "update"],
            embedIndex: [executableName, "embed"],
            keywordSearchPrefix: [executableName, "search"],
            vectorSearchPrefix: [executableName, "vsearch"],
            queryPrefix: [executableName, "query"],
            hybridSearchPrefix: [executableName, "query"],
            getDocumentPrefix: [executableName, "get"],
            multiGetDocumentPrefix: [executableName, "multi-get"],
            status: [executableName, "status"],
            mcpServer: [executableName, "mcp"],
            mcpHTTPServer: [executableName, "mcp", "--http"],
            mcpHTTPDaemon: [executableName, "mcp", "--http", "--daemon"],
            mcpStop: [executableName, "mcp", "stop"],
            httpHealthURL: "http://localhost:8181/health",
            httpMCPURL: "http://localhost:8181/mcp"
        )
    }

    public func parseSearchOutput(_ output: String, pages: [WikiPageRecord], limit: Int = 8) -> [WikiSearchHit] {
        let jsonHits = parseJSONSearchOutput(output, pages: pages, limit: limit)
        if !jsonHits.isEmpty { return jsonHits }
        let pagesBySlug = Dictionary(uniqueKeysWithValues: pages.map { ($0.slug, $0) })
        let pagesByTitle = Dictionary(uniqueKeysWithValues: pages.map { ($0.title.lowercased(), $0) })
        var hits: [WikiSearchHit] = []
        for (lineIndex, rawLine) in output.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let normalized = stripANSIEscapeCodes(line)
            guard let page = matchPage(in: normalized, pagesBySlug: pagesBySlug, pagesByTitle: pagesByTitle) else { continue }
            hits.append(WikiSearchHit(
                pageID: page.id,
                title: page.title,
                summary: page.summary,
                snippet: snippet(from: normalized, fallback: page.summary),
                filePath: page.filePath,
                score: max(1, Double(limit - lineIndex)),
                backend: .qmdCLI
            ))
            if hits.count >= limit { break }
        }
        return stableUnique(hits)
    }

    public func parseJSONSearchOutput(_ output: String, pages: [WikiPageRecord], limit: Int = 8) -> [WikiSearchHit] {
        guard let data = output.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        let candidates: [[String: Any]]
        if let array = root as? [[String: Any]] {
            candidates = array
        } else if let object = root as? [String: Any],
                  let array = (object["results"] ?? object["hits"] ?? object["documents"]) as? [[String: Any]] {
            candidates = array
        } else {
            return []
        }

        let pagesBySlug = Dictionary(uniqueKeysWithValues: pages.map { ($0.slug, $0) })
        let pagesByID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        let pagesByTitle = Dictionary(uniqueKeysWithValues: pages.map { ($0.title.lowercased(), $0) })
        var hits: [WikiSearchHit] = []
        for (index, item) in candidates.enumerated() {
            let title = stringValue(item["title"] ?? item["name"])
            let path = stringValue(item["path"] ?? item["displayPath"] ?? item["file"] ?? item["filepath"] ?? item["filePath"] ?? item["url"] ?? item["uri"] ?? item["docid"] ?? item["id"])
            let content = stringValue(item["snippet"] ?? item["summary"] ?? item["text"] ?? item["content"] ?? item["body"] ?? item["context"])
            let lookup = [title, path, content].joined(separator: " ")
            let page = pagesByID[path]
                ?? matchPage(in: lookup, pagesBySlug: pagesBySlug, pagesByTitle: pagesByTitle)
            guard let page else { continue }
            let score = doubleValue(item["score"] ?? item["rank"]) ?? max(1, Double(limit - index))
            hits.append(WikiSearchHit(
                pageID: page.id,
                title: page.title,
                summary: page.summary,
                snippet: content.isEmpty ? snippet(from: lookup, fallback: page.summary) : String(content.prefix(240)),
                filePath: page.filePath,
                score: score,
                backend: .qmdCLI
            ))
            if hits.count >= limit { break }
        }
        return stableUnique(hits)
    }

    public var installHint: String {
        "Install qmd yourself if you want the optional Mac search backend. Hive never installs qmd or starts qmd embedding/reranking models unless you explicitly enable those tools."
    }

    public func isAvailable() -> Bool {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-lc", "command -v \(executableName)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public func searchCLI(
        query: String,
        vaultWikiURL: URL,
        pages: [WikiPageRecord],
        limit: Int = 8,
        mode: WikiSearchMode = .hybrid
    ) throws -> [WikiSearchHit] {
        #if os(macOS)
        let plan = commandPlan(vaultWikiURL: vaultWikiURL)
        let prefix = qmdSearchPrefix(for: mode, plan: plan)
        let command = Array(prefix.dropFirst()) + [query, "-n", String(limit)]
        let output: String
        if let jsonOutput = try? run(arguments: command + ["--json"]) {
            output = jsonOutput
        } else {
            output = try run(arguments: command)
        }
        return parseSearchOutput(output, pages: pages, limit: limit)
        #else
        return []
        #endif
    }

    private func matchPage(
        in line: String,
        pagesBySlug: [String: WikiPageRecord],
        pagesByTitle: [String: WikiPageRecord]
    ) -> WikiPageRecord? {
        let lower = line.lowercased()
        for (slug, page) in pagesBySlug where lower.contains(slug.lowercased()) || lower.contains("\(slug).md") {
            return page
        }
        for (title, page) in pagesByTitle where lower.contains(title) {
            return page
        }
        return nil
    }

    private func stripANSIEscapeCodes(_ value: String) -> String {
        value.replacingOccurrences(of: #"\u{001B}\[[0-9;]*[A-Za-z]"#, with: "", options: .regularExpression)
    }

    private func snippet(from line: String, fallback: String) -> String {
        let cleaned = line.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if cleaned.count > 24 {
            return String(cleaned.prefix(240))
        }
        return fallback.isEmpty ? cleaned : fallback
    }

    private func qmdSearchPrefix(for mode: WikiSearchMode, plan: QMDCommandPlan) -> [String] {
        switch mode {
        case .lexical:
            return plan.keywordSearchPrefix
        case .semantic:
            return plan.vectorSearchPrefix
        case .hybrid, .automatic, .qmdOptional:
            return plan.queryPrefix
        }
    }

    private func stringValue(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }

    private func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func stableUnique(_ hits: [WikiSearchHit]) -> [WikiSearchHit] {
        var seen = Set<String>()
        var result: [WikiSearchHit] = []
        for hit in hits where seen.insert(hit.pageID).inserted {
            result.append(hit)
        }
        return result
    }

    #if os(macOS)
    private func run(arguments: [String]) throws -> String {
        let output = Pipe()
        let error = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executableName] + arguments
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: outputData, as: UTF8.self)
        if process.terminationStatus != 0 {
            let errorText = String(decoding: errorData, as: UTF8.self)
            throw NSError(
                domain: "Hive.QMDWikiSearchTool",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorText.isEmpty ? "qmd command failed." : errorText]
            )
        }
        return text
    }
    #endif
}

public struct WikiSearchEngine: Sendable {
    private let qmdTool: QMDWikiSearchTool

    public init(qmdTool: QMDWikiSearchTool = QMDWikiSearchTool()) {
        self.qmdTool = qmdTool
    }

    public func search(
        query: String,
        pages: [WikiPageRecord],
        limit: Int = 8,
        vaultWikiURL: URL? = nil,
        qmdOutput: String? = nil,
        mode: WikiSearchMode = .automatic,
        qmdEnabled: Bool = false
    ) -> [WikiSearchHit] {
        if mode == .qmdOptional,
           qmdEnabled,
           let vaultWikiURL,
           qmdTool.isAvailable(),
           let qmdHits = try? qmdTool.searchCLI(query: query, vaultWikiURL: vaultWikiURL, pages: pages, limit: limit, mode: mode),
           !qmdHits.isEmpty {
            return qmdHits
        }
        if let qmdOutput {
            let qmdHits = qmdTool.parseSearchOutput(qmdOutput, pages: pages, limit: limit)
            if !qmdHits.isEmpty { return qmdHits }
        }
        return fallbackSearch(query: query, pages: pages, limit: limit)
    }

    public func fallbackSearch(query: String, pages: [WikiPageRecord], limit: Int = 8) -> [WikiSearchHit] {
        let indexHits = WikiIndexNavigator().relevantPages(query: query, pages: pages, limit: limit)
        if !indexHits.isEmpty {
            return indexHits.map { hit in
                WikiSearchHit(
                    pageID: hit.page.id,
                    title: hit.page.title,
                    summary: hit.page.summary,
                    snippet: bestSnippet(for: query, page: hit.page),
                    filePath: hit.page.filePath,
                    score: Double(hit.score),
                    backend: .indexFallback
                )
            }
        }
        return lexicalFallback(query: query, pages: pages, limit: limit)
    }

    public func qmdCommandPlan(vaultWikiURL: URL) -> QMDCommandPlan {
        qmdTool.commandPlan(vaultWikiURL: vaultWikiURL)
    }

    private func lexicalFallback(query: String, pages: [WikiPageRecord], limit: Int) -> [WikiSearchHit] {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }
        return pages
            .filter(\.isUserVisibleArticle)
            .map { page -> WikiSearchHit in
                let fields = [
                    page.title,
                    page.summary,
                    page.frontmatter["tags"] ?? "",
                    page.markdown
                ]
                let score = fields.enumerated().reduce(0) { partial, pair in
                    let multiplier = pair.offset == 0 ? 7 : (pair.offset == 1 ? 5 : 1)
                    return partial + tokens(pair.element).intersection(queryTokens).count * multiplier
                }
                return WikiSearchHit(
                    pageID: page.id,
                    title: page.title,
                    summary: page.summary,
                    snippet: bestSnippet(for: query, page: page),
                    filePath: page.filePath,
                    score: Double(score),
                    backend: .indexFallback
                )
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private func bestSnippet(for query: String, page: WikiPageRecord) -> String {
        let queryTokens = tokens(query)
        let candidates = ([page.summary] + page.markdown.components(separatedBy: .newlines))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("---") }
        let best = candidates.max { left, right in
            tokens(left).intersection(queryTokens).count < tokens(right).intersection(queryTokens).count
        }
        let cleaned = (best ?? page.summary).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(cleaned.prefix(240))
    }

    private func tokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "about", "after", "also", "answer", "article", "because", "from", "have", "index",
            "into", "local", "page", "that", "the", "this", "wiki", "with", "without"
        ]
        return Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) })
    }
}

private struct NativeWikiFTSIndex {
    func search(query: String, pages: [WikiPageRecord], limit: Int) -> [WikiSearchResult] {
        let queryTokens = ftsTokens(query)
        guard !queryTokens.isEmpty else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let database = db else {
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(database) }

        let createSQL = """
        CREATE VIRTUAL TABLE wiki_fts USING fts5(
            page_id UNINDEXED,
            title,
            summary,
            tags,
            frontmatter,
            body,
            tokenize = 'porter unicode61'
        );
        """
        guard sqlite3_exec(database, createSQL, nil, nil, nil) == SQLITE_OK else {
            return []
        }

        guard insert(pages: pages.filter(\.isUserVisibleArticle), into: database) else {
            return []
        }

        let match = queryTokens.map { "\($0)*" }.joined(separator: " OR ")
        let sql = """
        SELECT page_id, title, summary, snippet(wiki_fts, 5, '', '', '...', 32),
               bm25(wiki_fts, 9.0, 7.0, 5.0, 4.0, 1.0) AS rank
        FROM wiki_fts
        WHERE wiki_fts MATCH ?
        ORDER BY rank
        LIMIT ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        bindText(match, to: statement, at: 1)
        sqlite3_bind_int(statement, 2, Int32(max(1, limit)))

        let pagesByID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        var results: [WikiSearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let pageID = columnText(statement, 0)
            guard let page = pagesByID[pageID] else { continue }
            let snippet = columnText(statement, 3)
            let rank = sqlite3_column_double(statement, 4)
            results.append(WikiSearchResult(
                pageID: page.id,
                title: page.title,
                summary: page.summary,
                snippet: snippet.isEmpty ? page.summary : snippet,
                score: max(0.01, -rank) + recencyBoost(for: page),
                backend: .nativeIndex,
                matchedFields: matchedFields(for: page, queryTokens: Set(queryTokens))
            ))
        }
        return results
    }

    private func insert(pages: [WikiPageRecord], into database: OpaquePointer) -> Bool {
        let sql = "INSERT INTO wiki_fts(page_id, title, summary, tags, frontmatter, body) VALUES (?, ?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        for page in pages {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(page.id, to: statement, at: 1)
            bindText(page.title, to: statement, at: 2)
            bindText(page.summary, to: statement, at: 3)
            bindText(page.frontmatter["tags"] ?? "", to: statement, at: 4)
            bindText(page.frontmatter.values.joined(separator: " "), to: statement, at: 5)
            bindText(page.markdown, to: statement, at: 6)
            guard sqlite3_step(statement) == SQLITE_DONE else { return false }
        }
        return true
    }

    private func matchedFields(for page: WikiPageRecord, queryTokens: Set<String>) -> [String] {
        let fields: [(String, String)] = [
            ("title", page.title),
            ("summary", page.summary),
            ("tags", page.frontmatter["tags"] ?? ""),
            ("frontmatter", page.frontmatter.values.joined(separator: " ")),
            ("body", page.markdown)
        ]
        return fields.compactMap { name, value in
            ftsTokens(value).contains(where: { queryTokens.contains($0) }) ? name : nil
        }
    }

    private func recencyBoost(for page: WikiPageRecord) -> Double {
        max(0, 1.0 - Date().timeIntervalSince(page.updatedAt) / (60 * 60 * 24 * 90))
    }

    private func ftsTokens(_ value: String) -> [String] {
        let stopwords: Set<String> = [
            "about", "after", "also", "answer", "article", "because", "from", "have", "index",
            "into", "local", "page", "that", "the", "this", "wiki", "with", "without"
        ]
        return value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }
}

public struct WikiSearchRouter: Sendable {
    private let engine: WikiSearchEngine
    private let qmdTool: QMDWikiSearchTool

    public init(
        engine: WikiSearchEngine = WikiSearchEngine(),
        qmdTool: QMDWikiSearchTool = QMDWikiSearchTool()
    ) {
        self.engine = engine
        self.qmdTool = qmdTool
    }

    public func searchWiki(
        query: String,
        pages: [WikiPageRecord],
        limit: Int = 8,
        mode: WikiSearchMode = .automatic,
        vaultWikiURL: URL? = nil,
        qmdEnabled: Bool = false,
        qmdOutput: String? = nil,
        coreMLRerankAvailable: Bool = false
    ) -> [WikiSearchResult] {
        if mode == .qmdOptional {
            let qmdHits = engine.search(
                query: query,
                pages: pages,
                limit: limit,
                vaultWikiURL: vaultWikiURL,
                qmdOutput: qmdOutput,
                mode: .qmdOptional,
                qmdEnabled: qmdEnabled
            )
            if qmdHits.contains(where: { $0.backend == .qmdCLI }) {
                return qmdHits.map { Self.result(from: $0, matchedFields: ["qmd"]) }
            }
        }

        let native = nativeIndexSearch(query: query, pages: pages, limit: limit, mode: mode)
        if coreMLRerankAvailable, mode == .semantic || mode == .hybrid {
            return native
        }
        if !native.isEmpty { return native }

        return engine
            .fallbackSearch(query: query, pages: pages, limit: limit)
            .map { Self.result(from: $0, matchedFields: ["index"]) }
    }

    public func searchWikiWithFoundationRanking(
        query: String,
        pages: [WikiPageRecord],
        limit: Int = 8,
        orchestrator: HiveFoundationModelsOrchestrator = HiveFoundationModelsOrchestrator()
    ) async -> [WikiSearchResult] {
        let deterministic = searchWiki(query: query, pages: pages, limit: limit, mode: .automatic)
        let ranked = await orchestrator.rankWikiPages(query: query, pages: pages, limit: limit)
        return ranked.isEmpty ? deterministic : ranked
    }

    public func qmdStatus(vaultWikiURL: URL? = nil) -> WikiToolBackendStatus {
        let plan = vaultWikiURL.map { qmdTool.commandPlan(vaultWikiURL: $0) }
        return WikiToolBackendStatus(
            backend: .qmdCLI,
            isAvailable: qmdTool.isAvailable(),
            userFacingStatus: qmdTool.isAvailable() ? "Available" : "Optional",
            advancedInstructions: plan.map {
                "Use \($0.updateIndex.joined(separator: " ")), \($0.queryPrefix.joined(separator: " ")), \($0.getDocumentPrefix.joined(separator: " ")), \($0.multiGetDocumentPrefix.joined(separator: " ")), or \($0.mcpServer.joined(separator: " ")) from Advanced. HTTP MCP is \($0.httpMCPURL)."
            } ?? qmdTool.installHint
        )
    }

    private func nativeIndexSearch(
        query: String,
        pages: [WikiPageRecord],
        limit: Int,
        mode: WikiSearchMode
    ) -> [WikiSearchResult] {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }
        let ftsResults = NativeWikiFTSIndex().search(query: query, pages: pages, limit: limit)
        if !ftsResults.isEmpty { return ftsResults }
        return pages
            .filter(\.isUserVisibleArticle)
            .map { page -> WikiSearchResult in
                let fields: [(String, String, Int)] = [
                    ("title", page.title, 9),
                    ("summary", page.summary, 7),
                    ("tags", page.frontmatter["tags"] ?? "", 5),
                    ("frontmatter", page.frontmatter.values.joined(separator: " "), 4),
                    ("links", (page.outboundLinks + page.inboundLinks).joined(separator: " "), 3),
                    ("body", page.markdown, 1)
                ]
                var matched: [String] = []
                var score = 0
                for field in fields {
                    let overlap = tokens(field.1).intersection(queryTokens).count
                    if overlap > 0 {
                        matched.append(field.0)
                        score += overlap * field.2
                    }
                }
                let recencyBoost = max(0, 1.0 - Date().timeIntervalSince(page.updatedAt) / (60 * 60 * 24 * 90))
                return WikiSearchResult(
                    pageID: page.id,
                    title: page.title,
                    summary: page.summary,
                    snippet: bestSnippet(for: queryTokens, page: page),
                    score: Double(score) + recencyBoost,
                    backend: .nativeIndex,
                    matchedFields: stableUnique(matched)
                )
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func result(from hit: WikiSearchHit, matchedFields: [String]) -> WikiSearchResult {
        WikiSearchResult(
            pageID: hit.pageID,
            title: hit.title,
            summary: hit.summary,
            snippet: hit.snippet,
            score: hit.score,
            backend: hit.backend,
            matchedFields: matchedFields
        )
    }

    private func bestSnippet(for queryTokens: Set<String>, page: WikiPageRecord) -> String {
        let candidates = ([page.summary] + page.markdown.components(separatedBy: .newlines))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("---") && !$0.hasPrefix("#") }
        let best = candidates.max { left, right in
            tokens(left).intersection(queryTokens).count < tokens(right).intersection(queryTokens).count
        }
        let cleaned = (best ?? page.summary).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(cleaned.prefix(240))
    }

    private func tokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "about", "after", "also", "answer", "article", "because", "from", "have", "index",
            "into", "local", "page", "that", "the", "this", "wiki", "with", "without"
        ]
        return Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) })
    }

    private func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

public struct WikiToolBackendStatus: Codable, Hashable, Sendable {
    public var backend: WikiSearchBackend
    public var isAvailable: Bool
    public var userFacingStatus: String
    public var advancedInstructions: String

    public init(
        backend: WikiSearchBackend,
        isAvailable: Bool,
        userFacingStatus: String,
        advancedInstructions: String
    ) {
        self.backend = backend
        self.isAvailable = isAvailable
        self.userFacingStatus = userFacingStatus
        self.advancedInstructions = advancedInstructions
    }
}

public enum WikiMaintenanceScope: String, Codable, CaseIterable, Sendable {
    case recentChanges
    case nightlyAudit
    case fullWiki
}

public enum WikiPatchOperationKind: String, Codable, CaseIterable, Sendable {
    case replaceSection
    case insertSection
    case mergePageIntoPage
    case addBacklink
    case updateFrontmatter
    case appendLogEntry
    case markReviewNeeded
}

public struct WikiPatchOperation: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: WikiPatchOperationKind
    public var pageID: String
    public var targetPageID: String?
    public var sectionTitle: String?
    public var markdown: String
    public var frontmatterUpdates: [String: String]

    public init(
        kind: WikiPatchOperationKind,
        pageID: String,
        targetPageID: String? = nil,
        sectionTitle: String? = nil,
        markdown: String = "",
        frontmatterUpdates: [String: String] = [:]
    ) {
        self.kind = kind
        self.pageID = pageID
        self.targetPageID = targetPageID
        self.sectionTitle = sectionTitle
        self.markdown = markdown
        self.frontmatterUpdates = frontmatterUpdates
        let payload = [kind.rawValue, pageID, targetPageID ?? "", sectionTitle ?? "", markdown].joined(separator: "|")
        self.id = "wiki-patch-\(Hashing.sha256(data: Data(payload.utf8)).prefix(18))"
    }
}

public struct WikiPatchProposal: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var reason: String
    public var touchedPageIDs: [String]
    public var beforeHashes: [String: String]
    public var operations: [WikiPatchOperation]
    public var confidenceLanguage: String
    public var requiresUserReview: Bool

    public init(
        reason: String,
        touchedPageIDs: [String],
        beforeHashes: [String: String],
        operations: [WikiPatchOperation],
        confidenceLanguage: String = "needs review",
        requiresUserReview: Bool = true
    ) {
        self.reason = reason
        self.touchedPageIDs = touchedPageIDs
        self.beforeHashes = beforeHashes
        self.operations = operations
        self.confidenceLanguage = confidenceLanguage
        self.requiresUserReview = requiresUserReview || operations.contains { $0.kind == .mergePageIntoPage }
        let payload = [
            reason,
            touchedPageIDs.sorted().joined(separator: ","),
            operations.map(\.id).sorted().joined(separator: ",")
        ].joined(separator: "|")
        self.id = "wiki-proposal-\(Hashing.sha256(data: Data(payload.utf8)).prefix(20))"
    }
}

public struct WikiMaintenanceProposalEnvelope: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var schemaVersion: Int
    public var proposal: WikiPatchProposal
    public var generatedAt: Date
    public var mutationPolicy: String
    public var validationErrors: [String]

    public init(
        proposal: WikiPatchProposal,
        generatedAt: Date = Date(),
        validationErrors: [String] = [],
        mutationPolicy: String = "wiki-maintenance-output-is-proposal-only"
    ) {
        self.schemaVersion = 1
        self.proposal = proposal
        self.generatedAt = generatedAt
        self.mutationPolicy = mutationPolicy
        self.validationErrors = validationErrors
        self.id = proposal.id
    }

    public var isValidProposal: Bool {
        validationErrors.isEmpty && !proposal.operations.isEmpty
    }
}

public struct HiveWikiToolbox: Sendable {
    public var pages: [WikiPageRecord]
    public var claims: [ClaimRecord]
    public var entities: [EntityRecord]
    public var contradictions: [ContradictionRecord]
    public var reviewQueue: [ReviewQueueItem]
    public var vaultWikiURL: URL?
    private let router: WikiSearchRouter

    public init(
        pages: [WikiPageRecord],
        claims: [ClaimRecord] = [],
        entities: [EntityRecord] = [],
        contradictions: [ContradictionRecord] = [],
        reviewQueue: [ReviewQueueItem] = [],
        vaultWikiURL: URL? = nil,
        router: WikiSearchRouter = WikiSearchRouter()
    ) {
        self.pages = pages
        self.claims = claims
        self.entities = entities
        self.contradictions = contradictions
        self.reviewQueue = reviewQueue
        self.vaultWikiURL = vaultWikiURL
        self.router = router
    }

    public func searchWiki(query: String, limit: Int = 8, mode: WikiSearchMode = .automatic) -> [WikiSearchResult] {
        router.searchWiki(query: query, pages: pages, limit: limit, mode: mode, vaultWikiURL: vaultWikiURL)
    }

    public func getWikiPage(pageIDOrPath: String) -> WikiPageRecord? {
        let lookup = pageIDOrPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = WikiPageRecord.slugify((lookup as NSString).deletingPathExtension)
        return pages.first {
            $0.id == lookup
                || $0.slug == lookup
                || $0.slug == slug
                || $0.filePath == lookup
                || $0.title.localizedCaseInsensitiveCompare(lookup) == .orderedSame
        }
    }

    public func relatedPages(pageID: String) -> [WikiPageRecord] {
        guard let page = getWikiPage(pageIDOrPath: pageID) else { return [] }
        let linked = Set(page.outboundLinks + page.inboundLinks)
        let claimRefs = Set(page.claimRefs)
        return pages
            .filter { candidate in
                candidate.id != page.id
                    && (linked.contains(candidate.id)
                        || linked.contains(candidate.title)
                        || linked.contains(candidate.slug)
                        || !Set(candidate.claimRefs).intersection(claimRefs).isEmpty)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func backlinks(pageID: String) -> [WikiPageRecord] {
        guard let page = getWikiPage(pageIDOrPath: pageID) else { return [] }
        return pages
            .filter { candidate in
                candidate.id != page.id
                    && (candidate.outboundLinks.contains(page.id)
                        || candidate.outboundLinks.contains(page.title)
                        || candidate.markdown.localizedCaseInsensitiveContains("[[\(page.title)]]"))
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func planMaintenance(scope: WikiMaintenanceScope = .recentChanges) -> [WikiMaintenanceTask] {
        let visiblePages = pages.filter(\.isUserVisibleArticle)
        let touchedPages: [WikiPageRecord]
        switch scope {
        case .recentChanges:
            touchedPages = Array(visiblePages.sorted { $0.updatedAt > $1.updatedAt }.prefix(8))
        case .nightlyAudit, .fullWiki:
            touchedPages = visiblePages
        }
        let lintFindings = WikiLintEngine().findings(
            pages: pages,
            claims: claims,
            entities: entities,
            contradictions: contradictions,
            reviewQueue: reviewQueue
        )
        return WikiMaintenancePlanner().plan(
            touchedPages: touchedPages,
            allPages: pages,
            lintFindings: lintFindings,
            contradictions: contradictions,
            operation: scope.rawValue,
            target: "The Colony"
        )
    }

    public func proposeWikiPatch(reason: String, touchedPageIDs: [String]) -> WikiPatchProposal {
        let touched = touchedPageIDs.compactMap { getWikiPage(pageIDOrPath: $0) }
        let beforeHashes = Dictionary(uniqueKeysWithValues: touched.map { ($0.id, Hashing.sha256(data: Data($0.markdown.utf8))) })
        var operations: [WikiPatchOperation] = touched.map { page in
            WikiPatchOperation(
                kind: .updateFrontmatter,
                pageID: page.id,
                frontmatterUpdates: [
                    "last_reviewed": ISO8601DateFormatter().string(from: Date()),
                    "review_reason": reason
                ]
            )
        }
        if touched.isEmpty {
            operations.append(WikiPatchOperation(
                kind: .markReviewNeeded,
                pageID: "wiki-health",
                markdown: reason
            ))
        }
        return WikiPatchProposal(
            reason: reason,
            touchedPageIDs: touched.map(\.id),
            beforeHashes: beforeHashes,
            operations: operations,
            confidenceLanguage: operations.count == touched.count && !operations.isEmpty ? "structured proposal" : "needs review",
            requiresUserReview: true
        )
    }
}

public struct WikiMaintenanceOrchestrator: Sendable {
    public init() {}

    public func runDryRun(
        toolbox: HiveWikiToolbox,
        scope: WikiMaintenanceScope = .nightlyAudit,
        now: Date = Date()
    ) -> WikiMaintenanceProposalEnvelope {
        let tasks = toolbox.planMaintenance(scope: scope)
        var touchedIDs = tasks.compactMap(\.pageID).filter { $0 != "index" && $0 != "log" }
        if touchedIDs.isEmpty {
            touchedIDs = toolbox.pages.filter(\.isUserVisibleArticle).prefix(3).map(\.id)
        }
        var proposal = toolbox.proposeWikiPatch(
            reason: "Review The Colony for \(scope.rawValue) and expand existing articles before creating new pages.",
            touchedPageIDs: touchedIDs
        )
        var operations = proposal.operations
        if tasks.contains(where: { $0.kind == .appendLog }) {
            operations.append(WikiPatchOperation(
                kind: .appendLogEntry,
                pageID: "log",
                markdown: "## [\(Self.logDate(now))] maintenance | \(scope.rawValue)"
            ))
        }
        if tasks.contains(where: { $0.kind == .reviewContradiction }) {
            operations.append(WikiPatchOperation(
                kind: .markReviewNeeded,
                pageID: "wiki-health",
                markdown: tasks
                    .filter { $0.kind == .reviewContradiction }
                    .map(\.detail)
                    .joined(separator: "\n")
            ))
        }
        proposal = WikiPatchProposal(
            reason: proposal.reason,
            touchedPageIDs: proposal.touchedPageIDs,
            beforeHashes: proposal.beforeHashes,
            operations: operations,
            confidenceLanguage: "structured proposal",
            requiresUserReview: true
        )
        return WikiMaintenanceProposalEnvelope(proposal: proposal, generatedAt: now)
    }

    public func runDryRunWithFoundationModels(
        toolbox: HiveWikiToolbox,
        scope: WikiMaintenanceScope = .nightlyAudit,
        orchestrator: HiveFoundationModelsOrchestrator = HiveFoundationModelsOrchestrator(),
        now: Date = Date()
    ) async -> WikiMaintenanceProposalEnvelope {
        let fallback = runDryRun(toolbox: toolbox, scope: scope, now: now)
        let tasks = toolbox.planMaintenance(scope: scope)
        let result = await orchestrator.planColonyPatch(
            reason: fallback.proposal.reason,
            pages: toolbox.pages,
            tasks: tasks,
            fallback: fallback.proposal
        )
        let proposal = result.proposal.wikiPatchProposal(fallback: fallback.proposal, pages: toolbox.pages)
        let envelope = WikiMaintenanceProposalEnvelope(proposal: proposal, generatedAt: now)
        return envelope.isValidProposal ? envelope : fallback
    }

    private static func logDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

public struct WikiMaintenanceTask: Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case updateIndex
        case appendLog
        case addCrossReference
        case refreshSummary
        case reviewContradiction
        case investigateGap
    }

    public var id: String
    public var kind: Kind
    public var pageID: String?
    public var title: String
    public var detail: String

    public init(kind: Kind, pageID: String?, title: String, detail: String) {
        self.id = "\(kind.rawValue)-\(pageID ?? WikiPageRecord.slugify(title))-\(Hashing.sha256(data: Data(detail.utf8)).prefix(8))"
        self.kind = kind
        self.pageID = pageID
        self.title = title
        self.detail = detail
    }
}

public struct WikiMaintenancePlanner: Sendable {
    public init() {}

    public func plan(
        touchedPages: [WikiPageRecord],
        allPages: [WikiPageRecord],
        lintFindings: [WikiLintFinding],
        contradictions: [ContradictionRecord],
        operation: String,
        target: String
    ) -> [WikiMaintenanceTask] {
        var tasks: [WikiMaintenanceTask] = [
            WikiMaintenanceTask(
                kind: .updateIndex,
                pageID: "index",
                title: "Update index",
                detail: "Refresh index.md after \(operation) | \(target) so agents can choose pages from the catalog first."
            ),
            WikiMaintenanceTask(
                kind: .appendLog,
                pageID: "log",
                title: "Append log",
                detail: #"Append `## [date] \#(operation) | \#(target)` to log.md so `grep "^## \[" log.md | tail -5` remains useful."#
            )
        ]

        for page in touchedPages where page.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tasks.append(WikiMaintenanceTask(
                kind: .refreshSummary,
                pageID: page.id,
                title: "Refresh summary for \(page.title)",
                detail: "\(page.title) needs a one-line summary for index search and qmd reranking."
            ))
        }

        for finding in lintFindings {
            if finding.title.hasPrefix("Missing cross-reference:") {
                tasks.append(WikiMaintenanceTask(
                    kind: .addCrossReference,
                    pageID: pageID(for: finding.title, pages: allPages),
                    title: finding.title,
                    detail: finding.detail
                ))
            } else if finding.title.hasPrefix("Research gap:") || finding.title.hasPrefix("Missing article:") {
                tasks.append(WikiMaintenanceTask(
                    kind: .investigateGap,
                    pageID: nil,
                    title: finding.title,
                    detail: finding.detail
                ))
            }
        }

        for contradiction in contradictions {
            tasks.append(WikiMaintenanceTask(
                kind: .reviewContradiction,
                pageID: nil,
                title: "Review contradiction: \(contradiction.title)",
                detail: contradiction.reason
            ))
        }
        return stableUnique(tasks)
    }

    private func pageID(for findingTitle: String, pages: [WikiPageRecord]) -> String? {
        guard let rawTitle = findingTitle.components(separatedBy: ":").dropFirst().first?
            .components(separatedBy: "→").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        return pages.first { $0.title.localizedCaseInsensitiveCompare(rawTitle) == .orderedSame }?.id
    }

    private func stableUnique(_ tasks: [WikiMaintenanceTask]) -> [WikiMaintenanceTask] {
        var seen = Set<String>()
        var result: [WikiMaintenanceTask] = []
        for task in tasks where seen.insert(task.id).inserted {
            result.append(task)
        }
        return result
    }
}
