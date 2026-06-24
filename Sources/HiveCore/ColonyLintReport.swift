import Foundation

/// The Colony lint report (Prompt 3 Part 4). It surfaces structural health
/// problems across the wiki vault. Note: per the spec, contradictions are NOT
/// part of the lint report — they are tracked separately in article frontmatter.
public struct ColonyLintReport: Codable, Hashable, Sendable {
    public var orphans: [String]
    public var staleArticles: [String]
    public var unsourcedClaims: [String]
    public var brokenLinks: [String]
    public var potentialDuplicates: [String]
    public var autoRepairs: Int
    public var generated: Date

    public init(
        orphans: [String] = [],
        staleArticles: [String] = [],
        unsourcedClaims: [String] = [],
        brokenLinks: [String] = [],
        potentialDuplicates: [String] = [],
        autoRepairs: Int = 0,
        generated: Date = Date()
    ) {
        self.orphans = orphans
        self.staleArticles = staleArticles
        self.unsourcedClaims = unsourcedClaims
        self.brokenLinks = brokenLinks
        self.potentialDuplicates = potentialDuplicates
        self.autoRepairs = autoRepairs
        self.generated = generated
    }

    /// Renders the lint report as a markdown document: a YAML header carrying the
    /// generation timestamp and integer counts, followed by one section per
    /// problem class listing each offending item. There is intentionally no
    /// contradictions section.
    public func renderMarkdown() -> String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("---")
        lines.append("generated: \(formatter.string(from: generated))")
        lines.append("orphans: \(orphans.count)")
        lines.append("stale_articles: \(staleArticles.count)")
        lines.append("unsourced_claims: \(unsourcedClaims.count)")
        lines.append("broken_links: \(brokenLinks.count)")
        lines.append("potential_duplicates: \(potentialDuplicates.count)")
        lines.append("auto_repairs: \(autoRepairs)")
        lines.append("---")

        appendSection(&lines, heading: "## Orphans", items: orphans)
        appendSection(&lines, heading: "## Stale Articles", items: staleArticles)
        appendSection(&lines, heading: "## Unsourced Claims", items: unsourcedClaims)
        appendSection(&lines, heading: "## Broken Links", items: brokenLinks)
        appendSection(&lines, heading: "## Potential Duplicates", items: potentialDuplicates)

        return lines.joined(separator: "\n")
    }

    private func appendSection(_ lines: inout [String], heading: String, items: [String]) {
        lines.append("")
        lines.append(heading)
        for item in items {
            lines.append("- \(item)")
        }
    }
}
