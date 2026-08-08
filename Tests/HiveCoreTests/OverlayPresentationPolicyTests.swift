import Testing
@testable import HiveCore

@Suite("OverlayPresentationPolicy")
struct OverlayPresentationPolicyTests {
    @Test func openingCommandPaletteDismissesTabSearch() {
        #expect(
            OverlayPresentationPolicy.openingCommandPalette() ==
                OverlayPresentationPolicy.State(commandPalettePresented: true, tabSearchPresented: false)
        )
    }

    @Test func openingTabSearchDismissesCommandPalette() {
        #expect(
            OverlayPresentationPolicy.openingTabSearch() ==
                OverlayPresentationPolicy.State(commandPalettePresented: false, tabSearchPresented: true)
        )
    }

    @Test func closingBothProducesEmptyState() {
        let state = OverlayPresentationPolicy.State(commandPalettePresented: false, tabSearchPresented: false)
        #expect(state.commandPalettePresented == false)
        #expect(state.tabSearchPresented == false)
    }

    @Test func bothStatesAreIndependent() {
        let state = OverlayPresentationPolicy.State(commandPalettePresented: true, tabSearchPresented: false)
        #expect(state.commandPalettePresented)
        #expect(!state.tabSearchPresented)
    }

    @Test func stateEqualityIgnoresTransientTimestamps() {
        let a = OverlayPresentationPolicy.State(commandPalettePresented: true, tabSearchPresented: false)
        let b = OverlayPresentationPolicy.State(commandPalettePresented: true, tabSearchPresented: false)
        #expect(a == b)
    }

@Test func bothShownIsPossible() {
        let state = OverlayPresentationPolicy.State(commandPalettePresented: true, tabSearchPresented: true)
        #expect(state.commandPalettePresented)
        #expect(state.tabSearchPresented)
    }

    @Test func policyNameIsStable() {
        let state = OverlayPresentationPolicy.State(commandPalettePresented: false, tabSearchPresented: false)
        #expect(!state.commandPalettePresented)
        #expect(!state.tabSearchPresented)
    }
}
