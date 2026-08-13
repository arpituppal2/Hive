import Foundation

/// Pure time-range policy for Chrome's "Clear Browsing Data".
///
/// The Chromium shell owns the actual mutations (history tombstones, download
/// record removal, CDP cookie/cache clearing). This value-level policy keeps
/// the range arithmetic and labels deterministic and unit-tested.
public enum ClearBrowsingDataPolicy {

    /// The time range applied to date-stamped data (browsing history). Cookies,
    /// cache, and download history are cleared in full when selected — our
    /// download records carry no per-item timestamp and CDP offers no
    /// time-scoped cookie/cache clearing — exactly as the panel states.
    public enum TimeRange: String, CaseIterable, Identifiable, Sendable {
        case lastHour
        case lastDay
        case lastWeek
        case allTime

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .lastHour: return "Last hour"
            case .lastDay: return "Last 24 hours"
            case .lastWeek: return "Last 7 days"
            case .allTime: return "All time"
            }
        }

        /// The cutoff instant before which date-stamped items are retained.
        /// Nil means "everything" (all time).
        public func cutoff(now: Date = Date()) -> Date? {
            switch self {
            case .lastHour: return now.addingTimeInterval(-3600)
            case .lastDay: return now.addingTimeInterval(-86400)
            case .lastWeek: return now.addingTimeInterval(-7 * 86400)
            case .allTime: return nil
            }
        }
    }

    /// Whether a date-stamped item falls inside the range (nil cutoff clears
    /// everything).
    public static func isInRange(_ date: Date, cutoff: Date?) -> Bool {
        guard let cutoff else { return true }
        return date >= cutoff
    }
}
