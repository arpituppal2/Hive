import Foundation
import Testing
@testable import HiveCore

@Suite("HiveSessionEvidence")
struct HiveSessionEvidenceTests {
    @Test("evidence marker is deterministic and contains lifecycle facts only")
    func deterministicMarker() {
        let evidence = HiveSessionEvidence(
            restoredFromDisk: true,
            priorCleanExit: false,
            snapshotSequence: 8,
            durableTabCount: 3,
            writeSucceeded: true
        )

        #expect(evidence.markerLine() == "HIVE_SESSION_EVIDENCE {\"durableTabCount\":3,\"priorCleanExit\":false,\"restoredFromDisk\":true,\"snapshotSequence\":8,\"writeSucceeded\":true}")
        #expect(!evidence.markerLine().contains("http"))
        #expect(!evidence.markerLine().contains("title"))
    }

    @Test("negative tab counts are fail-closed to zero")
    func tabCountIsBounded() {
        let evidence = HiveSessionEvidence(
            restoredFromDisk: false,
            priorCleanExit: nil,
            snapshotSequence: 0,
            durableTabCount: -1,
            writeSucceeded: false
        )

        #expect(evidence.durableTabCount == 0)
        #expect(evidence.markerLine().hasPrefix("HIVE_SESSION_EVIDENCE "))
    }
}
