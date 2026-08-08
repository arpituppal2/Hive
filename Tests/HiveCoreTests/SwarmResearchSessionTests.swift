import Testing
@testable import HiveCore

@Suite("SwarmResearchSession")
@MainActor
struct SwarmResearchSessionTests {
    @Test func publishesRunningEventsAndCompletedFinalResult() async throws {
        let provider = SessionTestProvider(events: [
            .sources([WebSearchSource(id: "s1", title: "Docs", url: "https://example.com/docs")]),
            .answerChunk("Answer")
        ])
        let session = SwarmResearchSession()
        let recorder = SessionSnapshotRecorder()

        session.start(provider: provider, query: "q", focusMode: .webSearch) { state in
            recorder.record(state)
        }
        await provider.waitUntilFinished(count: 1)
        await recorder.waitForTerminal()

        #expect(recorder.snapshots.first?.phase == .running)
        #expect(recorder.snapshots.contains { $0.answer == "Answer" })
        #expect(session.state.phase == .completed)
        #expect(session.state.sources.count == 1)
    }

    @Test func cancelPublishesCancelledAndIgnoresLateProviderEvents() async throws {
        let provider = SessionTestProvider(events: [
            .answerChunk("before stop")
        ], waitForRelease: true)
        let session = SwarmResearchSession()
        let recorder = SessionSnapshotRecorder()

        session.start(provider: provider, query: "q", focusMode: .webSearch) { state in
            recorder.record(state)
        }
        await provider.waitUntilStarted(count: 1)
        session.cancel()
        await recorder.waitForTerminal()
        provider.release()

        #expect(session.state.phase == .cancelled)
        #expect(recorder.snapshots.last?.phase == .cancelled)
        #expect(!recorder.snapshots.contains { $0.phase == .completed })
    }

    @Test func retryStartsFreshStateAndCanCompleteAfterFailure() async throws {
        let provider = SessionTestProvider(events: [], failure: WebSearchError.unexpectedResponse)
        let session = SwarmResearchSession()
        var runCount = 0
        let recorder = SessionSnapshotRecorder()

        session.start(provider: provider, query: "q", focusMode: .webSearch) { state in
            recorder.record(state)
        }
        await provider.waitUntilFinished(count: 1)
        await recorder.waitForTerminal()
        #expect(session.state.phase == .failed)

        provider.failure = nil
        provider.events = [.answerChunk("retry answer")]
        let snapshotsBeforeRetry = recorder.snapshots.count
        runCount += session.retry() ? 1 : 0
        await provider.waitUntilStarted(count: 2)
        await recorder.waitForTerminal(after: snapshotsBeforeRetry)

        #expect(runCount == 1)
        #expect(session.state.phase == .completed)
        #expect(session.state.answer == "retry answer")
        #expect(recorder.snapshots.filter { $0.phase == .running }.count >= 2)
    }

    @Test func providerCancellationPublishesCancelledState() async throws {
        let provider = SessionTestProvider(events: [], failure: CancellationError())
        let session = SwarmResearchSession()
        let recorder = SessionSnapshotRecorder()

        session.start(provider: provider, query: "q", focusMode: .webSearch) { state in
            recorder.record(state)
        }
        await provider.waitUntilFinished(count: 1)
        await recorder.waitForTerminal()

        #expect(session.state.phase == .cancelled)
        #expect(recorder.snapshots.last?.phase == .cancelled)
    }

    @Test func emptyEventsCompletesWithNoAnswer() async throws {
        let provider = SessionTestProvider(events: [])
        let session = SwarmResearchSession()
        let recorder = SessionSnapshotRecorder()
        session.start(provider: provider, query: "empty", focusMode: .webSearch) { recorder.record($0) }
        await provider.waitUntilFinished(count: 1)
        await recorder.waitForTerminal()
        #expect(session.state.phase == .completed)
        #expect(session.state.sources.isEmpty)
    }

    @Test func doubleCancelIsIdempotent() async throws {
        let provider = SessionTestProvider(events: [.answerChunk("x")], waitForRelease: true)
        let session = SwarmResearchSession()
        let recorder = SessionSnapshotRecorder()
        session.start(provider: provider, query: "q", focusMode: .webSearch) { recorder.record($0) }
        await provider.waitUntilStarted(count: 1)
        session.cancel()
        session.cancel()
        await recorder.waitForTerminal()
        provider.release()
        #expect(session.state.phase == .cancelled)
    }

    @Test func newRunInvalidatesOldRun() async throws {
        let oldProvider = SessionTestProvider(events: [.answerChunk("old")], waitForRelease: true)
        let newProvider = SessionTestProvider(events: [.answerChunk("new")])
        let session = SwarmResearchSession()
        let recorder = SessionSnapshotRecorder()

        session.start(provider: oldProvider, query: "old", focusMode: .webSearch) { recorder.record($0) }
        await oldProvider.waitUntilStarted(count: 1)
        session.start(provider: newProvider, query: "new", focusMode: .webSearch) { recorder.record($0) }
        await newProvider.waitUntilFinished(count: 1)
        await recorder.waitForTerminal()
        oldProvider.release()

        #expect(session.state.phase == .completed)
        #expect(session.state.answer == "new")
    }
}

@MainActor
private final class SessionSnapshotRecorder {
    private(set) var snapshots: [SwarmResearchState] = []
    private var terminalWaiter: CheckedContinuation<Void, Never>?

    func record(_ state: SwarmResearchState) {
        snapshots.append(state)
        guard state.phase != .running else { return }
        terminalWaiter?.resume()
        terminalWaiter = nil
    }

    func waitForTerminal() async {
        await waitForTerminal(after: 0)
    }

    func waitForTerminal(after snapshotIndex: Int) async {
        if snapshots.dropFirst(snapshotIndex).contains(where: { $0.phase != .running }) { return }
        await withCheckedContinuation { continuation in
            terminalWaiter = continuation
        }
    }
}

@MainActor
private final class SessionTestProvider: WebSearchProvider {
    let displayName = "Session fixture"
    var events: [WebSearchStreamEvent]
    var failure: Error?
    let waitForRelease: Bool
    private var startedCount = 0
    private var finishedCount = 0
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var startedWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var finishedWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(events: [WebSearchStreamEvent], failure: Error? = nil, waitForRelease: Bool = false) {
        self.events = events
        self.failure = failure
        self.waitForRelease = waitForRelease
    }

    func isAvailable() async -> Bool { true }

    func search(query: String, focusMode: WebSearchFocusMode) async throws -> WebSearchResult {
        try await streamSearch(query: query, focusMode: focusMode) { _ in }
    }

    func streamSearch(
        query: String,
        focusMode: WebSearchFocusMode,
        onUpdate: @escaping @MainActor (WebSearchStreamEvent) async -> Void
    ) async throws -> WebSearchResult {
        startedCount += 1
        resumeSatisfiedWaiters(&startedWaiters, count: startedCount)
        defer {
            finishedCount += 1
            resumeSatisfiedWaiters(&finishedWaiters, count: finishedCount)
        }

        if waitForRelease {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        try Task.checkCancellation()
        if let failure { throw failure }
        for event in events {
            await onUpdate(event)
        }
        return WebSearchResult(
            answer: events.compactMap {
                if case .answerChunk(let chunk) = $0 { return chunk }
                return nil
            }.joined(),
            sources: events.compactMap {
                if case .sources(let sources) = $0 { return sources }
                return nil
            }.flatMap { $0 }
        )
    }

    func waitUntilStarted(count expected: Int) async {
        guard startedCount < expected else { return }
        await withCheckedContinuation { continuation in
            startedWaiters.append((expected: expected, continuation: continuation))
        }
    }

    func waitUntilFinished(count expected: Int) async {
        guard finishedCount < expected else { return }
        await withCheckedContinuation { continuation in
            finishedWaiters.append((expected: expected, continuation: continuation))
        }
    }

    private func resumeSatisfiedWaiters(
        _ waiters: inout [(expected: Int, continuation: CheckedContinuation<Void, Never>)],
        count: Int
    ) {
        let satisfied = waiters.filter { $0.expected <= count }
        waiters.removeAll { $0.expected <= count }
        for waiter in satisfied {
            waiter.continuation.resume()
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
