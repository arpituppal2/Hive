import Foundation
import Testing
@testable import HiveCore

@Suite("HostContextHotMemory")
struct HostContextHotMemoryTests {
    private let page = PageContext(
        tabID: "active",
        url: URL(string: "https://example.com/article"),
        title: "Blocked article",
        text: "must never reach Swarm"
    )

    @Test("blocked scope rejects current page before assembly")
    func blockedScopeRejectsAtAcceptance() async {
        let store = HotMemoryStore()
        await store.setActiveScope(ContextScope(
            includesCurrentPage: true,
            includesHotMemory: false,
            includesProjectNodes: false,
            includesPreferences: false,
            pageVisibility: .blocked
        ))
        await store.setCurrentPage(page, nodeID: "page-1")

        let assembled = await store.assembleContext()
        #expect(assembled.currentPage == nil)
    }

    @Test("allowed scope retains current page")
    func allowedScopeRetainsPage() async {
        let store = HotMemoryStore()
        await store.setActiveScope(ContextScope(
            includesCurrentPage: true,
            includesHotMemory: false,
            includesProjectNodes: false,
            includesPreferences: false,
            pageVisibility: .allowed
        ))
        await store.setCurrentPage(page, nodeID: "page-1")

        let assembled = await store.assembleContext()
        #expect(assembled.currentPage?.text == "must never reach Swarm")
    }

    @Test("scope excluding current page omits it even when allowed")
    func excludesCurrentPageWhenNotIncluded() async {
        let store = HotMemoryStore()
        await store.setActiveScope(ContextScope(
            includesCurrentPage: false,
            includesHotMemory: false,
            includesProjectNodes: false,
            includesPreferences: false,
            pageVisibility: .allowed
        ))
        await store.setCurrentPage(page, nodeID: "page-1")

        let assembled = await store.assembleContext()
        #expect(assembled.currentPage == nil)
    }

    @Test("hot memory inclusion gates content independently")
    func hotMemoryIndependentOfPageVisibility() async {
        let store = HotMemoryStore()
        await store.setActiveScope(ContextScope(
            includesCurrentPage: false,
            includesHotMemory: true,
            includesProjectNodes: false,
            includesPreferences: false,
            pageVisibility: .blocked
        ))
        await store.setCurrentPage(page, nodeID: "page-1")

        let assembled = await store.assembleContext()
        #expect(assembled.currentPage == nil, "page blocked stands even with hotMemory on")
    }

    @Test("preferences inclusion does not leak page text")
    func preferencesInclusionDoesNotLeakPage() async {
        let store = HotMemoryStore()
        await store.setActiveScope(ContextScope(
            includesCurrentPage: false,
            includesHotMemory: false,
            includesProjectNodes: false,
            includesPreferences: true,
            pageVisibility: .allowed
        ))
        await store.setCurrentPage(page, nodeID: "page-1")

        let assembled = await store.assembleContext()
        #expect(assembled.currentPage == nil)
    }
}
