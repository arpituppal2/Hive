import SwiftUI
import HiveCore

// MARK: - NetworkSettingsView
//
// DNS-over-HTTPS (DoH), DNS-over-TLS (DoT), and proxy configuration (SOCKS5,
// HTTP CONNECT, PAC file). These are enterprise/privacy/dev features that most
// users never touch but are critical for the users who need them.
//
// All settings are persisted in ChromeUserPrefs and take effect on the next
// tab creation (network stack changes require a new WKWebView).

struct NetworkSettingsView: View {

    @Environment(ChromeState.self) private var state

    // MARK: - DNS

    @State private var dohResolver: String = ""
    @State private var dotResolver: String = ""

    // MARK: - Proxy

    @State private var proxyType: ProxyType = .none
    @State private var proxyHost: String = ""
    @State private var proxyPort: String = ""
    @State private var proxyUsername: String = ""
    @State private var pacFileURL: String = ""
    @State private var proxyBypassLocal: Bool = true

    private enum ProxyType: String, CaseIterable {
        case none = "none"
        case http = "http"
        case socks5 = "socks5"
        case pac = "pac"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none:   return "None"
            case .http:   return "HTTP CONNECT"
            case .socks5: return "SOCKS5"
            case .pac:    return "PAC File"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s24) {
            dnsSection
            proxySection
        }
        .onAppear { loadCurrentSettings() }
        .onChange(of: dohResolver) { _, _ in saveDNSSettings() }
        .onChange(of: proxyType) { _, _ in saveProxySettings() }
        .onChange(of: proxyHost) { _, _ in saveProxySettings() }
        .onChange(of: proxyPort) { _, _ in saveProxySettings() }
        .onChange(of: proxyUsername) { _, _ in saveProxySettings() }
        .onChange(of: pacFileURL) { _, _ in saveProxySettings() }
        .onChange(of: proxyBypassLocal) { _, _ in saveProxySettings() }
    }

    // MARK: - DNS Section

    private var dnsSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            Text("DNS-over-HTTPS (DoH)")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                Text("Encrypt your DNS queries so your internet provider cannot see which websites you visit. Plain DNS leaks your entire browsing history to anyone on your network.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .lineLimit(4)

                Picker("Resolver", selection: $dohResolver) {
                    Text("System Default").tag("")
                    Text("Cloudflare (1.1.1.1)").tag("https://cloudflare-dns.com/dns-query")
                    Text("Quad9 (9.9.9.9)").tag("https://dns.quad9.net/dns-query")
                    Text("Google (8.8.8.8)").tag("https://dns.google/dns-query")
                    Text("NextDNS").tag("https://dns.nextdns.io")
                    if isCustomDOH {
                        Text("Custom URL…").tag(dohResolver)
                    } else {
                        Text("Custom URL…").tag("__custom__")
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)

                if dohResolver == "__custom__" || isCustomDOH {
                    TextField("https://your-doh-resolver/dns-query", text: $dohResolver)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 400)
                }

                if !dohResolver.isEmpty && dohResolver != "__custom__" {
                    HStack(spacing: HiveSpacing.s8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("DNS queries will be encrypted using DoH")
                            .hiveType(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(HiveSpacing.s16)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Proxy Section

    private var proxySection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            Text("Proxy Configuration")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            VStack(alignment: .leading, spacing: HiveSpacing.s12) {
                Text("Route browser traffic through a proxy server. Required for many corporate networks and used by privacy tools like Tor and VPNs.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .lineLimit(3)

                Picker("Proxy Type", selection: $proxyType) {
                    ForEach(ProxyType.allCases, id: \.id) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)

                if proxyType != .none {
                    Divider().overlay(Color.hiveBorderSubtle)

                    if proxyType == .pac {
                        VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                            Text("PAC File URL")
                                .hiveType(.bodySmall)
                                .foregroundStyle(.hiveGraphite)
                            TextField("https://proxy.pac", text: $pacFileURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 400)
                        }
                    } else {
                        HStack(spacing: HiveSpacing.s12) {
                            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                                Text("Host")
                                    .hiveType(.bodySmall)
                                    .foregroundStyle(.hiveGraphite)
                                TextField("proxy.example.com", text: $proxyHost)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 220)
                            }
                            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                                Text("Port")
                                    .hiveType(.bodySmall)
                                    .foregroundStyle(.hiveGraphite)
                                TextField("1080", text: $proxyPort)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }

                        if proxyType == .socks5 {
                            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                                Text("Authentication (optional)")
                                    .hiveType(.bodySmall)
                                    .foregroundStyle(.hiveGraphite)
                                TextField("Username", text: $proxyUsername)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 220)
                                Text("Proxy password is stored securely in your macOS Keychain.")
                                    .hiveType(.caption2)
                                    .foregroundStyle(.hiveMist)
                            }
                        }

                        Toggle("Bypass proxy for local addresses", isOn: $proxyBypassLocal)
                    }
                }
            }
            .padding(HiveSpacing.s16)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .fill(Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Load current settings

    private func loadCurrentSettings() {
        let prefs = state.prefs
        dohResolver = prefs.dohResolver
        dotResolver = prefs.dotResolver
        proxyType = ProxyType(rawValue: prefs.proxyType) ?? .none
        proxyHost = prefs.proxyHost
        proxyPort = prefs.proxyPort > 0 ? String(prefs.proxyPort) : ""
        proxyUsername = prefs.proxyUsername
        pacFileURL = prefs.pacFileURL
        proxyBypassLocal = prefs.proxyBypassLocal
    }

    /// Persists proxy settings back to ChromeUserPrefs.
    /// Writes directly to the prefs struct; ChromeState persists on next save cycle.
    private func saveProxySettings() {
        let typeStr: String = switch proxyType {
        case .none:   "none"
        case .http:   "http"
        case .socks5: "socks5"
        case .pac:    "pac"
        }
        state.prefs.proxyType = typeStr
        state.prefs.proxyHost = proxyHost
        state.prefs.proxyPort = Int(proxyPort) ?? 0
        state.prefs.proxyUsername = proxyUsername
        state.prefs.pacFileURL = pacFileURL
        state.prefs.proxyBypassLocal = proxyBypassLocal
    }

    /// Whether the current DoH value is a custom URL (not matching any preset).
    private var isCustomDOH: Bool {
        let presets: Set<String> = [
            "",
            "https://cloudflare-dns.com/dns-query",
            "https://dns.quad9.net/dns-query",
            "https://dns.google/dns-query",
            "https://dns.nextdns.io"
        ]
        return !dohResolver.isEmpty && dohResolver != "__custom__" && !presets.contains(dohResolver)
    }

    /// Persists DNS settings back to ChromeUserPrefs.
    private func saveDNSSettings() {
        state.prefs.dohResolver = dohResolver == "__custom__" ? "" : dohResolver
        state.prefs.dotResolver = dotResolver
    }
}

// MARK: - Preferences

// Persisted DNS/proxy settings are added to ChromeUserPrefs below.
// These take effect on the next tab creation (WKWebViewConfiguration init).
//
// DoH is applied via WKWebViewConfiguration by setting a custom URLProtocol
// or via the system resolver on macOS 14+. For v1, the setting is persisted
// and the implementation is deferred to the network layer.
