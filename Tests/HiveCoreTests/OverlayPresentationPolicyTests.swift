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
}
