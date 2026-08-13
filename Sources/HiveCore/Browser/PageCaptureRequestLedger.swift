import Foundation

/// The identity of one page-capture extraction request.
public struct PageCaptureRequestKey: Hashable, Sendable {
    public let tabID: String
    public let requestID: Int

    public init(tabID: String, requestID: Int) {
        self.tabID = tabID
        self.requestID = requestID
    }
}

/// The capture kind resolved when an extraction callback arrives.
public enum PageCaptureRequestDisposition: Equatable, Sendable {
    case manual
    case auto
    case canceledAuto
    case stale
}

/// Caller-owned request bookkeeping for page extraction. `ChromeState` mutates
/// this value on the main actor; the value itself remains deterministic and
/// independently testable.
///
/// Every extraction request is armed with its exact generation. A callback for
/// an unknown generation is stale and is rejected; canceled Auto-Capture
/// generations remain as tombstones until their matching callback arrives.
public struct PageCaptureRequestLedger: Sendable {
    private var pendingManual: Set<PageCaptureRequestKey> = []
    private var pendingAuto: Set<PageCaptureRequestKey> = []
    private var canceledAuto: Set<PageCaptureRequestKey> = []

    public init() {}

    public mutating func armManualCapture(tabID: String, requestID: Int) {
        pendingManual.insert(PageCaptureRequestKey(tabID: tabID, requestID: requestID))
    }

    public mutating func armAutoCapture(tabID: String, requestID: Int) {
        pendingAuto.insert(PageCaptureRequestKey(tabID: tabID, requestID: requestID))
    }

    @discardableResult
    public mutating func cancelPendingAutoCapture(for tabID: String) -> Bool {
        let keys = pendingAuto.filter { $0.tabID == tabID }
        guard !keys.isEmpty else { return false }
        pendingAuto.subtract(keys)
        canceledAuto.formUnion(keys)
        return true
    }

    public mutating func consume(tabID: String, requestID: Int) -> PageCaptureRequestDisposition {
        let key = PageCaptureRequestKey(tabID: tabID, requestID: requestID)
        if canceledAuto.remove(key) != nil { return .canceledAuto }
        if pendingAuto.remove(key) != nil { return .auto }
        if pendingManual.remove(key) != nil { return .manual }
        return .stale
    }

    public mutating func removeAll(for tabID: String) {
        pendingManual = pendingManual.filter { $0.tabID != tabID }
        pendingAuto = pendingAuto.filter { $0.tabID != tabID }
        canceledAuto = canceledAuto.filter { $0.tabID != tabID }
    }

    public var pendingCount: Int { pendingManual.count + pendingAuto.count }
    public var canceledCount: Int { canceledAuto.count }
}
