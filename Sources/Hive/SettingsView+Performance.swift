//
//  SettingsView+Performance.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Performance
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + Performance

@MainActor
extension SettingsView {


    // MARK: - Performance

    /// Whether the selected provider can run right now. Driven by locally
    /// observed values (the Tavily field, the Vane URL binding) so the readout
    /// updates as the user types; the research path itself uses the state's
    /// `activeResearchProvider()` as the single authority.
    var researchReady: Bool {
        switch state.researchProvider {
        case .off: return false
        case .vane:
            return !state.vaneBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tavily:
            return !tavilyKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }


    var researchReadyText: String {
        switch state.researchProvider {
        case .off: return "Web research is off."
        case .vane: return "Vane is ready for `/research`."
        case .tavily: return "Tavily is ready for `/research`."
        }
    }


    /// Loads the Tavily key from Keychain into the local field.
    func loadTavilyKey() {
        tavilyKeyInput = state.tavilyAPIKey
    }


    /// Commits the current field value to Keychain. Debounced via onChange so
    /// typing doesn't hammer the Keychain on every keystroke.
    func commitTavilyKey() {
        state.setTavilyAPIKey(tavilyKeyInput)
    }


    /// Whether the BYOK gateway is fully configured (URL + model + key) and can
    /// serve the assistant right now.
    var byokReady: Bool {
        !state.byokBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.byokModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !byokKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    /// Loads the BYOK key from Keychain into the local field.
    func loadByokKey() {
        byokKeyInput = state.byokAPIKey
    }


    /// Commits the current field value to Keychain and reconfigures the
    /// Dispatcher. Debounced via onChange so typing doesn't hammer Keychain.
    func commitByokKey() {
        state.setByokAPIKey(byokKeyInput)
    }


    var performanceTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            Color.clear.task { await modelDownloader.refreshPresentCount() }
            settingsGroup("Memory") {
                Toggle("Memory Saver", isOn: $state.isMemorySaverEnabled)
                Text("Frees memory from inactive tabs so the active tab stays fast. Inactive tabs reload when you switch back.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Auto Archive", isOn: $state.enableAutoArchive)
                Text("Tabs untouched for 14+ days move to the Archive instead of staying on the tab strip. Restore them any time from the Archive panel (/archive).")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Download Notifications", isOn: $state.downloadNotificationsEnabled)
                Text("Shows a macOS notification when a download finishes. The first one asks for permission — you can change it later in System Settings.")
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

            settingsGroup("Remote AI (BYOK)") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Route the assistant through your own LiteLLM/OpenAI-compatible gateway. You pay the provider — Hive pays nothing. Pick \"Remote (BYOK)\" in the assistant panel to use it.")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("https://integrate.api.nvidia.com/v1", text: $state.byokBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.monoMedium)

                    TextField("model id (e.g. deepseek-v4-pro)", text: $state.byokModelID)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.monoMedium)

                    SecureField("API key", text: $byokKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(HiveDesign.Typography.monoMedium)
                        .onSubmit { commitByokKey() }
                        .onChange(of: byokKeyInput) { _, _ in
                            guard hasLoadedByokKey else { return }
                            byokKeyCommitTask?.cancel()
                            byokKeyCommitTask = Task { @MainActor in
                                try? await Task.sleep(for: .seconds(0.6))
                                guard !Task.isCancelled else { return }
                                commitByokKey()
                            }
                        }
                        .onAppear {
                            loadByokKey()
                            hasLoadedByokKey = true
                        }

                    HStack(spacing: 6) {
                        if byokReady {
                            Image(systemName: "checkmark.circle.fill")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.green)
                            Text("BYOK is ready — the assistant can route to your gateway.")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "circle.dashed")
                                .font(HiveDesign.Typography.smallLabel)
                                .foregroundStyle(.secondary)
                            Text("Not configured — the assistant falls back to on-device AI.")
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


    var needsDownload: Bool {
        modelDownloader.presentCount < ModelDownloader.requiredRepos.count
    }


    var modelStatusIcon: String {
        if modelDownloader.isDownloading { return "arrow.down.circle" }
        if needsDownload { return "icloud.and.arrow.down" }
        if modelDownloader.completedRepos.isEmpty && !needsDownload { return "checkmark.icloud" }
        return "cpu.fill"
    }


    var modelStatusColor: Color {
        if modelDownloader.isDownloading { return .blue }
        if needsDownload { return .orange }
        return .green
    }


    var modelStatusLabel: String {
        if modelDownloader.isDownloading { return "Downloading AI models..." }
        let total = ModelDownloader.requiredRepos.count
        let count = modelDownloader.presentCount
        if count == total { return "All \(total) models ready — real on-device AI active" }
        if count > 0 { return "\(count)/\(total) models downloaded" }
        return "No models downloaded — AI runs in preview mode"
    }


    var modelDetailText: String {
        if ModelDownloader.isCLIAvailable() {
            "Models run locally using MLX. Download ~300 MB for basic AI features (summarize, outline, cite). No data leaves your device."
        } else {
            "Requires huggingface-cli. Models run locally using Apple's MLX framework — zero data leaves your device."
        }
    }
}
