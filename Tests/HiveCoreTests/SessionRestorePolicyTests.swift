import Testing
@testable import HiveCore

@Suite("SessionRestorePolicy")
struct SessionRestorePolicyTests {

    private func tab(
        _ id: String,
        isPrivate: Bool = false,
        isTransient: Bool = false,
        isPinned: Bool = false,
        isEssential: Bool = false,
        wasActive: Bool = false
    ) -> SessionRestorePolicy.TabInput {
        SessionRestorePolicy.TabInput(
            id: id,
            isPrivate: isPrivate,
            isTransient: isTransient,
            isPinned: isPinned,
            isEssential: isEssential,
            wasActive: wasActive
        )
    }

    @Test("excludes private tabs even when pinned, essential, or active")
    func privateTabsNeverRestore() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("pinned-private", isPrivate: true, isPinned: true),
                   tab("active-private", isPrivate: true, wasActive: true)],
            priorCleanExit: false
        )
        #expect(plan.excludedIDs == ["pinned-private", "active-private"])
        #expect(plan.eagerIDs.isEmpty)
        #expect(plan.lazyIDs.isEmpty)
        #expect(plan.restoresNothing)
        #expect(plan.showRecoveryPrompt == false)
    }

    @Test("excludes transient blank tabs")
    func transientTabsNeverRestore() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("blank", isTransient: true),
                   tab("real")],
            priorCleanExit: false
        )
        #expect(plan.excludedIDs == ["blank"])
        #expect(plan.eagerIDs.isEmpty)
        #expect(plan.lazyIDs == ["real"])
    }

    @Test("preserves saved index order in eager and lazy sets")
    func preservesIndexOrder() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("a", wasActive: true),
                   tab("b"),
                   tab("c", isPinned: true),
                   tab("d")],
            priorCleanExit: true
        )
        // Eager keeps index order: active tab a first (index 0), pinned c third.
        #expect(plan.eagerIDs == ["a", "c"])
        #expect(plan.lazyIDs == ["b", "d"])
    }

    @Test("only the first active flag wins; later flags stay background")
    func firstActiveFlagWins() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("first-active", wasActive: true),
                   tab("second-active", wasActive: true),
                   tab("plain")],
            priorCleanExit: true
        )
        #expect(plan.eagerIDs == ["first-active"])
        #expect(plan.lazyIDs == ["second-active", "plain"])
    }

    @Test("pinned and essential tabs restore eagerly without an active tab")
    func pinnedEssentialEagerWithoutActive() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("pinned", isPinned: true),
                   tab("essential", isEssential: true),
                   tab("background")],
            priorCleanExit: true
        )
        #expect(plan.eagerIDs == ["pinned", "essential"])
        #expect(plan.lazyIDs == ["background"])
    }

    @Test("normalizes empty and duplicate IDs while preserving first order")
    func normalizesProjection() {
        let plan = SessionRestorePolicy.plan(
            from: [tab(""),
                   tab("dup"),
                   tab("dup"),
                   tab("b")],
            priorCleanExit: true
        )
        #expect(plan.excludedIDs.isEmpty)
        #expect(plan.eagerIDs.isEmpty)
        #expect(plan.lazyIDs == ["dup", "b"])
    }

    @Test("returns an empty plan with no prompt for empty input")
    func emptyInput() {
        let plan = SessionRestorePolicy.plan(from: [], priorCleanExit: false)
        #expect(plan.eagerIDs.isEmpty)
        #expect(plan.lazyIDs.isEmpty)
        #expect(plan.excludedIDs.isEmpty)
        #expect(plan.restoresNothing)
        #expect(plan.showRecoveryPrompt == false)
    }

    @Test("shows a recovery prompt only after a crash with durable content")
    func recoveryPromptRules() {
        let durable = [tab("a")]
        #expect(SessionRestorePolicy.plan(from: durable, priorCleanExit: false).showRecoveryPrompt)
        #expect(SessionRestorePolicy.plan(from: durable, priorCleanExit: true).showRecoveryPrompt == false)
        #expect(SessionRestorePolicy.plan(from: durable, priorCleanExit: nil).showRecoveryPrompt == false)
        // Crash with nothing durable: no prompt.
        #expect(SessionRestorePolicy.plan(
            from: [tab("p", isPrivate: true), tab("t", isTransient: true)],
            priorCleanExit: false
        ).showRecoveryPrompt == false)
    }

    @Test("disabling lazy restore makes every durable tab eager")
    func disablesLazyRestore() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("a"), tab("b"), tab("c")],
            priorCleanExit: true,
            allowLazyRestore: false
        )
        #expect(plan.eagerIDs == ["a", "b", "c"])
        #expect(plan.lazyIDs.isEmpty)
    }

    @Test("excluded order follows saved index and never contains durable tabs")
    func excludedOnlyNonDurable() {
        let plan = SessionRestorePolicy.plan(
            from: [tab("private-1", isPrivate: true),
                   tab("real"),
                   tab("blank", isTransient: true),
                   tab("private-2", isPrivate: true)],
            priorCleanExit: true
        )
        #expect(plan.excludedIDs == ["private-1", "blank", "private-2"])
        #expect(plan.eagerIDs.isEmpty)
        #expect(plan.lazyIDs == ["real"])
    }

@Test func tabStatePreservesTitle() {
        let t = TabState(title: "Page")
        #expect(t.title == "Page")
    }

@Test func windowSessionStateDefaultsToEmptyTabs() {
        let w = WindowSessionState()
        #expect(w.tabs.isEmpty)
    }
}
