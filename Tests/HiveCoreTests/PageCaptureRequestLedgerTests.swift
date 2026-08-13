import HiveCore
import Testing

@Suite("Page Capture Request Ledger")
struct PageCaptureRequestLedgerTests {
    @Test func canceledAutoRequestOnlyConsumesItsOwnCallback() {
        var ledger = PageCaptureRequestLedger()
        ledger.armAutoCapture(tabID: "tab", requestID: 7)
        let canceled = ledger.cancelPendingAutoCapture(for: "tab")
        let manual = ledger.consume(tabID: "tab", requestID: 8)
        let canceledCallback = ledger.consume(tabID: "tab", requestID: 7)

        #expect(canceled)
        #expect(manual == .stale)
        #expect(canceledCallback == .canceledAuto)
    }

    @Test func pendingAutoRequestIsAutoUntilCallbackArrives() {
        var ledger = PageCaptureRequestLedger()
        ledger.armAutoCapture(tabID: "tab", requestID: 3)
        let first = ledger.consume(tabID: "tab", requestID: 3)
        let duplicate = ledger.consume(tabID: "tab", requestID: 3)

        #expect(first == .auto)
        #expect(duplicate == .stale)
    }

    @Test func manualAndAutoGenerationsRemainDistinct() {
        var ledger = PageCaptureRequestLedger()
        ledger.armAutoCapture(tabID: "tab", requestID: 10)
        ledger.armManualCapture(tabID: "tab", requestID: 11)
        let auto = ledger.consume(tabID: "tab", requestID: 10)
        let manual = ledger.consume(tabID: "tab", requestID: 11)

        #expect(auto == .auto)
        #expect(manual == .manual)
    }

    @Test func multipleCanceledRequestsRemainDistinct() {
        var ledger = PageCaptureRequestLedger()
        ledger.armAutoCapture(tabID: "tab", requestID: 10)
        ledger.armAutoCapture(tabID: "tab", requestID: 11)
        ledger.armAutoCapture(tabID: "other", requestID: 10)
        let canceled = ledger.cancelPendingAutoCapture(for: "tab")
        let firstTab = ledger.consume(tabID: "tab", requestID: 11)
        let otherTab = ledger.consume(tabID: "other", requestID: 10)
        let secondTab = ledger.consume(tabID: "tab", requestID: 10)

        #expect(canceled)
        #expect(firstTab == .canceledAuto)
        #expect(otherTab == .auto)
        #expect(secondTab == .canceledAuto)
    }

    @Test func consumeWithoutArmingReturnsStale() {
        var ledger = PageCaptureRequestLedger()
        let result = ledger.consume(tabID: "unknown", requestID: 1)
        #expect(result == .stale)
    }

    @Test func cancelPendingWithoutArmingReturnsFalse() {
        var ledger = PageCaptureRequestLedger()
        let result = ledger.cancelPendingAutoCapture(for: "nonexistent")
        #expect(!result)
    }

    @Test func emptyLedgerHasZeroCounts() {
        let ledger = PageCaptureRequestLedger()
        #expect(ledger.pendingCount == 0)
        #expect(ledger.canceledCount == 0)
    }

    @Test func removingTabDropsPendingAndTombstones() {
        var ledger = PageCaptureRequestLedger()
        ledger.armAutoCapture(tabID: "tab", requestID: 1)
        _ = ledger.cancelPendingAutoCapture(for: "tab")
        ledger.removeAll(for: "tab")
        let result = ledger.consume(tabID: "tab", requestID: 1)

        #expect(ledger.pendingCount == 0)
        #expect(ledger.canceledCount == 0)
        #expect(result == .stale)
    }

@Test func requestKeyEquality() {
        let a = PageCaptureRequestKey(tabID: "t1", requestID: 1)
        let b = PageCaptureRequestKey(tabID: "t1", requestID: 1)
        #expect(a == b)
    }
}
