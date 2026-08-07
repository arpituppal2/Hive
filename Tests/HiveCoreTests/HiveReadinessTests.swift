import Foundation
import Testing
@testable import HiveCore

@Suite("HiveReadiness")
struct HiveReadinessTests {
    @Test("ready report emits a deterministic pass marker")
    func readyMarker() {
        let report = HiveReadinessReport(
            appInitialized: true,
            browserShellReady: true,
            message: "browser shell ready"
        )

        #expect(report.isReady)
        #expect(report.markerLine() == "HIVE_READINESS_PASS {\"appInitialized\":true,\"browserShellReady\":true,\"message\":\"browser shell ready\"}")
    }

    @Test("any failed bootstrap invariant emits a fail marker")
    func failedMarker() {
        let report = HiveReadinessReport(
            appInitialized: true,
            browserShellReady: false,
            message: "browser shell unavailable"
        )

        #expect(!report.isReady)
        #expect(report.markerLine().hasPrefix("HIVE_READINESS_FAIL "))
        #expect(report.markerLine().contains("browser shell unavailable"))
    }

    @Test("diagnostics are bounded before they enter smoke logs")
    func messageIsBounded() throws {
        let report = HiveReadinessReport(
            appInitialized: false,
            browserShellReady: false,
            message: String(repeating: "x", count: 1_000)
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(HiveReadinessReport.self, from: data)

        #expect(decoded.message.count == 240)
        #expect(decoded.markerLine().hasPrefix("HIVE_READINESS_FAIL "))
    }
}
