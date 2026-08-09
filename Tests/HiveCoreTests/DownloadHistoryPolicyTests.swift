import Foundation
import Testing
@testable import HiveCore

@Suite("DownloadHistoryPolicy")
struct DownloadHistoryPolicyTests {
    private let requestedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    @Test func removesOnlyMatchingTerminalRows() {
        #expect(DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: requestedID,
            requestedID: requestedID,
            isComplete: true,
            isCanceled: false,
            isInterrupted: false
        ))
        #expect(!DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: UUID(),
            requestedID: requestedID,
            isComplete: true,
            isCanceled: false,
            isInterrupted: false
        ))
    }

    @Test func activeRowsAreNeverRemovableHistory() {
        #expect(!DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: requestedID,
            requestedID: requestedID,
            isComplete: false,
            isCanceled: false,
            isInterrupted: false
        ))
    }

    @Test func completedRowsAreTerminal() {
        #expect(DownloadHistoryPolicy.isTerminal(isComplete: true, isCanceled: false, isInterrupted: false))
        #expect(!DownloadHistoryPolicy.isTerminal(isComplete: false, isCanceled: false, isInterrupted: false))
    }

    @Test func activeButCanceledRowsAreRemovableFromHistory() {
        #expect(DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: requestedID, requestedID: requestedID,
            isComplete: false, isCanceled: true, isInterrupted: false
        ))
    }

    @Test func completeWithMismatchedIDIsNotRemovable() {
        #expect(!DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: UUID(), requestedID: requestedID,
            isComplete: true, isCanceled: false, isInterrupted: false
        ))
    }

    @Test func interruptedAndCanceledRowsAreTerminal() {
        #expect(DownloadHistoryPolicy.isTerminal(
            isComplete: false,
            isCanceled: true,
            isInterrupted: false
        ))
        #expect(DownloadHistoryPolicy.isTerminal(
            isComplete: false,
            isCanceled: false,
            isInterrupted: true
        ))
    }

@Test func completedNotCanceledIsRemovableHistory() {
        #expect(DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: requestedID, requestedID: requestedID,
            isComplete: true, isCanceled: false, isInterrupted: false
        ))
    }

    @Test func alreadyCanceledNotRequestedIsNotRemovable() {
        #expect(!DownloadHistoryPolicy.shouldRemoveFromHistory(
            id: UUID(), requestedID: requestedID,
            isComplete: false, isCanceled: true, isInterrupted: false
        ))
    }

@Test func downloadStatesIncludePending() {
        #expect(DownloadState.allCases.contains(.pending))
    }
}
