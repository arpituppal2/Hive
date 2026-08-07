import SwiftUI

// MARK: - ExtensionsManagerSheet
//
// Presented from the ExtensionsToolbar (and reachable once a real extension
// runtime exists). The current CefKit integration does not expose extension
// loading or lifecycle APIs, so the sheet currently shows an honest empty
// state — pinned icons open it rather than faking an assistant response.

struct ExtensionsManagerSheet: View {
    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "puzzlepiece.extension")
                    .font(HiveDesign.Typography.panelTitle)
                    .foregroundStyle(HiveDesign.Accent.primary)
                Text("Extensions")
                    .font(HiveDesign.Typography.heading)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.subHeading)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if state.installedExtensions.isEmpty {
                emptyState
            } else {
                extensionList
            }
        }
        .frame(width: 420, height: 360)
        .background(HiveDesign.Material.panel)
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
                .frame(width: 26, height: 26)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(ext.name)
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(HiveDesign.Text.primary)

            Spacer()

            Toggle(isOn: Binding(
                get: { ext.isEnabled },
                set: { _ in state.toggleExtensionEnabled(id: ext.id) }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Enabled")

            Toggle(isOn: Binding(
                get: { ext.isPinned },
                set: { _ in state.toggleExtensionPin(id: ext.id) }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Pinned to toolbar")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.6))
            Text("No extensions installed")
                .font(HiveDesign.Typography.panelTitle)
                .foregroundStyle(HiveDesign.Text.secondary)
            Text("Hive is built on Chromium, so Chrome Web Store extensions are on the roadmap. Installed extensions will appear here with enable and toolbar-pin controls.")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
