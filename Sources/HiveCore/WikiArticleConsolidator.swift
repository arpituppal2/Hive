import Foundation

public struct WikiArticleConsolidationResult: Sendable {
    public var page: WikiPageRecord
    public var removedPageIDs: [String]
    public var auditEvent: AuditEventRecord

    public init(page: WikiPageRecord, removedPageIDs: [String], auditEvent: AuditEventRecord) {
        self.page = page
        self.removedPageIDs = removedPageIDs
        self.auditEvent = auditEvent
    }
}

public struct WikiArticleConsolidator: Sendable {
    public init() {}

    public func consolidate(
        pages: [WikiPageRecord],
        selectedPageIDs: [String],
        primaryPageID: String? = nil,
        now: Date = Date()
    ) -> WikiArticleConsolidationResult? {
        let requested = Set(selectedPageIDs)
        let selected = pages.filter { requested.contains($0.id) && $0.isUserVisibleArticle }
        guard selected.count >= 2 else { return nil }

        guard let primary = primaryPageID.flatMap({ id in selected.first { $0.id == id } })
            ?? selected.sorted { $0.updatedAt > $1.updatedAt }.first else { return nil }
        let secondary = selected.filter { $0.id != primary.id }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        var consolidated = primary
        consolidated.sourceRefs = Array(Set(selected.flatMap(\.sourceRefs))).sorted()
        consolidated.claimRefs = Array(Set(selected.flatMap(\.claimRefs))).sorted()
        consolidated.outboundLinks = Array(Set(selected.flatMap(\.outboundLinks))).sorted()
        consolidated.inboundLinks = Array(Set(selected.flatMap(\.inboundLinks))).sorted()
        consolidated.summary = summary(primary: primary, secondary: secondary)
        consolidated.markdown = markdown(primary: primary, secondary: secondary)
        consolidated.updatedAt = now
        consolidated.revision = primary.revision + 1
        consolidated.frontmatter = frontmatter(for: consolidated, previous: primary)

        let removedIDs = secondary.map(\.id).sorted()
        let audit = AuditEventRecord(
            eventType: "wiki.articlesConsolidated",
            targetType: "wikiPage",
            targetID: primary.id,
            actor: "user",
            sourceRefs: consolidated.sourceRefs,
            timestamp: now,
            detail: "Consolidated \(selected.count) selected Colony articles into \(primary.title)."
        )
        return WikiArticleConsolidationResult(page: consolidated, removedPageIDs: removedIDs, auditEvent: audit)
    }

    private func markdown(primary: WikiPageRecord, secondary: [WikiPageRecord]) -> String {
        let title = SourcePresentationModel.cleanTitle(primary.title)
        let primaryLines = meaningfulLines(from: primary, title: title)
        let secondaryLines = secondary.flatMap { meaningfulLines(from: $0, title: SourcePresentationModel.cleanTitle($0.title)) }

        var seen = Set<String>()
        let allLines = (primaryLines + secondaryLines).filter { line in
            seen.insert(normalized(line)).inserted
        }

        var body: [String] = ["# \(title)", ""]
        if let lead = allLines.first(where: { $0.count > 42 && !$0.hasPrefix("##") }) {
            body.append(lead)
            body.append("")
        }
        let factualLines = allLines
            .filter { !$0.hasPrefix("##") }
            .filter { $0.count > 18 }
            .filter { normalized($0) != normalized(body.dropFirst(2).first ?? "") }
        if !factualLines.isEmpty {
            body.append("## Claims")
            for line in factualLines.prefix(18) {
                body.append("- \(line)")
            }
        }

        let related = Array(Set(secondary.map { SourcePresentationModel.cleanTitle($0.title) })
            .subtracting([title]))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if !related.isEmpty {
            body.append("")
            body.append("## Related Concepts")
            for item in related.prefix(8) {
                body.append("- [[\(item)]]")
            }
        }

        return frontmatterBlock(frontmatter(for: primary, previous: primary)) + body.joined(separator: "\n") + "\n"
    }

    private func meaningfulLines(from page: WikiPageRecord, title: String) -> [String] {
        WikiPresentationModel.articleBody(from: page.markdown)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                var cleaned = line
                while cleaned.hasPrefix("#") {
                    cleaned.removeFirst()
                }
                if cleaned.hasPrefix("- ") {
                    cleaned.removeFirst(2)
                }
                return cleanContentLine(cleaned)
            }
            .filter { line in
                let lower = line.lowercased()
                return normalized(line) != normalized(title)
                    && !["claims", "known information", "related concepts", "strong claims", "weak claims"].contains(lower)
                    && !lower.contains("raw input")
                    && !lower.contains("source refs")
                    && !MemoryCompiler.isRawLinkLike(line)
            }
    }

    private func summary(primary: WikiPageRecord, secondary: [WikiPageRecord]) -> String {
        if !primary.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return primary.summary
        }
        return secondary.first { !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?.summary
            ?? SourcePresentationModel.cleanTitle(primary.title)
    }

    private func frontmatter(for page: WikiPageRecord, previous: WikiPageRecord) -> [String: String] {
        var frontmatter = previous.frontmatter
        frontmatter["id"] = page.id
        frontmatter["kind"] = page.kind.rawValue
        frontmatter["slug"] = WikiPageRecord.slugify(page.title)
        frontmatter[UserWikiEditPolicy.authorityKey] = UserWikiEditPolicy.authorityValue
        return frontmatter
    }

    private func frontmatterBlock(_ values: [String: String]) -> String {
        var lines = ["---"]
        for key in values.keys.sorted() {
            let value = values[key, default: ""].replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("\(key): \"\(value)\"")
        }
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func cleanContentLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: " — topic", with: "")
            .replacingOccurrences(of: " — project", with: "")
            .replacingOccurrences(of: " -> ", with: " to ")
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
