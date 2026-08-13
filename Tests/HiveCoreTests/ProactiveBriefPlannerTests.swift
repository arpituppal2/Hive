import Foundation
import Testing
@testable import HiveCore

// MARK: - ProactiveBriefPlanner (P2.6)

/// P2.6 contract: the proactive brief sections are derived from real Honeycomb
/// memory + calendar events, never invented. Tests lock the pure planner's
/// windowing, honest fallbacks, and output shaping so the brief template's
/// `proactive_work` / `painting.caption` / `looking_ahead_blurb` keys can't
/// silently regress to empty or fabricated content.
@Suite("ProactiveBriefPlanner")
struct ProactiveBriefPlannerTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// A fixed Wednesday 2026-08-12 09:00 UTC so day math is deterministic.
    /// Built through the same calendar as the day helpers to keep the epoch
    /// arithmetic obvious and correct.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 9))!
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    private func item(_ kind: ProactiveBriefPlanner.MemoryItem.Kind, _ title: String, day: Int, hour: Int = 9)
        -> ProactiveBriefPlanner.MemoryItem {
        ProactiveBriefPlanner.MemoryItem(kind: kind, title: title, createdAt: date(day, hour: hour))
    }

    @Test func noMemoryNoEventsYieldsHonestFallbacks() {
        let plan = ProactiveBriefPlanner.plan(now: now, calendar: calendar, memory: [], events: [])
        #expect(plan.proactiveWork == nil,
                "With no memory there must be no proactive card — the template hides it.")
        #expect(plan.paintingCaption.contains("nothing new saved"),
                "Painting caption must stay quiet, not invent content.")
        #expect(plan.lookingAheadBlurb.contains("clear day"),
                "Looking-ahead must not claim events that don't exist.")
    }

    @Test func yesterdayWindowExcludesOlderMemory() {
        // Items from Aug 11 (yesterday) count; Aug 10 (two days ago) is outside
        // the "since yesterday" window.
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [
                item(.note, "Aug 11 note", day: 11),
                item(.note, "Aug 10 stale note", day: 10),
            ],
            events: []
        )
        #expect(plan.proactiveWork != nil)
        #expect(plan.proactiveWork?.reasoning.contains("1 note") == true,
                "Only the Aug 11 note should be counted.")
    }

    @Test func researchBriefIsPreferredWork() {
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [
                item(.note, "Quick note", day: 11),
                item(.brief, "Deep research: Swift concurrency", day: 11, hour: 18),
            ],
            events: []
        )
        #expect(plan.proactiveWork?.title == "Deep research: Swift concurrency")
        #expect(plan.proactiveWork?.reasoning.contains("research brief") == true)
    }

    @Test func notesAndCapturesFormWorkWhenNoBrief() {
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [
                item(.capture, "captured page", day: 11, hour: 10),
                item(.capture, "another page", day: 11, hour: 11),
                item(.note, "a note", day: 11, hour: 12),
            ],
            events: []
        )
        #expect(plan.proactiveWork != nil)
        #expect(plan.proactiveWork?.reasoning.contains("2 pages") == true)
        #expect(plan.proactiveWork?.reasoning.contains("1 note") == true)
    }

    @Test func todayEventAppearsInLookingAhead() {
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [],
            events: [.init(title: "Standup", start: date(12, hour: 10))]
        )
        #expect(plan.lookingAheadBlurb.contains("Standup"))
        #expect(plan.lookingAheadBlurb.contains("10:00 AM"))
        #expect(plan.lookingAheadBlurb.contains("One event today"))
    }

    @Test func multipleTodayEventsAreSummarized() {
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [],
            events: [
                .init(title: "Standup", start: date(12, hour: 10)),
                .init(title: "Review", start: date(12, hour: 15)),
            ]
        )
        #expect(plan.lookingAheadBlurb.contains("2 events today"))
        #expect(plan.lookingAheadBlurb.contains("Standup"))
    }

    @Test func tomorrowEventIsNotTodaysLookingAhead() {
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [],
            events: [.init(title: "Tomorrow", start: date(13, hour: 9))]
        )
        #expect(!plan.lookingAheadBlurb.contains("Tomorrow"))
        #expect(plan.lookingAheadBlurb.contains("clear"))
    }

    @Test func memoryWithNoEventsProducesMemoryDrivenLookingAhead() {
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [item(.note, "note", day: 11)],
            events: []
        )
        #expect(plan.lookingAheadBlurb.contains("1 saved item"))
    }

    @Test func noteLabelsNeverSurfaceVerbatim() {
        // Note labels are freeform user text (the first 80 chars of a note).
        // The proactive card must never quote them — even if a caller slips a
        // raw note label through, the planner's note path is count-based and
        // generic. The title and reasoning must not contain the note text.
        let secret = "Meeting notes: quarterly revenue targets are confidential"
        let plan = ProactiveBriefPlanner.plan(
            now: now, calendar: calendar,
            memory: [item(.note, secret, day: 11)],
            events: []
        )
        #expect(plan.proactiveWork?.title != nil)
        #expect(plan.proactiveWork?.title.contains(secret) == false,
                "Note text must never be the proactive card title.")
        #expect(plan.proactiveWork?.reasoning.contains(secret) == false,
                "Note text must never be quoted in the reasoning.")
        #expect(plan.paintingCaption.contains(secret) == false)
        #expect(plan.lookingAheadBlurb.contains(secret) == false)
    }

    @Test func deterministicAcrossCalls() {
        let memory = [item(.brief, "Same brief", day: 11)]
        let a = ProactiveBriefPlanner.plan(now: now, calendar: calendar, memory: memory, events: [])
        let b = ProactiveBriefPlanner.plan(now: now, calendar: calendar, memory: memory, events: [])
        #expect(a == b, "Identical inputs must produce an identical plan.")
    }
}
