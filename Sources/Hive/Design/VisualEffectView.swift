import SwiftUI
import AppKit

// MARK: - VisualEffectView
//
// An NSViewRepresentable wrapping NSVisualEffectView for proper glass/translucency
// in browser chrome. This is the foundation for Hive's signature warm glass aesthetic:
// a subtly-tinted blur that lets desktop wallpaper bleed through while keeping chrome
// text perfectly legible.
//
// Usage in browser chrome:
//   VisualEffectView(material: .headerView, blendingMode: .behindWindow)
//       .ignoresSafeArea()
//
// The `behindWindow` mode creates a true glass effect where content behind the window
// (desktop, other windows) influences the blur. `withinWindow` is for in-window
// translucency (panels, popovers).
//
// SPEC §7.4 rules:
//   - Chrome uses .headerView material with .behindWindow blending
//   - Popovers/panels use .popover or .hudWindow with .withinWindow blending
//   - Never stack nested materials (performance killer)
//   - Never pure black or white underneath — always the warm Hive background

struct VisualEffectView: NSViewRepresentable {

    var material: NSVisualEffectView.Material = .headerView
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var isEmphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - HiveChromeGlass
//
// Convenience modifier that applies the standard Hive chrome glass treatment:
// the NSVisualEffectView material with a warm background tint wash overlaid.
// This is the single pattern all chrome surfaces should use — no more ad-hoc
// double-background hacks.

struct HiveChromeGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // The actual NSVisualEffectView behind everything
                    VisualEffectView(material: .headerView, blendingMode: .behindWindow)
                        .ignoresSafeArea()

                    // Warm background tint wash — the signature Hive warmth.
                    // In dark mode: deep mahogany (#1A1512) at low opacity so the glass
                    // material still shines through. In light mode: warm cream.
                    Color(hiveBackgroundFor(scheme))
                        .opacity(scheme == .dark ? 0.35 : 0.50)
                        .ignoresSafeArea()
                }
            )
    }
}

extension View {
    /// Applies the standard Hive chrome glass background — a true NSVisualEffectView
    /// with a warm tint wash. Use on chrome containers (top bar, sidebar, bottom bar).
    func hiveChromeGlass() -> some View {
        modifier(HiveChromeGlassModifier())
    }
}

// MARK: - HivePanelGlass
//
// A denser glass variant for floating panels, popovers, and overlays.
// Uses .hudWindow material with .withinWindow blending and a tint wash.

struct HivePanelGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .ignoresSafeArea()

                    Color(hiveBackgroundFor(scheme))
                        .opacity(scheme == .dark ? 0.50 : 0.60)
                        .ignoresSafeArea()
                }
            )
    }
}

extension View {
    /// Applies the Hive panel glass background — denser blur for floating panels.
    func hivePanelGlass() -> some View {
        modifier(HivePanelGlassModifier())
    }
}
