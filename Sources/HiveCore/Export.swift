import Foundation

public struct ExportManifest: Codable, Hashable, Sendable {
    public var exportedAt: Date
    public var sourceCount: Int
    public var claimCount: Int
    public var entityCount: Int
    public var relationshipCount: Int
    public var auditEventCount: Int
    public var note: String
}

public struct HiveExporter: Sendable {
    public init() {}

    public func exportSnapshot(store: HiveStore, to directory: URL, now: Date = Date()) throws -> URL {
        let exportDirectory = directory.appendingPathComponent("Hive Export \(Self.timestamp(now))", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: exportDirectory.appendingPathComponent("wiki", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: exportDirectory.appendingPathComponent("data", isDirectory: true), withIntermediateDirectories: true)

        let sources = try store.fetchSources()
        let activeSourceIDs = Set(sources.map(\.id))
        let claims = try store.fetchClaims().filter { claim in
            !claim.sourceRefs.contains { !activeSourceIDs.contains($0) }
        }
        let activeClaimIDs = Set(claims.map(\.id))
        let activeChunkIDs = Set(try store.fetchChunks().filter { activeSourceIDs.contains($0.sourceID) }.map(\.id))
        let entities = try store.fetchEntities().filter { entity in
            entity.sourceRefs.isEmpty || !entity.sourceRefs.contains { !activeSourceIDs.contains($0) }
        }
        let activeEntityIDs = Set(entities.map(\.id))
        let activeNodeIDs = activeSourceIDs.union(activeClaimIDs).union(activeEntityIDs)
        let activeEvidenceIDs = activeNodeIDs.union(activeChunkIDs)
        let relationships = try store.fetchRelationships().filter { relationship in
            activeNodeIDs.contains(relationship.subjectID)
                && activeNodeIDs.contains(relationship.objectID)
                && !relationship.sourceSpanRefs.contains { !activeEvidenceIDs.contains($0) }
        }
        let pages = try store.fetchWikiPages().filter { page in
            !page.sourceRefs.contains { !activeSourceIDs.contains($0) }
                && !page.claimRefs.contains { !activeClaimIDs.contains($0) }
        }
        let feedback = try store.fetchFeedback().filter { feedback in
            switch feedback.targetType {
            case "source":
                return activeSourceIDs.contains(feedback.targetID)
            case "claim":
                return activeClaimIDs.contains(feedback.targetID)
            default:
                return true
            }
        }
        let audit = try store.fetchAuditEvents().filter { event in
            let refsAreActive = !event.sourceRefs.contains { !activeSourceIDs.contains($0) }
            guard refsAreActive else { return false }
            switch event.targetType {
            case "source":
                return activeSourceIDs.contains(event.targetID)
            case "claim":
                return activeClaimIDs.contains(event.targetID)
            default:
                return true
            }
        }

        for page in pages {
            let fileName = Self.safeFileName(page.title.isEmpty ? page.id : page.title)
            try page.markdown.write(
                to: exportDirectory.appendingPathComponent("wiki", isDirectory: true).appendingPathComponent("\(fileName).md"),
                atomically: true,
                encoding: .utf8
            )
        }

        try writeJSON(sources, named: "sources.json", in: exportDirectory)
        try writeJSON(claims, named: "claims.json", in: exportDirectory)
        try writeJSON(entities, named: "entities.json", in: exportDirectory)
        try writeJSON(relationships, named: "relationships.json", in: exportDirectory)
        try writeJSON(feedback, named: "feedback.json", in: exportDirectory)
        try writeJSON(audit, named: "audit.json", in: exportDirectory)

        let manifest = ExportManifest(
            exportedAt: now,
            sourceCount: sources.count,
            claimCount: claims.count,
            entityCount: entities.count,
            relationshipCount: relationships.count,
            auditEventCount: audit.count,
            note: "Raw blobs, browser database snapshots, API keys, and security-scoped bookmarks are not included."
        )
        try writeJSON(manifest, named: "manifest.json", in: exportDirectory)
        return exportDirectory
    }

    private func writeJSON<T: Encodable>(_ value: T, named fileName: String, in exportDirectory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let url = exportDirectory.appendingPathComponent("data", isDirectory: true).appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        return formatter.string(from: date)
    }

    private static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
    }
}
