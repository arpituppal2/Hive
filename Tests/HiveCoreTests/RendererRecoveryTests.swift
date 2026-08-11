import Foundation
import Testing
@testable import HiveCore

@Suite("RendererRecovery")
struct RendererRecoveryTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func event(
        tabID: String = "tab-1",
        offset: TimeInterval = 0,
        reason: String = "renderer terminated"
    ) -> RendererFailureEvent {
        RendererFailureEvent(
            tabID: tabID,
            url: URL(string: "https://example.com/private/document?token=secret#section"),
            reason: reason,
            errorCode: 137,
            occurredAt: t0.addingTimeInterval(offset)
        )
    }

    @Test("policy allows one automatic retry, then shows recovery")
    func retryBudget() {
        let policy = CrashRecoveryPolicy(
            automaticRetryLimit: 1,
            automaticRetryBackoff: [0.5, 1.5]
        )
        let healthyBurst = CrashRecord(count: 1, firstCrash: t0, lastCrash: t0)

        #expect(policy.decision(for: healthyBurst) == .retryAutomatically)
        #expect(policy.decision(for: healthyBurst, automaticRetriesUsed: 1) == .showRecovery(retryAllowed: true))
        #expect(policy.delay(forAutomaticRetryNumber: 1) == 0.5)
        #expect(policy.delay(forAutomaticRetryNumber: 2) == 1.5)
        #expect(policy.delay(forAutomaticRetryNumber: 99) == 1.5)
    }

    @Test("crash loop escalates and the burst resets at five minutes")
    func crashLoopAndBurstBoundary() {
        let policy = CrashRecoveryPolicy()
        let crashLoop = CrashRecord(
            count: 3,
            firstCrash: t0,
            lastCrash: t0.addingTimeInterval(299)
        )

        #expect(crashLoop.isCrashLoop)
        #expect(policy.decision(for: crashLoop) == .showRecovery(retryAllowed: true))

        let reset = crashLoop.recorded(at: t0.addingTimeInterval(300))
        #expect(reset.count == 1)
        #expect(reset.firstCrash == t0.addingTimeInterval(300))
        #expect(!reset.isCrashLoop)
    }

    @Test("policy clamps invalid retry delays")
    func retryDelaySanitization() {
        let policy = CrashRecoveryPolicy(
            automaticRetryBackoff: [Double.nan, .infinity, 99]
        )

        let delaysAreValid = policy.automaticRetryBackoff.allSatisfy { delay in
            delay.isFinite && delay >= 0 && delay <= CrashRecoveryPolicy.maximumAutomaticRetryDelay
        }
        #expect(delaysAreValid)
        #expect(policy.delay(forAutomaticRetryNumber: 1) == CrashRecoveryPolicy.maximumAutomaticRetryDelay)
        #expect(policy.delay(forAutomaticRetryNumber: 3) == CrashRecoveryPolicy.maximumAutomaticRetryDelay)
        #expect(policy.delay(forAutomaticRetryNumber: 0) == 0)
    }

    @Test("duplicate termination events are idempotent")
    func duplicateTerminationEventsAreIdempotent() async {
        let controller = RendererRecoveryController()
        let firstEvent = event()

        let firstPlan = await controller.handleFailure(firstEvent)
        let duplicatePlan = await controller.handleFailure(firstEvent)
        let snapshot = await controller.snapshot(for: "tab-1")

        #expect(duplicatePlan == firstPlan)
        #expect(snapshot?.crashRecord.count == 1)
        #expect(snapshot?.automaticRetriesUsed == 1)
        #expect(snapshot?.isRecoveryVisible == false)
    }

    @Test("second distinct failure in the same burst exposes recovery")
    func secondDistinctFailureExposesRecovery() async {
        let controller = RendererRecoveryController()

        let firstPlan = await controller.handleFailure(event(offset: 0))
        let secondPlan = await controller.handleFailure(event(offset: 1, reason: "renderer terminated again"))
        let snapshot = await controller.snapshot(for: "tab-1")

        #expect(firstPlan.decision == .retryAutomatically)
        #expect(secondPlan.decision == .showRecovery(retryAllowed: true))
        #expect(secondPlan.shouldReloadAutomatically == false)
        #expect(secondPlan.requiresRecoverySurface)
        #expect(snapshot?.crashRecord.count == 2)
        #expect(snapshot?.automaticRetriesUsed == 1)
        #expect(snapshot?.isRecoveryVisible == true)
    }

    @Test("five-minute burst reset restores a fresh automatic retry")
    func fiveMinuteBurstResetRestoresRetry() async {
        let controller = RendererRecoveryController()

        _ = await controller.handleFailure(event(offset: 0))
        _ = await controller.handleFailure(event(offset: 1, reason: "second failure"))
        let resetPlan = await controller.handleFailure(event(offset: 300, reason: "later failure"))
        let snapshot = await controller.snapshot(for: "tab-1")

        #expect(resetPlan.decision == .retryAutomatically)
        #expect(snapshot?.crashRecord.count == 1)
        #expect(snapshot?.automaticRetriesUsed == 1)
        #expect(snapshot?.isRecoveryVisible == false)
    }

    @Test("retry budget follows the fixed burst anchor at the five-minute boundary")
    func retryBudgetUsesFixedBurstAnchor() async {
        let controller = RendererRecoveryController()

        _ = await controller.handleFailure(event(offset: 0))
        let withinBurstPlan = await controller.handleFailure(event(offset: 299, reason: "within fixed burst"))
        let afterBurstPlan = await controller.handleFailure(event(offset: 301, reason: "new fixed burst"))
        let snapshot = await controller.snapshot(for: "tab-1")

        #expect(withinBurstPlan.decision == .showRecovery(retryAllowed: true))
        #expect(afterBurstPlan.decision == .retryAutomatically)
        #expect(snapshot?.crashRecord.count == 1)
        #expect(snapshot?.crashRecord.firstCrash == t0.addingTimeInterval(301))
        #expect(snapshot?.automaticRetriesUsed == 1)
    }

    @Test("invalidating an automatic attempt rejects stale adapter work")
    func invalidatingAutomaticAttemptRejectsStaleWork() async {
        let controller = RendererRecoveryController()
        let plan = await controller.handleFailure(event())

        let currentBeforeInvalidation = await controller.isCurrentAttempt(tabID: "tab-1", attemptID: plan.attemptID)
        #expect(currentBeforeInvalidation)
        await controller.invalidateAttempt(tabID: "tab-1")
        let currentAfterInvalidation = await controller.isCurrentAttempt(tabID: "tab-1", attemptID: plan.attemptID)
        #expect(!currentAfterInvalidation)
        let snapshotAfterInvalidation = await controller.snapshot(for: "tab-1")
        #expect(snapshotAfterInvalidation != nil)
    }

    @Test("manual retry is available only for a visible recovery surface")
    func manualRetryRequiresVisibleRecovery() async {
        let controller = RendererRecoveryController()

        let retryBeforeRecovery = await controller.beginManualRetry(for: "tab-1")
        #expect(retryBeforeRecovery == false)
        _ = await controller.handleFailure(event(offset: 0))
        _ = await controller.handleFailure(event(offset: 1, reason: "second failure"))

        let firstManualRetry = await controller.beginManualRetry(for: "tab-1")
        #expect(firstManualRetry)
        let secondManualRetry = await controller.beginManualRetry(for: "tab-1")
        #expect(secondManualRetry == false)
        let snapshotAfterManualRetry = await controller.snapshot(for: "tab-1")
        #expect(snapshotAfterManualRetry?.isRecoveryVisible == false)
    }

    @Test("recovery and tab removal clear controller state")
    func recoveryAndRemovalClearState() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event())

        await controller.markRecovered(tabID: "tab-1")
        let recoveredSnapshot = await controller.snapshot(for: "tab-1")
        #expect(recoveredSnapshot == nil)

        _ = await controller.handleFailure(event(tabID: "tab-2"))
        await controller.remove(tabID: "tab-2")
        let remainingSnapshots = await controller.recoverySnapshots()
        #expect(remainingSnapshots.isEmpty)
    }

    @Test("failure diagnostics retain only safe bounded metadata")
    func failureDiagnosticsRetainOnlySafeBoundedMetadata() {
        let longReason = String(
            repeating: "api_key=top-secret password=hunter2 https://evil.example/path?token=abc\n",
            count: 30
        )
        let failure = RendererFailureEvent(
            tabID: String(repeating: "t", count: 400),
            url: URL(string: "https://user:password@example.com/private/record?token=secret#fragment"),
            reason: longReason,
            occurredAt: t0
        )

        #expect(failure.tabID.count == 256)
        #expect(failure.url?.absoluteString == "https://example.com")
        #expect(failure.reason.count <= 512)
        #expect(!failure.reason.contains("top-secret"))
        #expect(!failure.reason.contains("hunter2"))
        #expect(!failure.reason.contains("https://evil.example"))
        #expect(failure.reason.contains("[redacted]"))
        #expect(failure.reason.contains("[url]"))

        let bearerFailure = RendererFailureEvent(
            tabID: "tab-bearer",
            reason: "Authorization: Bearer bearer-secret access_token=access-secret client_secret: client-secret",
            occurredAt: t0
        )
        #expect(!bearerFailure.reason.contains("bearer-secret"))
        #expect(!bearerFailure.reason.contains("access-secret"))
        #expect(!bearerFailure.reason.contains("client-secret"))
        #expect(bearerFailure.reason.contains("Authorization=[redacted]"))

        let quotedFailure = RendererFailureEvent(
            tabID: "tab-quoted",
            reason: "{\"authorization\": \"Bearer quoted-secret\", \"token\": \"quoted-token\"}",
            occurredAt: t0
        )
        #expect(!quotedFailure.reason.contains("quoted-secret"))
        #expect(!quotedFailure.reason.contains("quoted-token"))

        let escapedFailure = RendererFailureEvent(
            tabID: "tab-escaped",
            reason: "token=\"secret,with;delimiters\\\"and-suffix\"",
            occurredAt: t0
        )
        #expect(!escapedFailure.reason.contains("secret,with;delimiters"))
        #expect(!escapedFailure.reason.contains("and-suffix"))

        let unterminatedFailure = RendererFailureEvent(
            tabID: "tab-unterminated",
            reason: "token=\"unterminated,still-secret trailing context",
            occurredAt: t0
        )
        #expect(!unterminatedFailure.reason.contains("unterminated"))
        #expect(!unterminatedFailure.reason.contains("still-secret"))
        #expect(bearerFailure.reason.contains("access_token=[redacted]"))
        #expect(bearerFailure.reason.contains("client_secret=[redacted]"))
        let containsOnlyPrintableScalars = failure.reason.unicodeScalars.allSatisfy {
            $0.value >= 0x20 && $0.value != 0x7F
        }
        #expect(containsOnlyPrintableScalars)
    }
}
