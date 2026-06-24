import Foundation

public struct WikiMarpDeckExportResult: Hashable, Sendable {
    public var page: WikiPageRecord
    public var fileURL: URL?
    public var auditEvent: AuditEventRecord

    public init(page: WikiPageRecord, fileURL: URL?, auditEvent: AuditEventRecord) {
        self.page = page
        self.fileURL = fileURL
        self.auditEvent = auditEvent
    }
}

public struct WikiMarpDeckExporter: Sendable {
    public init() {}

    public func exportDeck(
        title: String,
        pages: [WikiPageRecord],
        now: Date = Date(),
        destinationDirectory: URL? = nil
    ) throws -> WikiMarpDeckExportResult {
        let visiblePages = pages.filter(\.isUserVisibleArticle)
        let cleanTitle = SourcePresentationModel.cleanTitle(title).trimmingCharacters(in: .whitespacesAndNewlines)
        let deckTitle = cleanTitle.isEmpty ? "Hive Briefing" : cleanTitle
        let id = "marp-\(Hashing.sha256(data: Data((deckTitle + visiblePages.map(\.id).joined()).utf8)).prefix(16))"
        let slug = WikiPageRecord.slugify("Slide Deck - \(deckTitle)")
        let sourceRefs = Array(Set(visiblePages.flatMap(\.sourceRefs))).sorted()
        let claimRefs = Array(Set(visiblePages.flatMap(\.claimRefs))).sorted()
        let markdown = marpMarkdown(title: deckTitle, pages: visiblePages, sourceRefs: sourceRefs, now: now)
        let frontmatter = [
            "deck_title": deckTitle,
            "format": "marp",
            "id": id,
            "kind": WikiPageKind.answer.rawValue,
            "marp": "true",
            "page_count": String(max(1, visiblePages.count + 1)),
            "slug": slug,
            "source_count": String(sourceRefs.count),
            "updated": ISO8601DateFormatter().string(from: now)
        ]
        var fileURL: URL?
        if let destinationDirectory {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            let destinationFile = destinationDirectory.appendingPathComponent("\(slug).marp.md")
            try markdown.write(to: destinationFile, atomically: true, encoding: .utf8)
            fileURL = destinationFile
        }
        let page = WikiPageRecord(
            id: id,
            title: "Slide Deck - \(deckTitle)",
            markdown: markdown,
            sourceRefs: sourceRefs,
            claimRefs: claimRefs,
            updatedAt: now,
            slug: slug,
            kind: .answer,
            summary: "Marp slide deck generated from \(visiblePages.count) Colony \(visiblePages.count == 1 ? "article" : "articles").",
            frontmatter: frontmatter,
            outboundLinks: visiblePages.map(\.title),
            filePath: fileURL?.path
        )
        let audit = AuditEventRecord(
            eventType: "wiki.marpDeckCreated",
            targetType: "wikiPage",
            targetID: page.id,
            sourceRefs: sourceRefs,
            timestamp: now,
            detail: "Created a Marp markdown slide deck from selected Colony articles."
        )
        return WikiMarpDeckExportResult(page: page, fileURL: fileURL, auditEvent: audit)
    }

    private func marpMarkdown(title: String, pages: [WikiPageRecord], sourceRefs: [String], now: Date) -> String {
        var slides: [String] = [
            """
            ---
            marp: true
            theme: default
            paginate: true
            title: "\(yamlEscaped(title))"
            ---

            # \(title)

            Generated from The Colony on \(shortDate(now)).

            \(sourceRefs.isEmpty ? "" : "\(sourceRefs.count) Field source\(sourceRefs.count == 1 ? "" : "s") support this deck.")
            """
        ]
        for page in pages.prefix(12) {
            slides.append(slide(for: page))
        }
        return slides.joined(separator: "\n\n---\n\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func slide(for page: WikiPageRecord) -> String {
        let bullets = bulletCandidates(from: page)
            .prefix(4)
            .map { "- \($0)" }
            .joined(separator: "\n")
        let body = bullets.isEmpty ? page.summary : bullets
        return """
        ## \(SourcePresentationModel.cleanTitle(page.title))

        \(body)

        [[\(page.title)]]
        """
    }

    private func bulletCandidates(from page: WikiPageRecord) -> [String] {
        let lines = page.markdown
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("---")
                    && !line.hasPrefix("#")
                    && !line.hasPrefix("```")
                    && !line.localizedCaseInsensitiveContains("hidden source")
            }
        let candidates = ([page.summary] + lines)
            .map { cleanBullet($0) }
            .filter { $0.count > 12 }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.lowercased()).inserted }
    }

    private func cleanBullet(_ value: String) -> String {
        var cleaned = value
            .trimmingCharacters(in: CharacterSet(charactersIn: "-*• \t"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if cleaned.hasSuffix(".") {
            cleaned.removeLast()
        }
        return String(cleaned.prefix(180))
    }

    private func yamlEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
