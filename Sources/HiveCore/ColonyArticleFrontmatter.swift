import Foundation

/// Controlled set of article categories used by the Colony wiki schema
/// (Prompt 3 Part 1). The raw values double as the on-disk frontmatter
/// `category` value and as the section ordering used by the index renderer.
public enum ColonyCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case entity
    case concept
    case project
    case source
    case synthesis
    case question
}

/// The full frontmatter schema for a Colony article. This is both the in-memory
/// model and the serializer for the YAML frontmatter block that is written to the
/// top of every article markdown file.
public struct ColonyArticleFrontmatter: Codable, Hashable, Sendable {
    public var title: String
    public var slug: String
    public var category: ColonyCategory
    public var tags: [String]
    public var created: Date
    public var updated: Date
    public var sourceCount: Int
    public var claimCount: Int
    public var confidence: Double
    public var related: [String]
    public var contradicts: [String]
    public var aliases: [String]
    public var isStub: Bool

    public init(
        title: String,
        slug: String,
        category: ColonyCategory,
        tags: [String] = [],
        created: Date = Date(),
        updated: Date = Date(),
        sourceCount: Int = 0,
        claimCount: Int = 0,
        confidence: Double = 0,
        related: [String] = [],
        contradicts: [String] = [],
        aliases: [String] = [],
        isStub: Bool = false
    ) {
        self.title = title
        self.slug = slug
        self.category = category
        self.tags = tags
        self.created = created
        self.updated = updated
        self.sourceCount = sourceCount
        self.claimCount = claimCount
        self.confidence = confidence
        self.related = related
        self.contradicts = contradicts
        self.aliases = aliases
        self.isStub = isStub
    }

    // MARK: - YAML serialization

    /// Renders the exact YAML frontmatter block (delimited by `---` lines) for
    /// this article. Keys are emitted in spec order using snake_case, dates as
    /// ISO8601, and arrays as inline flow sequences (`[a, b]`). The optional
    /// `aliases` key and the `stub: true` flag are only emitted when they carry
    /// meaningful (non-empty / true) values.
    public func renderYAML() -> String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("---")
        lines.append("title: \(Self.escapeScalar(title))")
        lines.append("slug: \(Self.escapeScalar(slug))")
        lines.append("category: \(category.rawValue)")
        lines.append("tags: \(Self.renderFlowSequence(tags))")
        lines.append("created: \(formatter.string(from: created))")
        lines.append("updated: \(formatter.string(from: updated))")
        lines.append("source_count: \(sourceCount)")
        lines.append("claim_count: \(claimCount)")
        lines.append("confidence: \(Self.renderConfidence(confidence))")
        lines.append("related: \(Self.renderFlowSequence(related))")
        lines.append("contradicts: \(Self.renderFlowSequence(contradicts))")
        if !aliases.isEmpty {
            lines.append("aliases: \(Self.renderFlowSequence(aliases))")
        }
        if isStub {
            lines.append("stub: true")
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    private static func renderFlowSequence(_ values: [String]) -> String {
        "[" + values.map(escapeScalar).joined(separator: ", ") + "]"
    }

    /// Quotes a scalar only when it contains characters that would otherwise
    /// confuse a YAML parser (flow indicators, colons, leading/trailing space).
    private static func escapeScalar(_ value: String) -> String {
        let needsQuoting = value.isEmpty
            || value != value.trimmingCharacters(in: .whitespaces)
            || value.contains(where: { ":#[]{},\"'".contains($0) })
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Confidence is a probability in `[0, 1]`; emit a compact decimal without
    /// trailing zeros so `0.0` becomes `0` and `0.5` stays `0.5`.
    private static func renderConfidence(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value.rounded()))
        }
        var text = String(format: "%.4f", value)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    // MARK: - Slug generation

    /// Produces a URL/file-safe slug from a title: lowercased, every run of
    /// non-alphanumeric characters collapsed to a single hyphen, with leading
    /// and trailing hyphens trimmed.
    public static func slugify(_ title: String) -> String {
        let lowered = title.lowercased()
        var result = ""
        var lastWasHyphen = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasHyphen = false
            } else if !lastWasHyphen {
                result.append("-")
                lastWasHyphen = true
            }
        }
        while result.hasPrefix("-") {
            result.removeFirst()
        }
        while result.hasSuffix("-") {
            result.removeLast()
        }
        return result
    }
}

/// The seed controlled vocabulary for article tags. Articles are encouraged to
/// reuse these tags before introducing new ones so the tag space stays small
/// and navigable.
public enum ColonyControlledVocabulary {
    public static let seed: [String] = [
        "mathematics",
        "programming",
        "education",
        "project",
        "personal",
        "finance",
        "productivity",
        "research",
        "health",
        "writing",
        "design",
        "tools",
        "people",
        "events",
        "locations"
    ]
}
