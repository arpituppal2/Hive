import Foundation

// MARK: - Citation formatting

/// Formats web-search sources into inline citations (`[1]`) and a footer block.
///
/// Ported from the MIT-licensed perplexed-plugin's citation pipeline:
///   - date normalization (published / updated)
///   - deduplication by URL
///   - continuous numbering even when merging with an existing citations section
///   - Markdown footer generation
///
/// Hive stores each source as a Honeycomb `Source` node; this formatter only renders
/// the human-readable citation layer.
public struct CitationFormatter: Sendable {

    /// Formats a source list into inline citation markers and a footer. Returns a
    /// tuple of (answerWithInlineCitations, footerMarkdown).
    ///
    /// - Parameters:
    ///   - answer: the synthesized answer text. The formatter looks for existing
    ///     citation markers like `[1]` and, if absent, appends the footer unchanged.
    ///   - sources: the sources to cite.
    ///   - startIndex: the index number for the first source (default 1).
    public static func format(
        answer: String,
        sources: [WebSearchSource],
        startIndex: Int = 1
    ) -> (answer: String, footer: String) {
        let deduped = deduplicate(sources)
        guard !deduped.isEmpty else { return (answer, "") }

        let numbered = deduped.indexed(startingAt: startIndex)
        let footer = formatFooter(numbered: numbered)

        // If the answer already contains `[n]` style markers, leave it alone.
        let hasInlineMarkers = answer.range(of: "\\[\\d+\\]", options: .regularExpression) != nil
        let finalAnswer = hasInlineMarkers ? answer : appendInlineMarkers(answer: answer, sources: numbered)
        return (finalAnswer, footer)
    }

    /// Returns a short "Published: Jan 15, 2024 | Updated: ..." string.
    public static func formatPublicationInfo(date: String?, lastUpdated: String?) -> String {
        let published = date?.trimmingCharacters(in: .whitespaces)
        let updated = lastUpdated?.trimmingCharacters(in: .whitespaces)
        let publishedFormatted = published.flatMap(formatDate) ?? published
        let updatedFormatted = updated.flatMap(formatDate) ?? updated
        switch (publishedFormatted, updatedFormatted) {
        case let (p?, u?) where !p.isEmpty && !u.isEmpty:
            return "Published: \(p) | Updated: \(u)"
        case let (p?, _) where !p.isEmpty:
            return "Published: \(p)"
        case let (_, u?) where !u.isEmpty:
            return "Updated: \(u)"
        default:
            return ""
        }
    }

    // MARK: - Internal helpers

    private static func formatDate(_ string: String) -> String? {
        // Accept "2024-01-15" or "2024-01-15T..." and produce "Jan 15, 2024".
        guard let date = parseISO8601Date(string) else { return nil }
        return displayDate(date)
    }

    // MARK: - Internal

    private static func deduplicate(_ sources: [WebSearchSource]) -> [WebSearchSource] {
        var seen = Set<String>()
        var unique: [WebSearchSource] = []
        for source in sources {
            let key = source.url.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            unique.append(source)
        }
        return unique
    }

    private static func formatFooter(numbered: [(index: Int, source: WebSearchSource)]) -> String {
        guard !numbered.isEmpty else { return "" }
        var lines = ["### Citations", ""]
        for (index, source) in numbered {
            let pubInfo = formatPublicationInfo(date: source.date, lastUpdated: source.lastUpdated)
            let link = "[\(source.title)](\(source.url))"
            if pubInfo.isEmpty {
                lines.append("[\(index)]: \(link)")
            } else {
                lines.append("[\(index)]: \(pubInfo) \(link)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func appendInlineMarkers(
        answer: String,
        sources: [(index: Int, source: WebSearchSource)]
    ) -> String {
        // Naive heuristic: append a compact references block at the end of the answer.
        // A smarter model emits `[n]` markers itself; this fallback just makes citations visible.
        guard !sources.isEmpty else { return answer }
        let markers = sources.map { "[\($0.index)]" }.joined(separator: " ")
        return answer.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n_\(markers)_"
    }
}

private extension Array where Element == WebSearchSource {
    func indexed(startingAt: Int) -> [(index: Int, source: WebSearchSource)] {
        enumerated().map { (offset, source) in
            (index: startingAt + offset, source: source)
        }
    }
}

private func parseISO8601Date(_ string: String) -> Date? {
    // Date-only strings are treated as calendar dates in UTC so that a local
    // timezone does not shift "2024-01-15" to the previous day.
    let dateOnly = DateFormatter()
    dateOnly.dateFormat = "yyyy-MM-dd"
    dateOnly.timeZone = TimeZone(identifier: "UTC")

    // Full ISO-8601 timestamps (e.g. 2024-01-15T12:34:56Z).
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]

    return dateOnly.date(from: string) ?? iso.date(from: string)
}

private func displayDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
}
