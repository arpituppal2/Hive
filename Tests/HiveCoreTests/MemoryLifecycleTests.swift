import Foundation
import Testing
@testable import HiveCore

@Suite("DurableMemoryLifecycle")
struct DurableMemoryLifecycleTests {
    private func makeStore() throws -> HoneycombStore {
        try HoneycombStore(path: ":memory:")
    }

    @Test func correctionExposesInspectableRevisionAndRefreshesSearch() async throws {
        let store = try makeStore()
        let node = HoneycombStore.Node(
            type: .note,
            label: "Original title",
            metadata: .object(["content": .string("original memory")]),
            provenance: "user"
        )
        _ = try await store.insertNode(node)

        _ = try await store.updateNode(
            id: node.id,
            label: "Corrected title",
            metadata: .object(["content": .string("corrected memory")])
        )

        let revisions = try await store.getRevisions(nodeID: node.id)
        #expect(revisions.count == 1)
        #expect(revisions[0].nodeID == node.id)
        #expect(revisions[0].previousLabel == "Original title")
        #expect(revisions[0].previousMetadata == .object(["content": .string("original memory")]))
        // Search uses OR semantics across query terms; verify unique terms
        // rather than the shared word "memory".
        #expect(try await store.search(query: "original").isEmpty)
        #expect(try await store.search(query: "corrected").map(\.id) == [node.id])
    }

    @Test func revisionHistoryOmitsInternalMetadata() async throws {
        let store = try makeStore()
        let node = HoneycombStore.Node(
            type: .source,
            label: "Before",
            metadata: .object([
                "snippet": .string("safe snippet"),
                "extractedText": .string("sensitive fetched body"),
                "retentionClass": .string("restricted")
            ]),
            provenance: "user"
        )
        _ = try await store.insertNode(node)
        _ = try await store.updateNode(id: node.id, label: "After")
        let revision = try #require(await store.getRevisions(nodeID: node.id).first)
        #expect(revision.previousMetadata == .object(["snippet": .string("safe snippet")]))
    }

    @Test func typedClaimCorrectionRoundTripsThroughClaimAPI() async throws {
        let store = try makeStore()
        let claim = Claim(id: "claim-1", text: "Old claim", confidence: 0.4, provenance: "user")
        _ = try await store.createClaim(claim)

        _ = try await store.correctClaim(claimID: claim.id, text: "Corrected claim", confidence: 0.9)

        let corrected = try #require(await store.getClaim(id: claim.id))
        #expect(corrected.text == "Corrected claim")
        #expect(corrected.confidence == 0.9)
        #expect(try await store.getRevisions(nodeID: claim.id).count == 1)
        #expect(try await store.findNode(type: .claim, contentHash: HoneycombStore.sha256("Corrected claim"))?.id == claim.id)
        #expect(try await store.findNode(type: .claim, contentHash: HoneycombStore.sha256("Old claim")) == nil)

        let duplicate = try await store.createClaim(Claim(text: "Corrected claim", confidence: 0.2))
        #expect(duplicate.id == claim.id)

        let genericNode = HoneycombStore.Node(
            type: .note,
            label: "Hash-preserving note",
            metadata: .object(["content": .string("before")]),
            contentHash: "stable-hash",
            provenance: "user"
        )
        _ = try await store.insertNode(genericNode)
        let genericallyUpdated = try #require(await store.updateNode(
            id: genericNode.id,
            metadata: .object(["content": .string("after")])
        ))
        #expect(genericallyUpdated.contentHash == "stable-hash")
        #expect(try await store.getNode(id: genericNode.id)?.contentHash == "stable-hash")
    }

    @Test func correctingClaimToExistingTextFailsWithoutChangingEitherClaim() async throws {
        let store = try makeStore()
        let first = try await store.createClaim(Claim(text: "First claim"))
        let second = try await store.createClaim(Claim(text: "Second claim"))

        do {
            _ = try await store.correctClaim(claimID: second.id, text: first.text)
            Issue.record("Expected correction to an existing claim hash to fail")
        } catch let error as HoneycombError {
            #expect(error == .contentHashConflict(
                type: .claim,
                contentHash: HoneycombStore.sha256(first.text),
                existingNodeID: first.id
            ))
        }

        #expect(try await store.getClaim(id: first.id)?.text == "First claim")
        #expect(try await store.getClaim(id: second.id)?.text == "Second claim")
        #expect(try await store.getRevisions(nodeID: second.id).isEmpty)
    }

    @Test func typedBriefCorrectionPreservesSourceEdges() async throws {
        let store = try makeStore()
        let source = HoneycombStore.Node(
            type: .source,
            label: "Brief source",
            metadata: .object(["url": .string("https://example.com/brief")]),
            provenance: "user"
        )
        _ = try await store.insertNode(source)
        let brief = Brief(id: "brief-1", title: "Old brief", content: "Old body", sourceIDs: [source.id], provenance: "user")
        _ = try await store.createBrief(brief)

        _ = try await store.updateBrief(briefID: brief.id, title: "New brief", content: "New body")

        let corrected = try #require(await store.getBrief(id: brief.id))
        #expect(corrected.title == "New brief")
        #expect(corrected.content == "New body")
        #expect(try await store.getEdges(from: brief.id, relation: .references).count == 1)
    }

    @Test func durableExportIncludesProvenanceAndLinkedSource() async throws {
        let store = try makeStore()
        let source = HoneycombStore.Node(
            type: .source,
            label: "Hive docs",
            metadata: .object(["url": .string("https://example.com/hive")]),
            provenance: "browser-capture"
        )
        let note = HoneycombStore.Node(
            type: .note,
            label: "Research note",
            metadata: .object(["content": .string("A durable, cited observation")]),
            provenance: "user"
        )
        _ = try await store.insertNode(source)
        _ = try await store.insertNode(note)
        _ = try await store.insertEdge(.init(
            sourceID: note.id,
            targetID: source.id,
            relation: .references
        ))

        let markdown = try await store.exportMarkdown(note)
        #expect(markdown.contains("Research note"))
        #expect(markdown.contains("Provenance: `user`"))
        #expect(markdown.contains("A durable, cited observation"))
        #expect(markdown.contains("https://example.com/hive"))
    }

    @Test func durableExportOmitsInternalTransportMetadata() async throws {
        let store = try makeStore()
        let node = HoneycombStore.Node(
            type: .source,
            label: "Safe export",
            metadata: .object([
                "url": .string("https://example.com"),
                "snippet": .string("Visible citation"),
                "extractedText": .string("Internal fetched body"),
                "retentionClass": .string("restricted")
            ]),
            provenance: "user"
        )
        _ = try await store.insertNode(node)

        let markdown = try await store.exportMarkdown(node)
        #expect(markdown.contains("Visible citation"))
        #expect(!markdown.contains("Internal fetched body"))
        #expect(!markdown.contains("restricted"))
    }

    @Test func exportingCandidateOrPrivateNodeFailsClosed() async throws {
        let store = try makeStore()
        let candidate = HoneycombStore.Node(
            type: .note,
            label: "Candidate",
            metadata: .object(["content": .string("session only"), "candidate": .bool(true)])
        )
        let privateNode = HoneycombStore.Node(
            type: .note,
            label: "Private",
            metadata: .object(["content": .string("private"), "isPrivate": .bool(true)])
        )
        _ = try await store.insertNode(candidate)
        _ = try await store.insertNode(privateNode)
        for node in [candidate, privateNode] {
            do {
                _ = try await store.exportMarkdown(node)
                Issue.record("Expected export to be denied for \(node.label)")
            } catch let error as HoneycombError {
                #expect(error == .exportNotPermitted(node.id))
            }
        }
    }

    @Test func exportingMissingNodeFailsClosed() async throws {
        let store = try makeStore()
        let node = HoneycombStore.Node(id: "missing", type: .note, label: "Gone")
        do {
            _ = try await store.exportMarkdown(node)
            Issue.record("Expected export of a missing node to fail")
        } catch let error as HoneycombError {
            #expect(error == .nodeNotFound(node.id))
        }
    }

    @Test func deletingDurableNodeCleansGraphSearchAndRevisionHistory() async throws {
        let store = try makeStore()
        let source = HoneycombStore.Node(
            type: .source,
            label: "Delete source",
            metadata: .object(["url": .string("https://example.com/delete")]),
            provenance: "user"
        )
        let note = HoneycombStore.Node(
            type: .note,
            label: "Delete me",
            metadata: .object(["content": .string("remove this durable memory")]),
            provenance: "user"
        )
        _ = try await store.insertNode(source)
        _ = try await store.insertNode(note)
        _ = try await store.insertEdge(.init(
            sourceID: note.id,
            targetID: source.id,
            relation: .references
        ))
        _ = try await store.updateNode(id: note.id, label: "Edited before delete")

        try await store.deleteNode(id: note.id)

        #expect(try await store.getNode(id: note.id) == nil)
        #expect(try await store.getRevisions(nodeID: note.id).isEmpty)
        #expect(try await store.getEdges(from: note.id).isEmpty)
        #expect(try await store.getEdges(to: note.id).isEmpty)
        #expect(try await store.search(query: "remove this durable memory").isEmpty)
        #expect(try await store.getNode(id: source.id) != nil)
    }
}
