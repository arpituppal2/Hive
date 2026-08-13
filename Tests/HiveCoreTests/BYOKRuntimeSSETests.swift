import Foundation
import Testing
@testable import HiveCore

@Suite("BYOKRuntimeSSE")
struct BYOKRuntimeSSETests {
    private func makeRuntime(
        lines: [String],
        delayAfterFirst: UInt64 = 0
    ) -> (runtime: BYOKRuntime, observation: RequestObservation) {
        let config = BYOKRuntime.Config(
            baseURL: URL(string: "https://fixture.invalid/v1")!,
            apiKeyAlias: "hive-test-key",
            modelID: "fixture-model"
        )
        let observation = RequestObservation()
        let runtime = BYOKRuntime(
            config: config,
            keyResolver: { alias in
                alias == "hive-test-key" ? "secret-fixture-key" : nil
            },
            streamTransport: { request in
                await observation.record(request: request)
                let stream = AsyncThrowingStream<String, Error> { continuation in
                    let producer = Task {
                        do {
                            for (index, line) in lines.enumerated() {
                                if index > 0 && delayAfterFirst > 0 {
                                    try await Task.sleep(nanoseconds: delayAfterFirst)
                                }
                                try Task.checkCancellation()
                                continuation.yield(line)
                            }
                            continuation.finish()
                        } catch is CancellationError {
                            continuation.finish()
                        }
                    }
                    continuation.onTermination = { @Sendable _ in
                        producer.cancel()
                    }
                }
                return (stream, BYOKSSEFixture.response)
            }
        )
        return (runtime, observation)
    }

    @Test func streamsOpenAICompatibleSSEAndSendsResolvedKey() async throws {
        let (runtime, observation) = makeRuntime(lines: [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hello \"}}]}",
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hive\"}}]}",
            "data: [DONE]"
        ])

        var chunks: [String] = []
        for try await chunk in runtime.generateStream(makeRequest()) {
            chunks.append(chunk)
        }

        #expect(chunks == ["Hello ", "Hive"])
        let observed = await observation.values()
        #expect(observed.authorization == "Bearer secret-fixture-key")
        #expect(observed.path == "/v1/chat/completions")
    }

    @Test func ignoresCommentsMalformedFramesAndEmptyDeltas() async throws {
        let (runtime, _) = makeRuntime(lines: [
            ": keep-alive",
            "not an SSE payload",
            "data: {\"choices\":[{\"delta\":{\"content\":null}}]}",
            "data: {\"choices\":[{\"delta\":{\"content\":\"usable\"}}]}",
            "data: [DONE]"
        ])

        var chunks: [String] = []
        for try await chunk in runtime.generateStream(makeRequest()) {
            chunks.append(chunk)
        }

        #expect(chunks == ["usable"])
    }

    @Test func stopsAtDoneAndIgnoresFramesAfterIt() async throws {
        let (runtime, _) = makeRuntime(lines: [
            "data: {\"choices\":[{\"delta\":{\"content\":\"before\"}}]}",
            "data: [DONE]",
            "data: {\"choices\":[{\"delta\":{\"content\":\"after\"}}]}"
        ])

        var chunks: [String] = []
        for try await chunk in runtime.generateStream(makeRequest()) {
            chunks.append(chunk)
        }

        #expect(chunks == ["before"])
    }

    @Test func rejectsThreeMalformedDataFrames() async throws {
        let (runtime, _) = makeRuntime(lines: [
            "data: not-json-1",
            "data: not-json-2",
            "data: not-json-3"
        ])

        do {
            for try await _ in runtime.generateStream(makeRequest()) {}
            Issue.record("Malformed SSE stream unexpectedly completed successfully")
        } catch let error as InferenceError {
            guard case .generationFailed(let message) = error else {
                Issue.record("Unexpected inference error: \(error)")
                return
            }
            #expect(message == "BYOK malformed SSE response")
        }
    }

    @Test func rejectsStreamWithNoValidEvents() async throws {
        let (runtime, _) = makeRuntime(lines: [": keep-alive", "diagnostic text"])

        do {
            for try await _ in runtime.generateStream(makeRequest()) {}
            Issue.record("Empty SSE stream unexpectedly completed successfully")
        } catch let error as InferenceError {
            guard case .generationFailed(let message) = error else {
                Issue.record("Unexpected inference error: \(error)")
                return
            }
            #expect(message == "BYOK empty SSE response")
        }
    }

    @Test func rejectsEmptyChoicesFrame() async throws {
        let (runtime, _) = makeRuntime(lines: [
            "data: {\"choices\":[]}",
            "data: [DONE]"
        ])

        do {
            for try await _ in runtime.generateStream(makeRequest()) {}
            Issue.record("Empty choices frame unexpectedly completed successfully")
        } catch let error as InferenceError {
            guard case .generationFailed(let message) = error else {
                Issue.record("Unexpected inference error: \(error)")
                return
            }
            #expect(message == "BYOK malformed SSE response")
        }
    }

    @Test func cancellationIsNormalTerminationAndDoesNotBecomeProviderFailure() async throws {
        let firstFrameDelivered = TestSignal()
        let (runtime, _) = makeRuntime(
            lines: [
                "data: {\"choices\":[{\"delta\":{\"content\":\"first\"}}]}",
                "data: {\"choices\":[{\"delta\":{\"content\":\"late\"}}]}",
                "data: [DONE]"
            ],
            delayAfterFirst: 500_000_000
        )
        let stream = runtime.generateStream(makeRequest())
        let consumer = Task { () -> [String] in
            var chunks: [String] = []
            do {
                for try await chunk in stream {
                    chunks.append(chunk)
                    if chunks.count == 1 { firstFrameDelivered.signal() }
                }
            } catch {
                Issue.record("Cancellation surfaced as provider failure: \(error)")
            }
            return chunks
        }

        await firstFrameDelivered.wait()
        consumer.cancel()
        let chunks = await consumer.value
        #expect(chunks == ["first"])
    }

    private func makeRequest() -> GenerateRequest {
        GenerateRequest(
            role: .byokFrontier,
            system: "You are a test assistant.",
            user: "Say hello.",
            maxTokens: 32
        )
    }
}

actor RequestObservation {
    private var authorization: String?
    private var path: String?

    func record(request: URLRequest) {
        authorization = request.value(forHTTPHeaderField: "Authorization")
        path = request.url?.path
    }

    func values() -> (authorization: String?, path: String?) {
        (authorization, path)
    }
}

final class TestSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var signaled = false

    func signal() {
        lock.lock()
        signaled = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if signaled {
                lock.unlock()
                continuation.resume()
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }
}

enum BYOKSSEFixture {
    static var response: HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://fixture.invalid/v1/chat/completions")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
    }
}
