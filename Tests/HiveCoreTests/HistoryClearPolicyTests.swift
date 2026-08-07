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
}
