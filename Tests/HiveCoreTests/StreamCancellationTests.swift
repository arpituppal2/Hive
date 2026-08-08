import Foundation
import Testing
@testable import HiveCore

private actor StreamEventCounter {
    private(set) var chunks = 0
    private(set) var finished = false

    func recordChunk() { chunks += 1 }
    func markFinished() { finished = true }
    func snapshot() -> (chunks: Int, finished: Bool) { (chunks, finished) }
}

@Suite("StreamCancellation")
struct StreamCancellationTests {
    @Test func mockProducerStopsAfterConsumerTerminates() async throws {
        let runtime = MockRuntime()
        let request = GenerateRequest(
            role: .orchestrator,
            system: "system",
            user: String(repeating: "long request ", count: 20)
        )
        let counter = StreamEventCounter()
        let stream = runtime.generateStream(request)

        for try await _ in stream {
            await counter.recordChunk()
            break
        }

        try await Task.sleep(for: .milliseconds(30))
        let snapshot = await counter.snapshot()
        #expect(snapshot.chunks == 1)
        #expect(snapshot.finished == false,
                "consumer termination cancels the producer rather than reporting normal completion")
    }

    @Test func dispatcherFallbackStreamsHonestMockOutput() async throws {
        let dispatcher = Dispatcher()
        let request = GenerateRequest(role: .orchestrator, system: "", user: "stream probe")
        let stream = await dispatcher.streamGenerate(request)
        var output = ""
        for try await chunk in stream { output += chunk }

        #expect(output.contains("MOCK PLAN"))
        #expect(output.contains("no real local model"))
    }

    @Test func dispatcherProducerStopsAfterConsumerTerminates() async throws {
        let dispatcher = Dispatcher()
        let request = GenerateRequest(
            role: .orchestrator,
            system: "",
            user: String(repeating: "stream cancellation ", count: 20)
        )
        let stream = await dispatcher.streamGenerate(request)
        let counter = StreamEventCounter()

        for try await _ in stream {
            await counter.recordChunk()
            break
        }

        try await Task.sleep(for: .milliseconds(30))
        let snapshot = await counter.snapshot()
        #expect(snapshot.chunks == 1)
        #expect(snapshot.finished == false)
    }
}
