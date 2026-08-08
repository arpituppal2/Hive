import Foundation

/// Keeps mutually exclusive full-window browser overlays from stacking their
/// dimming layers and competing for keyboard focus.
public enum OverlayPresentationPolicy {
    public struct State: Equatable, Sendable {
        public var commandPalettePresented: Bool
        public var tabSearchPresented: Bool

        public init(commandPalettePresented: Bool = false, tabSearchPresented: Bool = false) {
            self.commandPalettePresented = commandPalettePresented
            self.tabSearchPresented = tabSearchPresented
        }
    }

    public static func openingCommandPalette() -> State {
        State(commandPalettePresented: true, tabSearchPresented: false)
    }

    public static func openingTabSearch() -> State {
        State(commandPalettePresented: false, tabSearchPresented: true)
    }
}
