import Foundation
import Testing
@testable import HiveCore

@Suite("CrashRecoveryPolicy")
struct CrashRecoveryPolicyTests {
    private let policy = CrashRecoveryPolicy()
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test("allows one automatic retry before showing recovery")
    func allowsSingleRetry() {
        let record = CrashRecord(
            count: 1,
            firstCrash: now,
            lastCrash: now
        )

        #expect(policy.decision(for: record) == .retryAutomatically)
        #expect(policy.decision(for: record, automaticRetriesUsed: 1) == .showRecovery(retryAllowed: true))
    }

    @Test("crash loops never auto-retry")
    func crashLoopShowsRecovery() {
        let record = CrashRecord(
            count: 3,
            firstCrash: now,
            lastCrash: now.addingTimeInterval(120)
        )

        #expect(record.isCrashLoop)
        #expect(policy.decision(for: record) == .showRecovery(retryAllowed: true))
        #expect(policy.decision(for: record, automaticRetriesUsed: 1) == .showRecovery(retryAllowed: true))
    }

    @Test("crashes outside the window are not a loop")
    func oldCrashesMayRetry() {
        let record = CrashRecord(
            count: 3,
            firstCrash: now,
            lastCrash: now.addingTimeInterval(301)
        )

        #expect(!record.isCrashLoop)
        #expect(policy.decision(for: record) == .retryAutomatically)
    }

    @Test("automatic retry delays are bounded and use the configured schedule")
    func automaticRetryDelays() {
        #expect(policy.delay(forAutomaticRetryNumber: 0) == 0)
        #expect(policy.delay(forAutomaticRetryNumber: 1) == 0.5)
        #expect(policy.delay(forAutomaticRetryNumber: 2) == 1.5)
        #expect(policy.delay(forAutomaticRetryNumber: 3) == 3.0)
        #expect(policy.delay(forAutomaticRetryNumber: 99) == 3.0)

        let custom = CrashRecoveryPolicy(
            automaticRetryLimit: 2,
            automaticRetryBackoff: [-1, .infinity, 9]
        )
        #expect(custom.automaticRetryBackoff == [0, 3.0, 3.0])
    }

    @Test("custom retry schedule remains bounded")
    func customRetryScheduleIsBounded() {
        let custom = CrashRecoveryPolicy(
            automaticRetryLimit: 3,
            automaticRetryBackoff: [0.5, 1.5, 3.0]
        )
        let record = CrashRecord(count: 1, firstCrash: now, lastCrash: now)
        let handler = DefaultRendererFailureHandler(policy: custom)
        let first = handler.classify(
            RendererFailureEvent(tabID: "tab", reason: "first", occurredAt: now),
            crashRecord: record,
            automaticRetriesUsed: 0
        )
        let second = handler.classify(
            RendererFailureEvent(tabID: "tab", reason: "second", occurredAt: now),
            crashRecord: record,
            automaticRetriesUsed: 1
        )
        let third = handler.classify(
            RendererFailureEvent(tabID: "tab", reason: "third", occurredAt: now),
            crashRecord: record,
            automaticRetriesUsed: 2
        )

        #expect(first.retryAfter == 0.5)
        #expect(second.retryAfter == 1.5)
        #expect(third.retryAfter == 3.0)
        #expect(third.shouldReloadAutomatically)
    }

    @Test("retry limit is configurable but never negative")
    func retryLimitIsClamped() {
        #expect(CrashRecoveryPolicy(automaticRetryLimit: -1).automaticRetryLimit == 0)

        let record = CrashRecord(count: 1, firstCrash: now, lastCrash: now)
        #expect(CrashRecoveryPolicy(automaticRetryLimit: 0).decision(for: record) == .showRecovery(retryAllowed: true))
    }

    @Test("crashes spaced within the last-crash window reset after the fixed burst window")
    func fixedBurstWindowDoesNotDrift() {
        let first = CrashRecord(count: 1, firstCrash: now, lastCrash: now)
        let second = first.recorded(at: now.addingTimeInterval(240))
        let reset = second.recorded(at: now.addingTimeInterval(301))

        #expect(second.count == 2)
        #expect(second.firstCrash == now)
        #expect(reset.count == 1)
        #expect(reset.firstCrash == now.addingTimeInterval(301))
        #expect(!reset.isCrashLoop)
    }

    @Test("recording exactly at the five-minute boundary starts a new burst")
    func exactWindowBoundaryResets() {
        let first = CrashRecord(count: 2, firstCrash: now, lastCrash: now.addingTimeInterval(240))
        let reset = first.recorded(at: now.addingTimeInterval(300))

        #expect(reset.count == 1)
        #expect(reset.firstCrash == now.addingTimeInterval(300))
        #expect(reset.lastCrash == reset.firstCrash)
    }

@Test func autoArchiveDefaultIs14Days() {
        #expect(AutoArchivePolicy.defaultThreshold == 14 * 86_400)
    }

@Test func crashRecordDefaults() {
        let cr = CrashRecord(count: 0, firstCrash: Date(), lastCrash: Date())
        #expect(cr.count == 0)
    }
}
