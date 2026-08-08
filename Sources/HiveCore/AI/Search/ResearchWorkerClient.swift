import CryptoKit
import Foundation
import Security
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Swift bridge to the Rust research worker

/// A bounded Swift client for the compiled `hive-fetch-worker` binary.
///
/// The worker owns network access and SSRF policy. Swift owns process
/// discovery, lifecycle, and conversion into the application handoff envelope.
/// The transport is deliberately described as local NDJSON over pipes: this
/// client does not claim authenticated IPC. Production packaging must inject a
/// signed worker URL; the locator is a convenience for development and tests.
public actor ResearchWorkerClient {

    /// Stable identifier required in the helper's release designated
    /// requirement. The Team ID remains release-injected; this identifier is
    /// safe to keep in the open source product contract.
    public static let workerCodeIdentifier = "com.hive.browser.research-worker"

    /// Production trust check. The requirement is read from the same bundled
    /// directory as the worker, never supplied by an arbitrary caller. Missing,
    /// oversized, or malformed release configuration fails closed.
    public nonisolated static func hasValidCodeSignature(at url: URL) -> Bool {
        let workerURL = url.standardizedFileURL
        guard let resourceRoot = trustedResourceRoot(for: workerURL) else {
            return false
        }
        let requirementURL = resourceRoot
            .appendingPathComponent("ResearchWorker", isDirectory: true)
            .appendingPathComponent("hive-worker-requirement.txt")
        guard let data = try? Data(contentsOf: requirementURL),
              data.count <= 4096,
              let requirementString = String(data: data, encoding: .utf8) else {
            return false
        }
        return hasValidCodeSignature(at: workerURL, requirementString: requirementString)
    }

    /// Accept only the SwiftPM resource-bundle layout used by HiveChromium:
    /// `<target>.bundle/Contents/Resources/ResearchWorker/worker`. This avoids
    /// treating an arbitrary executable directory as a production resource.
    private nonisolated static func trustedResourceRoot(for workerURL: URL) -> URL? {
        let expectedDirectory = workerURL.deletingLastPathComponent()
        guard expectedDirectory.lastPathComponent == "ResearchWorker",
              workerURL.lastPathComponent == "hive-fetch-worker" else {
            return nil
        }
        let resourcesURL = expectedDirectory.deletingLastPathComponent()
        guard resourcesURL.lastPathComponent == "Resources",
              resourcesURL.pathExtension.isEmpty else {
            return nil
        }
        let bundleURL = resourcesURL.deletingLastPathComponent().deletingLastPathComponent()
        guard bundleURL.pathExtension == "bundle",
              bundleURL.lastPathComponent.hasSuffix("_HiveChromium.bundle") else {
            return nil
        }
        return resourcesURL
    }

    /// Internal requirement-specific verifier used by tests and by the
    /// bundle-derived production wrapper above. Keeping this overload
    /// non-public prevents a production caller from selecting an alternate
    /// signer identity at construction time.
    nonisolated static func hasValidCodeSignature(
        at url: URL,
        requirementString: String
    ) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: url.path),
              isCanonicalReleaseRequirement(requirementString) else {
            return false
        }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementString as CFString,
            [],
            &requirement
        ) == errSecSuccess,
        let requirement else {
            return false
        }
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }
        return SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: 0),
            requirement
        ) == errSecSuccess
    }

    /// Rejects broad requirements such as `anchor apple generic` that would
    /// authenticate an unrelated signed executable. The full Security.framework
    /// parser is also exercised by the requirement-specific verifier.
    nonisolated static func isCanonicalReleaseRequirement(_ value: String) -> Bool {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalized.isEmpty,
              normalized.contains("anchor apple generic"),
              normalized.contains(workerCodeIdentifier),
              normalized.contains("certificate leaf[subject.OU]") else {
            return false
        }
        // Syntax is validated by SecRequirementCreateWithString in the
        // requirement-specific verifier. Keep this predicate focused on the
        // non-negotiable Hive worker identity and signer-field shape.
        return true
    }

    public struct FetchedSource: Sendable, Equatable {
        public let requestID: String
        public let requestedURL: String
        public let finalURL: String
        public let status: Int
        public let contentType: String?
        public let redirectCount: Int
        public let body: Data
        public let contentHashSHA256: String
        public let retrievedAtUnixMS: UInt64
        public let captureMethod: String

        public init(
            requestID: String,
            requestedURL: String,
            finalURL: String,
            status: Int,
            contentType: String?,
            redirectCount: Int,
            body: Data,
            contentHashSHA256: String,
            retrievedAtUnixMS: UInt64,
            captureMethod: String = "swarm-research"
        ) {
            self.requestID = requestID
            self.requestedURL = requestedURL
            self.finalURL = finalURL
            self.status = status
            self.contentType = contentType
            self.redirectCount = redirectCount
            self.body = body
            self.contentHashSHA256 = contentHashSHA256
            self.retrievedAtUnixMS = retrievedAtUnixMS
            self.captureMethod = captureMethod
        }

        /// Converts the fetched record into the exact schema consumed by
        /// `ResearchHandoffAdapter`. The adapter remains the final validator.
        public func makeHandoffPayload(
            retentionClass: String = "session",
            deletionScope: String = "this_source",
            expiresAtUnixMS: UInt64? = nil
        ) throws -> Data {
            let computedHash = SHA256.hash(data: body)
                .map { String(format: "%02x", $0) }
                .joined()
            guard contentHashSHA256 == computedHash else {
                throw ResearchWorkerError.invalidEnvelope("content hash does not match body")
            }

            var retention: [String: Any] = [
                "class": retentionClass,
                "deletion_scope": deletionScope
            ]
            if let expiresAtUnixMS {
                retention["expires_at_unix_ms"] = String(expiresAtUnixMS)
            }
            let object: [String: Any] = [
                "schema_version": 1,
                "kind": "research_source",
                "provenance": "rust-research-boundary",
                "source": [
                    "requested_url": requestedURL,
                    "final_url": finalURL,
                    "status": status,
                    "content_type": contentType.map { $0 as Any } ?? NSNull(),
                    "redirect_count": redirectCount,
                    "retrieved_at_unix_ms": String(retrievedAtUnixMS),
                    "content_hash_sha256": contentHashSHA256,
                    "body_base64": body.base64EncodedString(),
                    "capture_method": captureMethod
                ],
                "retention": retention,
                "extraction": "not_extracted",
                "citation_ready": false
            ]
            guard JSONSerialization.isValidJSONObject(object) else {
                throw ResearchWorkerError.invalidEnvelope("handoff payload is not valid JSON")
            }
            return try JSONSerialization.data(withJSONObject: object)
        }
    }

    public enum ResearchWorkerError: Error, Sendable, Equatable, CustomStringConvertible {
        case executableUnavailable
        case invalidURL
        case privateBrowsingNotAllowed
        case timedOut
        case cancelled
        case workerExited(status: Int32, stderr: String)
        case protocolError(String)
        case invalidEnvelope(String)
        case processLaunch(String)

        public var description: String {
            switch self {
            case .executableUnavailable:
                return "the Hive research worker executable is unavailable"
            case .invalidURL:
                return "research worker URL must be a bounded HTTP(S) URL"
            case .privateBrowsingNotAllowed:
                return "private browsing content is never sent to the research worker"
            case .timedOut:
                return "the research worker exceeded its time limit"
            case .cancelled:
                return "the research worker request was cancelled"
            case .workerExited(let status, let stderr):
                return stderr.isEmpty
                    ? "the research worker exited with status \(status)"
                    : "the research worker exited with status \(status): \(stderr)"
            case .protocolError(let message):
                return "research worker protocol error: \(message)"
            case .invalidEnvelope(let message):
                return "research handoff envelope is invalid: \(message)"
            case .processLaunch(let message):
                return "research worker could not launch: \(message)"
            }
        }
    }

    public let executableURL: URL
    private let timeout: Duration
    private let maxBytes: Int
    private let executableValidator: @Sendable (URL) -> Bool
    private var nextRequestNumber: UInt64 = 0

    public init(
        executableURL: URL,
        timeout: Duration = .seconds(15),
        maxBytes: Int = 5 * 1024 * 1024
    ) {
        self.executableURL = executableURL
        self.timeout = timeout
        self.maxBytes = maxBytes
        self.executableValidator = Self.hasValidCodeSignature(at:)
    }

    /// Test-only composition seam. Production callers must use the public
    /// initializer, which always enforces a release-supplied requirement.
    init(
        executableURL: URL,
        timeout: Duration = .seconds(15),
        maxBytes: Int = 5 * 1024 * 1024,
        executableValidator: @escaping @Sendable (URL) -> Bool
    ) {
        self.executableURL = executableURL
        self.timeout = timeout
        self.maxBytes = maxBytes
        self.executableValidator = executableValidator
    }

    /// Fetches one non-private URL through the Rust worker. Each call launches
    /// a fresh worker, which keeps the Swift bridge stateless and bounds the
    /// lifetime of network access. The returned body remains in memory until
    /// the caller either hands it to the validated adapter or discards it.
    public func fetch(
        url: URL,
        isPrivateBrowsing: Bool = false
    ) async throws -> FetchedSource {
        guard !isPrivateBrowsing else {
            throw ResearchWorkerError.privateBrowsingNotAllowed
        }
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil,
              url.user == nil,
              url.password == nil,
              url.absoluteString.utf8.count <= 8 * 1024 else {
            throw ResearchWorkerError.invalidURL
        }
        // Enforce the same trust boundary here as the Chromium composition
        // point. Callers must not be able to bypass signature validation by
        // constructing a client directly with an arbitrary executable URL.
        guard executableValidator(executableURL) else {
            throw ResearchWorkerError.executableUnavailable
        }
        guard maxBytes > 0, maxBytes <= 5 * 1024 * 1024 else {
            throw ResearchWorkerError.protocolError("maxBytes is outside the worker limit")
        }

        nextRequestNumber &+= 1
        let requestID = "swift-research-\(nextRequestNumber)-\(UUID().uuidString)"
        let timeoutMilliseconds = max(1, min(120_000, Int(timeout.components.seconds * 1_000) + Int(timeout.components.attoseconds / 1_000_000_000_000_000)))
        let request = WireRequest.fetch(
            requestID: requestID,
            url: url.absoluteString,
            timeoutMS: timeoutMilliseconds,
            maxBytes: maxBytes
        )
        let shutdown = WireRequest.shutdown
        let requestData = try Self.encodeRequests([request, shutdown])
        let executableURL = self.executableURL
        let workerTimeout = self.timeout
        let workerTask = Task.detached(priority: .utility) { () throws -> ProcessOutput in
            do {
                return try ProcessRunner.run(
                    executableURL: executableURL,
                    input: requestData,
                    timeout: workerTimeout
                )
            } catch is CancellationError {
                throw ResearchWorkerError.cancelled
            }
        }

        let output: ProcessOutput
        do {
            output = try await withTaskCancellationHandler(operation: {
                try await workerTask.value
            }, onCancel: {
                workerTask.cancel()
            })
        } catch is CancellationError {
            workerTask.cancel()
            throw ResearchWorkerError.cancelled
        } catch let error as ResearchWorkerError {
            throw error
        } catch let error as ProcessOutputError {
            throw ResearchWorkerError.workerExited(status: error.status, stderr: error.stderr)
        } catch {
            throw ResearchWorkerError.processLaunch(String(describing: error))
        }

        let response = try Self.decodeFetchResponse(
            output.stdout,
            requestID: requestID,
            maximumBodyBytes: maxBytes
        )
        let retrievedAt = UInt64(Date().timeIntervalSince1970 * 1_000)
        let hash = Self.sha256Hex(response.body)
        return FetchedSource(
            requestID: requestID,
            requestedURL: url.absoluteString,
            finalURL: response.finalURL,
            status: response.status,
            contentType: response.contentType,
            redirectCount: response.redirectCount,
            body: response.body,
            contentHashSHA256: hash,
            retrievedAtUnixMS: retrievedAt
        )
    }

    /// Development convenience. Shipping app composition should inject an
    /// explicit signed bundle path instead of trusting arbitrary PATH entries.
    public static func locateDevelopmentWorker() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["HIVE_RESEARCH_WORKER_PATH"],
           FileManager.default.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("hive-fetch-worker"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("hive-fetch-worker"),
            URL(fileURLWithPath: ".build/arm64-apple-macosx/debug/hive-fetch-worker", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    // MARK: - Wire codec

    private enum WireRequest: Encodable {
        case fetch(requestID: String, url: String, timeoutMS: Int, maxBytes: Int)
        case shutdown

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .fetch(let requestID, let url, let timeoutMS, let maxBytes):
                try container.encode("fetch", forKey: .type)
                try container.encode(1, forKey: .protocolVersion)
                try container.encode(requestID, forKey: .requestID)
                try container.encode(url, forKey: .url)
                try container.encode(timeoutMS, forKey: .timeoutMS)
                try container.encode(maxBytes, forKey: .maxBytes)
            case .shutdown:
                try container.encode("shutdown", forKey: .type)
                try container.encode(1, forKey: .protocolVersion)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case protocolVersion = "protocol_version"
            case requestID = "request_id"
            case url
            case timeoutMS = "timeout_ms"
            case maxBytes = "max_bytes"
        }
    }

    private struct WireResponse: Decodable {
        let type: String
        let protocolVersion: Int?
        let requestID: String?
        let status: Int?
        let finalURL: String?
        let contentType: String?
        let bodyBase64: String?
        let redirectCount: Int?
        let code: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case type
            case protocolVersion = "protocol_version"
            case requestID = "request_id"
            case status
            case finalURL = "final_url"
            case contentType = "content_type"
            case bodyBase64 = "body_base64"
            case redirectCount = "redirect_count"
            case code
            case message
        }
    }

    private struct WireFetchResult: Sendable {
        let status: Int
        let finalURL: String
        let contentType: String?
        let body: Data
        let redirectCount: Int
    }

    private static func encodeRequests(_ requests: [WireRequest]) throws -> Data {
        var output = Data()
        let encoder = JSONEncoder()
        for request in requests {
            output.append(try encoder.encode(request))
            output.append(0x0A)
        }
        return output
    }

    private static func decodeFetchResponse(
        _ data: Data,
        requestID: String,
        maximumBodyBytes: Int
    ) throws -> WireFetchResult {
        let decoder = JSONDecoder()
        var sawReady = false
        for line in data.split(separator: 0x0A) where !line.isEmpty {
            let response: WireResponse
            do {
                response = try decoder.decode(WireResponse.self, from: line)
            } catch {
                throw ResearchWorkerError.protocolError("invalid JSON response: \(error)")
            }
            switch response.type {
            case "ready":
                guard response.protocolVersion == 1 else {
                    throw ResearchWorkerError.protocolError("unsupported worker protocol version")
                }
                sawReady = true
            case "fetch_started":
                guard response.requestID == requestID else { continue }
            case "fetch_completed":
                guard sawReady, response.requestID == requestID,
                      let status = response.status,
                      let finalURL = response.finalURL,
                      let encoded = response.bodyBase64,
                      let body = Data(base64Encoded: encoded) else {
                    throw ResearchWorkerError.protocolError("incomplete fetch_completed response")
                }
                guard (200...599).contains(status),
                      finalURL.utf8.count <= 8 * 1024,
                      let parsedURL = URL(string: finalURL),
                      let scheme = parsedURL.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      parsedURL.host != nil,
                      parsedURL.user == nil,
                      parsedURL.password == nil,
                      !finalURL.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                      response.redirectCount.map { $0 >= 0 } ?? true,
                      body.count <= maximumBodyBytes else {
                    throw ResearchWorkerError.protocolError("worker returned invalid fetch metadata")
                }
                if let contentType = response.contentType,
                   contentType.utf8.count > 1024 || contentType.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                    throw ResearchWorkerError.protocolError("worker returned invalid content type")
                }
                return WireFetchResult(
                    status: status,
                    finalURL: finalURL,
                    contentType: response.contentType,
                    body: body,
                    redirectCount: response.redirectCount ?? 0
                )
            case "error":
                if response.requestID == nil || response.requestID == requestID {
                    throw ResearchWorkerError.protocolError(
                        "\(response.code ?? "unknown"): \(response.message ?? "worker error")"
                    )
                }
            default:
                continue
            }
        }
        throw ResearchWorkerError.protocolError("worker returned no completed response")
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct ProcessOutput: Sendable {
    let stdout: Data
}

private struct ProcessOutputError: Error {
    let status: Int32
    let stderr: String
}

private final class ProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let stdoutLimit: Int
    private let stderrLimit: Int
    private var stdoutData = Data()
    private var stderrData = Data()
    private var stdoutExceededLimit = false

    init(stdoutLimit: Int, stderrLimit: Int) {
        self.stdoutLimit = stdoutLimit
        self.stderrLimit = stderrLimit
    }

    func appendStdout(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !chunk.isEmpty else { return }
        let remaining = stdoutLimit - stdoutData.count
        if remaining > 0 {
            stdoutData.append(chunk.prefix(remaining))
        }
        if chunk.count > max(remaining, 0) {
            stdoutExceededLimit = true
        }
    }

    func appendStderr(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !chunk.isEmpty else { return }
        let remaining = stderrLimit - stderrData.count
        if remaining > 0 {
            stderrData.append(chunk.prefix(remaining))
        }
    }

    func snapshot() -> (stdout: Data, stderr: Data, stdoutExceededLimit: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (stdoutData, stderrData, stdoutExceededLimit)
    }
}

private enum ProcessRunner {
    static func run(
        executableURL: URL,
        input: Data,
        timeout: Duration
    ) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executableURL
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ResearchWorkerClient.ResearchWorkerError.processLaunch(String(describing: error))
        }

        #if canImport(Darwin)
        let processGroupCreated = Darwin.setpgid(process.processIdentifier, process.processIdentifier) == 0
        #else
        let processGroupCreated = false
        #endif

        do {
            try stdin.fileHandleForWriting.write(contentsOf: input)
            try stdin.fileHandleForWriting.close()
        } catch {
            Self.terminateAndReap(process, processGroupCreated: processGroupCreated)
            throw ResearchWorkerClient.ResearchWorkerError.processLaunch(
                "could not write to research worker: \(error)"
            )
        }

        let group = DispatchGroup()
        let collector = ProcessOutputCollector(
            stdoutLimit: 16 * 1024 * 1024,
            stderrLimit: 64 * 1024
        )
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drain(stdout.fileHandleForReading) { chunk in
                collector.appendStdout(chunk)
            }
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drain(stderr.fileHandleForReading) { chunk in
                collector.appendStderr(chunk)
            }
            group.leave()
        }

        let timeoutSeconds = max(0.1, Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Task.isCancelled {
                Self.terminateAndReap(process, processGroupCreated: processGroupCreated)
                group.wait()
                throw CancellationError()
            }
            if Date() >= deadline {
                Self.terminateAndReap(process, processGroupCreated: processGroupCreated)
                group.wait()
                throw ResearchWorkerClient.ResearchWorkerError.timedOut
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        // Reap a naturally exited child before returning or inspecting its
        // status. This is also the cleanup path for scripts that exit without
        // emitting a complete protocol response.
        process.waitUntilExit()
        group.wait()
        let captured = collector.snapshot()
        guard !captured.stdoutExceededLimit else {
            throw ResearchWorkerClient.ResearchWorkerError.protocolError(
                "worker stdout exceeded the 16 MiB transport limit"
            )
        }
        let output = captured.stdout
        let errorText = String(data: captured.stderr, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw ProcessOutputError(status: process.terminationStatus, stderr: errorText)
        }
        return ProcessOutput(stdout: output)
    }

    private static func drain(
        _ handle: FileHandle,
        consume: @Sendable (Data) -> Void
    ) {
        while true {
            let chunk = handle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { return }
            consume(chunk)
        }
    }

    private static func terminateAndReap(
        _ process: Process,
        processGroupCreated: Bool
    ) {
        #if canImport(Darwin)
        if processGroupCreated {
            _ = Darwin.kill(-process.processIdentifier, SIGTERM)
        } else {
            process.terminate()
        }
        #else
        process.terminate()
        #endif
        let graceDeadline = Date().addingTimeInterval(0.25)
        while process.isRunning && Date() < graceDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #if canImport(Darwin)
        if processGroupCreated {
            _ = Darwin.kill(-process.processIdentifier, SIGKILL)
        } else if process.isRunning {
            _ = Darwin.kill(process.processIdentifier, SIGKILL)
        }
        #endif
        process.waitUntilExit()
    }
}
