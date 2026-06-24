import Foundation

/// A single row in the Colony `index.md` file. The optional fields are used by
/// only some categories (e.g. `status` for projects, `relativeDate` for
/// entities and sources) and are ignored elsewhere.
public struct ColonyIndexEntry: Hashable, Sendable {
    public var slug: String
    public var category: ColonyCategory
    public var summary: String
    public var sourceCount: Int
    public var status: String?
    public var relativeDate: String?

    public init(
        slug: String,
        category: ColonyCategory,
        summary: String,
        sourceCount: Int = 0,
        status: String? = nil,
        relativeDate: String? = nil
    ) {
        self.slug = slug
        self.category = category
        self.summary = summary
        self.sourceCount = sourceCount
        self.status = status
        self.relativeDate = relativeDate
    }
}

/// Renders the Colony `index.md` file (Prompt 3 Part 3 Step 5). Entries are
/// grouped into category sections in a fixed order; empty sections are omitted.
public struct ColonyIndexRenderer: Sendable {
    public init() {}

    private struct Section {
        let category: ColonyCategory
        let heading: String
    }

    private static let sections: [Section] = [
        Section(category: .entity, heading: "## Entities"),
        Section(category: .concept, heading: "## Concepts"),
        Section(category: .project, heading: "## Projects"),
        Section(category: .source, heading: "## Sources"),
        Section(category: .synthesis, heading: "## Synthesis"),
        Section(category: .question, heading: "## Questions")
    ]

    public func render(entries: [ColonyIndexEntry], sourceCount: Int, now: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("# Colony Index")
        lines.append("")
        lines.append("_Last updated: \(formatter.string(from: now)) | \(entries.count) articles | \(sourceCount) sources_")

        for section in Self.sections {
            let sectionEntries = entries.filter { $0.category == section.category }
            guard !sectionEntries.isEmpty else { continue }
            lines.append("")
            lines.append(section.heading)
            for entry in sectionEntries {
                lines.append(line(for: entry))
            }
        }

        return lines.joined(separator: "\n")
    }

    private func line(for entry: ColonyIndexEntry) -> String {
        let base = "- [[\(entry.slug)]] — \(entry.summary)"
        guard let suffix = suffix(for: entry) else { return base }
        return "\(base) \(suffix)"
    }

    private func suffix(for entry: ColonyIndexEntry) -> String? {
        switch entry.category {
        case .entity:
            let date = entry.relativeDate ?? "unknown"
            return "(\(entry.sourceCount) sources, updated \(date))"
        case .project:
            let status = entry.status ?? "unknown"
            return "(Status: \(status))"
        case .source:
            let date = entry.relativeDate ?? "unknown"
            return "(ingested \(date))"
        case .synthesis:
            return "(generated from \(entry.sourceCount) sources)"
        case .concept, .question:
            return nil
        }
    }
}
