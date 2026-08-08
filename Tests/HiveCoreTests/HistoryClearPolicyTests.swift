import Testing
@testable import HiveCore

@Suite("HistoryClearPolicy")
struct HistoryClearPolicyTests {
    @Test func nonEmptyHistoryReturnsCountAndPersists() {
        let decision = HistoryClearPolicy.decision(itemCount: 7)
        #expect(decision.removedCount == 7)
        #expect(decision.shouldPersist)
    }

    @Test func emptyHistoryIsAnIdempotentNoOp() {
        let decision = HistoryClearPolicy.decision(itemCount: 0)
        #expect(decision.removedCount == 0)
        #expect(!decision.shouldPersist)
    }

    @Test func negativeCountsFailClosedToNoOp() {
        let decision = HistoryClearPolicy.decision(itemCount: -1)
        #expect(decision.removedCount == 0)
        #expect(!decision.shouldPersist)
    }

    @Test func largeCountIsStillValid() {
        let decision = HistoryClearPolicy.decision(itemCount: 1_000_000)
        #expect(decision.removedCount == 1_000_000)
        #expect(decision.shouldPersist)
    }

    @Test func singleItemClearPersists() {
        let decision = HistoryClearPolicy.decision(itemCount: 1)
        #expect(decision.removedCount == 1)
        #expect(decision.shouldPersist)
    }

    @Test func decisionEquality() {
        let a = HistoryClearPolicy.decision(itemCount: 5)
        let b = HistoryClearPolicy.decision(itemCount: 5)
        #expect(a == b)
    }
}
