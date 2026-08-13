import Foundation

// MARK: - Preference memory

/// A user-owned preference that can be applied as a soft ranking signal.
///
/// Preferences are deliberately separate from arbitrary model notes. They have a
/// stable taxonomy path, an explicit lifecycle, evidence, and a confidence score.
/// A preference never grants permission and never becomes a hard filter by itself.
public struct PreferenceMemory: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let path: String
    public let value: String
    public let confidence: Double
    public let evidence: String
    public let scope: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                path: String,
                value: String,
                confidence: Double,
                evidence: String,
                scope: String = "global",
                createdAt: Date = Date()) {
        self.id = id
        self.path = path
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
        self.evidence = String(evidence.prefix(240))
        self.scope = scope
        self.createdAt = createdAt
    }

    /// Converts a durable Honeycomb preference node back into a typed preference.
    /// Inactive/withdrawn nodes are not returned because retrieval must not surface
    /// superseded user intent.
    public init?(node: HoneycombStore.Node) {
        guard node.type == .preference,
              case let .object(metadata) = node.metadata,
              let path = metadata["path"].stringValue,
              let value = metadata["value"].stringValue,
              metadata["status"].stringValue != "withdrawn" else { return nil }
        let confidence = metadata["confidence"].doubleValue ?? 0
        guard confidence > 0 else { return nil }
        self.init(
            id: node.id,
            path: path,
            value: value,
            confidence: confidence,
            evidence: metadata["evidence"].stringValue ?? "",
            scope: metadata["scope"].stringValue ?? "global",
            createdAt: node.createdAt
        )
    }

    /// A preference is relevant only when its taxonomy is relevant to the user's
    /// current request. This is intentionally conservative: global memory is not
    /// automatically dumped into every unrelated answer.
    public static func isRelevant(path: String, value: String, to query: String) -> Bool {
        let queryWords = Set(query.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init))
        guard !queryWords.isEmpty else { return false }

        let pathWords = Set(path.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init))
        let valueWords = Set(value.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init))

        // Direct mentions are strongest: asking for "vegetarian" or "dietary"
        // should retrieve the matching preference without a broader classifier.
        if !queryWords.isDisjoint(with: pathWords.union(valueWords)) { return true }

        // Food requests get food preferences as soft ranking signals. They do not
        // turn into a vegan-only filter; the downstream answer can still choose
        // restaurants with suitable options and explain uncertainty.
        let foodIntent: Set<String> = [
            "restaurant", "restaurants", "dining", "dinner", "lunch", "breakfast",
            "food", "meal", "meals", "recipe", "recipes", "eat", "eating",
            "cafe", "cafes", "menu", "menus", "recommend", "recommendation",
            "recommendations", "where"
        ]
        return path.lowercased().hasPrefix("food.") && !queryWords.isDisjoint(with: foodIntent)
    }

    /// Formats the preference as advisory context. It explicitly tells the model
    /// how to use dietary preferences: rank and explain, do not over-filter.
    public var promptLine: String {
        let payload: [String: String] = [
            "path": path,
            "value": value,
            "confidence": String(format: "%.2f", confidence),
            "scope": scope,
            "evidence": evidence
        ]
        let encoded = (try? JSONEncoder().encode(payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "- preference_data: \(encoded)"
    }
}

// MARK: - Candidate extraction

public enum PreferenceAction: String, Sendable, Codable, Equatable {
    case set
    case withdraw
}

/// A candidate produced only from the user's own request. External page text and
/// model output are never accepted as direct preference writes.
public struct PreferenceCandidate: Sendable, Codable, Equatable {
    public let path: String
    public let value: String
    public let action: PreferenceAction
    public let confidence: Double
    public let evidence: String

    public init(path: String, value: String, action: PreferenceAction,
                confidence: Double, evidence: String) {
        self.path = path
        self.value = value
        self.action = action
        self.confidence = min(max(confidence, 0), 1)
        self.evidence = String(evidence.prefix(240))
    }
}

/// Conservative first-pass preference extraction.
///
/// This intentionally recognizes explicit first-person statements rather than
/// asking a model to decide what should become durable memory. It avoids false
/// positives such as "find vegetarian restaurants" and leaves ambiguous language
/// for a future confirmation UI or a typed model proposal.
public enum PreferenceExtractor {
    public static func extract(from text: String) -> [PreferenceCandidate] {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return [] }
        let normalized = original.lowercased()
        // Only direct user statements may become durable preferences. Common
        // attribution/quotation forms indicate external content and are kept
        // out of the write path to avoid memory poisoning by a webpage, email,
        // or pasted transcript.
        let externalAttribution = [
            "the page says", "this page says", "the website says", "the article says",
            "the email says", "quoted text", "quote:", "someone says", "they say"
        ]
        guard !externalAttribution.contains(where: { normalized.contains($0) }) else { return [] }
        var candidates: [PreferenceCandidate] = []

        let vegetarianSet = containsAny(normalized, [
            "i'm vegetarian", "i am vegetarian", "i'm a vegetarian", "i am a vegetarian",
            "my diet is vegetarian", "i don't eat meat", "i do not eat meat",
            "i avoid meat"
        ])
        let vegetarianWithdraw = containsAny(normalized, [
            "i'm no longer vegetarian", "i am no longer vegetarian",
            "i'm not vegetarian anymore", "i am not vegetarian anymore",
            "i eat meat now"
        ])
        if vegetarianSet || vegetarianWithdraw {
            candidates.append(.init(
                path: "food.preferences.dietary.vegetarian",
                value: "vegetarian",
                action: vegetarianWithdraw ? .withdraw : .set,
                confidence: vegetarianWithdraw ? 0.98 : 0.95,
                evidence: original
            ))
        }

        let veganSet = containsAny(normalized, [
            "i'm vegan", "i am vegan", "i'm a vegan", "i am a vegan",
            "my diet is vegan", "i don't eat animal products", "i do not eat animal products"
        ])
        let veganWithdraw = containsAny(normalized, [
            "i'm no longer vegan", "i am no longer vegan", "i'm not vegan anymore",
            "i am not vegan anymore"
        ])
        if veganSet || veganWithdraw {
            candidates.append(.init(
                path: "food.preferences.dietary.vegan",
                value: "vegan",
                action: veganWithdraw ? .withdraw : .set,
                confidence: veganWithdraw ? 0.98 : 0.95,
                evidence: original
            ))
        }

        let glutenFreeSet = containsAny(normalized, [
            "i'm gluten-free", "i am gluten-free", "i'm gluten free", "i am gluten free",
            "i avoid gluten", "i don't eat gluten", "i do not eat gluten"
        ])
        if glutenFreeSet {
            candidates.append(.init(
                path: "food.preferences.dietary.gluten_free",
                value: "gluten-free",
                action: .set,
                confidence: 0.94,
                evidence: original
            ))
        }

        for allergen in ["peanuts", "peanut", "shellfish", "sesame", "tree nuts"] {
            if containsAny(normalized, [
                "i'm allergic to \(allergen)", "i am allergic to \(allergen)",
                "i have a \(allergen) allergy", "i cannot eat \(allergen)",
                "i can't eat \(allergen)"
            ]) {
                candidates.append(.init(
                    path: "food.preferences.allergies.\(allergen.replacingOccurrences(of: " ", with: "_"))",
                    value: allergen,
                    action: .set,
                    confidence: 0.99,
                    evidence: original
                ))
            }
        }

        return candidates
    }

    private static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }
}

// MARK: - Durable bridge

public enum PreferenceMemoryBridge {
    /// Persists candidates into Honeycomb and mirrors active preferences into hot
    /// memory. Only candidates from the user's intent should reach this method.
    /// Conflicting values in the same taxonomy path are withdrawn before the new
    /// value is inserted, retaining the old node as an auditable revision.
    public static func persist(
        _ candidates: [PreferenceCandidate],
        in honeycomb: HoneycombStore,
        hotMemory: HotMemoryStore
    ) async {
        guard !candidates.isEmpty else { return }
        for candidate in candidates {
            guard candidate.confidence >= 0.9 else { continue }
            let nodes = (try? await honeycomb.getNodesByType(.preference, limit: 1000)) ?? []
            let matchingPath = nodes.filter { node in
                guard case let .object(metadata) = node.metadata else { return false }
                return metadata["path"].stringValue == candidate.path
            }

            switch candidate.action {
            case .withdraw:
                for node in matchingPath where PreferenceMemory(node: node) != nil {
                    let metadata = withdrawnMetadata(from: node.metadata)
                    _ = try? await honeycomb.updateNode(id: node.id, metadata: metadata)
                    await hotMemory.removeNode(id: node.id)
                }

            case .set:
                for node in matchingPath where PreferenceMemory(node: node) != nil {
                    guard case let .object(metadata) = node.metadata,
                          metadata["value"].stringValue != candidate.value else { continue }
                    _ = try? await honeycomb.updateNode(id: node.id, metadata: withdrawnMetadata(from: node.metadata))
                    await hotMemory.removeNode(id: node.id)
                }

                let existingValueNode = matchingPath.first { node in
                    guard case let .object(metadata) = node.metadata else { return false }
                    return metadata["value"].stringValue == candidate.value
                }
                let metadata: JSONValue = .object([
                    "path": .string(candidate.path),
                    "value": .string(candidate.value),
                    "status": .string("active"),
                    "confidence": .double(candidate.confidence),
                    "evidence": .string(candidate.evidence),
                    "scope": .string("global"),
                    "source": .string("user-intent")
                ])
                let storedID: String
                if let existingValueNode {
                    // Idempotent update: re-stating a preference refreshes its
                    // evidence/confidence instead of colliding on the same ID.
                    // This also reactivates a withdrawn value with the same
                    // deterministic ID instead of silently losing the write.
                    _ = try? await honeycomb.updateNode(id: existingValueNode.id,
                                                        label: candidate.value,
                                                        metadata: metadata)
                    storedID = existingValueNode.id
                } else {
                    let node = HoneycombStore.Node(
                        id: "preference-\(HoneycombStore.sha256(candidate.path + "|" + candidate.value))",
                        type: .preference,
                        label: candidate.value,
                        metadata: metadata,
                        contentHash: HoneycombStore.sha256(candidate.path + "|" + candidate.value),
                        provenance: "user-preference"
                    )
                    guard let stored = try? await honeycomb.insertNode(node) else { continue }
                    storedID = stored.id
                }
                await hotMemory.didAccessGlobalNode(
                    id: storedID,
                    sourceHint: "preference",
                    label: "Preference: \(candidate.path)",
                    content: "\(candidate.value) — user-owned preference"
                )
            }
        }
    }

    /// Loads only active preferences whose taxonomy is relevant to the query.
    public static func relevantPreferences(
        for query: String,
        from honeycomb: HoneycombStore?
    ) async -> [PreferenceMemory] {
        await relevantPreferences(for: query, from: honeycomb, scope: .browserDefault)
    }

    /// Loads only preferences that are both query-relevant and admitted by the
    /// same context scope as hot memory. Global preferences are allowed; a
    /// future scoped preference must match the active profile/workspace/project.
    public static func relevantPreferences(
        for query: String,
        from honeycomb: HoneycombStore?,
        scope: ContextScope
    ) async -> [PreferenceMemory] {
        guard let honeycomb else { return [] }
        let nodes = (try? await honeycomb.getNodesByType(.preference, limit: 1000)) ?? []
        return nodes.compactMap(PreferenceMemory.init(node:)).filter {
            scopeAdmits($0.scope, scope: scope) &&
            PreferenceMemory.isRelevant(path: $0.path, value: $0.value, to: query)
        }.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private static func scopeAdmits(_ storedScope: String, scope: ContextScope) -> Bool {
        guard storedScope != "global" else { return true }
        let components = storedScope.split(separator: "|", omittingEmptySubsequences: true)
        var profileID: String?
        var workspaceID: String?
        var projectID: String?
        for component in components {
            let pair = component.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { return false }
            switch pair[0] {
            case "profile": profileID = pair[1]
            case "workspace": workspaceID = pair[1]
            case "project": projectID = pair[1]
            default: return false
            }
        }
        return profileID == scope.profileID &&
               workspaceID == scope.workspaceID &&
               projectID == scope.projectID
    }

    private static func withdrawnMetadata(from metadata: JSONValue) -> JSONValue {
        guard case let .object(values) = metadata else {
            return .object(["status": .string("withdrawn")])
        }
        var updated = values
        updated["status"] = .string("withdrawn")
        return .object(updated)
    }
}

// MARK: - JSONValue convenience accessors

private extension Optional where Wrapped == JSONValue {
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        default: return nil
        }
    }
}
