import SwiftUI
import HiveCore

// MARK: - VaneSettingsView

/// Settings panel for the self-hosted Vane (Perplexica) web-search provider.
struct VaneSettingsView: View {

    @Environment(ChromeState.self) private var state

    @State private var baseURL: String = ""
    @State private var isEnabled: Bool = false
    @State private var focusMode: WebSearchFocusMode = .webSearch
    @State private var statusMessage: String = ""
    @State private var statusColor: Color = .hiveMist

    var body: some View {
        FormSection(title: "Vane Web Search") {
            VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                Text("Connect Hive to a self-hosted Vane (Perplexica) instance for real-time web research. The server URL is stored locally; no search history leaves your machine without your consent.")
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveMist)

                Toggle("Enable Vane", isOn: $isEnabled)

                TextField("Base URL", text: $baseURL, prompt: Text("http://localhost:3000"))

                Picker("Default Focus", selection: $focusMode) {
                    ForEach(WebSearchFocusMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: HiveSpacing.s12) {
                    Button("Save") {
                        Task { @MainActor in await save() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test Connection") {
                        Task { @MainActor in await testConnection() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(baseURL.isEmpty)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .hiveType(.caption1)
                        .foregroundStyle(statusColor)
                }
            }
            .textFieldStyle(.roundedBorder)
        }
        .onAppear { loadFromPrefs() }
    }

    @MainActor
    private func loadFromPrefs() {
        baseURL = state.prefs.vaneBaseURL
        isEnabled = state.prefs.vaneEnabled
        focusMode = state.prefs.vaneDefaultFocusMode
    }

    @MainActor
    private func save() async {
        guard !baseURL.isEmpty else {
            setStatus("Enter a Vane base URL.", color: .hiveError)
            return
        }
        state.setVaneConfig(baseURL: baseURL, enabled: isEnabled, focusMode: focusMode)
        setStatus("Saved.", color: .hiveSuccess)
    }

    @MainActor
    private func testConnection() async {
        guard !baseURL.isEmpty, let url = URL(string: baseURL) else {
            setStatus("Enter a valid Vane base URL.", color: .hiveError)
            return
        }
        let provider = VaneSearchProvider(baseURL: url)
        let available = await provider.isAvailable()
        setStatus(available ? "Vane is reachable." : "Could not reach Vane.",
                  color: available ? .hiveSuccess : .hiveError)
    }

    private func setStatus(_ text: String, color: Color) {
        statusMessage = text
        statusColor = color
    }
}
