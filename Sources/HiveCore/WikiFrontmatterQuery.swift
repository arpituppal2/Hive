import Foundation

public enum WikiFrontmatterSortDirection: String, Codable, CaseIterable, Sendable {
    case ascending
    case descending
}

public struct WikiFrontmatterQuery: Hashable, Sendable {
    public var kind: WikiPageKind?
    public var tags: [String]
    public var filters: [String: String]
    public var sortKey: String
    public var sortDirection: WikiFrontmatterSortDirection
    public var limit: Int?
    public var columns: [String]

    public init(
        kind: WikiPageKind? = nil,
        tags: [String] = [],
        filters: [String: String] = [:],
        sortKey: String = "updated",
        sortDirection: WikiFrontmatterSortDirection = .descending,
        limit: Int? = nil,
        columns: [String] = ["title", "kind", "updated", "tags"]
    ) {
        self.kind = kind
        self.tags = tags
        self.filters = filters
        self.sortKey = sortKey
        self.sortDirection = sortDirection
        self.limit = limit
        self.columns = columns
    }
}

public struct WikiFrontmatterQueryEngine: Sendable {
    public init() {}

    public func query(_ pages: [WikiPageRecord], using query: WikiFrontmatterQuery) -> [WikiPageRecord] {
        var matches = pages.filter(\.isUserVisibleArticle)
        if let kind = query.kind {
            matches = matches.filter { $0.kind == kind }
        }
        if !query.tags.isEmpty {
            let required = Set(query.tags.map(normalizeToken))
            matches = matches.filter { page in
                required.isSubset(of: Set(tags(for: page).map(normalizeToken)))
            }
        }
        for (key, expectedValue) in query.filters {
            let expected = normalizeToken(expectedValue)
            matches = matches.filter { page in
                normalizeToken(value(for: key, in: page)).contains(expected)
            }
        }
        matches.sort { left, right in
            let comparison = compare(left: value(for: query.sortKey, in: left), right: value(for: query.sortKey, in: right))
            return query.sortDirection == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
        if let limit = query.limit {
            return Array(matches.prefix(max(0, limit)))
        }
        return matches
    }

    public func parse(_ source: String) -> WikiFrontmatterQuery {
        if source.uppercased().contains("TABLE") || source.uppercased().contains("FROM") {
            return parseDataview(source)
        }
        var query = WikiFrontmatterQuery()
        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = parts[1]
            switch key {
            case "kind":
                query.kind = WikiPageKind(rawValue: value)
            case "tag", "tags":
                query.tags = splitList(value)
            case "sort":
                let sortParts = value.split(separator: " ").map(String.init)
                query.sortKey = sortParts.first ?? "updated"
                if sortParts.dropFirst().contains(where: { $0.lowercased().hasPrefix("asc") }) {
                    query.sortDirection = .ascending
                } else {
                    query.sortDirection = .descending
                }
            case "limit":
                query.limit = Int(value)
            case "columns":
                query.columns = splitList(value)
            case "where":
                let tokens = value.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if tokens.count == 2 {
                    query.filters[tokens[0]] = tokens[1]
                }
            default:
                query.filters[key] = value
            }
        }
        return query
    }

    public func parseDataview(_ source: String) -> WikiFrontmatterQuery {
        var query = WikiFrontmatterQuery()
        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("//") else { continue }
            let upper = line.uppercased()
            if upper.hasPrefix("TABLE ") {
                let rawColumns = String(line.dropFirst("TABLE ".count))
                query.columns = splitList(rawColumns).isEmpty ? ["title", "updated"] : splitList(rawColumns)
            } else if upper.hasPrefix("LIST") {
                query.columns = ["title", "updated"]
            } else if upper.hasPrefix("FROM ") {
                let tags = line
                    .dropFirst("FROM ".count)
                    .split(separator: " ")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#,\"'")) }
                    .filter { !$0.isEmpty }
                query.tags.append(contentsOf: tags)
            } else if upper.hasPrefix("WHERE ") {
                parseDataviewCondition(String(line.dropFirst("WHERE ".count)), into: &query)
            } else if upper.hasPrefix("SORT ") {
                let parts = line.dropFirst("SORT ".count).split(separator: " ").map(String.init)
                query.sortKey = parts.first ?? query.sortKey
                if parts.dropFirst().contains(where: { $0.localizedCaseInsensitiveContains("asc") }) {
                    query.sortDirection = .ascending
                } else {
                    query.sortDirection = .descending
                }
            } else if upper.hasPrefix("LIMIT ") {
                query.limit = Int(line.dropFirst("LIMIT ".count).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        query.tags = stableUnique(query.tags)
        return query
    }

    public func renderTable(pages: [WikiPageRecord], query: WikiFrontmatterQuery) -> String {
        let matches = self.query(pages, using: query)
        let columns = query.columns.isEmpty ? ["title"] : query.columns
        let header = "| " + columns.map(displayTitle(for:)).joined(separator: " | ") + " |"
        let separator = "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |"
        let rows = matches.map { page in
            "| " + columns.map { escapeTable(value(for: $0, in: page)) }.joined(separator: " | ") + " |"
        }
        return ([header, separator] + rows).joined(separator: "\n")
    }

    public func tags(for page: WikiPageRecord) -> [String] {
        let raw = page.frontmatter["tags"] ?? page.frontmatter["tag"] ?? ""
        let parsed = splitList(raw)
        return parsed.isEmpty ? [page.kind.rawValue] : parsed
    }

    public func value(for key: String, in page: WikiPageRecord) -> String {
        switch key.lowercased() {
        case "title":
            return SourcePresentationModel.cleanTitle(page.title)
        case "kind", "type":
            return page.kind.rawValue
        case "updated", "updatedat", "date":
            return ISO8601DateFormatter().string(from: page.updatedAt)
        case "sourcecount", "sources":
            return String(page.sourceRefs.count)
        case "claimcount", "claims":
            return String(page.claimRefs.count)
        case "tags":
            return tags(for: page).joined(separator: ", ")
        case "slug":
            return page.slug
        default:
            return page.frontmatter[key] ?? page.frontmatter[key.lowercased()] ?? ""
        }
    }

    private func splitList(_ value: String) -> [String] {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .components(separatedBy: CharacterSet(charactersIn: ","))
            .flatMap { $0.components(separatedBy: " ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \n\t")) }
            .filter { !$0.isEmpty }
    }

    private func parseDataviewCondition(_ condition: String, into query: inout WikiFrontmatterQuery) {
        let tokens = condition.components(separatedBy: "=").map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \n\t"))
        }
        guard tokens.count == 2 else { return }
        let key = tokens[0]
        let value = tokens[1]
        if key.localizedCaseInsensitiveCompare("kind") == .orderedSame || key.localizedCaseInsensitiveCompare("type") == .orderedSame {
            query.kind = WikiPageKind(rawValue: value)
        } else {
            query.filters[key] = value
        }
    }

    private func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(normalizeToken(value)).inserted {
            result.append(value)
        }
        return result
    }

    private func normalizeToken(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func compare(left: String, right: String) -> ComparisonResult {
        if let leftDouble = Double(left), let rightDouble = Double(right) {
            if leftDouble == rightDouble { return .orderedSame }
            return leftDouble < rightDouble ? .orderedAscending : .orderedDescending
        }
        if let leftDate = ISO8601DateFormatter().date(from: left),
           let rightDate = ISO8601DateFormatter().date(from: right) {
            return leftDate.compare(rightDate)
        }
        return left.localizedCaseInsensitiveCompare(right)
    }

    private func displayTitle(for key: String) -> String {
        switch key.lowercased() {
        case "sourcecount":
            return "Field"
        case "claimcount":
            return "Claims"
        case "updated", "updatedat":
            return "Updated"
        default:
            return key.prefix(1).uppercased() + key.dropFirst()
        }
    }

    private func escapeTable(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}

public struct WikiQueryBlockRenderer: Sendable {
    public init() {}

    public func render(markdown: String, pages: [WikiPageRecord]) -> String {
        guard markdown.contains("```hive-query") || markdown.contains("```dataview") else { return markdown }
        let pattern = #"(?s)```(?:hive-query|dataview)\s*\n(.*?)\n```"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }
        var rendered = markdown
        let nsMarkdown = markdown as NSString
        for match in regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length)).reversed() {
            let body = nsMarkdown.substring(with: match.range(at: 1))
            let engine = WikiFrontmatterQueryEngine()
            let table = engine.renderTable(pages: pages, query: engine.parse(body))
            if let range = Range(match.range, in: rendered) {
                rendered.replaceSubrange(range, with: table)
            }
        }
        return rendered
    }
}
