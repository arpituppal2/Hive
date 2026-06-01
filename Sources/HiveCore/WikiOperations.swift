import Foundation

public struct WikiQueryArchiveResult: Hashable, Sendable {
    public var page: WikiPageRecord
    public var auditEvent: AuditEventRecord

    public init(page: WikiPageRecord, auditEvent: AuditEventRecord) {
        self.page = page
        self.auditEvent = auditEvent
    }
}

public struct WikiOperationEngine: Sendable {
    public init() {}

    public func archiveAnswerPage(
        query: String,
        answer: CitedAnswer,
        relatedPages: [WikiPageRecord],
        previousPages: [WikiPageRecord],
        now: Date = Date()
    ) -> WikiQueryArchiveResult {
        let cleanedQuery = SourcePresentationModel.cleanTitle(query)
        let title = answerTitle(for: cleanedQuery)
        let id = "answer-\(Hashing.sha256(data: Data(cleanedQuery.lowercased().utf8)).prefix(16))"
        let previous = previousPages.first { $0.id == id }
        let sourceRefs = Array(Set(answer.citations.map(\.id))).sorted()
        let related = relatedWikiPages(for: cleanedQuery, answer: answer.answer, pages: relatedPages)
        let body = answerBody(title: title, query: cleanedQuery, answer: answer, relatedPages: related, now: now)
        let summary = answerSummary(answer.answer)
        let slug = WikiPageRecord.slugify(title)
        let frontmatter = [
            "answered_at": ISO8601DateFormatter().string(from: now),
            "id": id,
            "kind": WikiPageKind.answer.rawValue,
            "query": cleanedQuery,
            "slug": slug,
            "source_count": String(sourceRefs.count),
            "tags": "answer, query"
        ]
        let markdown = frontmatterBlock(frontmatter) + body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        let revision = previous.map { normalized($0.markdown) == normalized(markdown) ? $0.revision : $0.revision + 1 } ?? 1
        let page = WikiPageRecord(
            id: id,
            title: title,
            markdown: markdown,
            sourceRefs: sourceRefs,
            claimRefs: [],
            updatedAt: now,
            slug: slug,
            kind: .answer,
            summary: summary,
            frontmatter: frontmatter,
            revision: revision
        )
        let audit = AuditEventRecord(
            eventType: "wiki.answerFiled",
            targetType: "wikiPage",
            targetID: page.id,
            sourceRefs: sourceRefs,
            timestamp: now,
            detail: "Filed a local-memory answer page for: \(cleanedQuery)"
        )
        return WikiQueryArchiveResult(page: page, auditEvent: audit)
    }

    private func answerTitle(for query: String) -> String {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Saved Hive Answer" }
        let stripped = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "?.! "))
        return "Answer - \(String(stripped.prefix(72)))"
    }

    private func answerSummary(_ answer: String) -> String {
        let sentence = answer
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Saved answer"
        return String(sentence.prefix(180))
    }

    private func answerBody(
        title: String,
        query: String,
        answer: CitedAnswer,
        relatedPages: [WikiPageRecord],
        now: Date
    ) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "This page records a useful answer from Hive so the exploration remains part of the maintained wiki.",
            "",
            "## Question",
            query,
            "",
            "## Answer",
            answer.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        if !relatedPages.isEmpty {
            lines.append("")
            lines.append("## Related Wiki Pages")
            for page in relatedPages.prefix(8) {
                lines.append("- [[\(page.title)]]")
            }
        }
        if !answer.suggestedActions.isEmpty {
            lines.append("")
            lines.append("## Follow-Up")
            for action in answer.suggestedActions.prefix(5) {
                lines.append("- \(action)")
            }
        }
        lines.append("")
        lines.append("## Filing")
        lines.append("Filed \(shortDate(now)). Hidden source and claim references stay in page metadata for evidence trails.")
        return lines.joined(separator: "\n")
    }

    private func relatedWikiPages(for query: String, answer: String, pages: [WikiPageRecord]) -> [WikiPageRecord] {
        let tokens = searchTokens(query + " " + answer)
        guard !tokens.isEmpty else { return [] }
        return pages
            .filter(\.isUserVisibleArticle)
            .map { page -> (WikiPageRecord, Int) in
                let haystack = searchTokens(page.title + " " + page.summary + " " + page.markdown)
                return (page, haystack.intersection(tokens).count)
            }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.title.localizedCaseInsensitiveCompare($1.0.title) == .orderedAscending
                }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private func searchTokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = ["about", "answer", "because", "from", "have", "into", "that", "the", "this", "with"]
        return Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) })
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

    private func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
