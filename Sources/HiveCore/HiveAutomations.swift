import Foundation

public enum HiveAutomationKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case morningBriefing
    case callTranscript
    case personalKnowledgeBase
    case researchWiki
    case bookCompanion
    case businessWiki
    case competitiveAnalysis
    case clientKnowledgeVault
    case courseNotes
    case custom

    public var id: String { rawValue }
}

public enum HiveAutomationScheduleRole: String, Codable, Hashable, Sendable {
    case daily
    case onDemand
    case sourceDriven
    case custom
}

public struct HiveAutomationTemplate: Identifiable, Codable, Hashable, Sendable {
    public var id: HiveAutomationKind
    public var title: String
    public var summary: String
    public var promptTemplate: String
    public var defaultEnabled: Bool
    public var scheduleRole: HiveAutomationScheduleRole
    public var requiresInput: Bool

    public init(
        id: HiveAutomationKind,
        title: String,
        summary: String,
        promptTemplate: String,
        defaultEnabled: Bool = false,
        scheduleRole: HiveAutomationScheduleRole,
        requiresInput: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.promptTemplate = promptTemplate
        self.defaultEnabled = defaultEnabled
        self.scheduleRole = scheduleRole
        self.requiresInput = requiresInput
    }
}

public enum HiveAutomationCatalog {
    public static let defaultEnabledKinds: Set<HiveAutomationKind> = [.morningBriefing]

    public static let templates: [HiveAutomationTemplate] = [
        HiveAutomationTemplate(
            id: .morningBriefing,
            title: "Morning Briefing",
            summary: "Every morning, Hive reviews open actions, new Field sources, downloads, browser captures, and recent Colony changes.",
            promptTemplate: "Read Memory.md, new Field sources from the last 24 hours, recent downloads, approved browser captures, and Colony changes. Create a clean Swarm-only briefing with what needs attention today.",
            defaultEnabled: true,
            scheduleRole: .daily
        ),
        HiveAutomationTemplate(
            id: .callTranscript,
            title: "Process Call Transcript",
            summary: "Extract decisions, owners, deadlines, a short summary, and linked Colony pages from a meeting transcript.",
            promptTemplate: "Read the transcript from [source]. Extract every decision made, every action item with owner and deadline, and a 3-bullet summary. Add actions to The Colony, log decisions to decision-log.md, and create a topic page linking back to this transcript.",
            scheduleRole: .sourceDriven,
            requiresInput: true
        ),
        HiveAutomationTemplate(
            id: .personalKnowledgeBase,
            title: "Personal Knowledge Base",
            summary: "Track goals, health, self-improvement, journals, articles, and podcast notes without preserving low-signal clutter.",
            promptTemplate: "Build a personal knowledge base from approved sources. Keep specific goals, patterns, decisions, and recurring concerns; discard generic demographic or document-type facts.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .researchWiki,
            title: "Research Wiki",
            summary: "Accumulate articles, papers, reports, and evolving synthesis around a research question.",
            promptTemplate: "Integrate sources into a research wiki with claims, contradictions, open questions, source-backed comparisons, and an evolving thesis.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .bookCompanion,
            title: "Book Companion Wiki",
            summary: "File chapters into themes, characters, concepts, and reusable notes without flooding The Hive with every sentence.",
            promptTemplate: "Treat the book as a reference source. Create chapter summaries and concept links, but only promote user-relevant claims or actively studied material into The Hive.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .businessWiki,
            title: "Business Wiki",
            summary: "Maintain team decisions, customer calls, project docs, Slack exports, and meeting outcomes.",
            promptTemplate: "Build a business wiki from internal material. Extract decisions, owners, deadlines, customer facts, project context, and contradictions. Keep audit trails.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .competitiveAnalysis,
            title: "Competitive Analysis Vault",
            summary: "Track competitor pricing, features, hiring, positioning, and changes over time.",
            promptTemplate: "Maintain a competitor intelligence vault. Extract dated observations, source-backed claims, comparisons, and changes since the last source.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .clientKnowledgeVault,
            title: "Client Knowledge Vault",
            summary: "Keep client facts, preferences, open loops, decisions, and context searchable and current.",
            promptTemplate: "Build a client knowledge vault. Extract client-specific decisions, constraints, preferences, people, deadlines, and follow-up actions.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .courseNotes,
            title: "Course Notes",
            summary: "Create a study wiki across textbooks, lectures, notes, assignments, and exams.",
            promptTemplate: "Build a course wiki. Ask whether the user is taking the course, studying for fun, or using the material as reference before promoting textbook content into The Hive.",
            scheduleRole: .sourceDriven
        ),
        HiveAutomationTemplate(
            id: .custom,
            title: "Custom Automation",
            summary: "Guide the user through a scoped source, schedule, output, and privacy policy for their own automation.",
            promptTemplate: "Ask for the automation goal, sources, cadence, output page, review policy, and whether it may update The Colony or only draft a proposal.",
            scheduleRole: .custom,
            requiresInput: true
        )
    ]

    public static func template(for kind: HiveAutomationKind) -> HiveAutomationTemplate {
        templates.first { $0.id == kind } ?? templates[0]
    }

    public static func normalizedEnabledKinds(
        _ rawKinds: Set<HiveAutomationKind>,
        customAutomations: [HiveCustomAutomationDefinition] = []
    ) -> Set<HiveAutomationKind> {
        var enabledKinds = Set<HiveAutomationKind>()
        if rawKinds.contains(.morningBriefing) {
            enabledKinds.insert(.morningBriefing)
        }
        if rawKinds.contains(.custom) || customAutomations.contains(where: \.isEnabled) {
            enabledKinds.insert(.custom)
        }
        return enabledKinds
    }
}

public struct HiveAutomationSettings: Codable, Hashable, Sendable {
    public var enabledKinds: Set<HiveAutomationKind>
    public var morningBriefingHour: Int
    public var morningBriefingMinute: Int
    public var customAutomations: [HiveCustomAutomationDefinition]

    public init(
        enabledKinds: Set<HiveAutomationKind> = HiveAutomationCatalog.defaultEnabledKinds,
        morningBriefingHour: Int = HiveMaintenanceSchedule.defaultHour,
        morningBriefingMinute: Int = HiveMaintenanceSchedule.defaultMinute,
        customAutomations: [HiveCustomAutomationDefinition] = []
    ) {
        self.enabledKinds = HiveAutomationCatalog.normalizedEnabledKinds(
            enabledKinds,
            customAutomations: customAutomations
        )
        self.morningBriefingHour = min(23, max(0, morningBriefingHour))
        self.morningBriefingMinute = min(59, max(0, morningBriefingMinute))
        self.customAutomations = customAutomations
    }

    public var morningBriefingEnabled: Bool {
        enabledKinds.contains(.morningBriefing)
    }

    public var maintenanceSchedule: HiveMaintenanceSchedule {
        HiveMaintenanceSchedule(
            enabled: morningBriefingEnabled,
            hour: morningBriefingHour,
            minute: morningBriefingMinute
        )
    }
}

public struct HiveCustomAutomationDefinition: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var goal: String
    public var sources: String
    public var cadence: String
    public var frequency: String?
    public var preferredTime: String?
    public var duration: String?
    public var output: String
    public var createdAt: Date
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        goal: String,
        sources: String,
        cadence: String,
        frequency: String? = nil,
        preferredTime: String? = nil,
        duration: String? = nil,
        output: String,
        createdAt: Date = Date(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.sources = sources
        self.cadence = cadence
        self.frequency = frequency
        self.preferredTime = preferredTime
        self.duration = duration
        self.output = output
        self.createdAt = createdAt
        self.isEnabled = isEnabled
    }

    public var scheduleSummary: String {
        let pieces = [frequency, preferredTime, duration, cadence]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? "On" : pieces.joined(separator: " · ")
    }
}

public enum HiveAutomationSettingsStore {
    public static let enabledKindsKey = "hive.automations.enabledKinds"
    public static let customAutomationsKey = "hive.automations.customDefinitions"

    public static func load(defaults: UserDefaults? = nil) -> HiveAutomationSettings {
        let defaults = defaults ?? HiveMaintenanceSchedule.makeSharedDefaults()
        let schedule = HiveMaintenanceSchedule.load(defaults: defaults)
        let customAutomations: [HiveCustomAutomationDefinition]
        if let data = defaults.data(forKey: customAutomationsKey),
           let decoded = try? JSONDecoder().decode([HiveCustomAutomationDefinition].self, from: data) {
            customAutomations = decoded
        } else {
            customAutomations = []
        }
        let rawKinds = defaults.stringArray(forKey: enabledKindsKey)
        let enabledKinds: Set<HiveAutomationKind>
        if let rawKinds {
            enabledKinds = HiveAutomationCatalog.normalizedEnabledKinds(
                Set(rawKinds.compactMap(HiveAutomationKind.init(rawValue:))),
                customAutomations: customAutomations
            )
        } else {
            enabledKinds = HiveAutomationCatalog.defaultEnabledKinds
        }
        return HiveAutomationSettings(
            enabledKinds: enabledKinds,
            morningBriefingHour: schedule.hour,
            morningBriefingMinute: schedule.minute,
            customAutomations: customAutomations
        )
    }

    public static func save(_ settings: HiveAutomationSettings, defaults: UserDefaults? = nil) {
        let defaults = defaults ?? HiveMaintenanceSchedule.makeSharedDefaults()
        defaults.set(settings.enabledKinds.map(\.rawValue).sorted(), forKey: enabledKindsKey)
        if let data = try? JSONEncoder().encode(settings.customAutomations) {
            defaults.set(data, forKey: customAutomationsKey)
        }
        settings.maintenanceSchedule.save(defaults: defaults)
    }
}

public struct HiveAutomationReadinessReport: Codable, Hashable, Sendable {
    public var settings: HiveAutomationSettings
    public var lastMorningBriefingRun: Date?
    public var nextMorningBriefingRun: Date?
    public var sourceRequest: HiveStartupSourcePluginRequest

    public init(
        settings: HiveAutomationSettings,
        lastMorningBriefingRun: Date?,
        nextMorningBriefingRun: Date?,
        sourceRequest: HiveStartupSourcePluginRequest
    ) {
        self.settings = settings
        self.lastMorningBriefingRun = lastMorningBriefingRun
        self.nextMorningBriefingRun = nextMorningBriefingRun
        self.sourceRequest = sourceRequest
    }

    public var morningStatusTitle: String {
        settings.morningBriefingEnabled ? "Morning Briefing is ready" : "Morning Briefing is paused"
    }

    public var morningStatusDetail: String {
        if !settings.morningBriefingEnabled {
            return "Turn it on when you want Hive to prepare a daily Swarm briefing."
        }
        if sourceRequest.canRunWithoutPicker {
            return "Hive can gather approved source requests automatically, then update Field, Colony, and Swarm."
        }
        return "Hive will still brief known Field and Colony work. Add source locations below when you want automatic intake."
    }

    public var enabledTemplateCount: Int {
        settings.enabledKinds.subtracting([.custom]).count
    }

    public var enabledCustomAutomationCount: Int {
        settings.customAutomations.filter(\.isEnabled).count
    }

    public static func current(now: Date = Date(), defaults: UserDefaults? = nil) -> HiveAutomationReadinessReport {
        let defaults = defaults ?? HiveMaintenanceSchedule.makeSharedDefaults()
        let settings = HiveAutomationSettingsStore.load(defaults: defaults)
        let schedule = settings.maintenanceSchedule
        let lastRun = defaults.object(forKey: HiveMaintenanceSchedule.lastRunKey) as? Date
        let nextRun = schedule.enabled ? schedule.nextRun(after: now) : nil
        return HiveAutomationReadinessReport(
            settings: settings,
            lastMorningBriefingRun: lastRun,
            nextMorningBriefingRun: nextRun,
            sourceRequest: HiveStartupSourcePluginCatalog.load()
        )
    }
}

public enum HiveSourceUseIntent: String, Codable, Hashable, Sendable {
    case personalKnowledgeBase
    case researchWiki
    case bookCompanion
    case businessWiki
    case competitiveAnalysis
    case clientKnowledgeVault
    case courseNotes
    case unknown
}

public struct HiveSourceIntentReview: Codable, Hashable, Sendable {
    public var intent: HiveSourceUseIntent
    public var shouldAskBeforePromotingToHive: Bool
    public var suggestedQuestion: String?
    public var retentionGuidance: String

    public init(
        intent: HiveSourceUseIntent,
        shouldAskBeforePromotingToHive: Bool,
        suggestedQuestion: String? = nil,
        retentionGuidance: String
    ) {
        self.intent = intent
        self.shouldAskBeforePromotingToHive = shouldAskBeforePromotingToHive
        self.suggestedQuestion = suggestedQuestion
        self.retentionGuidance = retentionGuidance
    }
}

public struct HiveSourceIntentClassifier: Sendable {
    public init() {}

    public func review(title: String, text: String, sourceKind: SourceKind? = nil) -> HiveSourceIntentReview {
        let corpus = "\(title)\n\(text)".lowercased()
        let wordCount = corpus.split { $0.isWhitespace || $0.isNewline }.count
        let isLargeReference = wordCount > 12_000
            || containsAny(corpus, ["textbook", "chapter", "isbn", "course syllabus", "lecture notes", "problem set"])

        if containsAny(corpus, ["competitor", "pricing", "positioning", "market share", "feature comparison"]) {
            return HiveSourceIntentReview(
                intent: .competitiveAnalysis,
                shouldAskBeforePromotingToHive: false,
                retentionGuidance: "Track dated competitor observations and comparisons; do not create generic product-name nodes without user relevance."
            )
        }
        if containsAny(corpus, ["client", "stakeholder", "customer call", "account plan", "renewal"]) {
            return HiveSourceIntentReview(
                intent: .clientKnowledgeVault,
                shouldAskBeforePromotingToHive: false,
                retentionGuidance: "Keep client-specific facts, decisions, constraints, and follow-ups with source links."
            )
        }
        if containsAny(corpus, ["meeting transcript", "call transcript", "action item", "decision", "owner:"]) || sourceKind == .audio {
            return HiveSourceIntentReview(
                intent: .businessWiki,
                shouldAskBeforePromotingToHive: false,
                retentionGuidance: "Extract decisions, owners, deadlines, and topic pages. Do not keep filler conversation."
            )
        }
        if containsAny(corpus, ["paper", "abstract", "methodology", "literature review", "study", "research question"]) {
            return HiveSourceIntentReview(
                intent: .researchWiki,
                shouldAskBeforePromotingToHive: false,
                retentionGuidance: "Treat as research evidence. Keep claims, methods, contradictions, and synthesis."
            )
        }
        if isLargeReference {
            let hasStudyContext = containsAny(corpus, ["i am taking", "my class", "my course", "exam", "homework", "assignment", "professor", "for fun", "reference for"])
            return HiveSourceIntentReview(
                intent: hasStudyContext ? .courseNotes : .courseNotes,
                shouldAskBeforePromotingToHive: !hasStudyContext,
                suggestedQuestion: hasStudyContext ? nil : "Is this for a course, research, work, or just reference? Hive can keep the source without flooding The Hive.",
                retentionGuidance: "Keep the textbook as a source reference. Create summaries and links only where useful; do not promote every textbook fact into The Hive."
            )
        }
        return HiveSourceIntentReview(
            intent: .unknown,
            shouldAskBeforePromotingToHive: false,
            retentionGuidance: "Extract only source-backed facts that will still matter six months from now."
        )
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }
}

public struct MorningBriefingInput: Sendable {
    public var sources: [SourceRecord]
    public var claims: [ClaimRecord]
    public var reviewQueue: [ReviewQueueItem]
    public var auditEvents: [AuditEventRecord]
    public var now: Date

    public init(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        reviewQueue: [ReviewQueueItem],
        auditEvents: [AuditEventRecord],
        now: Date = Date()
    ) {
        self.sources = sources
        self.claims = claims
        self.reviewQueue = reviewQueue
        self.auditEvents = auditEvents
        self.now = now
    }
}

public struct MorningBriefingBuilder: Sendable {
    public init() {}

    public func build(input: MorningBriefingInput) -> WikiPageRecord {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: input.now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? input.now.addingTimeInterval(86_400)
        let last24Hours = input.now.addingTimeInterval(-86_400)
        let newSources = input.sources
            .filter { $0.importedAt >= last24Hours && $0.deletionState == .active }
            .sorted { $0.importedAt > $1.importedAt }
        let dueToday = input.claims.filter { claim in
            guard claim.status != .retracted else { return false }
            if let eventDate = claim.temporalState?.eventDate {
                return eventDate >= dayStart && eventDate < dayEnd
            }
            let lower = claim.statement.lowercased()
            return containsAny(lower, ["due today", "by today", "deadline today", "today"])
        }
        let openReview = input.reviewQueue.prefix(6)
        let recentAudit = input.auditEvents
            .filter { $0.timestamp >= last24Hours }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(6)

        let title = "Morning Briefing - \(Self.dayFormatter.string(from: input.now))"
        var lines: [String] = [
            "# \(title)",
            "",
            "> Swarm generated this page for the morning briefing. It is a chat-only briefing, not a permanent topic page.",
            "",
            "## Needs Attention Today"
        ]
        if dueToday.isEmpty && openReview.isEmpty {
            lines.append("- Nothing urgent found in The Colony.")
        } else {
            for claim in dueToday.prefix(8) {
                lines.append("- \(claim.statement)")
            }
            for item in openReview {
                lines.append("- Review: \(item.title)")
            }
        }

        lines.append(contentsOf: ["", "## New Field Sources"])
        if newSources.isEmpty {
            lines.append("- No new Field sources in the last 24 hours.")
        } else {
            for source in newSources.prefix(10) {
                lines.append("- \(source.title) - \(source.kind.rawValue)")
            }
        }

        lines.append(contentsOf: ["", "## Knowledge Changes"])
        if recentAudit.isEmpty {
            lines.append("- No logged Colony or Hive changes in the last 24 hours.")
        } else {
            for event in recentAudit {
                let detail = event.detail.isEmpty ? event.eventType : event.detail
                lines.append("- \(detail)")
            }
        }

        lines.append(contentsOf: [
            "",
            "## Suggested Next Step",
            "- Ask Swarm what changed, process a staged source, or open the review queue if anything above needs confirmation."
        ])

        return WikiPageRecord(
            id: "morning-briefing-\(Self.idFormatter.string(from: input.now))",
            title: title,
            markdown: lines.joined(separator: "\n"),
            sourceRefs: Array(newSources.prefix(20).map(\.id)),
            claimRefs: Array(dueToday.prefix(20).map(\.id)),
            updatedAt: input.now,
            kind: .answer,
            summary: "Daily Swarm briefing for open actions, new sources, and recent knowledge changes.",
            frontmatter: [
                "automation": HiveAutomationKind.morningBriefing.rawValue,
                "surface": "swarm-chat-only",
                "local_ai": "apple-intelligence-when-available"
            ]
        )
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let idFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

public struct CallTranscriptActionItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var owner: String?
    public var deadline: String?

    public init(id: String = UUID().uuidString, text: String, owner: String? = nil, deadline: String? = nil) {
        self.id = id
        self.text = text
        self.owner = owner
        self.deadline = deadline
    }
}

public struct CallTranscriptProcessingPlan: Codable, Hashable, Sendable {
    public var summaryBullets: [String]
    public var decisions: [String]
    public var actions: [CallTranscriptActionItem]
    public var topicPage: WikiPageRecord
    public var decisionLogPage: WikiPageRecord
    public var actionClaims: [ClaimRecord]
}

public struct CallTranscriptProcessor: Sendable {
    public init() {}

    public func process(transcriptTitle: String, text: String, sourceID: String, now: Date = Date()) -> CallTranscriptProcessingPlan {
        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let sentences = rawLines
            .flatMap { $0.split(separator: ".") }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let decisions = sentences.filter { line in
            let lower = line.lowercased()
            return containsAny(lower, ["decided", "decision", "agreed", "approved", "we will", "we're going to"])
        }.prefix(12).map(normalizeBullet)

        let actions = rawLines.filter { line in
            let lower = line.lowercased()
            return containsAny(lower, ["action", "todo", "to do", "follow up", "owner", "deadline", " due ", " by "])
        }.prefix(12).map { line in
            CallTranscriptActionItem(
                text: normalizeBullet(line),
                owner: owner(in: line),
                deadline: deadline(in: line)
            )
        }

        let summary = Array(rawLines.prefix(3).map(normalizeBullet))
        let safeTitle = transcriptTitle.isEmpty ? "Call Transcript" : transcriptTitle
        let topicTitle = "\(safeTitle) Notes"
        let actionClaims = actions.map { action in
            ClaimRecord(
                id: "action-\(sourceID)-\(abs(action.text.hashValue))",
                statement: action.text,
                claimType: "action-item",
                sourceRefs: [sourceID],
                confidence: 0.86,
                uncertaintyReason: "Extracted from call transcript",
                createdBy: "swarm-call-transcript",
                createdAt: now,
                temporalState: TemporalMemoryState(kind: .deadline, observedAt: now, stalenessPolicy: "review-after-deadline")
            )
        }

        var topicLines: [String] = [
            "# \(topicTitle)",
            "",
            "## Summary"
        ]
        topicLines += summary.isEmpty ? ["- No summary extracted."] : summary.map { "- \($0)" }
        topicLines += ["", "## Decisions"]
        topicLines += decisions.isEmpty ? ["- No explicit decisions found."] : decisions.map { "- \($0)" }
        topicLines += ["", "## Action Items"]
        topicLines += actions.isEmpty ? ["- No explicit action items found."] : actions.map { action in
            var value = "- \(action.text)"
            if let owner = action.owner { value += " Owner: \(owner)." }
            if let deadline = action.deadline { value += " Deadline: \(deadline)." }
            return value
        }
        topicLines += ["", "Source: \(safeTitle)"]

        let decisionLogMarkdown = decisionLogMarkdown(title: safeTitle, decisions: decisions, now: now)

        return CallTranscriptProcessingPlan(
            summaryBullets: summary,
            decisions: Array(decisions),
            actions: actions,
            topicPage: WikiPageRecord(
                id: "transcript-\(sourceID)-topic",
                title: topicTitle,
                markdown: topicLines.joined(separator: "\n"),
                sourceRefs: [sourceID],
                claimRefs: actionClaims.map(\.id),
                updatedAt: now,
                kind: .topic,
                summary: summary.first ?? "Call transcript notes with decisions and actions.",
                frontmatter: ["automation": HiveAutomationKind.callTranscript.rawValue]
            ),
            decisionLogPage: WikiPageRecord(
                id: "decision-log",
                title: "Decision Log",
                markdown: decisionLogMarkdown,
                sourceRefs: [sourceID],
                claimRefs: [],
                updatedAt: now,
                slug: "decision-log",
                kind: .topic,
                summary: "Chronological decisions extracted from meetings and calls.",
                frontmatter: [
                    "automation": HiveAutomationKind.callTranscript.rawValue,
                    "requested_path": "Colony/decision-log.md"
                ]
            ),
            actionClaims: actionClaims
        )
    }

    private func decisionLogMarkdown(title: String, decisions: [String], now: Date) -> String {
        var lines = [
            "# Decision Log",
            "",
            "## [\(Self.dayFormatter.string(from: now))] \(title)"
        ]
        if decisions.isEmpty {
            lines.append("- No explicit decisions found.")
        } else {
            lines += decisions.map { "- \($0)" }
        }
        return lines.joined(separator: "\n")
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private func normalizeBullet(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\s*[-*•]\s*"#, with: "", options: .regularExpression)
    }

    private func owner(in line: String) -> String? {
        let pattern = #"(?i)\bowner\s*[:=-]\s*([A-Za-z][A-Za-z0-9 _-]{0,40})"#
        return firstCapture(pattern: pattern, in: line)
    }

    private func deadline(in line: String) -> String? {
        let pattern = #"(?i)\b(?:deadline|due|by)\s*[:=-]?\s*([A-Za-z0-9 ,/-]{2,40})"#
        return firstCapture(pattern: pattern, in: line)
    }

    private func firstCapture(pattern: String, in line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let value = String(line[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

public struct HiveAutomationOrchestrator: Sendable {
    public var store: HiveStore
    public var paths: HivePaths

    public init(store: HiveStore, paths: HivePaths) {
        self.store = store
        self.paths = paths
    }

    @discardableResult
    public func runMorningBriefing(now: Date = Date()) throws -> WikiPageRecord {
        let sources = try store.fetchSources()
        let claims = try store.fetchClaims()
        let feedback = try store.fetchFeedback()
        let auditEvents = try store.fetchAuditEvents()
        let reviewQueue = ReviewQueueBuilder().build(claims: claims, sources: sources, feedback: feedback, now: now)
        let page = MorningBriefingBuilder().build(input: MorningBriefingInput(
            sources: sources,
            claims: claims,
            reviewQueue: reviewQueue,
            auditEvents: auditEvents,
            now: now
        ))
        try store.saveWikiPage(page)
        try store.appendAudit(AuditEventRecord(
            eventType: "automation.morningBriefing",
            targetType: "wikiPage",
            targetID: page.id,
            sourceRefs: page.sourceRefs,
            timestamp: now,
            detail: "Created Morning Briefing with \(page.sourceRefs.count) recent sources and \(page.claimRefs.count) due items."
        ))
        try WikiVaultManager(paths: paths).writeVault(pages: store.fetchWikiPages())
        return page
    }

    @discardableResult
    public func processCallTranscript(source: SourceRecord, transcriptText: String, now: Date = Date()) throws -> CallTranscriptProcessingPlan {
        let plan = CallTranscriptProcessor().process(
            transcriptTitle: source.title,
            text: transcriptText,
            sourceID: source.id,
            now: now
        )
        for claim in plan.actionClaims {
            try store.saveClaim(claim)
        }
        try store.saveWikiPage(plan.decisionLogPage)
        try store.saveWikiPage(plan.topicPage)
        try store.appendAudit(AuditEventRecord(
            eventType: "automation.callTranscript",
            targetType: "source",
            targetID: source.id,
            sourceRefs: [source.id],
            timestamp: now,
            detail: "Processed call transcript: \(plan.decisions.count) decisions, \(plan.actions.count) actions."
        ))
        try WikiVaultManager(paths: paths).writeVault(pages: store.fetchWikiPages())
        return plan
    }
}
