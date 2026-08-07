import SwiftUI

// MARK: - HiveSurfaceLayer
//
// Brand Guidelines v1.0 — The Hierarchy of Materials
// Hive's surfaces exist in a strict depth hierarchy. Nothing is opaque without reason.
//
// Layer 0 — Web Content (the actual page; Hive never covers it without purpose)
// Layer 1 — Passive Chrome (the browser itself)
//   Material: ultraThinMaterial (Liquid Glass)
//   Behavior: appears on scroll, disappears at rest
//   Blur radius: system-default vibrancy — do not override
//   Specular highlight: system-applied, not custom
//
// Layer 2 — Active Overlays (URL bar focused, tab switcher, settings)
//   Material: thinMaterial
//   Corner radius: 14pt (matches system UI corner radii precisely)
//   Subtle inner shadow: 0.5pt, black at 8% opacity on top edge only
//
// Layer 3 — Swarm Surface (AI responses, suggestions)
//   Material: regularMaterial (more opaque — Swarm earns screen presence by being useful)
//   Swarm Violet at 8% tint applied to the material background
//   Rounded rectangle: 18pt radius
//
// Layer 4 — Modals & Sheets (settings, permission dialogs)
//   Material: thickMaterial
//   Standard iOS/macOS sheet presentation — no custom chrome

public enum HiveSurfaceLayer: Sendable, Equatable {
    /// Layer 1 — The browser chrome strip (omnibar, tab bar, space bar).
    /// ultraThinMaterial, system vibrancy blur, no custom chrome.
    case passiveChrome

    /// Layer 2 — URL bar suggestions, tab switcher, command palette, popovers.
    /// thinMaterial, 14pt radius, 0.5pt inner shadow at 8% black on top edge.
    case activeOverlay

    /// Layer 3 — Swarm sidebar (AI responses, suggestions, conversation).
    /// regularMaterial, 18pt radius, Swarm Violet 8% tint over the material.
    case swarm

    /// Layer 4 — Settings sheets, permission dialogs, modal presentations.
    /// thickMaterial, default sheet styling.
    case modal
}

// MARK: - HiveSurfaceMaterialModifier

struct HiveSurfaceMaterialModifier: ViewModifier {

    let layer: HiveSurfaceLayer

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(ZStack { backgroundContent })
            .clipShape(shape)
            .overlay(alignment: .top) { innerShadow }
            .modifier(LayerNoiseModifier(layer: layer))
    }

    // MARK: Background material

    @ViewBuilder
    private var backgroundContent: some View {
        switch layer {
        case .passiveChrome:
            // Layer 1: ultraThinMaterial — Liquid Glass. The most transparent material
            // so desktop wallpaper bleeds through with maximum clarity.
            // Brand: "ultraThinMaterial (Liquid Glass)", "blur radius: system-default
            // vibrancy — do not override", "specular highlight: system-applied, not custom."
            // Warm tint wash at low opacity ensures the chrome doesn't feel cold/sterile.
            ZStack {
                VisualEffectView(
                    material: .ultraDark,  // SwiftUI .ultraThinMaterial equivalent
                    blendingMode: .behindWindow,
                    state: .active,
                    isEmphasized: true
                )
                .ignoresSafeArea()

                // Warm background tint — the signature Hive warmth so the Liquid Glass
                // doesn't feel cold. Matches the old `hiveChromeGlass()` approach.
                Color(hiveBackgroundFor(scheme))
                    .opacity(scheme == .dark ? 0.25 : 0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

        case .activeOverlay:
            // Layer 2: thinMaterial with 14pt corners.
            // Matches system UI corner radii precisely per brand.
            VisualEffectView(
                material: .popover,
                blendingMode: .withinWindow,
                state: .active,
                isEmphasized: true
            )
            .ignoresSafeArea()

        case .swarm:
            // Layer 3: regularMaterial + Swarm Violet 8% tint.
            // This is the exact spec: more opaque material earns screen presence,
            // tinted with Swarm Violet at exactly 8% to signal "AI is present."
            ZStack {
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .withinWindow,
                    state: .active,
                    isEmphasized: true
                )
                .ignoresSafeArea()

                // Swarm Violet at 8% tint per brand spec.
                Color(hiveSwarmAccentFor(scheme))
                    .opacity(0.08)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

        case .modal:
            // Layer 4: thickMaterial for modal sheets and dialogs.
            // Standard sheet presentation — no custom chrome per brand.
            VisualEffectView(
                material: .sheet,
                blendingMode: .withinWindow,
                state: .active,
                isEmphasized: true
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Shape (corner radius per layer)

    private var shape: some Shape {
        RoundedRectangle(cornerRadius: cornerRadius)
    }

    private var cornerRadius: CGFloat {
        switch layer {
        case .passiveChrome: return 0
        case .activeOverlay: return 14  // Brand spec: 14pt
        case .swarm:         return 18  // Brand spec: 18pt
        case .modal:         return 0   // System sheet handles its own radius
        }
    }

    // MARK: Inner shadow (Layer 2 only)

    @ViewBuilder
    private var innerShadow: some View {
        // Brand spec: "Subtle inner shadow: 0.5pt, black at 8% opacity on top edge only"
        // Only Layer 2 (active overlays) gets the inner shadow.
        if layer == .activeOverlay {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 0.5)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - View extension

extension View {
    /// Apply the brand's exact surface material for the given layer.
    /// Usage: `.hiveSurface(.passiveChrome)` on chrome containers,
    /// `.hiveSurface(.activeOverlay)` on popovers/command palette,
    /// `.hiveSurface(.swarm)` on the Swarm sidebar.
    func hiveSurface(_ layer: HiveSurfaceLayer) -> some View {
        modifier(HiveSurfaceMaterialModifier(layer: layer))
    }
}

// MARK: - Convenient presets

extension HiveSurfaceLayer {
    /// Returns the NSVisualEffectView material directly when needed outside
    /// the modifier (e.g. in NSViewRepresentable contexts).
    var material: NSVisualEffectView.Material {
        switch self {
        case .passiveChrome: return .ultraDark
        case .activeOverlay: return .popover
        case .swarm:         return .hudWindow
        case .modal:         return .sheet
        }
    }

    /// Whether this layer gets the brand noise/grain texture per §Noise & Grain.
    /// Only Layer 1 (passiveChrome) and Layer 2 (activeOverlay) get the grain.
    var includesNoise: Bool {
        switch self {
        case .passiveChrome, .activeOverlay: return true
        case .swarm, .modal:                return false
        }
    }
}

// MARK: - LayerNoiseModifier
//
// Applies the brand noise/grain texture selectively per layer.
// Layer 1 and 2 only — see HiveSurfaceLayer.includesNoise.
// The noise is defined in HiveNoiseTexture.swift.

private struct LayerNoiseModifier: ViewModifier {
    let layer: HiveSurfaceLayer

    func body(content: Content) -> some View {
        if layer.includesNoise {
            content.hiveNoise()
        } else {
            content
        }
    }
}
