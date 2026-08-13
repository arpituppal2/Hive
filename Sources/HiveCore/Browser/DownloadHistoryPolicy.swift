import Foundation

/// Pure rules for mutating terminal download history.
///
/// Live downloads must remain owned by the browser state until CEF reports a
/// terminal outcome. This policy is intentionally limited to terminal rows so
/// a history affordance cannot accidentally discard an active transfer.
public enum DownloadHistoryPolicy {
    public static func isTerminal(
        isComplete: Bool,
        isCanceled: Bool,
        isInterrupted: Bool
    ) -> Bool {
        isComplete || isCanceled || isInterrupted
    }

    public static func shouldRemoveFromHistory(
        id: UUID,
        requestedID: UUID,
        isComplete: Bool,
        isCanceled: Bool,
        isInterrupted: Bool
    ) -> Bool {
        id == requestedID && isTerminal(
            isComplete: isComplete,
            isCanceled: isCanceled,
            isInterrupted: isInterrupted
        )
    }
}
