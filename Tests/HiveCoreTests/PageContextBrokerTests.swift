import Foundation
import HiveCore
import Testing

@Test
func pageContextBrokerFulfill() async throws {
    let broker = PageContextBroker()
    let context = PageContext(
        tabID: "t1",
        url: URL(string: "https://example.com"),
        title: "Example",
        text: "page body"
    )

    let requestTask = Task { await broker.request(for: "t1") }
    try? await Task.sleep(for: .milliseconds(10))
    broker.fulfill(context)

    let result = await requestTask.value
    #expect(result != nil)
    #expect(result?.tabID == "t1")
    #expect(result?.text == "page body")
    #expect(result?.aiContextAllowed == true)
}

@Test
func pageContextBrokerRejectsDisallowedContext() async throws {
    let broker = PageContextBroker()
    let requestTask = Task { await broker.request(for: "blocked") }
    try? await Task.sleep(for: .milliseconds(10))
    broker.fulfill(PageContext(
        tabID: "blocked",
        url: URL(string: "https://example.com"),
        title: "Blocked",
        text: "must not reach Swarm",
        aiContextAllowed: false
    ))
    #expect(await requestTask.value == nil)
}

@Test
func pageContextBrokerTimeoutReturnsNil() async throws {
    let broker = PageContextBroker()
    let result = await broker.request(for: "t1", timeout: .milliseconds(50))
    #expect(result == nil)
}

@Test
func pageContextBrokerOverwriteCancelsFirst() async throws {
    let broker = PageContextBroker()
    let context = PageContext(
        tabID: "t1",
        url: URL(string: "https://example.com"),
        title: "Example",
        text: "second"
    )

    let first = Task { await broker.request(for: "t1") }
    try? await Task.sleep(for: .milliseconds(10))
    let second = Task { await broker.request(for: "t1") }
    try? await Task.sleep(for: .milliseconds(10))
    broker.fulfill(context)

    let firstResult = await first.value
    let secondResult = await second.value

    #expect(firstResult == nil)
    #expect(secondResult?.text == "second")
}

@Test
func pageContextBrokerNilURLIsStillFulfilled() async throws {
    let broker = PageContextBroker()
    let context = PageContext(tabID: "nil-url", url: nil, title: "No URL", text: "content")
    let task = Task { await broker.request(for: "nil-url") }
    try? await Task.sleep(for: .milliseconds(10))
    broker.fulfill(context)
    let result = await task.value
    #expect(result?.text == "content")
}

@Test
func pageContextBrokerFulfillDeliversToFirstWaiter() async throws {
    let broker = PageContextBroker()
    let task = Task { await broker.request(for: "t-waiter") }
    try? await Task.sleep(for: .milliseconds(10))
    broker.fulfill(PageContext(tabID: "t-waiter", url: URL(string: "https://a.example"), title: "A", text: "delivered"))
    let result = await task.value
    #expect(result?.text == "delivered")
}
