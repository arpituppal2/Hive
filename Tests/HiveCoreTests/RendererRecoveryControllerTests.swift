import Foundation
import Testing
@testable import HiveCore

@Suite("RendererRecoveryController")
struct RendererRecoveryControllerTests {
    private let start = Date(timeIntervalSince1970: 50_000)

    private func event(tabID: String, at offset: TimeInterval = 0, reason: String = "renderer crashed") -> RendererFailureEvent {
        RendererFailureEvent(
            tabID: tabID,
            url: URL(string: "https://example.com/private?token=secret"),
            reason: reason,
            errorCode: 137,
            occurredAt: start.addingTimeInterval(offset)
        )
    }

    @Test("first failure allows exactly one automatic retry")
    func firstFailureUsesAutomaticRetry() async {
        let controller = RendererRecoveryController()
        let plan = await controller.handleFailure(event(tabID: "tab-a"))

        #expect(plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0.5)
        #expect(!plan.requiresRecoverySurface)
        let snapshot = await controller.snapshot(for: "tab-a")
        #expect(snapshot?.automaticRetriesUsed == 1)
        #expect(snapshot?.isRecoveryVisible == false)
    }

    @Test("delayed retry attempt becomes stale after navigation or recovery")
    func delayedAttemptIsInvalidated() async {
        let controller = RendererRecoveryController()
        let first = await controller.handleFailure(event(tabID: "tab-a"))
        #expect(await controller.isCurrentAttempt(tabID: "tab-a", attemptID: first.attemptID))

        await controller.invalidateAttempt(tabID: "tab-a")
        #expect(!(await controller.isCurrentAttempt(tabID: "tab-a", attemptID: first.attemptID)))

        let second = await controller.handleFailure(event(tabID: "tab-a", at: 10))
        #expect(await controller.isCurrentAttempt(tabID: "tab-a", attemptID: second.attemptID))
        await controller.markRecovered(tabID: "tab-a")
        #expect(!(await controller.isCurrentAttempt(tabID: "tab-a", attemptID: second.attemptID)))
    }

    @Test("delayed retry attempt becomes stale after a newer failure")
    func delayedAttemptIsReplacedByNewFailure() async {
        let controller = RendererRecoveryController()
        let first = await controller.handleFailure(event(tabID: "tab-a"))
        let second = await controller.handleFailure(event(tabID: "tab-a", at: 301))

        #expect(!(await controller.isCurrentAttempt(tabID: "tab-a", attemptID: first.attemptID)))
        #expect(await controller.isCurrentAttempt(tabID: "tab-a", attemptID: second.attemptID))
    }

    @Test("second failure stops automatic retries and exposes recovery")
    func secondFailureShowsRecovery() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a"))
        let plan = await controller.handleFailure(event(tabID: "tab-a", at: 1))

        #expect(!plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0)
        #expect(plan.requiresRecoverySurface)
        let snapshot = await controller.snapshot(for: "tab-a")
        #expect(snapshot?.automaticRetriesUsed == 1)
        #expect(snapshot?.isRecoveryVisible == true)
    }

    @Test("crash loop never auto-retries")
    func crashLoopShowsRecovery() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a"))
        _ = await controller.handleFailure(event(tabID: "tab-a", at: 1))
        let plan = await controller.handleFailure(event(tabID: "tab-a", at: 2))

        #expect(!plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0)
        #expect(plan.requiresRecoverySurface)
        #expect((await controller.snapshot(for: "tab-a"))?.crashRecord.isCrashLoop == true)
    }

    @Test("duplicate native failure callbacks are idempotent")
    func duplicateFailureIsIdempotent() async {
        let controller = RendererRecoveryController()
        let failure = event(tabID: "tab-a")
        let first = await controller.handleFailure(failure)
        let duplicate = await controller.handleFailure(failure)

        #expect(duplicate == first)
        #expect((await controller.snapshot(for: "tab-a"))?.crashRecord.count == 1)
    }

    @Test("expired crash burst receives a fresh automatic retry budget")
    func expiredBurstResetsRetryBudget() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a"))
        let plan = await controller.handleFailure(event(tabID: "tab-a", at: 301))

        #expect(plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0.5)
        #expect(!plan.requiresRecoverySurface)
        let snapshot = await controller.snapshot(for: "tab-a")
        #expect(snapshot?.crashRecord.count == 1)
        #expect(snapshot?.automaticRetriesUsed == 1)
    }

    @Test("out-of-order failure starts a fresh burst")
    func outOfOrderFailureResetsBurst() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a", at: 100))
        let plan = await controller.handleFailure(event(tabID: "tab-a", at: 99))

        #expect(plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0.5)
        #expect((await controller.snapshot(for: "tab-a"))?.crashRecord.count == 1)
    }

    @Test("manual retry is one-shot and recovery clears only after success")
    func manualRetryAndRecovery() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a"))
        _ = await controller.handleFailure(event(tabID: "tab-a", at: 1))

        #expect(await controller.beginManualRetry(for: "tab-a"))
        #expect(!(await controller.snapshot(for: "tab-a"))!.isRecoveryVisible)
        #expect(!(await controller.beginManualRetry(for: "tab-a")))

        await controller.markRecovered(tabID: "tab-a")
        #expect(await controller.snapshot(for: "tab-a") == nil)
    }

    @Test("failure state is isolated per tab")
    func tabsDoNotShareCrashHistory() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a"))
        let plan = await controller.handleFailure(event(tabID: "tab-b"))

        #expect(plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0.5)
        #expect((await controller.snapshot(for: "tab-a"))?.automaticRetriesUsed == 1)
        #expect((await controller.snapshot(for: "tab-b"))?.automaticRetriesUsed == 1)
        #expect(await controller.recoverySnapshots().map(\.tabID) == ["tab-a", "tab-b"])
    }

    @Test("closed tab removal prevents stale identifier inheritance")
    func removedTabStateDoesNotReturn() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a"))
        await controller.remove(tabID: "tab-a")

        #expect(await controller.snapshot(for: "tab-a") == nil)
        let replacement = await controller.handleFailure(event(tabID: "tab-a", at: 500))
        #expect(replacement.shouldReloadAutomatically)
        #expect(replacement.retryAfter == 0.5)
    }

    @Test("snapshot keeps sanitized diagnostics only")
    func snapshotDoesNotRetainSecrets() async {
        let controller = RendererRecoveryController()
        _ = await controller.handleFailure(event(tabID: "tab-a", reason: "token=secret https://example.com/path"))
        let snapshot = await controller.snapshot(for: "tab-a")

        #expect(snapshot?.lastEvent.url?.absoluteString == "https://example.com")
        #expect(snapshot?.lastEvent.reason.contains("secret") == false)
        #expect(snapshot?.lastEvent.reason.contains("https://example.com") == false)
    }
}
