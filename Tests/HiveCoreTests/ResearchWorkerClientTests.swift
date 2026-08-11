import CryptoKit
import Foundation
#if canImport(Darwin)
import Darwin
#endif
import Testing
@testable import HiveCore

@Suite("ResearchWorkerClient")
struct ResearchWorkerClientTests {
    private func source(
        body: Data = Data("worker body".utf8),
        contentType: String? = "text/html"
    ) -> ResearchWorkerClient.FetchedSource {
        let hash = SHA256.hash(data: body)
            .map { String(format: "%02x", $0) }
            .joined()
        return ResearchWorkerClient.FetchedSource(
            requestID: "request-1",
            requestedURL: "https://example.com/start",
            finalURL: "https://example.com/final",
            status: 200,
            contentType: contentType,
            redirectCount: 1,
            body: body,
            contentHashSHA256: hash,
            retrievedAtUnixMS: 1_725_000_000_000
        )
    }

    @Test func handoffEnvelopeRoundTripsTransportMetadata() throws {
        let payload = try source().makeHandoffPayload(
            retentionClass: "project",
            deletionScope: "provenance",
            expiresAtUnixMS: 1_800_000_000_000
        )
        let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["schema_version"] as? Int == 1)
        #expect(object["kind"] as? String == "research_source")
        #expect(object["provenance"] as? String == "rust-research-boundary")
        let transport = try #require(object["source"] as? [String: Any])
        #expect(transport["requested_url"] as? String == "https://example.com/start")
        #expect(transport["final_url"] as? String == "https://example.com/final")
        #expect(transport["status"] as? Int == 200)
        #expect(transport["content_type"] as? String == "text/html")
        #expect(transport["redirect_count"] as? Int == 1)
        #expect(transport["retrieved_at_unix_ms"] as? String == "1725000000000")
        #expect(transport["body_base64"] as? String == Data("worker body".utf8).base64EncodedString())
        let retention = try #require(object["retention"] as? [String: Any])
        #expect(retention["class"] as? String == "project")
        #expect(retention["deletion_scope"] as? String == "provenance")
        #expect(retention["expires_at_unix_ms"] as? String == "1800000000000")
    }

    @Test func absentContentTypeIsEncodedAsExplicitJSONNull() throws {
        let payload = try source(contentType: nil).makeHandoffPayload()
        let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let transport = try #require(object["source"] as? [String: Any])
        #expect(transport["content_type"] is NSNull)
    }

    @Test func envelopeRejectsTamperedBodyHashBeforePersistence() {
        let body = Data("worker body".utf8)
        let tampered = ResearchWorkerClient.FetchedSource(
            requestID: "request-1",
            requestedURL: "https://example.com/start",
            finalURL: "https://example.com/final",
            status: 200,
            contentType: nil,
            redirectCount: 0,
            body: body,
            contentHashSHA256: String(repeating: "0", count: 64),
            retrievedAtUnixMS: 1
        )
        #expect(throws: ResearchWorkerClient.ResearchWorkerError.invalidEnvelope("content hash does not match body")) {
            _ = try tampered.makeHandoffPayload()
        }
    }

    @Test func privateBrowsingIsRejectedBeforeExecutableLookup() async {
        let client = ResearchWorkerClient(executableURL: URL(fileURLWithPath: "/does/not/exist"))
        await #expect(throws: ResearchWorkerClient.ResearchWorkerError.privateBrowsingNotAllowed) {
            _ = try await client.fetch(
                url: URL(string: "https://example.com/private")!,
                isPrivateBrowsing: true
            )
        }
    }

    @Test func invalidSchemesAndCredentialsAreRejected() async {
        let client = ResearchWorkerClient(executableURL: URL(fileURLWithPath: "/does/not/exist"))
        for url in [
            URL(string: "file:///tmp/private")!,
            URL(string: "javascript:alert(1)")!,
            URL(string: "https://user:password@example.com/private")!
        ] {
            await #expect(throws: ResearchWorkerClient.ResearchWorkerError.invalidURL) {
                _ = try await client.fetch(url: url)
            }
        }
    }

    @Test func missingWorkerIsReportedOnlyAfterRequestValidation() async {
        let client = ResearchWorkerClient(executableURL: URL(fileURLWithPath: "/does/not/exist"))
        await #expect(throws: ResearchWorkerClient.ResearchWorkerError.executableUnavailable) {
            _ = try await client.fetch(url: URL(string: "https://example.com")!)
        }
    }

    @Test func releaseRequirementPolicyRejectsBroadOrWrongRequirements() {
        let valid = "anchor apple generic and certificate leaf[subject.OU] = \\\"TEAMID123\\\" and identifier \\\"com.hive.browser.research-worker\\\""
        #expect(ResearchWorkerClient.isCanonicalReleaseRequirement(valid))
        #expect(!ResearchWorkerClient.isCanonicalReleaseRequirement("anchor apple generic"))
        #expect(!ResearchWorkerClient.isCanonicalReleaseRequirement("anchor apple generic and certificate leaf[subject.OU] = \\\"TEAMID123\\\" and identifier \\\"com.other.worker\\\""))
        #expect(!ResearchWorkerClient.isCanonicalReleaseRequirement("not a valid requirement"))
        #expect(!ResearchWorkerClient.isCanonicalReleaseRequirement("   "))
    }

    @Test func trustedResourceRootAcceptsCurrentHiveBundleAndRejectsLegacyName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-research-worker-layout-\(UUID().uuidString)")
        let currentWorker = root
            .appendingPathComponent("Hive_Hive.bundle/Contents/Resources/ResearchWorker/hive-fetch-worker")
        let legacyWorker = root
            .appendingPathComponent("Hive_HiveChromium.bundle/Contents/Resources/ResearchWorker/hive-fetch-worker")
        try FileManager.default.createDirectory(
            at: currentWorker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: legacyWorker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(ResearchWorkerClient.trustedResourceRoot(for: currentWorker)?.lastPathComponent == "Resources")
        #expect(ResearchWorkerClient.trustedResourceRoot(for: legacyWorker) == nil)
    }

    @Test func workerLocatorHandlesAppResourcesAndAlreadyBundledRoots() {
        let appResources = URL(fileURLWithPath: "/tmp/Hive.app/Contents/Resources")
        let resourceBundle = appResources.appendingPathComponent("Hive_Hive.bundle")
        let bundledResources = resourceBundle.appendingPathComponent("Contents/Resources")
        let expectedWorker = resourceBundle.appendingPathComponent("Contents/Resources/ResearchWorker/hive-fetch-worker")
        #expect(ResearchWorkerClient.workerURL(fromResourceRoot: appResources).path == expectedWorker.path)
        #expect(ResearchWorkerClient.workerURL(fromResourceRoot: resourceBundle).path == expectedWorker.path)
        #expect(ResearchWorkerClient.workerURL(fromResourceRoot: bundledResources).path == expectedWorker.path)
    }

    @Test func unsignedExecutableFailsCodeSignatureGate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-research-worker-signature-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("unsigned-worker.sh")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: executable.path
        )

        #expect(!ResearchWorkerClient.hasValidCodeSignature(
            at: executable,
            requirementString: "identifier \\\"com.hive.missing-worker\\\""
        ))
        #expect(!ResearchWorkerClient.hasValidCodeSignature(
            at: executable,
            requirementString: "not a valid requirement"
        ))
        #expect(!ResearchWorkerClient.hasValidCodeSignature(
            at: executable,
            requirementString: "   "
        ))
    }

    @Test func incompatibleWorkerProtocolIsRejectedAtReadyHandshake() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-research-worker-protocol-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("incompatible-worker.sh")
        let script = "#!/bin/sh\nprintf '%s\\n' '{\"type\":\"ready\",\"protocol_version\":2}'\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: executable.path
        )

        let client = ResearchWorkerClient(
            executableURL: executable,
            // The fixture exits immediately, but Swift Testing may launch it
            // alongside compilation/process-heavy suites. Keep the handshake
            // test bounded while allowing startup contention.
            timeout: .seconds(5),
            executableValidator: { _ in true } // test fixture; production uses code-signature validation
        )
        await #expect(
            throws: ResearchWorkerClient.ResearchWorkerError.protocolError(
                "unsupported worker protocol version"
            )
        ) {
            _ = try await client.fetch(url: URL(string: "https://example.com")!)
        }
    }

    @Test func timedOutWorkerIsTerminatedAndReaped() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-research-worker-timeout-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let pidFile = directory.appendingPathComponent("worker.pid")
        let childPIDFile = directory.appendingPathComponent("child.pid")
        let executable = directory.appendingPathComponent("sleeping-worker.sh")
        let script = "#!/bin/sh\necho $$ > \"\(pidFile.path)\"\n(sleep 30) &\necho $! > \"\(childPIDFile.path)\"\nwait\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: executable.path
        )

        let client = ResearchWorkerClient(
            executableURL: executable,
            // Allow the shell to start and publish both PIDs even when the
            // full suite is running in parallel; the worker still sleeps for
            // 30 seconds, so this remains a deterministic timeout test.
            timeout: .seconds(3),
            executableValidator: { _ in true } // test fixture; production uses code-signature validation
        )
        await #expect(throws: ResearchWorkerClient.ResearchWorkerError.timedOut) {
            _ = try await client.fetch(url: URL(string: "https://example.com")!)
        }

        let pidDeadline = Date().addingTimeInterval(1)
        while !FileManager.default.fileExists(atPath: pidFile.path), Date() < pidDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let pidText = try String(contentsOf: pidFile, encoding: .utf8)
        let childPIDDeadline = Date().addingTimeInterval(1)
        while !FileManager.default.fileExists(atPath: childPIDFile.path), Date() < childPIDDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let pid = try #require(Int32(pidText.trimmingCharacters(in: .whitespacesAndNewlines)))
        let childPIDText = try String(contentsOf: childPIDFile, encoding: .utf8)
        let childPID = try #require(Int32(childPIDText.trimmingCharacters(in: .whitespacesAndNewlines)))
        #if canImport(Darwin)
        #expect(Darwin.kill(pid, 0) != 0, "timed-out worker must not remain alive")
        #expect(Darwin.kill(childPID, 0) != 0, "timed-out worker descendants must not remain alive")
        #endif
    }

    @Test func oversizedWorkerOutputIsRejectedAfterThePipeIsDrained() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-research-worker-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("oversized-worker.sh")
        let script = "#!/bin/sh\nhead -c 17000000 /dev/zero\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: executable.path
        )

        let client = ResearchWorkerClient(
            executableURL: executable,
            timeout: .seconds(5),
            executableValidator: { _ in true } // test fixture; production uses code-signature validation
        )
        await #expect(
            throws: ResearchWorkerClient.ResearchWorkerError.protocolError(
                "worker stdout exceeded the 16 MiB transport limit"
            )
        ) {
            _ = try await client.fetch(url: URL(string: "https://example.com")!)
        }
    }
}
