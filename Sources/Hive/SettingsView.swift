import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView
//
// Safari/Chrome-style browser settings. Appearance, search engine, privacy,
// performance, and about in a tabbed sidebar layout.

struct SettingsView: View {
    @Bindable var state: BrowserState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: SettingsTab = .appearance
    @State private var safeBrowsingKeyInput: String = ""
    @State private var safeBrowsingKeyCommitTask: Task<Void, Never>?
    @State private var hasLoadedSafeBrowsingKey: Bool = false
    @State private var commandTitle: String = ""
    @State private var commandURL: String = ""
    @State private var commandIcon: String = "link"
    @State private var commandKeywords: String = ""
    @State private var commandError: String?
    @State private var tavilyKeyInput: String = ""
    @State private var tavilyKeyCommitTask: Task<Void, Never>?
    @State private var hasLoadedTavilyKey: Bool = false

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

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) { selectedTab = tab }
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(.top, 32)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Content
            ScrollView {
                contentView
                    .padding(32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 440)
        .background(.background)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .appearance: appearanceTab
        case .search: searchTab
        case .commands: commandsTab
        case .privacy: privacyTab
        case .performance: performanceTab
        case .about: aboutTab
        }
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Tab Layout") {
                Picker("", selection: $state.layout) {
                    ForEach(BrowserState.TabLayout.allCases) { layout in
                        HStack(spacing: 6) {
                            Image(systemName: layout.icon)
                            Text(layout.title)
                        }
                        .tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }

            settingsGroup("Accent Color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                    ForEach(ThemePreset.presets) { preset in
                        Button(action: { state.setAccentColor(hex: preset.colorHex) }) {
                            Circle()
                                .fill(Color(hex: preset.colorHex) ?? Color.hiveAccent)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if state.browserAccentColorHex == preset.colorHex {
                                        Image(systemName: "checkmark")
                                            .font(HiveDesign.Typography.smallLabelBold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                }
                .frame(maxWidth: 320)
            }

            settingsGroup("New Tab") {
                Picker("", selection: $state.openBriefOnNewTab) {
                    Text("Morning Brief").tag(true)
                    Text("Start Page").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Text("New tabs open with a daily brief assembled locally from your browsing. The classic start page keeps search + top sites.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsGroup("Toolbar") {
                Toggle("Show Bookmarks Bar", isOn: $state.showBookmarksBar)
            }
        }
    }

    // MARK: - Search

    private var searchTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Search Engine") {
                VStack(spacing: 6) {
                    ForEach(BrowserState.SearchEngine.allCases) { engine in
                        Button(action: { state.searchEngine = engine; state.scheduleAutosave() }) {
                            HStack(spacing: 10) {
                                Image(systemName: engine.icon)
                                    .font(HiveDesign.Typography.panelTitleMedium)
                                    .foregroundStyle(engine.color)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(engine.rawValue)
                                        .font(HiveDesign.Typography.bodyMedium)
                                        .foregroundStyle(.primary)
                                    Text(searchEngineDescription(for: engine))
                                        .font(HiveDesign.Typography.smallLabel)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if state.searchEngine == engine {
                                    Image(systemName: "checkmark")
                                        .font(HiveDesign.Typography.smallLabelBold)
                                        .foregroundStyle(Color.hiveAccent)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(state.searchEngine == engine
                                        ? HiveDesign.Surface.level2
                                        : Color.primary.opacity(0.03))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Custom Commands

    private var commandsTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Custom launcher entries") {
                Text("Create focused ⌘K commands for pages you open often. Commands only open http:// or https:// URLs and never execute shell or app actions.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    TextField("Command title", text: $commandTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("https://example.com", text: $commandURL)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.monoMedium)
                    HStack(spacing: 8) {
                        TextField("Icon (SF Symbol)", text: $commandIcon)
                            .textFieldStyle(.roundedBorder)
                        TextField("Keywords, comma separated", text: $commandKeywords)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        if let commandError {
                            Label(commandError, systemImage: "exclamationmark.triangle")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Add Command") { addCommand() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(commandTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commandURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            settingsGroup("Saved commands") {
                if state.userDefinedCommands.isEmpty {
                    Text("No custom commands yet.")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(state.userDefinedCommands) { command in
                            HStack(spacing: 8) {
                                Image(systemName: command.icon)
                                    .foregroundStyle(Color.hiveAccent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(command.title)
                                        .font(HiveDesign.Typography.sidebarItemMedium)
                                    Text(command.url)
                                        .font(HiveDesign.Typography.monoCaption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    state.removeUserDefinedCommand(id: command.id)
                                }
                                .buttonStyle(.borderless)
                                .font(HiveDesign.Typography.smallLabel)
                                .help("Delete \(command.title)")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    private func addCommand() {
        let title = commandTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = commandURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = commandKeywords
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let command = UserDefinedCommand(title: title, url: url, icon: commandIcon, keywords: keywords)
        guard command.isValidWebURL else {
            commandError = "Enter a valid http:// or https:// URL without credentials."
            return
        }
        guard state.addUserDefinedCommand(command) else {
            commandError = "That command could not be saved."
            return
        }
        commandTitle = ""
        commandURL = ""
        commandIcon = "link"
        commandKeywords = ""
        commandError = nil
    }

    private func searchEngineDescription(for engine: BrowserState.SearchEngine) -> String {
        switch engine {
        case .duckduckgo: return "Private search, no tracking"
        case .google: return "Fast, comprehensive results"
        case .bing: return "Microsoft's search engine with AI features"
        }
    }

    // MARK: - Privacy

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Private Browsing") {
                Button {
                    state.newPrivateTab()
                } label: {
                    HStack {
                        Label("Open New Private Tab", systemImage: "theatermasks")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Text("Private tabs use an ephemeral profile and are never saved to history, session restore, or Swarm memory.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsGroup("Tracker Blocking") {
                Toggle("Block ads & trackers", isOn: $state.isAdBlockEnabled)
                Text("Blocks requests to known ad/tracker domains (EasyList-based) and hides ad elements after load. Turn off for sites that misbehave.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.checkered")
                                .foregroundStyle(.green)
                                .font(HiveDesign.Typography.body)
                            Text("\(state.trackerBlockedCount) trackers blocked")
                                .font(HiveDesign.Typography.bodyMedium)
                        }
                        Text("Trackers are blocked using the EasyList blocklist across all pages.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Privacy Report") { state.openPrivacyReport() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            settingsGroup("Safe Browsing (Google)") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Protects against phishing, malware, and deceptive sites. Only 4 bytes of a URL hash are sent to Google.")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        TextField("Google Safe Browsing API key", text: $safeBrowsingKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(HiveDesign.Typography.sidebarItem)
                            .frame(width: 320)
                            .onSubmit { commitSafeBrowsingKey() }
                            .onChange(of: safeBrowsingKeyInput) { _, _ in
                                // Skip the spurious onChange that fires when
                                // loadSafeBrowsingKey sets the initial value.
                                guard hasLoadedSafeBrowsingKey else { return }
                                safeBrowsingKeyCommitTask?.cancel()
                                safeBrowsingKeyCommitTask = Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.6))
                                    guard !Task.isCancelled else { return }
                                    commitSafeBrowsingKey()
                                }
                            }
                        Text("Free key: developers.google.com")
                            .font(HiveDesign.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .onAppear {
                        loadSafeBrowsingKey()
                        hasLoadedSafeBrowsingKey = true
                    }
                }
            }

            settingsGroup("Passwords") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(state.savedPasswords.count) saved passwords")
                            .font(HiveDesign.Typography.bodyMedium)
                        Text("Stored in Apple Keychain with hardware-backed encryption.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Manage Passwords") { state.isPasswordsManagerOpen = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    /// Loads the Safe Browsing key from Keychain into the local field.
    private func loadSafeBrowsingKey() {
        safeBrowsingKeyInput = KeychainSecretStore.read(key: GoogleSafeBrowsingClient.apiKeyAccount) ?? ""
    }

    /// Commits the current field value to Keychain. Debounced via
    /// onChange so typing doesn't hammer the Keychain on every keystroke.
    private func commitSafeBrowsingKey() {
        let trimmed = safeBrowsingKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainSecretStore.delete(key: GoogleSafeBrowsingClient.apiKeyAccount)
        } else {
            KeychainSecretStore.save(key: GoogleSafeBrowsingClient.apiKeyAccount, value: trimmed)
        }
    }

    // MARK: - Performance

    /// Whether the selected provider can run right now. Driven by locally
    /// observed values (the Tavily field, the Vane URL binding) so the readout
    /// updates as the user types; the research path itself uses the state's
    /// `activeResearchProvider()` as the single authority.
    private var researchReady: Bool {
        switch state.researchProvider {
        case .off: return false
        case .vane:
            return !state.vaneBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tavily:
            return !tavilyKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var researchReadyText: String {
        switch state.researchProvider {
        case .off: return "Web research is off."
        case .vane: return "Vane is ready for `/research`."
        case .tavily: return "Tavily is ready for `/research`."
        }
    }

    /// Loads the Tavily key from Keychain into the local field.
    private func loadTavilyKey() {
        tavilyKeyInput = state.tavilyAPIKey
    }

    /// Commits the current field value to Keychain. Debounced via onChange so
    /// typing doesn't hammer the Keychain on every keystroke.
    private func commitTavilyKey() {
        state.setTavilyAPIKey(tavilyKeyInput)
    }

    @StateObject private var modelDownloader = ModelDownloader()

    private var performanceTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            Color.clear.task { await modelDownloader.refreshPresentCount() }
            settingsGroup("Memory") {
                Toggle("Memory Saver", isOn: $state.isMemorySaverEnabled)
                Text("Frees memory from inactive tabs so the active tab stays fast. Inactive tabs reload when you switch back.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if UpdateManager.shared.canCheckForUpdates {
                settingsGroup("Updates") {
                    HStack {
                        Text("Auto-update via Sparkle")
                        Spacer()
                        Button("Check for Updates…") {
                            UpdateManager.shared.checkForUpdates()
                        }
                    }
                    if let updater = UpdateManager.shared.updater {
                        Text(updater.automaticallyChecksForUpdates
                             ? "Hive checks for updates daily and installs them automatically."
                             : "Hive checks for updates when you open this panel.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingsGroup("Web Research") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Provider", selection: $state.researchProvider) {
                        ForEach(BrowserState.ResearchProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)

                    switch state.researchProvider {
                    case .off:
                        Text("Web research is off. Choose Vane or Tavily to answer `/research` queries with cited sources.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    case .vane:
                        TextField("http://localhost:3000", text: $state.vaneBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(HiveDesign.Typography.monoMedium)
                        Text("Hive answers `/research` queries through a self-hosted Vane (formerly Perplexica) instance. Only your query and the results travel between this Mac and your Vane server.")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    case .tavily:
                        SecureField("Tavily API key", text: $tavilyKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(HiveDesign.Typography.monoMedium)
                            .onSubmit { commitTavilyKey() }
                            .onChange(of: tavilyKeyInput) { _, _ in
                                // Skip the spurious onChange that fires when
                                // loadTavilyKey sets the initial value.
                                guard hasLoadedTavilyKey else { return }
                                tavilyKeyCommitTask?.cancel()
                                tavilyKeyCommitTask = Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.6))
                                    guard !Task.isCancelled else { return }
                                    commitTavilyKey()
                                }
                            }
                            .onAppear {
                                loadTavilyKey()
                                hasLoadedTavilyKey = true
                            }
                        HStack(spacing: 6) {
                            Text("Cloud research with a free 1,000-searches/month tier. The key stays in Keychain and is only sent to Tavily's API.")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Get a free key") {
                                if let url = URL(string: "https://app.tavily.com") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    HStack(spacing: 6) {
                        if researchReady {
                            Image(systemName: "checkmark.circle.fill")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.green)
                            Text(researchReadyText)
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "circle.dashed")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                            Text("Research status: \(state.researchProvider == .off ? "off" : "not configured").")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            settingsGroup("On-Device AI") {

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: modelStatusIcon)
                            .font(HiveDesign.Typography.bodyLarge)
                            .foregroundStyle(modelStatusColor)
                        Text(modelStatusLabel)
                            .font(HiveDesign.Typography.bodyMedium)
                        Spacer()
                        if modelDownloader.isDownloading {
                            Button("Cancel") { modelDownloader.cancelDownload() }
                                .buttonStyle(.borderless)
                                .font(HiveDesign.Typography.sidebarItem)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(action: { modelDownloader.downloadAllIfNeeded() }) {
                                Text(needsDownload ? "Download" : "Re-download")
                                    .font(HiveDesign.Typography.sidebarItemMedium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(modelDownloader.isDownloading)
                        }
                    }

                    if modelDownloader.isDownloading {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(modelDownloader.statusText)
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.hiveAccent)
                                        .frame(width: max(0, geo.size.width * modelDownloader.progress), height: 6)
                                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: modelDownloader.progress)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("\(Int(modelDownloader.downloadedMB)) MB of \(Int(modelDownloader.totalMB)) MB")
                                    .font(HiveDesign.Typography.caption)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("\(Int(modelDownloader.progress * 100))%")
                                    .font(HiveDesign.Typography.buttonCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let error = modelDownloader.errorText {
                        Text(error)
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !modelDownloader.completedRepos.isEmpty {
                        Text("Downloaded: \(modelDownloader.completedRepos.count) model(s)")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.green)
                    }

                    Text(modelDetailText)
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !ModelDownloader.isCLIAvailable() {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.yellow)
                            Text(ModelDownloader.installInstructions())
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var needsDownload: Bool {
        modelDownloader.presentCount < ModelDownloader.requiredRepos.count
    }

    private var modelStatusIcon: String {
        if modelDownloader.isDownloading { return "arrow.down.circle" }
        if needsDownload { return "icloud.and.arrow.down" }
        if modelDownloader.completedRepos.isEmpty && !needsDownload { return "checkmark.icloud" }
        return "cpu.fill"
    }

    private var modelStatusColor: Color {
        if modelDownloader.isDownloading { return .blue }
        if needsDownload { return .orange }
        return .green
    }

    private var modelStatusLabel: String {
        if modelDownloader.isDownloading { return "Downloading AI models..." }
        let total = ModelDownloader.requiredRepos.count
        let count = modelDownloader.presentCount
        if count == total { return "All \(total) models ready — real on-device AI active" }
        if count > 0 { return "\(count)/\(total) models downloaded" }
        return "No models downloaded — AI runs in preview mode"
    }

    private var modelDetailText: String {
        if ModelDownloader.isCLIAvailable() {
            "Models run locally using MLX. Download ~300 MB for basic AI features (summarize, outline, cite). No data leaves your device."
        } else {
            "Requires huggingface-cli. Models run locally using Apple's MLX framework — zero data leaves your device."
        }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.hiveAccent)

                VStack(spacing: 2) {
                    Text("The Hive Browser")
                        .font(.system(size: 18, weight: .bold))
                    Text("Version 1.0")
                        .font(HiveDesign.Typography.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            settingsGroup("Engine") {
                LabeledContent("Rendering engine", value: "Chromium Embedded Framework (CEF)")
                LabeledContent("JavaScript engine", value: "V8")
                LabeledContent("Platform", value: "macOS")
                LabeledContent("Swift version", value: "6.0")
            }
        }
    }

    // MARK: - Helpers

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(HiveDesign.Typography.smallLabelBold)
                .foregroundStyle(Color.hiveAccent)
                .textCase(.uppercase)

            content()
                .font(HiveDesign.Typography.body)
        }
    }
}

// MARK: - SettingsSidebarRow

private struct SettingsSidebarRow: View {
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
