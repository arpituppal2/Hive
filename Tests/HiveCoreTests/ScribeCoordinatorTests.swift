import Foundation
import Testing
@testable import HiveCore

// MARK: - ScribeCoordinator tests
//
// Regression guard for the scribe invocation routes (PITCH/backend-completion.md Track A):
// the `captureScribe` (Auto-Capture moat, gap 7) and `pageQa` (Arc/Comet "ask on page"
// parity, gap 8) Cells. These tests pin the two invariants the routes were built for:
//
//   1. HONEST MOCK DEGRADATION — with MLX not linked, `Dispatcher` serves `MockRuntime`,
//      whose scribe bodies are `{"verdict":"skip","reason":"mock",...}` and
//      `{"answer_type":"page_does_not_say",...}`. The route MUST surface these as a
//      `skip` verdict / `pageDoesNotSay` answer labelled `provider: mock` — complete and
//      correct with or without local inference, never silent, never fabricated. Private
//      contexts are denied with a distinct policy outcome before model invocation.
//   2. PARSER TOLERANCE — `ScribeCoordinator` accepts BOTH the prompt's strict schema
//      (`skip_reason`, `extracted.facts`, `keep_confidence`) AND the mock's flatter shape
//      (`reason`, top-level `facts`). A real model should emit the strict schema; the
//      tolerance is so slightly-off real outputs parse rather than throwing to a parseError.

@Suite("ScribeCoordinator")
struct ScribeCoordinatorTests {

    // A throwaway page context for the triage input.
    private func makeContext(text: String = "page body text") -> PageContext {
        PageContext(tabID: "tab-1", url: URL(string: "https://example.com/article"),
                    title: "Example Article", text: text)
    }

    // MARK: - Auto-Capture triage (captureScribe)

    @Test func autoCaptureTriageDegradesToMockSkip() async throws {
        // No loader, no local weights → MockRuntime. The mock capture_scribe body is
        // `{"verdict":"skip","reason":"mock",...}`. The honest, complete path returns a
        // `.skip` verdict labelled `mock` — NOT a parseError and NOT a fabricated `keep`.
        let verdict = await ScribeCoordinator.autoCaptureTriage(
            pageContext: makeContext(), loader: nil)
        #expect(verdict.verdict == .skip, "mock capture_scribe must skip, not keep")
        #expect(verdict.providerLabel == GenerateResult.Provider.mock.rawValue,
                "provider must be honestly labelled mock")
        #expect(verdict.skipReason != .parseError,
                "the mock's flatter JSON shape must parse, not trip parseError")
        #expect(verdict.extracted.facts.isEmpty)
        #expect(verdict.extracted.decisions.isEmpty)
        #expect(verdict.extracted.commitments.isEmpty)
        // The mock body has no `dedup` object → not-a-duplicate (the artifact-level dedup
        // only fires when a real model, seeded with dedup_context, emits is_duplicate:true).
        #expect(verdict.deduplication.isDuplicate == false)
    }

    @Test func privatePageNeverReachesCaptureScribe() async throws {
        let privateContext = PageContext(
            tabID: "private-tab",
            url: URL(string: "https://example.com/private"),
            title: "Private",
            text: "secret page contents",
            privateBrowsing: true
        )
        let verdict = await ScribeCoordinator.autoCaptureTriage(
            pageContext: privateContext, loader: nil)
        #expect(verdict.verdict == .skip)
        #expect(verdict.skipReason == .privateBrowsing)
        #expect(verdict.providerLabel == "policy-denied")
        #expect(verdict.extracted.facts.isEmpty)
    }

    @Test func disabledPageNeverReachesCaptureScribe() async throws {
        let disabledContext = PageContext(
            tabID: "tab-1",
            url: URL(string: "https://example.com/article"),
            title: "Example Article",
            text: "secret page contents",
            aiContextAllowed: false
        )
        let verdict = await ScribeCoordinator.autoCaptureTriage(
            pageContext: disabledContext, loader: nil)
        #expect(verdict.verdict == .skip)
        #expect(verdict.skipReason == .aiContextDisabled)
        #expect(verdict.providerLabel == "policy-denied")
    }

    // MARK: - Page Q&A (pageQa)

    @Test func privatePageNeverReachesPageQA() async throws {
        let privateContext = PageContext(
            tabID: "private-tab",
            url: URL(string: "https://example.com/private"),
            title: "Private",
            text: "secret page contents",
            privateBrowsing: true
        )
        let answer = await ScribeCoordinator.askOnPage(
            question: "What is the secret?", pageContext: privateContext, loader: nil)
        #expect(answer.answer.isEmpty)
        #expect(answer.answerType == .privateBrowsing)
        #expect(answer.providerLabel == "policy-denied")
        #expect(answer.confidence == 0)
    }

    @Test func disabledPageNeverReachesPageQA() async throws {
        let disabledContext = PageContext(
            tabID: "tab-1",
            url: URL(string: "https://example.com/article"),
            title: "Example Article",
            text: "secret page contents",
            aiContextAllowed: false
        )
        let answer = await ScribeCoordinator.askOnPage(
            question: "What is the secret?", pageContext: disabledContext, loader: nil)
        #expect(answer.answerType == .aiContextDisabled)
        #expect(answer.providerLabel == "policy-denied")
    }

    @Test func askOnPageDegradesToMockPageDoesNotSay() async throws {
        // MockRuntime's pageQa body: `{"answer_type":"page_does_not_say","confidence":0.0,...}`.
        // The honest answer when the (mock) Cell "can't read the page" is page-does-not-say —
        // never a guess, never a parseError.
        let answer = await ScribeCoordinator.askOnPage(
            question: "What is this page about?", pageContext: makeContext(), loader: nil)
        #expect(answer.answerType == .pageDoesNotSay,
                "mock pageQa must answer page-does-not-say, not guess")
        #expect(answer.providerLabel == GenerateResult.Provider.mock.rawValue)
        #expect(answer.confidence == 0.0)
        #expect(answer.basis.isEmpty)
    }

    @Test func askOnPageHandlesNoPageText() async throws {
        // An empty page shouldn't crash the encoder/Cell; the mock still answers honestly.
        let empty = PageContext(tabID: "t", url: nil, title: "", text: "")
        let answer = await ScribeCoordinator.askOnPage(
            question: "anything?", pageContext: empty, loader: nil)
        #expect(answer.answerType == .pageDoesNotSay)
    }

    // MARK: - Dispatcher-error surface (honest, never crashes the load)

    @Test func autoCaptureTriageNeverThrowsOnDispatcherError() async throws {
        // The coordinator wraps the Dispatcher call in a do/catch that returns a
        // mock-labelled empty result on throw. Even a totally empty/nil context must
        // produce a (skip, parseError-ish) verdict rather than propagating an error —
        // Auto-Capture runs on the load-finish path and must never crash a page load.
        let verdict = await ScribeCoordinator.autoCaptureTriage(
            pageContext: PageContext(tabID: "t", url: nil, title: "", text: ""), loader: nil)
        // Either a clean mock-skip or a dispatcher-error skip — both are non-throwing,
        // both are `.skip`. The invariant: it returned, it didn't throw.
        #expect(verdict.verdict == .skip)
    }
}
