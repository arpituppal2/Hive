import Foundation
import Testing
@testable import HiveCore

@Suite("RendererFailureEvent")
struct RendererFailureEventTests {
    private let now = Date(timeIntervalSince1970: 20_000)

    @Test("classifies a first renderer failure as an automatic retry")
    func firstFailureRetries() {
        let event = RendererFailureEvent(
            tabID: "tab-1",
            url: URL(string: "https://example.com"),
            reason: "crashed",
            errorCode: 137,
            occurredAt: now
        )
        let crash = CrashRecord(count: 1, firstCrash: now, lastCrash: now)
        let plan = DefaultRendererFailureHandler().classify(
            event,
            crashRecord: crash,
            automaticRetriesUsed: 0
        )

        #expect(plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0.5)
        #expect(!plan.requiresRecoverySurface)
        #expect(plan.event == event)
    }

    @Test("plan initializer clamps untrusted retry delays")
    func planDelayIsBounded() {
        let plan = RendererRecoveryPlan(
            event: RendererFailureEvent(tabID: "tab-delay", reason: "test"),
            decision: .retryAutomatically,
            retryAfter: 999
        )

        #expect(plan.retryAfter == CrashRecoveryPolicy.maximumAutomaticRetryDelay)

        let recoveryPlan = RendererRecoveryPlan(
            event: plan.event,
            decision: .showRecovery(retryAllowed: true),
            retryAfter: 999
        )
        #expect(recoveryPlan.retryAfter == 0)
    }

    @Test("classifies a crash loop as recovery-only")
    func crashLoopRequiresRecovery() {
        let event = RendererFailureEvent(tabID: "tab-loop", reason: "renderer terminated")
        let crash = CrashRecord(
            count: 3,
            firstCrash: now,
            lastCrash: now.addingTimeInterval(120)
        )
        let plan = DefaultRendererFailureHandler().classify(event, crashRecord: crash)

        #expect(!plan.shouldReloadAutomatically)
        #expect(plan.retryAfter == 0)
        #expect(plan.requiresRecoverySurface)
        #expect(plan.decision == .showRecovery(retryAllowed: true))
    }

    @Test("event diagnostics strip URL secrets and bound failure text")
    func diagnosticsAreSanitized() {
        let event = RendererFailureEvent(
            tabID: String(repeating: "t", count: 400),
            url: URL(string: "https://user:password@example.com/private?token=secret#fragment"),
            reason: "line one\napi_key=super-secret https://example.com/private?token=secret " + String(repeating: "x", count: 700)
        )

        #expect(event.tabID.count == 256)
        #expect(event.url?.absoluteString == "https://example.com")
        #expect(!event.reason.contains("\n"))
        #expect(event.reason.count == 512)
        #expect(!event.reason.contains("api_key=super-secret"))
        #expect(!event.reason.contains("https://example.com"))
    }

    @Test("decoded diagnostics are sanitized too")
    func decodedDiagnosticsAreSanitized() throws {
        let payload = """
        {"tabID":"\(String(repeating: "x", count: 400))","url":"file:///private?secret=1","reason":"token=decoded-secret\\nhttps://example.com/private","errorCode":9,"occurredAt":"1970-01-01T05:33:20Z"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(RendererFailureEvent.self, from: payload)

        #expect(event.tabID.count == 256)
        #expect(event.url == nil)
        #expect(!event.reason.contains("decoded-secret"))
        #expect(!event.reason.contains("https://example.com"))
        #expect(!event.reason.contains("\\n"))
    }

    @Test("event metadata round-trips without page content")
    func eventCodableRoundTrip() throws {
        let event = RendererFailureEvent(
            tabID: "tab-codable",
            url: URL(string: "https://example.com/path"),
            reason: "killed for memory pressure",
            errorCode: 9,
            occurredAt: now
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(RendererFailureEvent.self, from: data)

        #expect(decoded == event)
        #expect(String(decoding: data, as: UTF8.self).contains("killed for memory pressure"))
    }

@Test func boostDefaultEnabled() {
        let b = Boost(id: "b1", name: "Test", urlPattern: "*.example.com", css: "", js: "", forceDarkMode: false, zappedSelectors: [], isEnabled: true)
        #expect(b.isEnabled)
    }
}
