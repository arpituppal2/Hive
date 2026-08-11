//
//  ProactiveBriefCalendar.swift
//  Hive
//
//  P2.6 Proactive Briefing — EventKit adapter for the Morning Brief's
//  calendar-aware looking-ahead section.
//
//  The brief never touches the calendar unless the user has explicitly
//  enabled "Include Today's Calendar" in Settings (default off). Access is
//  requested lazily at serve time; denial, restriction, write-only access,
//  or a storage error all degrade to an empty event list — the brief still
//  renders, just without event text. Only today's events are read, and only
//  titles + start times are handed to the planner (never notes, attendees,
//  or locations).
//

import Foundation
import EventKit
import HiveCore

enum ProactiveBriefCalendar {

    /// Reads today's titled events sorted by start time (the planner's
    /// looking-ahead line uses the earliest as "first"). Runs nonisolated so
    /// the synchronous EventKit query never blocks the MainActor (the brief
    /// is served on the UI thread).
    nonisolated static func todayEvents(limit: Int = 12) async -> [ProactiveBriefPlanner.CalendarEvent] {
        let store = EKEventStore()
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            break
        case .notDetermined:
            // macOS 14+ async full-access request; a denied or failed request
            // degrades to no events (the brief's memory fallback still shows).
            guard (try? await store.requestFullAccessToEvents()) == true else { return [] }
        default:
            // Restricted, denied, write-only, and pre-macOS-14 `.authorized`
            // states all return empty — the brief's memory fallback still
            // shows, it just never quotes the calendar.
            return []
        }

        guard let today = Calendar.current.dateInterval(of: .day, for: Date()) else { return [] }
        let predicate = store.predicateForEvents(withStart: today.start, end: today.end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)
        return events.map {
            ProactiveBriefPlanner.CalendarEvent(title: $0.title, start: $0.startDate)
        }
    }
}
