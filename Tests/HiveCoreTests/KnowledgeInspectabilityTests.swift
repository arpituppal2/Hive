import Foundation
import Testing
@testable import HiveCore

@Suite("KnowledgeInspectabilityPolicy")
struct KnowledgeInspectabilityPolicyTests {
    @Test func candidatePrivateLegacyAndDurableRowsAreSeparated() {
        let durable = HoneycombStore.Node(type: .note, label: "Durable", provenance: "user")
        let candidate = HoneycombStore.Node(
            type: .note, label: "Candidate",
            metadata: .object(["candidate": .bool(true)]), provenance: "user"
        )
        let privateNode = HoneycombStore.Node(
            type: .note, label: "Private",
            metadata: .object(["isPrivate": .bool(true)]), provenance: "user"
        )
        let legacyPrivate = HoneycombStore.Node(type: .note, label: "Legacy private", provenance: "private-voice")
        let legacyLibrarian = HoneycombStore.Node(type: .note, label: "Legacy extraction", provenance: "librarian-extraction")

        #expect(HoneycombStore.isInspectableNode(durable))
        #expect(!HoneycombStore.isInspectableNode(candidate))
        #expect(!HoneycombStore.isInspectableNode(privateNode))
        #expect(!HoneycombStore.isInspectableNode(legacyPrivate))
        #expect(!HoneycombStore.isInspectableNode(legacyLibrarian))
    }
}
