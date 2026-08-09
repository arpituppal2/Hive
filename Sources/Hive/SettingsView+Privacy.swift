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
