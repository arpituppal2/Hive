import Foundation
import Testing
@testable import HiveCore

@Suite("SwarmRunState")
struct SwarmRunStateTests {
    @Test func activeStatesAreOnlyRunningAndStopping() {
        #expect(!SwarmRunState.idle.isActive)
        #expect(SwarmRunState.running.isActive)
        #expect(SwarmRunState.stopping.isActive)
        #expect(!SwarmRunState.completed.isActive)
        #expect(!SwarmRunState.failed.isActive)
        #expect(!SwarmRunState.cancelled.isActive)
    }

    @Test func labelsAndSymbolsAreStableForDenseStatusUI() {
        #expect(SwarmRunState.idle.label == "Ready")
        #expect(SwarmRunState.running.label == "Working")
        #expect(SwarmRunState.stopping.label == "Stopping")
        #expect(SwarmRunState.completed.label == "Complete")
        #expect(SwarmRunState.failed.label == "Failed")
        #expect(SwarmRunState.cancelled.label == "Stopped")
        #expect(SwarmRunState.running.systemImage == "arrow.triangle.2.circlepath")
        #expect(SwarmRunState.cancelled.systemImage == "stop.circle")
    }

    @Test func stateRoundTripsAsCodableValue() throws {
        for state in SwarmRunState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(SwarmRunState.self, from: data)
            #expect(decoded == state)
        }
    }
}

@Suite("DispatcherStreamingAvailability")
struct DispatcherStreamingAvailabilityTests {
    @Test func unavailableLocalFallbackIsNotAdvertisedAsStreaming() async {
        let dispatcher = Dispatcher()
        #expect(await dispatcher.availableStreamingProvider(for: .librarian) == nil)
    }

    @Test func byokRequiresAResolvedKey() async {
        let config = BYOKRuntime.Config(
            baseURL: URL(string: "https://example.invalid/v1")!,
            apiKeyAlias: "missing-key",
            modelID: "test-model"
        )
        let runtime = BYOKRuntime(config: config) { _ in nil }
        let dispatcher = Dispatcher(byok: runtime)
        #expect(await dispatcher.availableProvider(for: .byokFrontier) == nil)
        #expect(await dispatcher.availableStreamingProvider(for: .byokFrontier) == nil)
    }

    @Test func resolvedByokKeyIsAdvertisedAsStreaming() async {
        let config = BYOKRuntime.Config(
            baseURL: URL(string: "https://example.invalid/v1")!,
            apiKeyAlias: "present-key",
            modelID: "test-model"
        )
        let runtime = BYOKRuntime(config: config) { _ in "test-secret" }
        let dispatcher = Dispatcher(byok: runtime)
        #expect(await dispatcher.availableProvider(for: .byokFrontier) == .byokRemote)
        #expect(await dispatcher.availableStreamingProvider(for: .byokFrontier) == .byokRemote)
    }

@Test func intentCategoriesAreNonEmpty() {
        #expect(!IntentCategory.allCases.isEmpty)
    }

@Test func modelTiersAreNonEmpty() {
        #expect(!ModelTier.allCases.isEmpty)
    }

@Test func axNodePreservesRole() {
        let node = AXNode(ref: "r1", role: "button", name: "Click", value: nil, desc: nil, bounds: nil, focusable: true, children: [])
        #expect(node.role == "button")
        #expect(node.ref == "r1")
    }

@Test func swarmRunStateIdleIsIdle() {
        #expect(SwarmRunState.idle == .idle)
    }
}
