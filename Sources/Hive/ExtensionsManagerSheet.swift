import SwiftUI
import AppKit

// MARK: - ExtensionsManagerSheet
//
// Full extension management: install unpacked extensions (folder with
// manifest.json), enable/disable, pin/unpin to toolbar, and uninstall.
// Real CEF extension loading (chrome.webRequest, background pages) is
// gated on CEF extension API availability; this sheet manages the UI
// layer and extension metadata storage today.

struct ExtensionsManagerSheet: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if state.installedExtensions.isEmpty {
                emptyState
            } else {
                extensionList
            }

            Divider()
            footer
        }
        .frame(width: 460, height: 400)
        .background(HiveDesign.Material.panel)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "puzzlepiece.extension")
                .font(HiveDesign.Typography.panelTitle)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text("Extensions")
                .font(HiveDesign.Typography.heading)
            Spacer()
            if let msg = statusMessage {
                Text(msg)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(statusIsError ? .red : HiveDesign.Text.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(HiveDesign.Typography.subHeading)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var extensionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(state.installedExtensions) { ext in
                    extensionRow(ext)
                    Divider().padding(.leading, 48)
                }
            }
            .padding(.top, 4)
        }
    }

    private func extensionRow(_ ext: ExtensionItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ext.iconName)
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(HiveDesign.Accent.primary)
                .frame(width: 28, height: 28)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(ext.name)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(HiveDesign.Text.primary)
                if !ext.description.isEmpty {
                    Text(ext.description)
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                        .lineLimit(1)
                }
                Text("v\(ext.version)")
                    .font(HiveDesign.Typography.monoMicro)
                    .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.6))
            }

            Spacer()

            // Enable toggle
            Toggle(isOn: Binding(
                get: { ext.isEnabled },
                set: { _ in state.toggleExtensionEnabled(id: ext.id) }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(ext.isEnabled ? "Enabled" : "Disabled")

            // Pin toggle
            Button(action: { state.toggleExtensionPin(id: ext.id) }) {
                Image(systemName: ext.isPinned ? "pin.fill" : "pin")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(ext.isPinned ? HiveDesign.Accent.primary : HiveDesign.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help(ext.isPinned ? "Pinned to toolbar" : "Pin to toolbar")

            // Uninstall
            Button(action: { uninstall(ext) }) {
                Image(systemName: "trash")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Uninstall \(ext.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.5))
            Text("No extensions installed")
                .font(HiveDesign.Typography.panelTitle)
                .foregroundStyle(HiveDesign.Text.secondary)
            Text("Hive is built on Chromium. Install unpacked extensions from a local folder, or wait for Chrome Web Store support when the CEF extension API matures.")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: installFromFolder) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(HiveDesign.Typography.sidebarItemSemiBold)
                    Text("Install Extension…")
                        .font(HiveDesign.Typography.sidebarItemSemiBold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(HiveDesign.Accent.primary)
            .help("Select a folder containing an extension manifest.json")

            Spacer()

            Text("\(state.installedExtensions.count) installed")
                .font(HiveDesign.Typography.caption)
                .foregroundStyle(HiveDesign.Text.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func installFromFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Install Extension"
        panel.message = "Select a folder containing manifest.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Validate manifest.json exists
        let manifestURL = url.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            withAnimation { statusMessage = "No manifest.json found in selected folder"; statusIsError = true }
            return
        }

        // Basic manifest validation
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              manifest["name"] is String
        else {
            withAnimation { statusMessage = "Invalid manifest.json"; statusIsError = true }
            return
        }

        // Check for required manifest_version
        guard let version = manifest["manifest_version"] as? Int, version == 2 || version == 3 else {
            withAnimation { statusMessage = "manifest_version must be 2 or 3"; statusIsError = true }
            return
        }

        if let installed = state.installExtension(from: url) {
            withAnimation {
                statusMessage = "✓ \(installed.name) installed"
                statusIsError = false
            }
        } else {
            withAnimation { statusMessage = "Failed to install extension"; statusIsError = true }
        }
    }

    private func uninstall(_ ext: ExtensionItem) {
        state.uninstallExtension(id: ext.id)
        withAnimation {
            statusMessage = "\(ext.name) uninstalled"
            statusIsError = false
        }
    }
}
