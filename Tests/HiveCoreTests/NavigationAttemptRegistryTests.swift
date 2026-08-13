import Foundation
import Testing
@testable import HiveCore

@Suite("NavigationAttemptRegistry")
struct NavigationAttemptRegistryTests {
    @Test("new navigation invalidates the previous attempt for the same tab")
    func replacementInvalidatesPreviousAttempt() {
        let registry = NavigationAttemptRegistry()
        let first = registry.issue(for: "tab-a")
        let second = registry.issue(for: "tab-a")

        #expect(first != second)
        #expect(!registry.isCurrent(tabID: "tab-a", attemptID: first))
        #expect(registry.isCurrent(tabID: "tab-a", attemptID: second))
    }

    @Test("invalidating a tab rejects pending callbacks")
    func invalidationRejectsCallback() {
        let registry = NavigationAttemptRegistry()
        let attempt = registry.issue(for: "tab-a")

        registry.invalidate(tabID: "tab-a")

        #expect(!registry.isCurrent(tabID: "tab-a", attemptID: attempt))
        registry.invalidate(tabID: "tab-a")
    }

    @Test("attempts are isolated between tabs")
    func tabsAreIndependent() {
        let registry = NavigationAttemptRegistry()
        let first = registry.issue(for: "tab-a")
        let other = registry.issue(for: "tab-b")

        #expect(registry.isCurrent(tabID: "tab-a", attemptID: first))
        #expect(registry.isCurrent(tabID: "tab-b", attemptID: other))

        registry.invalidate(tabID: "tab-a")
        #expect(!registry.isCurrent(tabID: "tab-a", attemptID: first))
        #expect(registry.isCurrent(tabID: "tab-b", attemptID: other))
    }

    @Test("remove reports whether state existed and is idempotent")
    func removeIsIdempotent() {
        let registry = NavigationAttemptRegistry()
        _ = registry.issue(for: "tab-a")

        #expect(registry.remove(tabID: "tab-a"))
        #expect(!registry.remove(tabID: "tab-a"))
    }

    @Test("removing nonexistent tab returns false")
    func removeNonExistentReturnsFalse() {
        let registry = NavigationAttemptRegistry()
        #expect(!registry.remove(tabID: "ghost"))
    }
}
