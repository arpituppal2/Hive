import Foundation

public struct UserWikiEditCompilation: Sendable {
    public var page: WikiPageRecord
    public var claimsToSave: [ClaimRecord]
    public var feedbackToSave: [FeedbackRecord]
    public var auditEvents: [AuditEventRecord]

    public init(
        page: WikiPageRecord,
        claimsToSave: [ClaimRecord],
        feedbackToSave: [FeedbackRecord],
        auditEvents: [AuditEventRecord]
    ) {
        self.page = page
        self.claimsToSave = claimsToSave
        self.feedbackToSave = feedbackToSave
        self.auditEvents = auditEvents
    }
}

public struct UserWikiEditPolicy: Sendable {
    public static let authorityKey = "editAuthority"
    public static let authorityValue = "user"

    public init() {}

    public func compile(
        page: WikiPageRecord,
        editedMarkdown: String,
        existingClaims: [ClaimRecord],
        existingFeedback: [FeedbackRecord] = [],
        now: Date = Date()
    ) -> UserWikiEditCompilation {
        let body = Self.stripFrontmatter(editedMarkdown).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = Self.title(from: body, fallback: page.title)
        let statements = Self.authoritativeStatements(from: body)
        let scopedClaims = scopedExistingClaims(for: page, existingClaims: existingClaims)
        let existingByNormalized = Dictionary(grouping: existingClaims) { Self.normalizedStatement($0.statement) }
        let existingFeedbackKeys = Set(existingFeedback.map { "\($0.targetType)|\($0.targetID)|\($0.action.rawValue)" })
        let sourceRefs = page.sourceRefs
        let baseClaimRefs = Set(page.claimRefs)

        var claimsToSave: [ClaimRecord] = []
        var feedbackToSave: [FeedbackRecord] = []
        var authoritativeClaimIDs = Set<String>()

        for statement in statements {
            let normalized = Self.normalizedStatement(statement)
            if var existing = existingByNormalized[normalized]?.first(where: { $0.status != .retracted }) {
                existing.statement = statement
                existing.confidence = 1.0
                existing.status = .userCorrected
                existing.createdBy = "user-wiki-edit"
                existing.uncertaintyReason = "User correction for a Colony article; treated as canonical guidance."
                existing.correctionLineage.append("wiki:\(page.id)")
                claimsToSave.append(existing)
                authoritativeClaimIDs.insert(existing.id)
            } else {
                let id = Self.claimID(pageID: page.id, statement: statement)
                let claim = ClaimRecord(
                    id: id,
                    statement: statement,
                    claimType: "user-authored-wiki",
                    subjectEntityID: Self.subjectEntityID(for: page),
                    sourceRefs: sourceRefs,
                    confidence: 1.0,
                    uncertaintyReason: "User correction for a Colony article; treated as canonical guidance.",
                    status: .userCorrected,
                    createdBy: "user-wiki-edit",
                    createdAt: now,
                    correctionLineage: ["wiki:\(page.id)"]
                )
                claimsToSave.append(claim)
                authoritativeClaimIDs.insert(claim.id)
            }
        }

        let contradictionGroupID = "wiki-user-edit-\(page.id)-\(Int(now.timeIntervalSince1970))"
        for existing in scopedClaims where !authoritativeClaimIDs.contains(existing.id) && existing.status != .retracted {
            guard !Self.isUserWikiClaim(existing) else { continue }
            let strongest = statements
                .map { statement in (statement, Self.relationScore(statement, existing.statement)) }
                .max { $0.1 < $1.1 }
            guard let strongest, strongest.1 >= 0.42 else { continue }

            if Self.contradicts(strongest.0, existing.statement) {
                var updated = existing
                updated.status = .retracted
                updated.confidence = min(updated.confidence, 0.25)
                updated.contradictionGroupID = contradictionGroupID
                updated.uncertaintyReason = "Retracted by authoritative user correction on \(title)."
                updated.correctionLineage.append("wiki:\(page.id)")
                claimsToSave.append(updated)
            } else if strongest.1 >= 0.52 && Self.normalizedStatement(strongest.0) != Self.normalizedStatement(existing.statement) {
                var updated = existing
                updated.status = .suspect
                updated.confidence = min(updated.confidence, 0.66)
                updated.uncertaintyReason = "Possible mismatch with an authoritative user correction on \(title)."
                updated.correctionLineage.append("wiki:\(page.id)")
                claimsToSave.append(updated)

                let key = "claim|\(existing.id)|\(FeedbackAction.askLater.rawValue)"
                if !existingFeedbackKeys.contains(key) {
                    feedbackToSave.append(FeedbackRecord(
                        targetType: "claim",
                        targetID: existing.id,
                        action: .askLater,
                        note: "User correction may conflict or overlap with this memory: \(strongest.0)"
                    ))
                }
            }
        }

        var updatedPage = page
        updatedPage.title = title
        updatedPage.slug = WikiPageRecord.slugify(title)
        updatedPage.kind = page.kind
        updatedPage.markdown = Self.markdownWithFrontmatter(
            body: body.isEmpty ? "# \(title)\n\n" : body,
            pageID: page.id,
            kind: page.kind,
            slug: updatedPage.slug,
            previous: page
        )
        updatedPage.summary = Self.summary(from: body, fallback: page.summary)
        updatedPage.claimRefs = Array(baseClaimRefs.union(authoritativeClaimIDs)).sorted()
        updatedPage.sourceRefs = sourceRefs
        updatedPage.updatedAt = now
        updatedPage.revision = page.revision + 1
        updatedPage.frontmatter = Self.authoritativeFrontmatter(
            pageID: page.id,
            kind: page.kind,
            slug: updatedPage.slug,
            previous: page
        )

        let audit = AuditEventRecord(
            eventType: "wiki.userCorrectionApplied",
            targetType: "wikiPage",
            targetID: page.id,
            actor: "user",
            sourceRefs: sourceRefs,
            timestamp: now,
            detail: "User correction applied as canonical guidance with \(statements.count) authoritative statements."
        )

        return UserWikiEditCompilation(
            page: updatedPage,
            claimsToSave: Self.stableClaims(claimsToSave),
            feedbackToSave: feedbackToSave,
            auditEvents: [audit]
        )
    }

    public static func isUserAuthored(_ page: WikiPageRecord) -> Bool {
        page.frontmatter[authorityKey] == authorityValue
    }

    public static func stripFrontmatter(_ raw: String) -> String {
        guard raw.hasPrefix("---") else { return raw }
        let searchStart = raw.index(raw.startIndex, offsetBy: min(3, raw.count))
        guard let close = raw.range(of: "\n---\n", range: searchStart..<raw.endIndex) else {
            return raw
        }
        return String(raw[close.upperBound...])
    }

    public static func authoritativeStatements(from markdown: String) -> [String] {
        let body = stripFrontmatter(markdown)
        var statements: [String] = []
        var currentSection = ""
        for rawLine in body.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") {
                currentSection = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).lowercased()
                continue
            }
            if ["related concepts", "see also", "links", "references"].contains(currentSection) {
                continue
            }
            let cleaned = cleanStatement(trimmed)
            guard cleaned.count >= 18 else { continue }
            guard !MemoryCompiler.isRawLinkLike(cleaned) else { continue }
            statements.append(cleaned)
        }
        var seen = Set<String>()
        return statements.filter { seen.insert(normalizedStatement($0)).inserted }
    }

    private func scopedExistingClaims(for page: WikiPageRecord, existingClaims: [ClaimRecord]) -> [ClaimRecord] {
        let claimRefs = Set(page.claimRefs)
        let sourceRefs = Set(page.sourceRefs)
        return existingClaims.filter { claim in
            claimRefs.contains(claim.id)
                || (!sourceRefs.isEmpty && !Set(claim.sourceRefs).isDisjoint(with: sourceRefs))
                || claim.subjectEntityID == Self.subjectEntityID(for: page)
                || Self.relationScore(page.title, claim.statement) >= 0.28
        }
    }

    private static func title(from markdown: String, fallback: String) -> String {
        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("# ") {
                let title = cleanStatement(String(trimmed.dropFirst(2)))
                if !title.isEmpty { return title }
            }
        }
        return fallback.isEmpty ? "Untitled Article" : fallback
    }

    private static func summary(from markdown: String, fallback: String) -> String {
        for statement in authoritativeStatements(from: markdown) {
            return String(statement.prefix(180))
        }
        return fallback
    }

    private static func markdownWithFrontmatter(
        body: String,
        pageID: String,
        kind: WikiPageKind,
        slug: String,
        previous: WikiPageRecord
    ) -> String {
        authoritativeFrontmatter(pageID: pageID, kind: kind, slug: slug, previous: previous)
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
            .withFrontmatter(body: body)
    }

    private static func authoritativeFrontmatter(
        pageID: String,
        kind: WikiPageKind,
        slug: String,
        previous: WikiPageRecord
    ) -> [String: String] {
        var frontmatter = previous.frontmatter
        frontmatter["id"] = pageID
        frontmatter["kind"] = kind.rawValue
        frontmatter["slug"] = slug
        frontmatter[authorityKey] = authorityValue
        return frontmatter
    }

    private static func stableClaims(_ claims: [ClaimRecord]) -> [ClaimRecord] {
        var byID: [String: ClaimRecord] = [:]
        for claim in claims {
            byID[claim.id] = claim
        }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }

    private static func claimID(pageID: String, statement: String) -> String {
        let digest = Hashing.sha256(data: Data("\(pageID)|\(normalizedStatement(statement))".utf8))
        return "user-wiki-\(WikiPageRecord.slugify(pageID))-\(digest.prefix(16))"
    }

    private static func subjectEntityID(for page: WikiPageRecord) -> String? {
        if page.id.hasPrefix("entity-") {
            return String(page.id.dropFirst("entity-".count))
        }
        return nil
    }

    private static func cleanStatement(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("-") || value.hasPrefix("*") {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = value.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            value.removeSubrange(range)
        }
        value = value
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
        value = value.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedStatement(_ statement: String) -> String {
        statement
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func isUserWikiClaim(_ claim: ClaimRecord) -> Bool {
        claim.createdBy == "user-wiki-edit" || claim.claimType == "user-authored-wiki"
    }

    private static func relationScore(_ left: String, _ right: String) -> Double {
        let leftTokens = semanticTokens(left)
        let rightTokens = semanticTokens(right)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return 0 }
        let overlap = leftTokens.intersection(rightTokens)
        return Double(overlap.count) / Double(min(leftTokens.count, rightTokens.count))
    }

    private static func semanticTokens(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { token in
                token.count >= 4
                    && !["this", "that", "with", "from", "have", "user", "wiki", "article", "their", "there"].contains(token)
            })
    }

    private static func contradicts(_ left: String, _ right: String) -> Bool {
        guard relationScore(left, right) >= 0.42 else { return false }
        if containsNegation(left) != containsNegation(right) {
            return true
        }
        let leftNumbers = numberTokens(left)
        let rightNumbers = numberTokens(right)
        if !leftNumbers.isEmpty, !rightNumbers.isEmpty, leftNumbers.isDisjoint(with: rightNumbers), relationScore(left, right) >= 0.55 {
            return true
        }
        return opposingPreference(left, right) || opposingAbility(left, right)
    }

    private static func containsNegation(_ text: String) -> Bool {
        let lower = " \(text.lowercased()) "
        return [" not ", " never ", " no longer ", " cannot ", " can't ", " does not ", " doesn't ", " do not ", " don't ", " has no ", " without "].contains {
            lower.contains($0)
        }
    }

    private static func opposingPreference(_ left: String, _ right: String) -> Bool {
        let lowerLeft = left.lowercased()
        let lowerRight = right.lowercased()
        return (lowerLeft.contains("prefers") && (lowerRight.contains("dislikes") || lowerRight.contains("hates")))
            || (lowerRight.contains("prefers") && (lowerLeft.contains("dislikes") || lowerLeft.contains("hates")))
            || (lowerLeft.contains("wants") && lowerRight.contains("does not want"))
            || (lowerRight.contains("wants") && lowerLeft.contains("does not want"))
    }

    private static func opposingAbility(_ left: String, _ right: String) -> Bool {
        let lowerLeft = left.lowercased()
        let lowerRight = right.lowercased()
        return (lowerLeft.contains("can ") && lowerRight.contains("cannot "))
            || (lowerRight.contains("can ") && lowerLeft.contains("cannot "))
    }

    private static func numberTokens(_ text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        })
    }
}

private extension String {
    func withFrontmatter(body: String) -> String {
        "---\n\(self)\n---\n\(body.trimmingCharacters(in: .whitespacesAndNewlines))\n"
    }
}
