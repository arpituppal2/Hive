import Foundation
import Testing
@testable import HiveCore

@Suite("HostContextPolicyStore")
struct HostContextPolicyStoreTests {
    private let page = URL(string: "https://example.com/docs/read?token=secret#fragment")!

    private func makePath() throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiveHostPolicyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("policy.json"))
    }

    @Test("missing storage resolves the default policy")
    func missingStorageIsEmpty() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HostContextPolicyStore(path: path)

        #expect(await store.decision(for: page) == .default)
        #expect(await store.origins().isEmpty)
    }

    @Test("allow and block survive a new store instance")
    func decisionsRoundTrip() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HostContextPolicyStore(path: path)

        #expect(await store.set(.block, for: page))
        #expect(await store.decision(for: URL(string: "https://example.com/other")) == .block)

        let reopened = HostContextPolicyStore(path: path)
        #expect(await reopened.decision(for: page) == .block)
        #expect(await reopened.origins() == ["https://example.com"])
    }

    @Test("default reset removes one origin and resetAll removes every origin")
    func resetBehavior() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let other = URL(string: "https://other.example/path")!
        let store = HostContextPolicyStore(path: path)

        #expect(await store.set(.block, for: page))
        #expect(await store.set(.allow, for: other))
        #expect(await store.reset(for: page))
        #expect(await store.decision(for: page) == .default)
        #expect(await store.origins() == ["https://other.example"])
        #expect(await store.resetAll())
        #expect(await store.origins().isEmpty)
    }

    @Test("invalid URLs are rejected without creating a file")
    func invalidURLsAreRejected() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HostContextPolicyStore(path: path)

        #expect(await store.set(.allow, for: URL(string: "file:///tmp/private")) == false)
        #expect(await store.set(.block, for: URL(string: "https://user:pass@example.com")) == false)
        #expect(await store.origins().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: path.path))
    }

    @Test("malformed storage fails closed to an empty policy")
    func malformedStorageFailsClosed() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not-json".utf8).write(to: path)

        let store = HostContextPolicyStore(path: path)
        #expect(await store.decision(for: page) == .default)
        #expect(await store.origins().isEmpty)
        #expect(String(data: try Data(contentsOf: path), encoding: .utf8) == "not-json")
    }

    @Test("failed persistence rolls back policy and sequence state")
    func failedPersistenceRollsBackState() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HostContextPolicyStore(path: path, persistenceOverride: { _, _ in false })

        #expect(await store.set(.allow, for: page, sequence: 2) == false)
        #expect(await store.decision(for: page) == .default)
        #expect(await store.set(.block, for: page, sequence: 1) == false)
        #expect(await store.decision(for: page) == .default)
    }

    @Test("older sequenced mutations cannot overwrite newer durable decisions")
    func staleSequencedMutationIsRejected() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HostContextPolicyStore(path: path)

        #expect(await store.set(.allow, for: page, sequence: 2))
        #expect(await store.set(.block, for: page, sequence: 1) == false)
        #expect(await store.decision(for: page) == .allow)

        let reopened = HostContextPolicyStore(path: path)
        #expect(await reopened.decision(for: page) == .allow)
    }

    @Test("persisted data contains only canonical origins and decisions")
    func persistedDataIsOriginOnly() async throws {
        let (directory, path) = try makePath()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HostContextPolicyStore(path: path)

        #expect(await store.set(.block, for: page))
        let persistedData = try Data(contentsOf: path)
        let persisted = String(data: persistedData, encoding: .utf8) ?? ""
        let object = try #require(JSONSerialization.jsonObject(with: persistedData) as? [String: Any])
        let decisions = try #require(object["decisions"] as? [String: String])
        #expect(decisions == ["https://example.com": "block"])
        #expect(!persisted.contains("/docs/read"))
        #expect(!persisted.contains("token=secret"))
        #expect(!persisted.contains("fragment"))
        #expect(!persisted.contains("user:pass"))
    }
}
