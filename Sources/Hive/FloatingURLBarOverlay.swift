import SwiftUI
import HiveCore

// MARK: - FloatingURLBarOverlay
//
// A Zen-style floating URL/search bar that appears centered over the web content
// when the user presses Cmd+T / Cmd+L or clicks the new-tab button. It is modal,
// heavily blurred, and dismisses on Escape or when the user submits a URL.

struct FloatingURLBarOverlay: View {

    @Environment(BrowserState.self) private var state
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Backdrop
            HiveDesign.Surface.canvas.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { state.hideFloatingURLBar() }

            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 14)

                    TextField("Search or enter address", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .focused($isFocused)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                        .onSubmit { submit() }

                    if !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: HiveDesign.AddressBar.radius, style: .continuous)
                        .fill(HiveDesign.Material.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HiveDesign.AddressBar.radius, style: .continuous)
                        .stroke(isFocused ? HiveDesign.Accent.primary : HiveDesign.Surface.hairline, lineWidth: isFocused ? 2 : 1)
                )
                .frame(maxWidth: 520)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)

                if !quickSites.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(quickSites, id: \.host) { site in
                            Button(action: { state.navigateToURL(site.url) }) {
                                HStack(spacing: 4) {
                                    if let favicon = site.faviconURL {
                                        FaviconImage(url: favicon).frame(width: 14, height: 14)
                                    }
                                    Text(site.host)
                                        .font(HiveDesign.Typography.smallLabelMedium)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(HiveDesign.Material.panel)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !text.isEmpty, text.hasPrefix("/"), !text.hasPrefix("//") {
                    slashSuggestions
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            text = state.floatingURLBarText
            isFocused = true
        }
        .onChange(of: state.floatingURLBarText) { _, new in
            text = new
        }
        .onKeyPress(.escape) {
            state.hideFloatingURLBar()
            return .handled
        }
    }

    /// Top 4 most-visited domains from real browsing history for quick access
    /// chips. Empty for new users — the product never fabricates content
    /// (no hardcoded defaults masquerading as visited sites).
    private var quickSites: [(host: String, url: URL, faviconURL: URL?)] {
        state.topDomainsFromHistory(limit: 4)
    }

    private var slashSuggestions: some View {
        let commands = state.omniboxSuggestions(for: text)
            .filter { $0.kind == .command }
        let skills = SkillRunner.skills(matching: text)
        let displaySkills = text.count <= 1 ? SkillRunner.allSkills : skills

        return VStack(spacing: 6) {
            ForEach(commands) { suggestion in
                Button(action: { runSlashInput(suggestion.text) }) {
                    HStack(spacing: 10) {
                        Image(systemName: "command")
                            .font(HiveDesign.Typography.bodySemiBold)
                            .foregroundStyle(Color.hiveAccent)
                            .frame(width: 24, height: 24)
                            .background(Color.hiveAccent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(commandLabel(for: suggestion))
                                .font(HiveDesign.Typography.bodyMedium)
                                .foregroundStyle(.primary)
                            Text("Browser command")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HiveDesign.Material.panel)
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(displaySkills) { skill in
                Button(action: { runSkill(skill.command) }) {
                    HStack(spacing: 10) {
                        Image(systemName: skill.icon)
                            .font(HiveDesign.Typography.bodySemiBold)
                            .foregroundStyle(skill.swiftUIColor)
                            .frame(width: 24, height: 24)
                            .background(skill.swiftUIColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(skill.command) — \(skill.title)")
                                .font(HiveDesign.Typography.bodyMedium)
                                .foregroundStyle(.primary)
                            Text(skill.description)
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HiveDesign.Material.panel)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 520)
    }

    private func commandLabel(for suggestion: BrowserState.OmniboxSuggestion) -> String {
        guard let command = suggestion.command else { return suggestion.text }
        return "\(suggestion.text) — \(CommandRegistry().definition(for: command)?.title ?? command.rawValue)"
    }

    private func runSlashInput(_ input: String) {
        state.hideFloatingURLBar()
        if let command = state.omniboxCommand(for: input) {
            state.executeOmniboxCommand(command)
        } else {
            SkillRunner.run(input, in: state)
        }
    }

    private func runSkill(_ command: String) {
        runSlashInput(command)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let command = state.omniboxCommand(for: trimmed) {
            state.hideFloatingURLBar()
            state.executeOmniboxCommand(command)
        } else if trimmed.hasPrefix("/") && !trimmed.hasPrefix("//"),
                  SkillRunner.skill(for: trimmed) != nil {
            runSkill(trimmed)
        } else {
            let opensNewTab = state.floatingURLBarOpensNewTab
            state.hideFloatingURLBar()
            if opensNewTab {
                state.newTab()
            }
            state.navigateToAddress(trimmed)
        }
    }
}
