import Foundation
import Testing
@testable import HiveCore

@Suite("DownloadControlStateMachine")
struct DownloadControlStateTests {
    @Test("pause is represented as a pending request until native state confirms it")
    func pauseRequiresNativeReconciliation() {
        var machine = DownloadControlStateMachine()

        let transition = machine.requestPause()

        #expect(transition?.action == .pause)
        #expect(transition?.state == .pauseRequested)
        #expect(machine.state == .pauseRequested)
        #expect(!machine.canRequestPause)
        #expect(!machine.canRequestResume)

        machine.reconcile(nativeIsPaused: nil)
        #expect(machine.state == .pauseRequested)

        machine.reconcile(nativeIsPaused: true)
        #expect(machine.state == .paused)
        #expect(machine.canRequestResume)
    }

    @Test("resume is represented as a pending request until native state confirms it")
    func resumeRequiresNativeReconciliation() {
        var machine = DownloadControlStateMachine(state: .paused)

        let transition = machine.requestResume()

        #expect(transition?.action == .resume)
        #expect(transition?.state == .resumeRequested)
        #expect(machine.state == .resumeRequested)
        #expect(!machine.canRequestPause)
        #expect(!machine.canRequestResume)

        machine.reconcile(nativeIsPaused: nil)
        #expect(machine.state == .resumeRequested)

        machine.reconcile(nativeIsPaused: false)
        #expect(machine.state == .active)
        #expect(machine.canRequestPause)
    }

    @Test("duplicate or contradictory requests are rejected while one is pending")
    func pendingRequestIsSingleFlight() {
        var machine = DownloadControlStateMachine()

        #expect(machine.requestPause() != nil)
        #expect(machine.requestPause() == nil)
        #expect(machine.requestResume() == nil)

        machine.reconcile(nativeIsPaused: true)
        #expect(machine.requestResume() != nil)
        #expect(machine.requestPause() == nil)
    }

    @Test("a request timeout re-enables the last actionable control")
    func pendingRequestTimeout() {
        var machine = DownloadControlStateMachine()
        _ = machine.requestPause()
        machine.timeoutPendingRequest()
        #expect(machine.state == .active)
        #expect(machine.canRequestPause)

        _ = machine.requestPause()
        machine.reconcile(nativeIsPaused: true)
        _ = machine.requestResume()
        machine.timeoutPendingRequest()
        #expect(machine.state == .paused)
        #expect(machine.canRequestResume)
    }

    @Test("terminal cleanup resets control state")
    func terminalCleanup() {
        var machine = DownloadControlStateMachine(state: .paused)
        _ = machine.requestResume()

        machine.resetToActive()

        #expect(machine.state == .active)
        #expect(machine.canRequestPause)
    }

    @Test("control state is codable without runtime controller data")
    func stateRoundTrips() throws {
        let values: [DownloadControlState] = [.active, .paused, .pauseRequested, .resumeRequested]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for value in values {
            let data = try encoder.encode(value)
            #expect(try decoder.decode(DownloadControlState.self, from: data) == value)
        }
    }
}
