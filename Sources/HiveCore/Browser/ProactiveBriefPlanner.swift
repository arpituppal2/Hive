import Foundation

/// P2.6 Proactive Briefing — pure planner for the Morning Brief's proactive
/// sections.
///
/// The brief template (Sources/Hive/WebChrome/brief/) already renders three
/// data-driven sections that Hive never filled before:
///   - `proactive_work`   (the "Started for you in a new tab" card)
///   - `painting.caption` (caption under the painting)
///   - `looking_ahead_blurb` (the looking-ahead section)
///
/// This planner derives those sections from what the user captured/noted/saved
/// in Honeycomb since yesterday, plus optional calendar events. It is pure and
/// deterministic — identical inputs produce identical output — so the contract
/// is testable from HiveCore without a CEF runtime. It is honest by default:
/// with no memory and no events it emits quiet fallbacks, never invented
/// items (the same contract as the rest of the brief).
public enum ProactiveBriefPlanner: Sendable {

    /// One Honeycomb node summarized for the planner. The planner never reads
    /// raw page content — titles and creation times only.
    public struct MemoryItem: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable {
            case capture
            case note
            case brief
            case source
            case claim
        }

        public let kind: Kind
        public let title: String
        public let createdAt: Date

        public init(kind: Kind, title: String, createdAt: Date) {
            self.kind = kind
            self.title = title
            self.createdAt = createdAt
        }
    }

    /// A calendar event. Wired from the app's EventKit adapter when the
    /// user opts into calendar-aware looking ahead; the planner accepts it
    /// unconditionally so the section stays testable without EventKit.
    public struct CalendarEvent: Sendable, Equatable {
        public let title: String
        public let start: Date

        public init(title: String, start: Date) {
            self.title = title
            self.start = start
        }
    }

    /// The "Started for you in a new tab" card content.
    public struct Work: Sendable, Equatable {
        public let title: String
        public let reasoning: String

        public init(title: String, reasoning: String) {
            self.title = title
            self.reasoning = reasoning
        }
    }

    public struct Plan: Sendable, Equatable {
        /// Nil when there is nothing to surface — the template hides the
        /// proactive card rather than showing an empty one.
        public let proactiveWork: Work?
        public let paintingCaption: String
        public let lookingAheadBlurb: String

        public init(proactiveWork: Work?, paintingCaption: String, lookingAheadBlurb: String) {
            self.proactiveWork = proactiveWork
            self.paintingCaption = paintingCaption
            self.lookingAheadBlurb = lookingAheadBlurb
        }
    }

    /// Deterministic 12-hour clock formatting for the looking-ahead section.
    /// Fixed en_US_POSIX locale so output is stable across machine locales;
    /// the timezone is taken from the injected calendar so the tests can pin
    /// the wall-clock output exactly.
    private static func timeFormatter(for calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    public static func plan(
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        memory: [MemoryItem],
        events: [CalendarEvent]
    ) -> Plan {
        let startOfToday = calendar.startOfDay(for: now)
        // Calendar math failure is not a data absence — degrade to the same
        // honest fallbacks as an empty day rather than silently blank sections.
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return Plan(
                proactiveWork: nil,
                paintingCaption: "A quiet start — nothing new saved to memory yet.",
                lookingAheadBlurb: "A clear day ahead — no calendar events on the agenda."
            )
        }

        // "Since yesterday": memory created from start-of-yesterday through now.
        let windowItems = memory.filter { $0.createdAt >= startOfYesterday && $0.createdAt <= now }
        let briefs = windowItems.filter { $0.kind == .brief }.sorted { $0.createdAt > $1.createdAt }
        let notes = windowItems.filter { $0.kind == .note }
        let captures = windowItems.filter { $0.kind == .capture }
        let total = windowItems.count

        // Proactive work: prefer a research brief (strongest signal), then
        // authored notes/captures. Nothing invented — no items, no card.
        let work: Work?
        if let latest = briefs.first {
            work = Work(
                title: latest.title,
                reasoning: "Your research brief from yesterday is ready to revisit."
            )
        } else if !notes.isEmpty || !captures.isEmpty {
            let what: String
            if notes.isEmpty {
                what = "\(captures.count) page\(captures.count == 1 ? "" : "s")"
            } else if captures.isEmpty {
                what = "\(notes.count) note\(notes.count == 1 ? "" : "s")"
            } else {
                what = "\(notes.count) note\(notes.count == 1 ? "" : "s") and \(captures.count) page\(captures.count == 1 ? "" : "s")"
            }
            work = Work(
                title: total == 1 ? "1 new item in memory" : "\(total) new items in memory",
                reasoning: "You saved \(what) since yesterday — Hive kept them ready to pick back up."
            )
        } else {
            work = nil
        }

        // Painting caption: memory-derived, quiet when empty.
        let paintingCaption: String
        if total == 0 {
            paintingCaption = "A quiet start — nothing new saved to memory yet."
        } else {
            paintingCaption = "\(total) new item\(total == 1 ? "" : "s") in memory since yesterday."
        }

        // Looking ahead: today's events first, then a memory-driven fallback.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let todaysEvents = events
            .filter { $0.start >= startOfToday && $0.start < tomorrow }
            .sorted { $0.start < $1.start }
        let lookingAheadBlurb: String
        if let first = todaysEvents.first {
            let time = timeFormatter(for: calendar).string(from: first.start)
            if todaysEvents.count == 1 {
                lookingAheadBlurb = "One event today — \(first.title) at \(time)."
            } else {
                lookingAheadBlurb = "\(todaysEvents.count) events today — first, \(first.title) at \(time)."
            }
        } else if total > 0 {
            lookingAheadBlurb = "No calendar events today — a clear runway to pick up \(total) saved item\(total == 1 ? "" : "s")."
        } else {
            lookingAheadBlurb = "A clear day ahead — no calendar events on the agenda."
        }

        return Plan(
            proactiveWork: work,
            paintingCaption: paintingCaption,
            lookingAheadBlurb: lookingAheadBlurb
        )
    }
}
