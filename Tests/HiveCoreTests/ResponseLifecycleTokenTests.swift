import Testing
@testable import HiveCore

@Suite("ResponseLifecycleToken")
struct ResponseLifecycleTokenTests {
    @Test("a newer response invalidates the older response")
    func newerResponseWins() {
        let token = ResponseLifecycleToken()

        let first = token.begin()
        let second = token.begin()

        #expect(!token.isCurrent(first))
        #expect(token.isCurrent(second))
        #expect(token.current() == second)
    }

    @Test("stop invalidates the active response without creating a replacement")
    func cancellationInvalidatesCurrentResponse() {
        let token = ResponseLifecycleToken()
        let request = token.begin()

        let cancelledGeneration = token.cancel()

        #expect(cancelledGeneration != request)
        #expect(!token.isCurrent(request))
        #expect(token.current() == cancelledGeneration)
    }

    @Test("request identifiers remain monotonic across repeated cancellation")
    func identifiersRemainMonotonic() {
        let token = ResponseLifecycleToken()
        let first = token.begin()
        let cancelled = token.cancel()
        let second = token.begin()

        #expect(first < cancelled)
        #expect(cancelled < second)
        #expect(token.isCurrent(second))
    }
}
