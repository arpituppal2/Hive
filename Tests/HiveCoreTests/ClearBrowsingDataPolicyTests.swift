import Foundation
import Testing
@testable import HiveCore

@Suite("ClearBrowsingDataPolicy")
struct ClearBrowsingDataPolicyTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Range labels are human-readable")
    func labels() {
        #expect(ClearBrowsingDataPolicy.TimeRange.lastHour.label == "Last hour")
        #expect(ClearBrowsingDataPolicy.TimeRange.lastDay.label == "Last 24 hours")
        #expect(ClearBrowsingDataPolicy.TimeRange.lastWeek.label == "Last 7 days")
        #expect(ClearBrowsingDataPolicy.TimeRange.allTime.label == "All time")
    }

    @Test("Cutoffs are exact offsets from now")
    func cutoffs() {
        #expect(ClearBrowsingDataPolicy.TimeRange.lastHour.cutoff(now: now) == now.addingTimeInterval(-3600))
        #expect(ClearBrowsingDataPolicy.TimeRange.lastDay.cutoff(now: now) == now.addingTimeInterval(-86400))
        #expect(ClearBrowsingDataPolicy.TimeRange.lastWeek.cutoff(now: now) == now.addingTimeInterval(-7 * 86400))
        #expect(ClearBrowsingDataPolicy.TimeRange.allTime.cutoff(now: now) == nil)
    }

    @Test("Range membership is inclusive of the cutoff")
    func membership() {
        let cutoff = now.addingTimeInterval(-3600)
        #expect(ClearBrowsingDataPolicy.isInRange(now, cutoff: cutoff))
        #expect(ClearBrowsingDataPolicy.isInRange(cutoff, cutoff: cutoff))
        #expect(!ClearBrowsingDataPolicy.isInRange(cutoff.addingTimeInterval(-1), cutoff: cutoff))
        // All time clears everything, including ancient items.
        #expect(ClearBrowsingDataPolicy.isInRange(.distantPast, cutoff: nil))
    }

    @Test("All time clears every date-stamped item")
    func allTimeClearsAll() {
        let old = now.addingTimeInterval(-30 * 86400)
        let recent = now.addingTimeInterval(-60)
        #expect(ClearBrowsingDataPolicy.isInRange(old, cutoff: ClearBrowsingDataPolicy.TimeRange.allTime.cutoff(now: now)))
        #expect(ClearBrowsingDataPolicy.isInRange(recent, cutoff: ClearBrowsingDataPolicy.TimeRange.allTime.cutoff(now: now)))
    }
}
