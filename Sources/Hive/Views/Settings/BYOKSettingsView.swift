import SwiftUI
import HiveCore

// MARK: - BYOKSettingsView

/// Settings panel for BYOK (Bring Your Own Key) model configuration. Lets the user connect
/// Hive to any OpenAI-compatible /chat/completions endpoint (OpenAI, LiteLLM proxy, etc.)
/// by providing a base URL, model ID, and API key. The key is stored in the macOS Keychain;
/// only a configurable alias is persisted in user prefs.
struct BYOKSettingsView: View {

    @Environment(ChromeState.self) private var state

    @State private var baseURL: String = ""
    @State private var modelID: String = ""
    @State private var keyAlias: String = ""
    @State private var apiKey: String = ""
    @State private var isEnabled: Bool = false
    @State private var statusMessage: String = ""
    @State private var statusColor: Color = .hiveMist

    var body: some View {
        FormSection(title: "BYOK Model Provider") {
            VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                Text("Connect Hive to your own remote model via an OpenAI-compatible endpoint. Your API key is stored in the macOS Keychain and never written to prefs or source control.")
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveMist)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Remote model privacy: API keys are stored in the macOS Keychain and are not written to preferences or source control.")

                TextField("Base URL", text: $baseURL, prompt: Text("https://api.openai.com/v1"))
                    .accessibilityLabel("Remote model base URL")
                    .accessibilityHint("Enter the HTTPS endpoint for the OpenAI-compatible service")
                TextField("Model ID", text: $modelID, prompt: Text("gpt-4o"))
                    .accessibilityLabel("Remote model ID")
                    .accessibilityHint("Enter the model identifier used by the endpoint")
                TextField("Keychain Alias", text: $keyAlias, prompt: Text("byok-api-key"))
                    .accessibilityLabel("Keychain alias")
                    .accessibilityHint("Enter the alias used to store this API key")
                SecureField("API Key", text: $apiKey, prompt: Text("sk-..."))
                    .accessibilityLabel("Remote model API key")
                    .accessibilityHint("The key is stored in the macOS Keychain")

                Toggle("Enable BYOK", isOn: $isEnabled)

                HStack(spacing: HiveSpacing.s12) {
                    Button("Save") {
                        Task { @MainActor in await save() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Save remote model settings")

                    Button("Test Connection") {
                        Task { @MainActor in await testConnection() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Test remote model connection")
                    .accessibilityHint("Tests the configured endpoint and resolves the key from Keychain")
                    .disabled(baseURL.isEmpty || modelID.isEmpty || keyAlias.isEmpty || apiKey.isEmpty)

                    Button("Remove Key") {
                        Task { @MainActor in await removeKey() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Remove remote model API key")
                    .accessibilityHint("Permanently removes the key from the macOS Keychain and disables BYOK")
                    .disabled(keyAlias.isEmpty)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .hiveType(.caption1)
                        .foregroundStyle(statusColor)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Remote model status: \(statusMessage)")
                }
            }
            .textFieldStyle(.roundedBorder)
        }
        .onAppear { loadFromPrefs() }
    }

    @MainActor
    private func loadFromPrefs() {
        baseURL = state.prefs.byokBaseURL
        modelID = state.prefs.byokModelID
        keyAlias = state.prefs.byokKeyAlias
        isEnabled = state.prefs.byokEnabled
        apiKey = ""
    }

    @MainActor
    private func save() async {
        do {
            // Save the key first, then the config. The alias is required so the runtime can
            // resolve the key later.
            if !apiKey.isEmpty && !keyAlias.isEmpty {
                try await state.saveBYOKKey(apiKey, alias: keyAlias)
            }
            try state.setBYOKConfig(baseURL: baseURL, modelID: modelID, keyAlias: keyAlias, enabled: isEnabled)
            setStatus("Saved. Swarm will use BYOK when enabled.", color: .hiveSuccess)
        } catch {
            setStatus("Failed to save: \(error.localizedDescription)", color: .hiveError)
        }
    }

    @MainActor
    private func testConnection() async {
        guard !baseURL.isEmpty, !modelID.isEmpty, !keyAlias.isEmpty, !apiKey.isEmpty else {
            setStatus("Fill all fields before testing.", color: .hiveWarning)
            return
        }
        do {
            try await state.saveBYOKKey(apiKey, alias: keyAlias)
            guard let base = URL(string: baseURL), isValidHTTPS(baseURL) else {
                setStatus("Base URL must be a valid HTTPS URL.", color: .hiveError)
                return
            }
            let config = BYOKRuntime.Config(baseURL: base, apiKeyAlias: keyAlias, modelID: modelID)
            let secretStore = state.secretStore
            let runtime = BYOKRuntime(config: config) { alias in
                try? await secretStore?.get(for: alias)
            }
            let available = await runtime.isAvailable()
            setStatus(available ? "Connection OK — key resolved." : "Key not found in Keychain.",
                      color: available ? .hiveSuccess : .hiveWarning)
        } catch {
            setStatus("Connection test failed: \(error.localizedDescription)", color: .hiveError)
        }
    }

    @MainActor
    private func removeKey() async {
        guard !keyAlias.isEmpty else { return }
        do {
            try await state.deleteBYOKKey(alias: keyAlias)
            apiKey = ""
            isEnabled = false
            setStatus("Key removed from Keychain. BYOK disabled.", color: .hiveSuccess)
        } catch {
            setStatus("Failed to remove key: \(error.localizedDescription)", color: .hiveError)
        }
    }

    private func isValidHTTPS(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "https" && !(url.host?.isEmpty ?? true)
    }

    private func setStatus(_ text: String, color: Color) {
        statusMessage = text
        statusColor = color
    }
}
