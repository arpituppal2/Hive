import SwiftUI
import HiveCore

// MARK: - OmniboxSuggestionPanel
//
// Chrome/Safari-style autocomplete dropdown. Appears below the address bar
// as the user types, showing matching history, bookmarks, and a search
// suggestion fallback. Uses HiveDesign tokens.

struct OmniboxSuggestionPanel: View {
    @Environment(BrowserState.self) private var state

    let query: String
    let onSubmit: (BrowserState.OmniboxSuggestion) -> Void
    let onDismiss: () -> Void

    private var suggestions: [BrowserState.OmniboxSuggestion] {
        state.omniboxSuggestions(for: query)
    }

    var body: some View {
        if suggestions.isEmpty { EmptyView() } else {
            VStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button(action: { onSubmit(suggestion) }) {
                        HStack(spacing: HiveDesign.Space.lg) {
                            Image(systemName: icon(for: suggestion.kind))
                                .font(.system(size: HiveDesign.Icon.small))
                                .foregroundStyle(color(for: suggestion.kind))
                                .frame(width: 18, height: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.text)
                                    .font(.system(size: HiveDesign.Typography.sizeBody, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if let url = suggestion.url {
                                    Text(url.host ?? url.absoluteString)
                                        .font(.system(size: HiveDesign.Typography.sizeMD))
                                        .foregroundStyle(HiveDesign.Text.tertiary)
                                        .lineLimit(1)
                                } else if suggestion.kind == .command, let command = suggestion.command {
                                    Text(CommandRegistry().definition(for: command)?.title ?? command.rawValue)
                                        .font(.system(size: HiveDesign.Typography.sizeMD))
                                        .foregroundStyle(HiveDesign.Text.tertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            kindLabel(suggestion.kind)
                        }
                        .padding(.horizontal, HiveDesign.Space.xl)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != suggestions.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            // Match the host bar's width exactly (address bar 240-380pt, NTP up
            // to 620pt) instead of a hard-coded 520 that misaligns with both.
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(HiveDesign.Material.panel)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
        }
    }

    private func icon(for kind: BrowserState.OmniboxSuggestion.Kind) -> String {
        switch kind {
        case .history: return "clock.arrow.circlepath"
        case .bookmark: return "bookmark.fill"
        case .search: return "magnifyingglass"
        case .tab: return "arrow.turn.up.right"
        case .command: return "command"
        }
    }

    private func color(for kind: BrowserState.OmniboxSuggestion.Kind) -> Color {
        switch kind {
        case .history: return HiveDesign.Text.secondary
        case .bookmark: return HiveDesign.Accent.primary
        case .search: return HiveDesign.Accent.primary
        case .tab: return HiveDesign.Accent.primary
        case .command: return HiveDesign.Accent.primary
        }
    }

    private func kindLabel(_ kind: BrowserState.OmniboxSuggestion.Kind) -> some View {
        Text(label(for: kind))
            .font(.system(size: HiveDesign.Typography.sizeSM, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, HiveDesign.Space.md)
            .padding(.vertical, 2)
            .background(HiveDesign.Surface.level2)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xs, style: .continuous))
    }

    private func label(for kind: BrowserState.OmniboxSuggestion.Kind) -> String {
        switch kind {
        case .history: return "History"
        case .bookmark: return "Bookmark"
        case .search: return "Search"
        case .tab: return "Tab"
        case .command: return "Command"
        }
    }
}
