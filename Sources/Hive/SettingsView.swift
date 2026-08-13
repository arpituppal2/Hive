import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView
//
// Safari/Chrome-style browser settings. Appearance, search engine, privacy,
// performance, and about in a tabbed sidebar layout.

struct SettingsView: View {
    @Bindable var state: BrowserState
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var selectedTab: SettingsTab = .appearance
    @State var safeBrowsingKeyInput: String = ""
    @State var safeBrowsingKeyCommitTask: Task<Void, Never>?
    @State var hasLoadedSafeBrowsingKey: Bool = false
    @State var commandTitle: String = ""
    @State var commandURL: String = ""
    @State var commandIcon: String = "link"
    @State var commandKeywords: String = ""
    @State var commandError: String?
    @State var tavilyKeyInput: String = ""
    @State var tavilyKeyCommitTask: Task<Void, Never>?
    @State var hasLoadedTavilyKey: Bool = false
    @State var byokKeyInput: String = ""
    @State var byokKeyCommitTask: Task<Void, Never>?
    @State var hasLoadedByokKey: Bool = false

    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case search = "Search"
        case commands = "Commands"
        case privacy = "Privacy"
        case performance = "Performance"
        case about = "About"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .search: return "magnifyingglass"
            case .commands: return "command"
            case .privacy: return "hand.raised"
            case .performance: return "gauge.with.dots.needle.33percent"
            case .about: return "info.circle"
            }
        }
    }

    @StateObject var modelDownloader = ModelDownloader()
}

// MARK: - SettingsSidebarRow

struct SettingsSidebarRow: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(isSelected ? Color.hiveAccent : .secondary)
                    .frame(width: 20)

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? HiveDesign.Surface.level2 : (isHovered ? HiveDesign.Surface.level1 : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
