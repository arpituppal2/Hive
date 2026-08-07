import SwiftUI
import AppKit
import HiveCore

// MARK: - Space Menu Utilities
//
// Shared helpers used by SpaceBarView and VerticalTabBarView for the space rail
// context menus (rename + accent color picker).

/// Curated accent colors a user can assign to a space. Excludes light-mode variants and
// extreme values that would be invisible or off-brand as chrome tints.
let spaceAccentTokens: [HiveColorToken] = [
    .accent, .graphite, .mist, .paper, .surface, .surfaceElevated
]

/// Curated SFSymbol names for space avatars. Each icon maps to a common workspace role so
/// users can visually distinguish spaces at a glance in the rail, horizontal bar, and start page.
let spaceIconNames: [String] = [
    "square.grid.2x2",      // default / general
    "briefcase.fill",       // work
    "house.fill",           // personal
    "gamecontroller.fill",  // gaming
    "cart.fill",            // shopping
    "airplane.fill",        // travel
    "graduationcap.fill",   // school
    "heart.fill",           // interests
    "star.fill",            // favorites
    "gear.fill",            // tools / settings
    "paintbrush.fill",      // creative
    "film.fill",            // media
    "music.note.fill",      // music
    "newspaper.fill",       // news
    "leaf.fill",            // wellness
    "flame.fill",           // active / fitness
    "lightbulb.fill",       // ideas
    "hammer.fill",          // development
    "person.3.fill",        // family / team
    "banknote.fill",        // finance
    "car.fill"              // commute / auto
]

/// Human-readable label for a space icon name (best-effort; unknown names pass through).
func spaceIconLabel(_ name: String) -> String {
    switch name {
    case "square.grid.2x2":      return "Default"
    case "briefcase.fill":       return "Work"
    case "house.fill":           return "Personal"
    case "gamecontroller.fill":  return "Gaming"
    case "cart.fill":            return "Shopping"
    case "airplane.fill":        return "Travel"
    case "graduationcap.fill":   return "School"
    case "heart.fill":           return "Interests"
    case "star.fill":            return "Favorites"
    case "gear.fill":            return "Tools"
    case "paintbrush.fill":      return "Creative"
    case "film.fill":            return "Media"
    case "music.note.fill":      return "Music"
    case "newspaper.fill":       return "News"
    case "leaf.fill":            return "Wellness"
    case "flame.fill":           return "Fitness"
    case "lightbulb.fill":       return "Ideas"
    case "hammer.fill":          return "Development"
    case "person.3.fill":        return "Team"
    case "banknote.fill":        return "Finance"
    case "car.fill":             return "Auto"
    default:                     return name
    }
}

/// Human-readable label for a HiveColorToken in the space context menu.
func tokenLabel(_ token: HiveColorToken) -> String {
    switch token {
    case .ink:             return "Ink"
    case .graphite:        return "Graphite"
    case .paper:           return "Paper"
    case .mist:            return "Mist"
    case .accent:          return "Honey"
    case .background:      return "Background"
    case .surface:         return "Surface"
    case .surfaceElevated: return "Elevated"
    case .swarmAccent:     return "Swarm"
    case .inkLight:        return "Ink Light"
    case .backgroundLight: return "Background Light"
    case .surfaceLight:    return "Surface Light"
    case .accentLight:     return "Accent Light"
    case .swarmAccentLight:return "Swarm Light"
    case .gold:            return "Gold"
    case .ruby:            return "Ruby"
    case .emerald:         return "Emerald"
    case .sapphire:        return "Sapphire"
    case .amethyst:        return "Amethyst"
    case .rose:            return "Rose"
    case .sky:             return "Sky"
    case .coral:           return "Coral"
    case .jade:            return "Jade"
    case .lavender:        return "Lavender"
    case .sunset:          return "Sunset"
    case .steel:           return "Steel"
    case .mint:            return "Mint"
    }
}

// MARK: - Shared space context menu components

/// A reusable "Icon" submenu for a space. Highlights the current icon with a checkmark.
@MainActor
@ViewBuilder
func SpaceIconPicker(space: Space, state: ChromeState) -> some View {
    Menu("Icon") {
        ForEach(spaceIconNames, id: \.self) { iconName in
            Button {
                state.setSpaceIcon(space.id, to: iconName)
            } label: {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.hiveInk)
                        .frame(width: 16, height: 16)
                    Text(spaceIconLabel(iconName))
                        .foregroundStyle(.hiveInk)
                    Spacer(minLength: 0)
                    if space.iconName == iconName {
                        Image(systemName: "checkmark")
                            .font(HiveTypography.font(.caption3Bold))
                            .foregroundStyle(.hiveAccent)
                    }
                }
            }
        }
    }
}

/// A reusable "Accent Color" submenu for a space. Highlights the current accent with a checkmark.
@MainActor
@ViewBuilder
func SpaceAccentPicker(space: Space, state: ChromeState) -> some View {
    Menu("Accent Color") {
        ForEach(spaceAccentTokens, id: \.self) { token in
            Button {
                state.setSpaceAccent(space.id, to: token.rawValue)
            } label: {
                HStack(spacing: HiveSpacing.s8) {
                    Circle()
                        .fill(Color(token))
                        .frame(width: 10, height: 10)
                    Text(tokenLabel(token))
                        .foregroundStyle(.hiveInk)
                    Spacer(minLength: 0)
                    if space.accentTokenName == token.rawValue {
                        Image(systemName: "checkmark")
                            .font(HiveTypography.font(.caption3Bold))
                            .foregroundStyle(.hiveAccent)
                    }
                }
            }
        }
    }
}

/// Prompts the user to rename a space using a native NSAlert text field.
/// Returns the trimmed new name, or nil if the user cancels or leaves the field empty.
@MainActor
func promptForSpaceName(_ current: String) -> String? {
    let alert = NSAlert()
    alert.messageText = "Rename Space"
    alert.informativeText = "Enter a new name for this space."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
    textField.stringValue = current
    alert.accessoryView = textField
    if alert.runModal() == .alertFirstButtonReturn {
        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    return nil
}
