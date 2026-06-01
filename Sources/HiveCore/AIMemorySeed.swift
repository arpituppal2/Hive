import Foundation

public struct AIMemorySeed: Sendable {
    public var canonicalProfile: AIMemoryCanonicalProfile?
    public var entities: [AIMemoryEntity]
    public var confirmedClaims: [AIMemoryConfirmedClaim]
    public var unresolvedClaims: [AIMemoryUnresolvedClaim]
    public var refusedInferences: [AIMemoryRefusedInference]
    public var projects: [AIMemoryProject]
    public var sourceClusters: [AIMemorySourceCluster]
    public var relationshipEdges: [AIMemoryRelationshipEdge]
    public var wikiStarters: [AIMemoryWikiStarter]
    public var oneQuestionPriorities: [AIMemoryOneQuestionPriority]

    public var isEmpty: Bool {
        canonicalProfile == nil
            && entities.isEmpty
            && confirmedClaims.isEmpty
            && unresolvedClaims.isEmpty
            && refusedInferences.isEmpty
            && projects.isEmpty
            && sourceClusters.isEmpty
            && relationshipEdges.isEmpty
            && wikiStarters.isEmpty
            && oneQuestionPriorities.isEmpty
    }
}

public struct AIMemoryCanonicalProfile: Codable, Sendable {
    public var identity: AIMemoryIdentity
    public var preferences: [AIMemoryPreference]
    public var constraints: [AIMemoryPreference]
}

public struct AIMemoryIdentity: Codable, Sendable {
    public var name: String
    public var roleOrRoles: [String]
    public var locations: [String]
    public var organizations: [String]
    public var highConfidenceDescriptors: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case roleOrRoles = "role_or_roles"
        case locations
        case organizations
        case highConfidenceDescriptors = "high_confidence_descriptors"
    }
}

public struct AIMemoryPreference: Codable, Sendable {
    public var claim: String
    public var confidence: Double
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case claim
        case confidence
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemoryEntity: Codable, Sendable {
    public var id: String
    public var name: String
    public var type: String
    public var description: String
    public var confidence: Double
    public var aliases: [String]
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case description
        case confidence
        case aliases
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemoryConfirmedClaim: Codable, Sendable {
    public var id: String
    public var subject: String
    public var predicate: String
    public var object: String
    public var confidence: Double
    public var whyItMatters: String
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case predicate
        case object
        case confidence
        case whyItMatters = "why_it_matters"
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemoryUnresolvedClaim: Codable, Sendable {
    public var id: String
    public var claim: String
    public var confidence: Double
    public var whyUncertain: String
    public var bestFollowupQuestion: String
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case id
        case claim
        case confidence
        case whyUncertain = "why_uncertain"
        case bestFollowupQuestion = "best_followup_question"
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemoryRefusedInference: Codable, Sendable {
    public var id: String
    public var possibleInference: String
    public var reasonToRefuse: String
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case id
        case possibleInference = "possible_inference"
        case reasonToRefuse = "reason_to_refuse"
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemoryProject: Codable, Sendable {
    public var id: String
    public var name: String
    public var status: String
    public var summary: String
    public var goals: [String]
    public var stackOrTools: [String]
    public var relatedEntities: [String]
    public var confidence: Double
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case summary
        case goals
        case stackOrTools = "stack_or_tools"
        case relatedEntities = "related_entities"
        case confidence
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemorySourceCluster: Codable, Sendable {
    public var id: String
    public var label: String
    public var summary: String
    public var primaryEntities: [String]
    public var primaryProjects: [String]
    public var signalLevel: String
    public var whyThisClusterMatters: String

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case summary
        case primaryEntities = "primary_entities"
        case primaryProjects = "primary_projects"
        case signalLevel = "signal_level"
        case whyThisClusterMatters = "why_this_cluster_matters"
    }
}

public struct AIMemoryRelationshipEdge: Codable, Sendable {
    public var source: String
    public var target: String
    public var relationship: String
    public var confidence: Double
    public var evidenceQuote: String

    enum CodingKeys: String, CodingKey {
        case source
        case target
        case relationship
        case confidence
        case evidenceQuote = "evidence_quote"
    }
}

public struct AIMemoryWikiStarter: Codable, Sendable {
    public var title: String
    public var type: String
    public var starterSummary: String
    public var linkedEntities: [String]
    public var openQuestions: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case starterSummary = "starter_summary"
        case linkedEntities = "linked_entities"
        case openQuestions = "open_questions"
    }
}

public struct AIMemoryOneQuestionPriority: Codable, Sendable {
    public var question: String
    public var unlocks: String
}

public struct AIMemorySeedParser: Sendable {
    public init() {}

    public func parse(_ markdown: String) -> AIMemorySeed? {
        let decoder = JSONDecoder()
        guard markdown.localizedCaseInsensitiveContains("# HIVE MEMORY SEED") else {
            return parseStandaloneQuestionPriorities(markdown, decoder: decoder)
        }
        let profile: AIMemoryCanonicalProfile? = decodeSection("## 1.", in: markdown, decoder: decoder)
        let entities: [AIMemoryEntity] = decodeSection("## 2.", in: markdown, decoder: decoder) ?? []
        let confirmed: [AIMemoryConfirmedClaim] = decodeSection("## 3.", in: markdown, decoder: decoder) ?? []
        let unresolved: [AIMemoryUnresolvedClaim] = decodeSection("## 4.", in: markdown, decoder: decoder) ?? []
        let refused: [AIMemoryRefusedInference] = decodeSection("## 5.", in: markdown, decoder: decoder) ?? []
        let projects: [AIMemoryProject] = decodeSection("## 6.", in: markdown, decoder: decoder) ?? []
        let clusters: [AIMemorySourceCluster] = decodeSection("## 7.", in: markdown, decoder: decoder) ?? []
        let edges: [AIMemoryRelationshipEdge] = decodeSection("## 8.", in: markdown, decoder: decoder) ?? []
        let starters: [AIMemoryWikiStarter] = decodeSection("## 9.", in: markdown, decoder: decoder) ?? []
        let questions: [AIMemoryOneQuestionPriority] = decodeSection("## 10.", in: markdown, decoder: decoder) ?? []
        let seed = AIMemorySeed(
            canonicalProfile: profile,
            entities: entities,
            confirmedClaims: confirmed,
            unresolvedClaims: unresolved,
            refusedInferences: refused,
            projects: projects,
            sourceClusters: clusters,
            relationshipEdges: edges,
            wikiStarters: starters,
            oneQuestionPriorities: questions
        )
        return seed.isEmpty ? nil : seed
    }

    private func parseStandaloneQuestionPriorities(_ text: String, decoder: JSONDecoder) -> AIMemorySeed? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        let questions = (try? decoder.decode([AIMemoryOneQuestionPriority].self, from: data))
            ?? (try? decoder.decode(StandaloneQuestionPriorityPayload.self, from: data).oneQuestionPriorities)
        guard let questions, !questions.isEmpty else { return nil }
        return AIMemorySeed(
            canonicalProfile: nil,
            entities: [],
            confirmedClaims: [],
            unresolvedClaims: [],
            refusedInferences: [],
            projects: [],
            sourceClusters: [],
            relationshipEdges: [],
            wikiStarters: [],
            oneQuestionPriorities: questions
        )
    }

    private func decodeSection<T: Decodable>(_ headingPrefix: String, in markdown: String, decoder: JSONDecoder) -> T? {
        guard let block = jsonBlock(afterHeadingPrefix: headingPrefix, in: markdown),
              let data = block.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }

    private func jsonBlock(afterHeadingPrefix headingPrefix: String, in markdown: String) -> String? {
        guard let heading = markdown.range(of: headingPrefix, options: [.caseInsensitive]) else {
            return nil
        }
        let remainder = markdown[heading.upperBound...]
        guard let fence = remainder.range(of: "```json", options: [.caseInsensitive]) else {
            return nil
        }
        let afterFence = remainder[fence.upperBound...]
        guard let end = afterFence.range(of: "```") else {
            return nil
        }
        return String(afterFence[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct StandaloneQuestionPriorityPayload: Decodable {
    var oneQuestionPriorities: [AIMemoryOneQuestionPriority]

    enum CodingKeys: String, CodingKey {
        case oneQuestionPriorities = "one_question_priorities"
    }
}
