import SwiftUI
import HiveCore

// MARK: - TavilySettingsView

/// Settings panel for the Tavily cloud research provider (free tier, always-available).
/// API key is read from the TAVILY_API_KEY environment variable; the toggle lets
/// users explicitly disable Tavily even when the key is present.
struct TavilySettingsView: View {

    @Environment(ChromeState.self) private var state

    @State private var isEnabled: Bool = true
    @State private var statusMessage: String = ""
    @State private var statusColor: Color = .hiveMist

    var body: some View {
        FormSection(title: "Tavily Cloud Research") {
            VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                Text("Tavily is a cloud research API purpose-built for AI agents. Free tier: 1,000 searches/month. Set the TAVILY_API_KEY environment variable to enable. Searches run through Tavily's servers — review their privacy policy before use.")
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveMist)

                Toggle("Enable Tavily", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        state.setTavilyConfig(enabled: newValue)
                        refreshStatus()
                    }

                HStack(spacing: HiveSpacing.s12) {
                    Button("Check Availability") {
                        Task { @MainActor in await checkAvailability() }
                    }
                    .buttonStyle(.bordered)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .hiveType(.caption1)
                        .foregroundStyle(statusColor)
                }
            }
        }
        .onAppear {
            isEnabled = state.prefs.tavilyEnabled
            refreshStatus()
        }
    }

    @MainActor
    private func checkAvailability() async {
        guard let provider = TavilySearchProvider() else {
            setStatus("TAVILY_API_KEY is not set in your environment. Add it to use Tavily.",
                      color: .hiveError)
            return
        }
        let available = await provider.isAvailable()
        setStatus(available ? "Tavily is configured and available." : "Tavily API key is set but invalid.",
                  color: available ? .hiveSuccess : .hiveError)
    }

    private func refreshStatus() {
        if !state.prefs.tavilyEnabled {
            setStatus("Tavily is disabled. Toggle above to enable.", color: .hiveMist)
            return
        }
        if TavilySearchProvider() == nil {
            setStatus("TAVILY_API_KEY is not set. Tavily will not be used.", color: .secondary)
        } else {
            setStatus("Tavily is enabled. Cloud research is available.", color: .hiveSuccess)
        }
    }

    private func setStatus(_ text: String, color: Color) {
        statusMessage = text
        statusColor = color
    }
}
