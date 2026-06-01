import Foundation

public enum SwarmPartnerCommand: Codable, Hashable, Sendable {
    case reorganizeTopic(String)
    case defineAutomation(String)
    case defineSkill(String)

    public var statusText: String {
        switch self {
        case .reorganizeTopic(let topic):
            return "Reorganizing \(topic)."
        case .defineAutomation:
            return "Setting up an automation."
        case .defineSkill:
            return "Creating a Hive skill."
        }
    }
}

public struct SwarmPartnerCommandRouter: Sendable {
    public init() {}

    public func route(_ rawPrompt: String) -> SwarmPartnerCommand? {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }
        let lower = prompt.lowercased()

        if let topic = payload(
            prompt: prompt,
            lower: lower,
            prefixes: [
                "reorganize everything to do with",
                "reorganise everything to do with",
                "reorganize everything about",
                "reorganise everything about",
                "organize everything to do with",
                "organise everything to do with",
                "clean up everything to do with",
                "clean up everything about"
            ]
        ) {
            return .reorganizeTopic(topic)
        }

        if containsAny(lower, terms: ["set up automation", "setup automation", "create automation", "make an automation", "schedule hive to", "have hive send me", "notify me when"]) {
            return .defineAutomation(prompt)
        }

        if containsAny(lower, terms: ["create a skill", "make a skill", "teach hive to", "new skill", "add a skill"]) {
            return .defineSkill(prompt)
        }

        return nil
    }

    private func payload(prompt: String, lower: String, prefixes: [String]) -> String? {
        for prefix in prefixes where lower.hasPrefix(prefix) {
            let index = prompt.index(prompt.startIndex, offsetBy: min(prefix.count, prompt.count))
            let value = prompt[index...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " ,.:;-_").union(.whitespacesAndNewlines))
            return value.isEmpty ? nil : String(value.prefix(96))
        }
        return nil
    }

    private func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }
}

public struct HiveSkillDefinition: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var instruction: String
    public var triggerPhrases: [String]
    public var createdAt: Date
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        instruction: String,
        triggerPhrases: [String],
        createdAt: Date = Date(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.triggerPhrases = triggerPhrases
        self.createdAt = createdAt
        self.isEnabled = isEnabled
    }
}

public enum HiveSkillDefinitionStore {
    public static let definitionsKey = "hive.skills.definitions"

    public static func load(defaults: UserDefaults? = nil) -> [HiveSkillDefinition] {
        let defaults = defaults ?? HiveMaintenanceSchedule.makeSharedDefaults()
        guard let data = defaults.data(forKey: definitionsKey),
              let decoded = try? JSONDecoder().decode([HiveSkillDefinition].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func save(_ definitions: [HiveSkillDefinition], defaults: UserDefaults? = nil) {
        let defaults = defaults ?? HiveMaintenanceSchedule.makeSharedDefaults()
        if let data = try? JSONEncoder().encode(definitions) {
            defaults.set(data, forKey: definitionsKey)
        }
    }

    public static func add(_ definition: HiveSkillDefinition, defaults: UserDefaults? = nil) {
        var definitions = load(defaults: defaults)
        definitions.insert(definition, at: 0)
        save(definitions, defaults: defaults)
    }
}

public struct SwarmReorganizationResult: Codable, Hashable, Sendable {
    public var topic: String
    public var page: WikiPageRecord
    public var matchedPageTitles: [String]
    public var matchedClaimCount: Int
    public var auditEvent: AuditEventRecord
}

public struct SwarmKnowledgeOrganizer: Sendable {
    public init() {}

    public func reorganize(
        topic: String,
        pages: [WikiPageRecord],
        claims: [ClaimRecord],
        now: Date = Date()
    ) -> SwarmReorganizationResult {
        let cleanTopic = SourcePresentationModel.cleanTitle(topic)
        let tokens = searchTokens(cleanTopic)
        let visiblePages = pages.filter(\.isUserVisibleArticle)
        let matchedPages = rankPages(visiblePages, tokens: tokens).prefix(12).map(\.page)
        let matchedClaims = claims
            .filter { claim in
                claim.status == .active && !searchTokens(claim.statement + " " + (claim.subjectEntityID ?? "")).isDisjoint(with: tokens)
            }
            .prefix(18)

        let id = "swarm-reorganized-\(WikiPageRecord.slugify(cleanTopic))"
        let previous = pages.first { $0.id == id }
        let sourceRefs = Array(Set(matchedPages.flatMap(\.sourceRefs) + matchedClaims.flatMap(\.sourceRefs))).sorted()
        let claimRefs = Array(Set(matchedPages.flatMap(\.claimRefs) + matchedClaims.map(\.id))).sorted()
        let pageTitle = "\(cleanTopic) Map"
        let summary = matchedPages.isEmpty && matchedClaims.isEmpty
            ? "Swarm created a workspace for organizing \(cleanTopic)."
            : "Swarm reorganized \(cleanTopic) across \(matchedPages.count) Colony pages and \(matchedClaims.count) claims."
        let frontmatter = [
            "id": id,
            "kind": WikiPageKind.synthesis.rawValue,
            "slug": WikiPageRecord.slugify(pageTitle),
            "topic": cleanTopic,
            "source_count": String(sourceRefs.count),
            "claim_count": String(claimRefs.count),
            "updated_by": "swarm"
        ]
        let markdown = frontmatterBlock(frontmatter) + markdownBody(
            title: pageTitle,
            topic: cleanTopic,
            pages: Array(matchedPages),
            claims: Array(matchedClaims),
            now: now
        )
        let page = WikiPageRecord(
            id: id,
            title: pageTitle,
            markdown: markdown,
            sourceRefs: sourceRefs,
            claimRefs: claimRefs,
            updatedAt: now,
            slug: WikiPageRecord.slugify(pageTitle),
            kind: .synthesis,
            summary: summary,
            frontmatter: frontmatter,
            outboundLinks: Array(Set(matchedPages.map(\.title))).sorted(),
            revision: (previous?.revision ?? 0) + 1
        )
        let audit = AuditEventRecord(
            eventType: "swarm.reorganizedTopic",
            targetType: "wikiPage",
            targetID: page.id,
            actor: "swarm",
            sourceRefs: sourceRefs,
            timestamp: now,
            detail: "Swarm reorganized knowledge around \(cleanTopic): \(matchedPages.count) pages, \(matchedClaims.count) claims."
        )
        return SwarmReorganizationResult(
            topic: cleanTopic,
            page: page,
            matchedPageTitles: matchedPages.map(\.title),
            matchedClaimCount: matchedClaims.count,
            auditEvent: audit
        )
    }

    private func rankPages(_ pages: [WikiPageRecord], tokens: Set<String>) -> [(page: WikiPageRecord, score: Int)] {
        guard !tokens.isEmpty else { return [] }
        return pages.compactMap { page in
            let haystack = searchTokens(page.title + " " + page.summary + " " + page.markdown)
            let overlap = haystack.intersection(tokens).count
            guard overlap > 0 else { return nil }
            let titleBoost = searchTokens(page.title).intersection(tokens).count * 4
            return (page, overlap + titleBoost)
        }
        .sorted {
            if $0.score == $1.score {
                return $0.page.updatedAt > $1.page.updatedAt
            }
            return $0.score > $1.score
        }
    }

    private func markdownBody(title: String, topic: String, pages: [WikiPageRecord], claims: [ClaimRecord], now: Date) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Swarm reorganized this area so related Colony pages, durable claims, and next steps live together.",
            "",
            "## What Hive Knows"
        ]
        if claims.isEmpty {
            lines.append("- No durable claims matched yet. Add sources or tell Swarm what belongs here.")
        } else {
            for claim in claims.prefix(12) {
                lines.append("- \(claim.statement)")
            }
        }

        lines.append("")
        lines.append("## Related Colony Pages")
        if pages.isEmpty {
            lines.append("- No existing Colony pages matched \(topic).")
        } else {
            for page in pages.prefix(12) {
                lines.append("- [[\(page.title)]]")
            }
        }

        lines.append("")
        lines.append("## Swarm Maintenance")
        lines.append("- Keep this page as the hub for future \(topic) sources.")
        lines.append("- Merge thin pages into this hub only when they repeat the same evidence.")
        lines.append("- Ask before promoting broad reference material into The Hive.")
        lines.append("")
        lines.append("Updated \(shortDate(now)).")
        return lines.joined(separator: "\n") + "\n"
    }

    private func searchTokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = ["about", "after", "again", "around", "before", "doing", "everything", "from", "have", "into", "that", "this", "with", "would"]
        return Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) })
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

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
