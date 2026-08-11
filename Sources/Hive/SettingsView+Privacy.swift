//
//  SettingsView+Privacy.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Privacy
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + Privacy

@MainActor
extension SettingsView {


    // MARK: - Privacy

    var privacyTab: some View {
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

            settingsGroup("HTTPS-Only Mode") {
                Toggle("Always use secure connections", isOn: $state.isHTTPSOnlyEnabled)
                Text("Upgrades plaintext HTTP addresses to HTTPS and warns when a page still loads over HTTP. Use \"Load anyway\" on the warning to allow a site to stay on HTTP.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !state.httpsOnlyExceptions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sites allowed to use HTTP")
                            .font(HiveDesign.Typography.smallLabelBold)
                            .foregroundStyle(.secondary)
                        ForEach(Array(state.httpsOnlyExceptions).sorted(), id: \.self) { host in
                            HStack(spacing: 6) {
                                Text(host)
                                    .font(HiveDesign.Typography.smallLabel)
                                    .lineLimit(1)
                                Spacer()
                                Button("Remove") {
                                    var exceptions = state.httpsOnlyExceptions
                                    exceptions.remove(host)
                                    state.httpsOnlyExceptions = exceptions
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            settingsGroup("Clear Browsing Data") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove browsing history, downloads, cookies, and cache")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Clear Browsing Data…") { state.isClearDataPanelOpen = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            settingsGroup("Site Settings") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review per-site zoom, mute, HTTPS-Only, and permission decisions")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Manage Site Settings…") { state.openSiteSettings() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            settingsGroup("Safety Check") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review saved passwords, Safe Browsing, extensions, updates, and notification permissions")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Run Safety Check…") { state.isSafetyCheckPanelOpen = true }
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
    func loadSafeBrowsingKey() {
        safeBrowsingKeyInput = KeychainSecretStore.read(key: GoogleSafeBrowsingClient.apiKeyAccount) ?? ""
    }


    /// Commits the current field value to Keychain. Debounced via
    /// onChange so typing doesn't hammer the Keychain on every keystroke.
    func commitSafeBrowsingKey() {
        let trimmed = safeBrowsingKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainSecretStore.delete(key: GoogleSafeBrowsingClient.apiKeyAccount)
        } else {
            KeychainSecretStore.save(key: GoogleSafeBrowsingClient.apiKeyAccount, value: trimmed)
        }
    }
}
