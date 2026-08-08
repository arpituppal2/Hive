import Foundation
import Testing
@testable import HiveCore

@Suite("TerminalDownloadRecord")
struct TerminalDownloadRecordTests {
    private let fixedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    @Test func terminalStateRequiresCompletionOrCancellation() {
        let active = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "partial.zip",
            url: URL(string: "https://example.com/partial.zip")!,
            progress: 0.4
        )
        let completed = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "done.zip",
            url: URL(string: "https://example.com/done.zip")!,
            progress: 1,
            isComplete: true
        )
        let canceled = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "stopped.zip",
            url: URL(string: "https://example.com/stopped.zip")!,
            progress: 0.2,
            isCanceled: true
        )
        let interrupted = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "interrupted.zip",
            url: URL(string: "https://example.com/interrupted.zip")!,
            progress: 0.2,
            isInterrupted: true
        )

        #expect(!active.isTerminal)
        #expect(completed.isTerminal)
        #expect(canceled.isTerminal)
        #expect(interrupted.isTerminal)
        #expect(!interrupted.isCanceled)
        #expect(!interrupted.isComplete)
    }

    @Test func sensitiveURLComponentsAreRemovedAtConstruction() {
        let record = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "report.pdf",
            url: URL(string: "https://user:secret@example.com/files/report.pdf?token=private#section")!,
            isComplete: true
        )

        #expect(record.url.absoluteString == "https://example.com/files/report.pdf")
    }

    @Test func progressIsClampedToHistoryBounds() {
        let below = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "below",
            url: URL(string: "https://example.com/below")!,
            progress: -4
        )
        let above = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "above",
            url: URL(string: "https://example.com/above")!,
            progress: 4
        )

        #expect(below.progress == 0)
        #expect(above.progress == 1)
    }

    @Test func codableRoundTripContainsOnlyStableHistoryFields() throws {
        let record = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "report.pdf",
            url: URL(string: "https://example.com/report.pdf?token=private")!,
            progress: 1,
            isComplete: true
        )
        let data = try JSONEncoder().encode(record)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(object.keys)

        #expect(keys == ["id", "suggestedName", "url", "progress", "isComplete", "isCanceled", "isInterrupted"])
        #expect(object["url"] as? String == "https://example.com/report.pdf")
        #expect(object["destinationURL"] == nil)
        #expect(object["cefID"] == nil)
        #expect(object["downloadController"] == nil)
        #expect(object["isPaused"] == nil)
    }

    @Test func legacyRuntimeAndPathKeysAreIgnoredOnDecode() throws {
        let json = """
        {
          "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
          "suggestedName": "legacy.zip",
          "url": "https://example.com/legacy.zip?token=private",
          "progress": 1.4,
          "isComplete": true,
          "isCanceled": false,
          "cefID": 42,
          "isPaused": true,
          "destinationURL": "/Users/private/Downloads/legacy.zip",
          "downloadController": "process-local"
        }
        """
        let record = try JSONDecoder().decode(
            TerminalDownloadRecord.self,
            from: Data(json.utf8)
        )

        #expect(record.id == fixedID)
        #expect(record.progress == 1)
        #expect(record.isTerminal)
        #expect(record.url.absoluteString == "https://example.com/legacy.zip")
        #expect(!record.isInterrupted)
    }

    @Test func interruptedStateRoundTripsWithoutBecomingCanceled() throws {
        let record = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "interrupted.zip",
            url: URL(string: "https://example.com/interrupted.zip")!,
            progress: 0.4,
            isInterrupted: true
        )
        let decoded = try JSONDecoder().decode(
            TerminalDownloadRecord.self,
            from: JSONEncoder().encode(record)
        )

        #expect(decoded.isInterrupted)
        #expect(!decoded.isCanceled)
        #expect(!decoded.isComplete)
        #expect(decoded.isTerminal)
    }

    @Test func equalityRoundTripsStableMetadata() throws {
        let record = TerminalDownloadRecord(
            id: fixedID,
            suggestedName: "same.zip",
            url: URL(string: "https://example.com/same.zip")!,
            progress: 0.75,
            isCanceled: true
        )
        let decoded = try JSONDecoder().decode(
            TerminalDownloadRecord.self,
            from: JSONEncoder().encode(record)
        )

        #expect(decoded == record)
    }
}
