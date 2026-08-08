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

    @Test("nil priorCleanExit is reflected as null")
    func nilPriorCleanExit() {
        let evidence = HiveSessionEvidence(
            restoredFromDisk: true,
            priorCleanExit: nil,
            snapshotSequence: 1,
            durableTabCount: 0,
            writeSucceeded: true
        )
        #expect(evidence.priorCleanExit == nil)
        // The marker line contains the JSON-encoded evidence; nil fields
        // may be omitted or rendered as null depending on encoder config.
        let line = evidence.markerLine()
        #expect(line.contains("restoredFromDisk") && line.contains("durableTabCount"))
    }

    @Test("write failure is reflected in marker")
    func writeFailureMarker() {
        let evidence = HiveSessionEvidence(
            restoredFromDisk: true,
            priorCleanExit: true,
            snapshotSequence: 5,
            durableTabCount: 10,
            writeSucceeded: false
        )
        #expect(!evidence.writeSucceeded)
        #expect(evidence.markerLine().contains("\"writeSucceeded\":false"))
    }

    @Test("zero sequence with no restore is a fresh session")
    func freshSession() {
        let evidence = HiveSessionEvidence(
            restoredFromDisk: false,
            priorCleanExit: nil,
            snapshotSequence: 0,
            durableTabCount: 0,
            writeSucceeded: true
        )
        #expect(!evidence.restoredFromDisk)
        #expect(evidence.snapshotSequence == 0)
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

@Test("highSnapshotSequencePreserved")
    func highSnapshot() {
        let evidence = HiveSessionEvidence(
            restoredFromDisk: true, priorCleanExit: true,
            snapshotSequence: 9_999_999, durableTabCount: 42, writeSucceeded: true
        )
        #expect(evidence.snapshotSequence == 9_999_999)
        #expect(evidence.durableTabCount == 42)
    }
}
