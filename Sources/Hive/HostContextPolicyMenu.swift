import SwiftUI
import HiveCore

/// Address-bar control for the active origin's Swarm page-context decision.
///
/// This is intentionally separate from site security and tracker blocking: it
/// controls only whether page content may enter Swarm context. The browser
/// state remains the sole mutation authority.
struct HostContextPolicyMenu: View {
    @Environment(BrowserState.self) private var state

    private var isUnavailable: Bool {
        !state.canConfigureActiveHostContext
    }

    var body: some View {
        Menu {
            Section {
                Button {
                    state.setActiveHostContextDecision(.default)
                } label: {
                    policyLabel("Use session default", icon: "circle.dashed")
                }
                .disabled(isUnavailable)

                Button {
                    state.setActiveHostContextDecision(.allow)
                } label: {
                    policyLabel("Allow page context", icon: "checkmark.circle")
                }
                .disabled(isUnavailable)

                Button {
                    state.setActiveHostContextDecision(.block)
                } label: {
                    policyLabel("Block page context", icon: "nosign")
                }
                .disabled(isUnavailable)
            }

            Section {
                Text("Controls Swarm page context only. It does not change navigation, cookies, site permissions, or tracker blocking.")
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: HiveDesign.Typography.sizeMD, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: HiveDesign.HitTarget.compact + 2, height: HiveDesign.HitTarget.compact + 2)
        }
        .menuStyle(.borderlessButton)
        .disabled(isUnavailable)
        .accessibilityLabel("Swarm page context")
        .accessibilityValue(valueText)
        .accessibilityHint(isUnavailable
            ? "Unavailable for private browsing or non-web pages"
            : "Choose whether Swarm may read this site's page")
        .help(valueText)
    }

    private var iconName: String {
        switch state.activeHostContextState {
        case .blocked: return "shield.slash.fill"
        case .privateBrowsing: return "theatermasks.fill"
        case .unavailable: return "shield"
        case .allowed: return "shield.checkered"
        case .default: return "shield"
        }
    }

    private var iconColor: Color {
        switch state.activeHostContextState {
        case .blocked, .privateBrowsing: return HiveDesign.State.warning
        case .allowed: return HiveDesign.State.success
        case .default, .unavailable: return HiveDesign.Text.tertiary
        }
    }

    private var valueText: String {
        switch state.activeHostContextState {
        case .default: return "Using session default"
        case .allowed: return "Allowed"
        case .blocked: return "Blocked by site policy"
        case .privateBrowsing: return "Unavailable in private browsing"
        case .unavailable: return "Unavailable for this page"
        }
    }

    private func policyLabel(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            if title == currentSelectionTitle {
                Image(systemName: "checkmark")
            }
        }
    }

    private var currentSelectionTitle: String {
        switch state.activeHostContextDecision {
        case .default: return "Use session default"
        case .allow: return "Allow page context"
        case .block: return "Block page context"
        }
    }
}
