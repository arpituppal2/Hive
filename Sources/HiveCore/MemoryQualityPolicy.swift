import Foundation

public enum MemoryQualityPolicy {
    public static let minimumStandaloneArticleClaimCount = 2

    public static func normalizedTitle(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func isLowInformationStandaloneTitle(_ value: String) -> Bool {
        let normalized = normalizedTitle(value)
        return genericStandaloneTitles.contains(normalized)
            || contextlessToolTitles.contains(normalized)
            || isGeneratedMetadataFragment(value)
    }

    public static func isGeneratedMetadataFragment(_ value: String) -> Bool {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return true }
        let lowercased = raw.lowercased()
        let normalized = normalizedTitle(raw)

        if lowercased.contains("bundle=")
            || lowercased.contains("path=/")
            || lowercased.contains("running=")
            || lowercased.contains("lastused=")
            || lowercased.contains("uses=")
            || lowercased.hasPrefix("app: ")
            || lowercased.hasPrefix("app |") {
            return true
        }
        if generatedMetadataPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        if generatedMetadataNeedles.contains(where: { lowercased.contains($0) || normalized.contains($0) }) {
            return true
        }
        return false
    }

    public static func isContextlessToolTitle(_ value: String) -> Bool {
        contextlessToolTitles.contains(normalizedTitle(value))
    }

    public static func containsUserPredicate(_ value: String) -> Bool {
        let lower = " \(value.lowercased()) "
        return userPredicateFragments.contains { lower.contains($0) }
    }

    public static func isGeneratedArticleSubstantial(_ page: WikiPageRecord) -> Bool {
        guard !UserWikiEditPolicy.isUserAuthored(page) else { return true }
        guard [.topic, .person, .project].contains(page.kind) else { return true }
        if page.id.hasPrefix("starter-") { return true }
        if isLowInformationStandaloneTitle(page.title) { return false }
        if page.claimRefs.count >= minimumStandaloneArticleClaimCount { return true }
        if hasUserCenteredArticleEvidence(page) { return true }
        if page.sourceRefs.isEmpty && page.claimRefs.isEmpty { return false }
        return false
    }

    public static func supportsStandaloneEntityArticle(
        entity: EntityRecord,
        claimSentences: [String],
        previous: WikiPageRecord?
    ) -> Bool {
        if previous.map(UserWikiEditPolicy.isUserAuthored) == true { return true }
        if isLowInformationStandaloneTitle(entity.name) { return false }
        if entity.entityType == "user-context", claimSentences.contains(where: containsUserPredicate) {
            return true
        }
        if claimSentences.count >= minimumStandaloneArticleClaimCount {
            return true
        }
        if !isContextlessToolTitle(entity.name), claimSentences.contains(where: containsUserPredicate) {
            return true
        }
        return false
    }

    public static func shouldSuppressContextlessEntity(
        _ entity: EntityRecord,
        supportingClaims: [ClaimRecord]
    ) -> Bool {
        guard isContextlessToolTitle(entity.name) else { return false }
        return !supportingClaims.contains { claim in
            claim.status != .retracted
                && containsUserPredicate(claim.statement)
                && claim.statement.localizedCaseInsensitiveContains(entity.name)
        }
    }

    private static let userPredicateFragments: Set<String> = [
        " the user ",
        " user's ",
        " user ",
        " i ",
        " i'm ",
        " i am ",
        " i use ",
        " i use",
        " uses ",
        " using ",
        " builds ",
        " building ",
        " built ",
        " works ",
        " working ",
        " studies ",
        " prefers ",
        " wants ",
        " needs ",
        " owns ",
        " learned ",
        " knows ",
        " skilled ",
        " experience with "
    ]

    private static func hasUserCenteredArticleEvidence(_ page: WikiPageRecord) -> Bool {
        let text = [
            page.title,
            page.summary,
            WikiPresentationModel.articleBody(from: page.markdown)
        ].joined(separator: " ")
        return containsUserPredicate(text) && !isContextlessToolTitle(page.title)
    }

    private static let genericStandaloneTitles: Set<String> = [
        "work",
        "personal",
        "background",
        "professional",
        "creative",
        "analytical",
        "school",
        "education",
        "finance",
        "hardware",
        "health",
        "family",
        "system",
        "project",
        "projects",
        "tools",
        "tool",
        "workflow",
        "research",
        "shopping",
        "apps",
        "app",
        "battery health",
        "cycle count",
        "experience",
        "experiences",
        "life",
        "information",
        "thing",
        "things",
        "stuff",
        "note",
        "notes",
        "memory",
        "memories",
        "source",
        "sources",
        "idea",
        "ideas",
        "content",
        "topic",
        "topics",
        "general",
        "misc",
        "miscellaneous",
        "google sign in",
        "buy mac",
        "refurbished mac",
        "amazon",
        "ebay",
        "los angeles",
        "california",
        "ca",
        "united states",
        "usa",
        "us",
        "new york",
        "san francisco",
        "bay area",
        "cupertino",
        "austin",
        "seattle"
    ]

    private static let contextlessToolTitles: Set<String> = [
        "python",
        "react",
        "react js",
        "node",
        "node js",
        "next",
        "next js",
        "swift",
        "swiftui",
        "xcode",
        "metal",
        "figma",
        "notion",
        "obsidian",
        "unreal",
        "unreal engine",
        "unity",
        "blender",
        "canva",
        "github",
        "google drive",
        "macbook",
        "macbook pro",
        "m4 macbook",
        "m4 macbook pro",
        "mac studio",
        "m3 ultra mac studio"
    ]

    private static let generatedMetadataPrefixes: Set<String> = [
        "captured at:",
        "captured_at:",
        "captured:",
        "location to grab:",
        "location_to_grab:",
        "pasted location:",
        "pasted_location:",
        "enabled source plugins:",
        "enabled_source_plugins:",
        "prompt for hive:",
        "prompt_for_hive:",
        "capture kind:",
        "capture_kind:",
        "app:",
        "app |",
        "page capture"
    ]

    private static let generatedMetadataNeedles: Set<String> = [
        "captured at",
        "captured_at",
        "none pasted",
        "from downloads",
        "from assets",
        "enabled source plugins",
        "enabled_source_plugins",
        "google drive links and web pages uploads",
        "location to grab",
        "location_to_grab",
        "pasted location",
        "pasted_location",
        "prompt for hive",
        "prompt_for_hive",
        "capture kind",
        "capture_kind",
        "bundle com",
        "system applications utilities",
        "application monitor",
        "activity monitor",
        "activitymonitor"
    ]
}
